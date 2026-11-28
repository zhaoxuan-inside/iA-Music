package com.hardstone.iamusic

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Build
import java.io.OutputStream

/// MediaCodec PCM 解码核心——指纹链（写文件）与嵌入链（写内存）共用的
/// 底层 DSP 原语。16-bit PCM 原始字节流输出（源采样率/声道），
/// 重采样/下混留在各消费侧。
object PcmDecoder {
    /** 解码 [path] 至多 [maxSeconds] 秒，PCM 字节写入 [out]，返回 (sampleRate, channels)。 */
    fun decodeToPcmStream(path: String, maxSeconds: Int, out: OutputStream): Pair<Int, Int> {
        val extractor = MediaExtractor()
        extractor.setDataSource(path)
        var trackIndex = -1
        var format: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val f = extractor.getTrackFormat(i)
            val mime = f.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("audio/")) {
                trackIndex = i
                format = f
                break
            }
        }
        val selected = format ?: throw IllegalArgumentException("no audio track")
        if (trackIndex < 0) throw IllegalArgumentException("no audio track")
        extractor.selectTrack(trackIndex)

        val mime = selected.getString(MediaFormat.KEY_MIME)
            ?: throw IllegalArgumentException("audio mime missing")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            selected.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
        }
        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(selected, null, null, 0)
        codec.start()

        var sampleRate = selected.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var channels = selected.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val info = MediaCodec.BufferInfo()
        val maxUs = maxSeconds.toLong() * 1_000_000L
        var inputDone = false
        var outputDone = false

        try {
            while (!outputDone) {
                if (!inputDone) {
                    val inIdx = codec.dequeueInputBuffer(10_000)
                    if (inIdx >= 0) {
                        val buf = codec.getInputBuffer(inIdx)
                        val size = if (buf == null) -1 else extractor.readSampleData(buf, 0)
                        val time = extractor.sampleTime
                        if (buf == null || size < 0 || time > maxUs) {
                            codec.queueInputBuffer(
                                inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(inIdx, 0, size, time, 0)
                            extractor.advance()
                        }
                    }
                }

                val outIdx = codec.dequeueOutputBuffer(info, 10_000)
                if (outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val of = codec.outputFormat
                    if (of.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        sampleRate = of.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    }
                    if (of.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        channels = of.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                        of.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                        of.getInteger(MediaFormat.KEY_PCM_ENCODING) != AudioFormat.ENCODING_PCM_16BIT
                    ) {
                        throw IllegalStateException("decoder output is not 16-bit PCM")
                    }
                } else if (outIdx >= 0) {
                    val buf = codec.getOutputBuffer(outIdx)
                    if (buf != null && info.size > 0) {
                        val chunk = ByteArray(info.size)
                        buf.position(info.offset)
                        buf.get(chunk)
                        out.write(chunk)
                    }
                    codec.releaseOutputBuffer(outIdx, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        outputDone = true
                    }
                }
            }
        } finally {
            try {
                codec.stop()
            } catch (_: Exception) {
            }
            codec.release()
            extractor.release()
        }

        return Pair(sampleRate, channels)
    }
}
