/// 元数据解析契约（只读：解析 tag 与内嵌封面；写回 tag 属未来扩展，另立方法）。
library;

import '../errors.dart';

class ParsedTags {
  const ParsedTags({
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.trackNo,
    required this.durationMs,
    required this.audioFormat,
  });

  final String title;
  final String artist;
  final String album;

  /// 流派裸值（可空串——无标签即空，UI 侧隐藏流派入口）。
  final String genre;
  final int trackNo;
  final int durationMs;
  final String audioFormat;
}

abstract class MetadataPort {
  /// 解析标签裸值（不读内嵌图——封面走 CoverPort，避免整文件二次读）。
  /// 文件损坏/不可读 → 抛 [MetadataError]。
  Future<ParsedTags> readTags(String path);

  /// 读取内嵌封面（若有）；无或损坏 → null。
  Future<List<int>?> readEmbeddedCover(String path);

  /// 读取内嵌歌词（USLT/LYRICS 原文）；无 → null。
  Future<String?> readEmbeddedLyrics(String path);
}
