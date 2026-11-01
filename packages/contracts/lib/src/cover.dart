/// CoverFetchPort —— 封面在线补缺契约（CAA 主源 + iTunes 兜底）。
///
/// 红线（C22）：**只补缺不覆盖**——调用方（CoverChain）决策顺序：
/// 内嵌图 > 同目录图 > 本 Port（仅完全无封面才允许调用）> 首字母色块。
///
/// 实现约束：令牌桶 1 req/s；UA 强制；失败/离线返回 null（静默，不抛、不重试）。
library;

final class CoverQuery {
  const CoverQuery({required this.trackId, required this.title, this.artistDisplay, this.albumDisplay});

  final int trackId;
  final String title;
  final String? artistDisplay;
  final String? albumDisplay;
}

enum CoverSource { caa, itunes }

final class CoverResult {
  const CoverResult({required this.localPath, required this.source, this.width, this.height});

  /// 已落盘的本地封面文件（同目录 `.cover.jpg` 或缓存位；落位由调用方执行）。
  final String localPath;
  final CoverSource source;
  final int? width;
  final int? height;
}

abstract class CoverFetchPort {
  /// 命中返回结果（含已下载临时文件路径），未命中/离线/失败 → `null`（静默）。
  Future<CoverResult?> fetchTrackCover(CoverQuery query);
}
