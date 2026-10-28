/// SearchPort —— 平台内搜索契约（R1 增量，2026-10-24）。
///
/// 产品语境：未登录态即可搜索（B 站公开搜索面）；登录态用于提高提取音质，
/// 不作为搜索前置门禁。抖音无免登录搜索通道（平台签名墙），契约保留平台
/// 枚举以便诚实降级（UI 明示「粘贴分享链接」路径），不伪造结果。
///
/// 纪律：
/// * 结果 title 必须去除平台高亮标记（`<em>` 等），调用方直接展示；
/// * coverUrl 一律返回绝对 https 地址（`//host/...` 协议相对形态由实现补全）；
/// * durationMs 由实现从平台原生形态（"4:30" / 秒数）归一为毫秒；
/// * 搜索不得携带任何凭据要求：`AuthRequiredSearchException` 仅在平台风控
///   明确要求登录时抛出（人话文案由 UI 层组织）。
library;

/// 支持搜索的平台（与 tracks.sourceType 同族词汇；诚实降级面）。
enum SearchPlatform { bilibili, douyin }

/// 平台内搜索的单条结果（未解析态——qualities 由提取时的二次 resolve 补全）。
final class SearchResult {
  const SearchResult({
    required this.platform,
    required this.sourceId,
    required this.url,
    required this.title,
    required this.uploader,
    required this.durationMs,
    this.coverUrl,
    this.playCount,
    this.publishedAtMs,
  });

  final SearchPlatform platform;

  /// 平台内容 ID（B 站=BV 号；提取复用 extract_tasks.source_id 同域）。
  final String sourceId;

  /// 可直接解析/下载的规范内容页地址。
  final String url;
  final String title;
  final String uploader;

  /// 归一毫秒（搜索面缺失时=0，UI 显示「--:--」，不伪造）。
  final int durationMs;

  /// 绝对 https 封面地址（缺失=null）。
  final String? coverUrl;

  /// 平台播放量（B 站=play 计数；展示「12.3万」由 UI 归一）。
  final int? playCount;

  /// 发布时刻 epoch ms（缺失=null）。
  final int? publishedAtMs;
}

abstract class SearchPort {
  /// 关键词搜索（REQ-SEARCH-01；≤3s 量级由实现自查，不阻塞串行泵）。
  ///
  /// 抛出：
  /// * `AuthRequiredSearchException`：平台风控明确要求登录；
  /// * `FormatException`：关键词为空等输入面问题。
  Future<List<SearchResult>> search(
    String keyword, {
    SearchPlatform platform = SearchPlatform.bilibili,
    int limit = 20,
  });
}

/// 平台风控要求登录（UI 引导登录；不与网络失败混同）。
class AuthRequiredSearchException implements Exception {
  const AuthRequiredSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}
