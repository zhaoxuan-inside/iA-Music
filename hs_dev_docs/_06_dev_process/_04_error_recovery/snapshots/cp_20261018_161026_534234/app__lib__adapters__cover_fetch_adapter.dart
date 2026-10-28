/// Real MusicBrainz → CAA front art; iTunes fallback. No automatic retries.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';

/// Capacity-one token bucket. A shared instance serializes every request start,
/// including redirects and downloads; Stopwatch avoids wall-clock adjustments.
final class CoverRequestLimiter {
  Future<void> _tail = Future.value();
  final Stopwatch _clock = Stopwatch()..start();
  int _nextUs = 0;

  Future<void> acquire() {
    final turn = _tail.then((_) async {
      while (_clock.elapsedMicroseconds < _nextUs) {
        final wait = _nextUs - _clock.elapsedMicroseconds;
        // Timers use millisecond granularity on Windows. Round up, then recheck.
        await Future<void>.delayed(
          Duration(milliseconds: (wait + 999) ~/ 1000),
        );
      }
      _nextUs = _clock.elapsedMicroseconds + 1001000; // 1ms scheduling margin
    });
    _tail = turn;
    return turn;
  }
}

final class CoverFetchAdapter implements CoverFetchPort {
  CoverFetchAdapter();

  static final _limiter = CoverRequestLimiter();
  static const userAgent =
      'iA-Music/0.1 (https://github.com/HardStone/iA-Music)';
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  bool _closed = false;
  int _requestCount = 0;
  int get requestCount => _requestCount;

  /// Diagnostics observe real outbound starts, never replace the HTTP transport.
  final List<({Uri uri, DateTime startedAt})> requests = [];
  final List<({Uri uri, int statusCode})> responses = [];

  @override
  Future<CoverResult?> fetchTrackCover(CoverQuery query) async {
    if (_closed || query.title.trim().isEmpty) return null;
    try {
      final caa = await _caa(query);
      if (caa != null) return caa;
    } on Exception catch (_) {
      // A failed primary still permits one independent fallback lookup.
    }
    try {
      return await _itunes(query);
    } on Exception catch (_) {
      return null;
    }
  }

  Future<CoverResult?> _caa(CoverQuery q) async {
    // Search recordings by title (album optional), then choose their releases.
    final title = q.title.replaceAll('"', '').replaceAll('\\', '');
    final artist = (q.artistDisplay ?? '')
        .replaceAll('"', '')
        .replaceAll('\\', '');
    final search =
        'recording:"$title"${artist.isEmpty ? '' : ' AND artist:"$artist"'}';
    final data = await _json(
      Uri.https('musicbrainz.org', '/ws/2/recording/', {
        'query': search,
        'fmt': 'json',
        'limit': '5',
      }),
    );
    for (final row in (data?['recordings'] as List? ?? [])) {
      if (!_same(row['title'], q.title)) continue;
      if (artist.isNotEmpty &&
          !(row['artist-credit'] as List? ?? []).any(
            (a) => _same(a['name'] ?? a['artist']?['name'], q.artistDisplay),
          )) {
        continue;
      }
      for (final release in (row['releases'] as List? ?? []).take(3)) {
        if ((q.albumDisplay ?? '').isNotEmpty &&
            !_same(release['title'], q.albumDisplay)) {
          continue;
        }
        final id = release['id'];
        if (id is! String || !RegExp(r'^[a-f0-9-]{36}$').hasMatch(id)) continue;
        final art = await _json(
          Uri.https('coverartarchive.org', '/release/$id'),
        );
        final fronts = (art?['images'] as List? ?? []).where(
          (a) => a['front'] == true,
        );
        for (final front in fronts) {
          final thumbs = front['thumbnails'] as Map? ?? {};
          final url =
              thumbs['1200'] ??
              thumbs['500'] ??
              thumbs['250'] ??
              front['image'];
          if (url is String) {
            final result = await _download(Uri.parse(url), CoverSource.caa);
            if (result != null) return result;
          }
        }
      }
    }
    return null;
  }

  Future<CoverResult?> _itunes(CoverQuery q) async {
    final term = [
      q.title,
      q.artistDisplay,
      q.albumDisplay,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
    final data = await _json(
      Uri.https('itunes.apple.com', '/search', {
        'term': term,
        'entity': 'song',
        'media': 'music',
        'limit': '10',
      }),
    );
    for (final row in (data?['results'] as List? ?? [])) {
      if (!_same(row['trackName'], q.title)) continue;
      if ((q.artistDisplay ?? '').isNotEmpty &&
          !_same(row['artistName'], q.artistDisplay)) {
        continue;
      }
      if ((q.albumDisplay ?? '').isNotEmpty &&
          !_same(row['collectionName'], q.albumDisplay)) {
        continue;
      }
      final url = row['artworkUrl100'];
      if (url is String) {
        final result = await _download(Uri.parse(url), CoverSource.itunes);
        if (result != null) return result;
      }
    }
    return null;
  }

  static bool _same(Object? a, Object? b) =>
      a is String &&
      b is String &&
      a.trim().toLowerCase() == b.trim().toLowerCase();

  Future<Map<String, dynamic>?> _json(Uri uri) async {
    final bytes = await _get(uri, maxBytes: 2 * 1024 * 1024);
    if (bytes == null) return null;
    final data = jsonDecode(utf8.decode(bytes));
    return data is Map<String, dynamic> ? data : null;
  }

  Future<CoverResult?> _download(Uri uri, CoverSource source) async {
    final bytes = await _get(uri, maxBytes: 12 * 1024 * 1024);
    // .cover.jpg must contain an actual JPEG, never an HTML error response.
    if (bytes == null ||
        bytes.length < 3 ||
        bytes[0] != 255 ||
        bytes[1] != 216 ||
        bytes[2] != 255) {
      return null;
    }
    final temp = await Directory.systemTemp.createTemp('ia_cover_');
    try {
      final file = await File('${temp.path}/cover.jpg')
          .writeAsBytes(bytes, flush: true);
      return CoverResult(localPath: file.path, source: source);
    } on Exception {
      await temp.delete(recursive: true);
      rethrow;
    }
  }

  Future<List<int>?> _get(Uri uri, {required int maxBytes}) async {
    for (var redirects = 0; redirects < 6; redirects++) {
      if (_closed || uri.scheme != 'https') return null;
      final request = await _http
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      // Acquire immediately before sending HTTP headers, after DNS/TLS setup.
      // A slow first connection must not let the next actual send start early.
      await _limiter.acquire();
      if (_closed) {
        request.abort();
        return null;
      }
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      _requestCount++;
      requests.add((uri: uri, startedAt: DateTime.now().toUtc()));
      // Bound diagnostics memory for long library browsing sessions.
      if (requests.length > 200) requests.removeAt(0);
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      responses.add((uri: uri, statusCode: response.statusCode));
      if (responses.length > 200) responses.removeAt(0);
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (response.isRedirect && location != null) {
        await response.drain<void>().timeout(const Duration(seconds: 10));
        uri = uri.resolve(location);
        if (uri.scheme == 'http') uri = uri.replace(scheme: 'https');
        continue;
      }
      if (response.statusCode != HttpStatus.ok ||
          response.contentLength > maxBytes) {
        request.abort();
        return null;
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        if (bytes.length + chunk.length > maxBytes) {
          request.abort();
          return null;
        }
        bytes.addAll(chunk);
      }
      return bytes;
    }
    return null;
  }

  void close() {
    _closed = true;
    _http.close(force: true);
  }
}
