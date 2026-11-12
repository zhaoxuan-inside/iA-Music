/// LyricTextSearchPort 实现——lrclib.net 免 key API。
///
/// 链路（v1 实证）：/api/get（全参数）→ /api/search(artist+track) →
/// /api/search(q) → /api/search(仅 track_name)。候选接受规则=歌词至少一项
/// 非空 + 时长锚 ±2s。传输异常重试一次；非 200 是真语义（未命中/拒绝）不吞。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/errors.dart';
import '../../domain/ports/lyrics_port.dart';

class LrclibAdapter implements LyricTextSearchPort {
  LrclibAdapter({HttpClient? client});

  static const String _host = 'lrclib.net';
  static const String _ua = 'iA-Music/2.0 (https://github.com/HardStone/iA-Music)';

  HttpClient? _client;
  bool _closed = false;

  HttpClient get _http => _client ??= HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  Uri _get(String path, Map<String, String> params) => Uri.https(_host, path, params);

  @override
  Future<LyricHit?> getByFields({
    required String title,
    required String artist,
    int? durationMs,
  }) async {
    if (title.isEmpty) {
      return null;
    }
    final got = await _json(_get('/api/get', {
      'track_name': title,
      if (artist.isNotEmpty) 'artist_name': artist,
      if (durationMs != null) 'duration': '${(durationMs / 1000).round()}',
    }));
    if (got != null && _accept(got, durationMs)) {
      return _toHit(got);
    }
    for (final items in [
      await _searchList(_get('/api/search', {
        if (artist.isNotEmpty) 'artist_name': artist,
        'track_name': title,
      })),
      await _searchList(_get('/api/search', {
        'q': artist.isEmpty ? title : '$artist $title',
      })),
      if (durationMs != null)
        await _searchList(_get('/api/search', {'track_name': title})),
    ]) {
      for (final it in items) {
        if (_accept(it, durationMs)) {
          return _toHit(it);
        }
      }
    }
    return null;
  }

  @override
  Future<LyricHit?> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return null;
    }
    for (final items in [
      await _searchList(_get('/api/search', {'q': q})),
    ]) {
      for (final it in items) {
        final hit = _toHit(it);
        if (hit != null &&
            (hit.syncedLrc.trim().isNotEmpty || hit.plainLrc.trim().isNotEmpty)) {
          return hit;
        }
      }
    }
    return null;
  }

  bool _accept(Map<String, dynamic> cand, int? durationMs) {
    final hasLyric =
        ((cand['syncedLyrics'] as String?)?.trim().isNotEmpty ?? false) ||
            ((cand['plainLyrics'] as String?)?.trim().isNotEmpty ?? false);
    if (!hasLyric) {
      return false;
    }
    final dur = (cand['duration'] as num?)?.toInt();
    if (durationMs != null && dur != null) {
      return (dur * 1000 - durationMs).abs() <= 2000;
    }
    return true;
  }

  LyricHit? _toHit(Map<String, dynamic> j) {
    final synced = (j['syncedLyrics'] as String?) ?? '';
    final plain = (j['plainLyrics'] as String?) ?? '';
    if (synced.trim().isEmpty && plain.trim().isEmpty) {
      return null;
    }
    return LyricHit(syncedLrc: synced, plainLrc: plain);
  }

  Future<Map<String, dynamic>?> _json(Uri uri) async {
    final body = await _fetchBody(uri);
    if (body == null || body.code != 200) {
      return null;
    }
    try {
      return jsonDecode(body.body) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _searchList(Uri uri) async {
    final body = await _fetchBody(uri);
    if (body == null || body.code != 200) {
      return const <Map<String, dynamic>>[];
    }
    try {
      final list = jsonDecode(body.body) as List<dynamic>;
      return [for (final it in list) it as Map<String, dynamic>];
    } on Object {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<({int code, String body})?> _fetchBody(Uri uri, {int attempt = 0}) async {
    if (_closed) {
      return null;
    }
    try {
      final rq = await _http.getUrl(uri)
        ..headers.set(HttpHeaders.userAgentHeader, _ua);
      final rs = await rq.close();
      final code = rs.statusCode;
      final body = await rs.transform(utf8.decoder).join();
      return (code: code, body: body);
    } on Exception {
      if (attempt == 0) {
        return _fetchBody(uri, attempt: 1); // TLS/连接抖动重试一次
      }
      throw NetworkError(detail: 'lrclib $uri 不可达');
    }
  }

  Future<void> dispose() async {
    _closed = true;
    _client?.close();
    _client = null;
  }
}
