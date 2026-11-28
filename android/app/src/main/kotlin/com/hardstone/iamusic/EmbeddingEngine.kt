package com.hardstone.iamusic

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.math.min
import kotlin.math.sqrt
import org.tensorflow.lite.Interpreter

/// 音频嵌入引擎——推理模块（lib/inference）的原生侧：**只负责推理**。
/// 按调用方传入的模型文件路径装载并计算：解码 → 下混/16kHz 重采样 →
/// 分帧推理 → 帧均值 → L2 归一化。不做任何模型文件管理（下载/存储/
/// 校验归 data 层 ModelStore）——路径换装自动重载解释器。
///
/// 失败分级（与 Dart 侧 adapter 契约对应）：
/// * 模型装载/签名自检失败 → error code "model"（端口级，Dart 会话禁用）；
/// * 单曲解码/推理失败 → error code "embed"（曲目级，Dart 记账重试）。
class EmbeddingEngine {
    private val channelName = "ia_music/embedding"

    @Volatile
    private var activeModelPath: String? = null

    @Volatile
    private var interpreter: Interpreter? = null

    /** 注册 MethodChannel（MainActivity.configureFlutterEngine 里调用一次）。 */
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "embed") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val modelPath = call.argument<String>("modelPath")
                val maxSeconds = call.argument<Int>("maxSeconds") ?: 120
                if (path == null || modelPath == null) {
                    result.error("args", "path/modelPath required", null)
                    return@setMethodCallHandler
                }
                Thread {
                    try {
                        // 模型装载/签名自检失败 = 端口级（error code "model"，
                        // Dart 侧吞为 null 会话禁用）；单曲解码/推理失败 =
                        // 曲目级（error code "embed"，Dart 侧记账重试）。
                        val itp = try {
                            interpreterFor(modelPath)
                        } catch (e: Throwable) {
                            runOnMain {
                                result.error("model", e.message ?: "model load failed", null)
                            }
                            return@Thread
                        }
                        val vec = embedTrack(itp, path, maxSeconds)
                        runOnMain { result.success(vec) }
                    } catch (e: Throwable) {
                        runOnMain { result.error("embed", e.message, null) }
                    }
                }.start()
            }
    }

    /** 通道回传必须回到主线程（MethodChannel 契约）。 */
    private fun runOnMain(block: () -> Unit) {
        Handler(Looper.getMainLooper()).post(block)
    }

    /** 单曲嵌入：解码 → 下混/16kHz 重采样 → 分帧推理 → 帧均值 → L2 归一化。 */
    @Synchronized
    private fun embedTrack(itp: Interpreter, path: String, maxSeconds: Int): List<Float> {
        val outIdx = embeddingOutputIndex(itp)
            ?: throw IllegalStateException("no 1024-d embedding output")
        val mem = ByteArrayOutputStream()
        val (sr, ch) = PcmDecoder.decodeToPcmStream(path, maxSeconds, mem)
        if (sr <= 0 || ch <= 0) throw IllegalStateException("bad decode format")

        // 16-bit LE → 下混单声道（逐声道平均）→ 线性插值重采样到 16kHz
        // （与 Dart 侧指纹链 _toMono11025 同款算法思路）。
        val shorts = ByteBuffer.wrap(mem.toByteArray()).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
        val srcFrames = shorts.remaining() / ch
        if (srcFrames <= 0) throw IllegalStateException("empty decode output")
        val mono = FloatArray(srcFrames)
        for (i in 0 until srcFrames) {
            var acc = 0f
            for (c in 0 until ch) acc += shorts.get(i * ch + c) / 32768f
            mono[i] = acc / ch
        }
        val dstRate = 16000
        val dst = FloatArray(((srcFrames.toLong() * dstRate) / sr).toInt().coerceAtLeast(1))
        for (j in dst.indices) {
            val pos = j.toDouble() * sr / dstRate
            val i0 = pos.toInt().coerceAtMost(srcFrames - 1)
            val i1 = (i0 + 1).coerceAtMost(srcFrames - 1)
            val frac = (pos - i0).toFloat()
            dst[j] = mono[i0] * (1 - frac) + mono[i1] * frac
        }

        // 分帧推理：0.975s 帧（15600 样本）+ 0.75 重叠步进（11700）——
        // TF 官方教程口径；尾帧静音补齐（短文件也能出一个有效向量）。
        val frameSize = 15600
        val hop = 11700
        val inputBuf = ByteBuffer.allocateDirect(frameSize * 4).order(ByteOrder.nativeOrder())
        val inputFb = inputBuf.asFloatBuffer()
        val outBuf = ByteBuffer.allocateDirect(1024 * 4).order(ByteOrder.nativeOrder())
        val frame = FloatArray(frameSize)
        val sum = DoubleArray(1024)
        var n = 0
        var pos = 0
        do {
            java.util.Arrays.fill(frame, 0f)
            val take = min(frameSize, dst.size - pos)
            System.arraycopy(dst, pos, frame, 0, take)
            inputBuf.rewind()
            inputFb.rewind()
            inputFb.put(frame)
            outBuf.rewind()
            // outputs 按张量索引寻址（TFLite/LiteRT Java API 契约）
            itp.runForMultipleInputsOutputs(arrayOf<Any>(inputBuf), mapOf(outIdx to outBuf))
            outBuf.rewind()
            val ob = outBuf.asFloatBuffer()
            if (ob.remaining() != 1024) {
                throw IllegalStateException("embedding output dim ${ob.remaining()}")
            }
            for (k in 0 until 1024) sum[k] += ob.get(k).toDouble()
            n++
            pos += hop
        } while (pos < dst.size)
        if (n == 0) throw IllegalStateException("no frames inferred")

        val vec = FloatArray(1024)
        var norm = 0.0
        for (k in 0 until 1024) {
            vec[k] = (sum[k] / n).toFloat()
            norm += vec[k].toDouble() * vec[k].toDouble()
        }
        norm = sqrt(norm)
        if (norm > 0) {
            for (k in 0 until 1024) vec[k] = (vec[k] / norm).toFloat()
        }
        return vec.toList()
    }

    /** 解释器按模型路径换装：路径变更（换模型/重下）即重载，同路径复用。 */
    private fun interpreterFor(modelPath: String): Interpreter {
        if (interpreter != null && activeModelPath == modelPath) {
            return interpreter!!
        }
        synchronized(this) {
            if (interpreter != null && activeModelPath == modelPath) {
                return interpreter!!
            }
            interpreter?.close()
            interpreter = null
            val itp = Interpreter(loadModelFile(modelPath), Interpreter.Options().setNumThreads(2))
            val inShape = itp.getInputTensor(0).shape()
            if (inShape.isEmpty() || inShape[inShape.size - 1] != 15600) {
                itp.close()
                throw IllegalStateException("unexpected embedding input shape")
            }
            if (embeddingOutputIndex(itp) == null) {
                itp.close()
                throw IllegalStateException("no 1024-d embedding output")
            }
            interpreter = itp
            activeModelPath = modelPath
            return itp
        }
    }

    /** 按 shape 末维选 1024 的输出张量下标——不依赖 Identity 固定序号。 */
    private fun embeddingOutputIndex(itp: Interpreter): Int? {
        for (i in 0 until itp.outputTensorCount) {
            val shape = itp.getOutputTensor(i).shape()
            if (shape.isNotEmpty() && shape[shape.size - 1] == 1024) {
                return i
            }
        }
        return null
    }

    /** 模型文件 mmap 装载（data 层 ModelStore 管理的沙箱文件，非 assets）。 */
    private fun loadModelFile(path: String): MappedByteBuffer {
        val f = File(path)
        FileInputStream(f).use { fin ->
            return fin.getChannel().map(FileChannel.MapMode.READ_ONLY, 0, f.length())
        }
    }
}
