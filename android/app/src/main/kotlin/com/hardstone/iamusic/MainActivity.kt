package com.hardstone.iamusic

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/// 平台通道装配层——各底层能力模块在此注册：
/// * ia_music/fingerprint  指纹识别（chromaprint FFI 的 PCM 供给，adapters 域）
/// * ia_music/embedding    音频嵌入（EmbeddingEngine，推理域 lib/inference）
/// 业务实现分别在 PcmDecoder（解码原语）/ EmbeddingEngine（推理引擎）。
class MainActivity : AudioServiceActivity() {
    private val fingerprintChannel = "ia_music/fingerprint"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerFingerprintChannel(flutterEngine)
        EmbeddingEngine().register(flutterEngine.dartExecutor.binaryMessenger)
    }

    /** 指纹识别：MediaCodec 解码 → 落临时 PCM 文件（chromaprint FFI 在 Dart 侧消费）。 */
    private fun registerFingerprintChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fingerprintChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "decodePcm") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val outPath = call.argument<String>("outPath")
                val maxSeconds = call.argument<Int>("maxSeconds") ?: 110
                if (path == null || outPath == null) {
                    result.error("args", "path/outPath required", null)
                    return@setMethodCallHandler
                }
                Thread {
                    try {
                        val info = decodeToPcm(path, outPath, maxSeconds)
                        runOnUiThread { result.success(info) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("decode", e.message, null) }
                    }
                }.start()
            }
    }

    /** MediaCodec 解码为 16-bit PCM（源采样率/声道），写到 outPath。
     *  重采样/下混在 Dart 侧做，避免在平台层堆 DSP。 */
    private fun decodeToPcm(path: String, outPath: String, maxSeconds: Int): Map<String, Any> {
        val out = FileOutputStream(File(outPath))
        try {
            val (sr, ch) = PcmDecoder.decodeToPcmStream(path, maxSeconds, out)
            return mapOf(
                "sampleRate" to sr,
                "channels" to ch,
                "bytes" to File(outPath).length(),
            )
        } finally {
            try {
                out.close()
            } catch (_: Exception) {
            }
        }
    }
}
