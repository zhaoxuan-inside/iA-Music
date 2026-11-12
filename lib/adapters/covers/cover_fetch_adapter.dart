/// CoverFetchPort 实现——MusicBrainz(CAA) → iTunes，容量 1 令牌桶全局限速。
///
/// 纪律（v1 实证）：MusicBrainz 要求显式 UA 且禁止高频（1 req/s 级）；
/// 抓图上限字节钳制；http 一律升 https；未命中返回 null 不抛。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/errors.dart';
import '../../domain/ports/cover_port.dart';

class CoverFetchAdapter implements CoverFetchPort {
  CoverFetchAdapter();

  static const String _ua = 'iA-Music/2.0 (https://github.com/HardStone/iA-Music)';
  static const int _maxImageBytes = 4 * 1024 * 1024;
  static const int _maxJsonBytes = 512 * 1024;
  static const Duration _minInterval = Duration(milliseconds: 1100);

  static final _limiter = _TokenBucket(_minInterval);
  HttpClient? _client;
  bool _closed = false;

  HttpClient get _http => _client ??= HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  @override
  Future<CoverResult?> fetch(CoverQuery query) async {
    if (_closed) {
      return null;
    }
    final title = query.title.trim();
    if (title.isEmpty) {
      return null;
    }
    final artist = query.artist.trim();
    try {
      final caa = await _caa(title, artist);
      if (caa != null) {
        return caa;
      }
      final term = (artist.isEmpty ? '' : '$artist ') + title;
      return await _itunes(term);
    } on Exception catch (e) {
      throw NetworkError(detail: 'cover fetch: $e');
    }
  }

  /// MusicBrainz recording 搜索取 release id → CAA 首图。
  Future<CoverResult?> _caa(String title, String artist) async {
    final mb = await _json(Uri.https('musicbrainz.org', '/ws/2/recording/', {
      'query': 'recording:"$title"${artist.isEmpty ? '' : ' AND artist:"$artist"'}',
      'fmt': 'json',
      'limit': '5',
    }));
    if (mb == null) {
      return null;
    }
    final recordings = (mb['recordings'] as List<dynamic>?) ?? const <dynamic>[];
    for (final rec in recordings) {
      final releases = (rec as Map<String, dynamic>)['releases'] as List<dynamic>?;
      if (releases == null || releases.isEmpty) {
        continue;
      }
      final releaseId = (releases.first as Map<String, dynamic>)['id'] as String?;
      if (releaseId == null || releaseId.isEmpty) {
        continue;
      }
      final caa = await _json(Uri.https('coverartarchive.org', '/release/$releaseId'));
      if (caa == null) {
        continue;
      }
      final images = (caa['images'] as List<dynamic>?) ?? const <dynamic>[];
      for (final img in images) {
        final url = (img as Map<String, dynamic>)['thumbnails']?['small'] as String?;
        if (url == null || url.isEmpty) {
          continue;
        }
        final bytes = await _getBytes(Uri.parse(url));
        if (bytes != null) {
          return CoverResult(bytes: bytes, contentType: 'image/jpeg');
        }
      }
    }
    return null;
  }

  Future<CoverResult?> _itunes(String term) async {
    if (term.isEmpty) {
      return null;
    }
    final it = await _json(Uri.https('itunes.apple.com', '/search', {
      'term': term,
      'media': 'music',
      'entity': 'song',
      'limit': '10',
    }));
    if (it == null) {
      return null;
    }
    final results = (it['results'] as List<dynamic>?) ?? const <dynamic>[];
    for (final r in results) {
      var url = (r as Map<String, dynamic>)['artworkUrl100'] as String?;
      if (url == null || url.isEmpty) {
        continue;
      }
      url = url.replaceFirst('100x100', '600x600'); // 高清位
      final bytes = await _getBytes(Uri.parse(url));
      if (bytes != null) {
        return CoverResult(bytes: bytes, contentType: 'image/jpeg');
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _json(Uri uri) async {
    final bytes = await _getBytes(uri, maxBytes: _maxJsonBytes);
    if (bytes == null) {
      return null;
    }
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  Future<List<int>?> _getBytes(Uri uri, {int maxBytes = _maxImageBytes}) async {
    if (_closed) {
      return null;
    }
    if (uri.scheme == 'http') {
      uri = uri.replace(scheme: 'https');
    }
    if (uri.scheme != 'https') {
      return null;
    }
    await _limiter.acquire();
    try {
      final rq = await _http.getUrl(uri)
        ..headers.set(HttpHeaders.userAgentHeader, _ua);
      final rs = await rq.close();
      if (rs.statusCode != 200) {
        await rs.drain<void>();
        return null;
      }
      final builder = BytesBuilder();
      await for (final chunk in rs) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          return null;
        }
      }
      return builder.takeBytes();
    } on Exception {
      return null;
    }
  }

  Future<void> dispose() async {
    _closed = true;
    _client?.close();
    _client = null;
  }
}

/// 容量 1 的全局令桶：串行化请求起始并保证最小间隔（MusicBrainz 礼节）。
class _TokenBucket {
  _TokenBucket(this.minInterval);

  final Duration minInterval;
  Completer<void>? _pending;
  DateTime _next = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> acquire() async {
    while (_pending != null) {
      await _pending!.future;
    }
    final now = DateTime.now();
    final wait = _next.difference(now);
    _next = (wait > Duration.zero ? _next : now).add(minInterval);
    if (wait > Duration.zero) {
      final c = _pending = Completer<void>();
      try {
        await Future<void>.delayed(wait);
      } finally {
        _pending = null;
        if (!c.isCompleted) {
          c.complete();
        }
      }
    }
  }
}
