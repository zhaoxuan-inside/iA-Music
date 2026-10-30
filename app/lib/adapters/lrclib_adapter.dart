/// LrclibAdapter —— T9C（歌词域第一批）LyricsPort 桌面/Android 双态实现。
///
/// 纪律：
/// * lrclib.net 免 key 正规 API：`/api/get`（参数全对，404 频现）→
///   `/api/search?track_name&artist_name` 兜底 → 模糊 `q` 末兜底；
///   时长锚 ±2s（DEC-011）。
/// * 代理：`findProxyFromEnvironment`（宿主 HTTPS_PROXY）；Android 由系统全局
///   http_proxy 验证配置（验证布点语义，非产品行为）。
/// * UA 诚实；全量真网络；未命中/非 200 → null/空（不抛）——调用方记账。
/// * 正文反查红线：LRCLIB 实证不索引歌词正文（真实歌词句 q=0）→ 本适配器
///   只做条件检索；正文反查源=T10 挂账（Musixmatch 商业 / 网易灰，待拍板）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';

final class LrclibAdapter implements LyricsPort {
  LrclibAdapter({String? proxy, DateTime Function()? now})
      : _now = now ?? DateTime.now {
    if (proxy != null) {
      // findProxy 语法=PROXY host:port（无 scheme）；调用方惯传 env 形态
      // http://host:port——归一化剥 scheme（模拟器实证 10.0.2.2:7897 直通、
      // 带 scheme 宿主实测全 -1）。
      var p = proxy;
      if (p.startsWith('http://') || p.startsWith('https://')) {
        p = Uri.parse(p).authority;
      }
      _http.findProxy = (_) => 'PROXY $p';
    }
  }

  /// 诊断面只观测真实出网（同 CoverFetchAdapter 惯例），永不替代运输层。
  final List<({Uri uri, DateTime startedAt})> requests = [];
  final List<({Uri uri, int statusCode})> responses = [];
  final List<({Uri uri, int statusCode, String snippet})> failures = [];

  final DateTime Function() _now;
  static const userAgent =
      'iA-Music/0.1 (https://github.com/HardStone/iA-Music)';
  final HttpClient _http = HttpClient()
    ..findProxy = HttpClient.findProxyFromEnvironment
    ..connectionTimeout = const Duration(seconds: 10);

  static const _host = 'lrclib.net';

  Uri _get(String path, Map<String, String> params) =>
      Uri.https(_host, path, params);

  @override
  Future<LyricsResolution?> resolve(LyricsQuery q) async {
    final title = q.title.trim();
    if (title.isEmpty) {
      return null;
    }
    final artist = (q.artistDisplay ?? '').trim();
    if (artist.isNotEmpty) {
      final got = await _json(_get('/api/get', {
        'track_name': title,
        'artist_name': artist,
        if (q.durationMs != null)
          'duration': '${(q.durationMs! / 1000).round()}',
      }));
      if (got != null && _accept(got, q)) {
        return _toResolution(got);
      }
    }
    // /api/search 条件兜底（载荷=裸数组；按返回序优先时长锚匹配候选）。
    // T9C 增量（2026-10-19）：末兜底补「仅 track_name」检索——B 站单 P 标题
    // 尾巴（【Hi-Res…】等）污染 artist 参数时 404/空频现（实证 孤勇者）；
    // 仅曲名+时长锚 ±2s（DEC-011）足够锚定正主。
    for (final items in [
      await _searchList(_get('/api/search', {
        if (artist.isNotEmpty) 'artist_name': artist,
        'track_name': title,
      })),
      await _searchList(_get('/api/search', {
        'q': artist.isEmpty ? title : '$artist $title',
      })),
      if (q.durationMs != null)
        await _searchList(_get('/api/search', {'track_name': title})),
    ]) {
      for (final it in items) {
        if (_accept(it, q)) {
          return _toResolution(it);
        }
      }
    }
    return null;
  }

  /// 候选接受规则：同步/纯文本歌词至少一项非空；时长锚 ±2s（有锚时）。
  bool _accept(Map<String, dynamic> cand, LyricsQuery q) {
    final hasLyric =
        ((cand['syncedLyrics'] as String?)?.trim().isNotEmpty ?? false) ||
            ((cand['plainLyrics'] as String?)?.trim().isNotEmpty ?? false);
    if (!hasLyric) {
      return false;
    }
    final dur = (cand['duration'] as num?)?.toInt();
    if (q.durationMs != null && dur != null) {
      return (dur * 1000 - q.durationMs!).abs() <= 2000;
    }
    return true;
  }

  LyricsResolution _toResolution(Map<String, dynamic> j) => LyricsResolution(
        source: LyricsSource.lrclib,
        trackName: (j['trackName'] as String?) ?? '',
        artistName: (j['artistName'] as String?) ?? '',
        albumName: j['albumName'] as String?,
        plainLyrics: j['plainLyrics'] as String?,
        syncedLyrics: j['syncedLyrics'] as String?,
        durationSec: (j['duration'] as num?)?.toInt(),
      );

  /// 底层真网 GET。纪律：
  /// * 传输层异常（连接/TLS 抖动——宿主代理对 lrclib.net 高频 SSL EOF 实测，
  ///   2026-10-19 择窗实证）**重试一次**；重试只发生在[-1]类，绝不伪造数据。
  /// * 非 200 是**真语义**（404 未命中 / 400 拒绝）——不重试不吞，逐条附
  ///   failures 诊断（body 片段）交调用方按语义记账。
  Future<({int code, String body})?> _fetchBody(Uri uri, {int attempt = 0}) async {
    try {
      final rq = await _http.getUrl(uri)
        ..headers.set(HttpHeaders.userAgentHeader, userAgent);
      final rs = await rq.close();
      final code = rs.statusCode;
      final body = await rs.transform(utf8.decoder).join();
      responses.add((uri: uri, statusCode: code));
      if (code != 200) {
        failures.add((
          uri: uri,
          statusCode: code,
          snippet: body.length > 260 ? body.substring(0, 260) : body,
        ));
      }
      return (code: code, body: body);
    } on Exception {
      responses.add((uri: uri, statusCode: -1));
      if (attempt == 0) {
        return _fetchBody(uri, attempt: 1);
      }
      return null;
    }
  }

  /// /api/get=对象载荷；未命中/非 200/传输失败=null（不抛——调用方记账）。
  Future<Map<String, dynamic>?> _json(Uri uri) async {
    requests.add((uri: uri, startedAt: _now()));
    final got = await _fetchBody(uri);
    if (got == null || got.code != 200) {
      return null;
    }
    try {
      return jsonDecode(got.body) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  /// /api/search=裸 JSON 数组载荷（真网实证）；传输失败/非 200 → []。
  Future<List<Map<String, dynamic>>> _searchList(Uri uri) async {
    requests.add((uri: uri, startedAt: _now()));
    final got = await _fetchBody(uri);
    if (got == null || got.code != 200) {
      return const [];
    }
    try {
      return (jsonDecode(got.body) as List? ?? const [])
          .cast<Map<String, dynamic>>();
    } on FormatException {
      return const [];
    }
  }

  /// 传输层释放（hub.dispose 消费；同 NetEaseLyricSearch.dispose 惯例）。
  void close() {
    _http.close();
  }
}
