/// 歌词在线来源契约。
library;

import '../errors.dart';

class LyricHit {
  const LyricHit({required this.syncedLrc, required this.plainLrc});

  /// 逐行同步歌词（LRC 文本）；可能为空串。
  final String syncedLrc;

  /// 纯文本歌词兜底。
  final String plainLrc;
}

/// 在线歌词库的候选匹配（含元数据，供反向重建采纳）。
class LrcMatch {
  const LrcMatch({
    required this.trackName,
    required this.artistName,
    required this.durationMs,
    required this.syncedLrc,
    required this.plainLrc,
  });

  final String trackName;
  final String artistName;
  final int durationMs;
  final String syncedLrc;
  final String plainLrc;
}

abstract class LyricTextSearchPort {
  /// 精确匹配（时长锚 ±2s）；未命中返回 null（不抛——调用方记账）。
  Future<LyricHit?> getByFields({
    required String title,
    required String artist,
    int? durationMs,
  });

  /// 关键词模糊检索；未命中/网络失败 → null 或抛 [NetworkError]。
  Future<LyricHit?> search(String query);

  /// 候选检索（含 trackName/artistName/duration），供元数据补全反向匹配。
  /// 网络失败 → 抛 [NetworkError]。
  Future<List<LrcMatch>> searchMatches(String query);
}
