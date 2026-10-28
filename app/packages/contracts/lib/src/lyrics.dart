/// LyricsPort —— 歌词检索契约（T9C 批次，2026-10-19 开发者裁决）。
///
/// 裁决（开发者当次会话拍板）：
/// * 歌词来源分级：**LRCLIB（lrclib.net，免 key 正规 API）优先 + 真 ASR 兜底**
///   （ASR 运行时未装配=既往 T10/RV-C 挂账；宿主无 onnxruntime，src/model 位
///    `C:/Users/hardstone/tools/r3/sensevoice/model.int8.onnx` 实测在）。
/// * 「根据歌词反查歌名歌手」：**正文反查引擎暂缺**（实证：LRCLIB /api/search
///   对真实歌词句 q=0 结果，不索引歌词正文）→ 本批次以 LRCLIB 条件检索返回的
///   **正式 trackName/artistName/albumName 补全曲目元数据**（title/artist 域）；
///   正文反查源（Musixmatch 商业 API / 网易灰接口）挂账待开发者另行拍板。
library;

/// `resolve(q)` 的请求面（题名/歌手/时长锚；不传 cook/token）。
final class LyricsQuery {
  const LyricsQuery({
    required this.trackId,
    required this.title,
    this.artistDisplay,
    this.albumDisplay,
    this.durationMs,
  });

  final int trackId;
  final String title;
  final String? artistDisplay;
  final String? albumDisplay;

  /// 时长锚（LRCLIB 候选定锚 ±2s；null=不锚）。
  final int? durationMs;
}

/// 歌词来源（DEC-011 分级；asr=T10 兜底位，本批次不会产出）。
enum LyricsSource { lrclib, asr }

/// `resolve(q)` 的产物（全量年为真网络真实返回面；未命中=null）。
final class LyricsResolution {
  const LyricsResolution({
    required this.source,
    required this.trackName,
    required this.artistName,
    this.albumName,
    this.plainLyrics,
    this.syncedLyrics,
    this.durationSec,
  });

  final LyricsSource source;

  /// LRCLIB 正规检索面（词库正式歌名，即「歌名歌手等信息」补全源）。
  final String trackName;
  final String artistName;
  final String? albumName;
  final String? plainLyrics;

  /// `[mm:ss.xx]行` 同步歌词（REQ-LYR-03 存同目录 `.lrc`）。
  final String? syncedLyrics;

  /// 候选曲目时长（秒；时长锚定依据）。
  final int? durationSec;
}

abstract class LyricsPort {
  /// 按题名/歌手/时长条件检索歌词与正规元数据（LRCLIB /api/get → /api/search
  /// 兜底；全量真网；未命中/服务故障 → null，不抛——调用方按未命中记账）。
  Future<LyricsResolution?> resolve(LyricsQuery q);
}
