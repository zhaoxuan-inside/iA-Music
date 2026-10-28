/// MetadataPort —— 音频元数据只读契约（audio_metadata_reader）。
///
/// 红线（REQ-LIB-03）：**绝不写回原文件**——本 Port 不提供任何写方法。
library;

/// 音频格式枚举（§1.2 tracks.audio_format 一致）。
enum AudioFormat { mp3, flac, m4a, ogg, wav, ape }

final class ParsedMeta {
  const ParsedMeta({
    required this.title,
    required this.artistDisplay,
    required this.albumDisplay,
    required this.durationMs,
    required this.format,
    required this.fileSizeBytes,
    required this.mtimeMs,
    this.embeddedCoverPath,
    this.sampleRate,
    this.channels,
  });

  final String title;
  final String artistDisplay;
  final String albumDisplay;
  final int durationMs;
  final AudioFormat format;
  final int fileSizeBytes;
  final int mtimeMs;

  /// 内嵌封面被解出时的临时文件路径（**不落原文件旁**；调用方决定缓存位）。
  final String? embeddedCoverPath;
  final int? sampleRate;
  final int? channels;
}

abstract class MetadataPort {
  /// 只读解析；损坏文件 → `FormatException`（调用方按 skipped 计数，REQ-LIB-01）。
  Future<ParsedMeta> read(String audioPath);
}
