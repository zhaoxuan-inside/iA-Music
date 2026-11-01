/// BilibiliSearchAdapter —— SearchPort 的 B 站实现（免登录 Web 搜索面）。
///
/// 通道（EXP-2026-10-24 实测）：
/// * `finger/spi` 引导 buvid3/buvid4 → `nav` 取 wbi key → `wbi/search/type`
///   签名搜索（search_type=video）；全程无登录要求，SESSDATA 在池则随行。
/// * 结果映射：title 去 `<em class="keyword">` 高亮；duration "4:30"/"1:02:03"
///   → ms；pic `//i0.hdslb.com/...` → https 绝对地址。
/// * 抖音：平台签名墙无免登录通道 → 抛 `AuthRequiredSearchException`（诚实
///   降级，UI 引导粘贴分享链接路径），不伪造结果。
library;

import 'dart:convert';

import 'package:contracts/contracts.dart';
import 'package:ia_music/adapters/bilibili_client.dart';
import 'package:ia_music/l10n/s.dart';

final class BilibiliSearchAdapter implements SearchPort {
  BilibiliSearchAdapter({BilibiliClient? client})
      : _client = client ?? BilibiliClient();

  final BilibiliClient _client;

  /// 登录态透出（UI 引导卡消费）。
  bool get hasLoginCookie => _client.hasLoginCookie;

  /// 登录域接入点（登录成功后搜索结果面即携 SESSDATA）。
  BilibiliClient get client => _client;

  @override
  Future<List<SearchResult>> search(
    String keyword, {
    SearchPlatform platform = SearchPlatform.bilibili,
    int limit = 20,
  }) async {
    final kw = keyword.trim();
    if (kw.isEmpty) {
      throw FormatException(msg.searchQueryEmpty);
    }
    if (platform == SearchPlatform.douyin) {
      throw AuthRequiredSearchException(msg.douyinUnsupported);
    }
    final j = await _client.getJsonSigned(
      Uri.parse('https://api.bilibili.com/x/web-interface/wbi/search/type'),
      {
        'search_type': 'video',
        'keyword': kw,
        'page': '1',
        'page_size': '$limit',
        'order': 'totalrank',
      },
    );
    final code = j['code'];
    if (code == -412 || code == -352) {
      throw AuthRequiredSearchException(msg.riskControlIntercepted);
    }
    if (code != 0) {
      throw FormatException(msg.searchApiFailed(
          '${j['code']}', '${j['message'] ?? msg.unknownReason}'));
    }
    return mapBiliSearchJson(j).take(limit).toList(growable: false);
  }

  /// 高亮标记剥离（`<em class="keyword">晴天</em>` → 晴天）。
  static String _stripHighlight(String raw) => raw
      .replaceAll(RegExp(r'<em[^>]*>'), '')
      .replaceAll('</em>', '')
      .replaceAll(RegExp(r'<[^>]+>'), '');

  /// "4:30" | "1:02:03" → ms（无法解析=0，UI 显示 --:--，不伪造）。
  static int _parseDuration(String raw) {
    final parts = raw.split(':');
    if (parts.isEmpty || parts.length > 3) {
      return 0;
    }
    var secs = 0;
    for (final p in parts) {
      final v = int.tryParse(p.trim());
      if (v == null) {
        return 0;
      }
      secs = secs * 60 + v;
    }
    return secs * 1000;
  }

  /// 协议相对地址 → https 绝对。
  static String? _absUrl(String raw) {
    if (raw.isEmpty) {
      return null;
    }
    if (raw.startsWith('//')) {
      return 'https:$raw';
    }
    if (raw.startsWith('http')) {
      return raw;
    }
    return 'https://$raw';
  }
}

/// 搜索结果 JSON（测试固定样本）反序列化（页面/测试共用映射面）。
List<SearchResult> mapBiliSearchJson(Map<String, dynamic> j) {
  final data = (j['data'] as Map?)?.cast<String, dynamic>() ?? const {};
  final rows = (data['result'] as List? ?? const []);
  final out = <SearchResult>[];
  for (final row in rows) {
    if (row is! Map) {
      continue;
    }
    final m = Map<String, dynamic>.from(row.cast<Object?, Object?>());
    if ('${m['type'] ?? ''}' != 'video') {
      continue;
    }
    final bvid = '${m['bvid'] ?? ''}';
    if (bvid.isEmpty) {
      continue;
    }
    out.add(SearchResult(
      platform: SearchPlatform.bilibili,
      sourceId: bvid,
      url: 'https://www.bilibili.com/video/$bvid',
      title: BilibiliSearchAdapter._stripHighlight('${m['title'] ?? bvid}'),
      uploader: '${m['author'] ?? ''}',
      durationMs: BilibiliSearchAdapter._parseDuration('${m['duration'] ?? ''}'),
      coverUrl: BilibiliSearchAdapter._absUrl('${m['pic'] ?? ''}'),
      playCount: (m['play'] is num) ? (m['play'] as num).toInt() : null,
      publishedAtMs: (m['pubdate'] is num)
          ? (m['pubdate'] as num).toInt() * 1000
          : null,
    ));
  }
  return out;
}

/// 搜索历史设置键（settings kv；JSON list，≤10 条）。
const String kSearchHistoryKey = 'search.history';

/// JSON list → 关键词列表（装载容错）。
List<String> decodeSearchHistory(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  try {
    final v = jsonDecode(raw);
    if (v is List) {
      return v.whereType<String>().toList();
    }
  } on FormatException {
    // 损坏=视为无历史
  }
  return const [];
}
