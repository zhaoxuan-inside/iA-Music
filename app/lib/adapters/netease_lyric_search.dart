/// 歌词正文反查（2026-10-25 用户拍板落地）：ASR 歌词句 → 歌曲身份。
///
/// * LRCLIB 实证不索引正文（真实句 q=0，见 LrclibAdapter 头注红线）→
///   反查源=网易云音乐公开 web 端点（type=1006 歌词搜索，真网验证可用）。
/// * 稳健性：取 ASR 文本中 ≥[minLineChars] 字的多行逐句查询，按 songId
///   投票；最高票候选再经时长锚（详情 API，±[durationToleranceMs]）确认。
/// * 纪律：UA/Referer 诚实；未命中→null 不抛；灰色端点仅本机个人使用语义
///   （与 B 站搜索/提取同界），不落任何凭据。
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

/// 反查命中的歌曲身份。
final class LyricsIdentity {
  const LyricsIdentity({
    required this.songId,
    required this.title,
    required this.artist,
    this.album,
    required this.durationMs,
  });
  final int songId;
  final String title;
  final String artist;
  final String? album;
  final int durationMs;
}

abstract class LyricTextSearchPort {
  /// [lines]=ASR 歌词句（多行投票）；[durationMs]=段时长锚（null=跳过锚）。
  Future<LyricsIdentity?> identifyByLyrics(
    List<String> lines, {
    int? durationMs,
  });

  /// D12-4① 标准歌词回填（默认不支持；NetEase 实现取 /api/song/lyric）。
  Future<String?> fetchSyncedLyrics(int songId) async => null;

  /// D12-4② 反查封面（默认不支持；NetEase 实现取 detail.album.picUrl 字节）。
  Future<({String url, List<int> bytes})?> fetchCover(int songId) async => null;
}

final class NetEaseLyricSearch implements LyricTextSearchPort {
  NetEaseLyricSearch();

  static const int minLineChars = 6;
  static const int maxQueryLines = 3;
  static const int durationToleranceMs = 6000;
  static const int maxCandidatesPerLine = 10;

  final HttpClient _http = HttpClient()
    ..findProxy = HttpClient.findProxyFromEnvironment
    ..connectionTimeout = const Duration(seconds: 10);

  @override
  Future<LyricsIdentity?> identifyByLyrics(
    List<String> lines, {
    int? durationMs,
  }) async {
    final queries = lines
        .map((l) => l.trim())
        .where((l) => l.length >= minLineChars)
        .take(maxQueryLines)
        .toList();
    if (queries.isEmpty) {
      return null;
    }
    // songId → (票数, 身份)
    final votes = <int, ({int n, LyricsIdentity id})>{};
    for (final q in queries) {
      final songs = await _searchLine(q);
      for (final s in songs) {
        final id = s.songId;
        final prev = votes[id];
        votes[id] = (n: (prev?.n ?? 0) + 1, id: s);
      }
    }
    if (votes.isEmpty) {
      return null;
    }
    // 最高票（平票取首个）→ 时长锚确认
    final ranked = votes.values.toList()
      ..sort((a, b) => b.n.compareTo(a.n));
    for (final cand in ranked.take(3)) {
      if (durationMs == null) {
        return cand.id;
      }
      final realDur = await _songDurationMs(cand.id.songId);
      if (realDur != null &&
          (realDur - durationMs).abs() <= durationToleranceMs) {
        return cand.id;
      }
    }
    return null;
  }

  Future<List<LyricsIdentity>> _searchLine(String line) async {
    final uri = Uri.https('music.163.com', '/api/search/get/web', {
      's': line,
      'type': '1006', // 歌词搜索（正文索引）
      'offset': '0',
      'total': 'true',
      'limit': '$maxCandidatesPerLine',
    });
    try {
      final rq = await _http.getUrl(uri)
        ..headers.set(HttpHeaders.userAgentHeader,
            'iA-Music/0.1 (https://github.com/HardStone/iA-Music)')
        ..headers.set(HttpHeaders.refererHeader, 'https://music.163.com/');
      final rs = await rq.close();
      if (rs.statusCode != 200) {
        return const [];
      }
      final body = jsonDecode(await rs.transform(utf8.decoder).join())
          as Map<String, dynamic>;
      final result = resultOf(body);
      final songs = (result?['songs'] as List? ?? const []);
      return [
        for (final e in songs)
          if (e is Map)
            LyricsIdentity(
              songId: (e['id'] as num?)?.toInt() ?? 0,
              title: '${e['name'] ?? ''}'.trim(),
              artist: ((e['artists'] as List?)?.firstOrNull is Map)
                  ? '${((e['artists'] as List).first as Map)['name'] ?? ''}'
                      .trim()
                  : '',
              album: (e['album'] is Map)
                  ? '${(e['album'] as Map)['name'] ?? ''}'.trim()
                  : null,
              durationMs: 0, // 详情 API 补
            ),
      ].where((s) => s.title.isNotEmpty && s.artist.isNotEmpty).toList();
    } on Exception {
      return const [];
    }
  }

  /// 歌曲详情 → 时长（未命中/异常=null）。
  Future<int?> _songDurationMs(int songId) async {
    final uri = Uri.https('music.163.com', '/api/song/detail', {
      'id': '$songId',
      'ids': '[$songId]',
    });
    try {
      final rq = await _http.getUrl(uri)
        ..headers.set(HttpHeaders.refererHeader, 'https://music.163.com/');
      final rs = await rq.close();
      if (rs.statusCode != 200) {
        return null;
      }
      final body = jsonDecode(await rs.transform(utf8.decoder).join())
          as Map<String, dynamic>;
      final songs = body['songs'] as List? ?? const [];
      if (songs.isEmpty || songs.first is! Map) {
        return null;
      }
      return ((songs.first as Map)['duration'] as num?)?.toInt();
    } on Exception {
      return null;
    }
  }

  /// 标准歌词回填（D12-4①）：lv=1 取带时间轴的原文歌词（LRC 文本）。
  @override
  Future<String?> fetchSyncedLyrics(int songId) async {
    final uri = Uri.https('music.163.com', '/api/song/lyric', {
      'id': '$songId',
      'lv': '1',
      'kv': '1',
      'tv': '-1',
    });
    try {
      final rq = await _http.getUrl(uri)
        ..headers.set(HttpHeaders.refererHeader, 'https://music.163.com/');
      final rs = await rq.close();
      if (rs.statusCode != 200) {
        return null;
      }
      final body = jsonDecode(await rs.transform(utf8.decoder).join())
          as Map<String, dynamic>;
      final lrc = body['lrc'];
      if (lrc is! Map) {
        return null;
      }
      final text = '${lrc['lyric'] ?? ''}'.trim();
      if (!text.contains('[')) {
        return null; // 无时间轴不回填（不覆盖 ASR 成果）
      }
      return text;
    } on Exception {
      return null;
    }
  }

  /// 反查封面（D12-4②）：detail.album.picUrl → 下载字节（绝对 https）。
  @override
  Future<({String url, List<int> bytes})?> fetchCover(int songId) async {
    final pic = await _songPicUrl(songId);
    if (pic == null) {
      return null;
    }
    try {
      final rq = await _http.getUrl(Uri.parse(pic));
      final rs = await rq.close();
      if (rs.statusCode != 200) {
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in rs) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return (url: pic, bytes: bytes);
    } on Exception {
      return null;
    }
  }

  /// 歌曲详情 → 专辑封面地址（http 协议相对形态统一升 https）。
  Future<String?> _songPicUrl(int songId) async {
    final uri = Uri.https('music.163.com', '/api/song/detail', {
      'id': '$songId',
      'ids': '[$songId]',
    });
    try {
      final rq = await _http.getUrl(uri)
        ..headers.set(HttpHeaders.refererHeader, 'https://music.163.com/');
      final rs = await rq.close();
      if (rs.statusCode != 200) {
        return null;
      }
      final body = jsonDecode(await rs.transform(utf8.decoder).join())
          as Map<String, dynamic>;
      final songs = body['songs'] as List? ?? const [];
      if (songs.isEmpty || songs.first is! Map) {
        return null;
      }
      final album = (songs.first as Map)['album'];
      if (album is! Map) {
        return null;
      }
      final raw = '${album['picUrl'] ?? ''}'.trim();
      if (raw.isEmpty) {
        return null;
      }
      return raw.startsWith('//') ? 'https:$raw' : raw;
    } on Exception {
      return null;
    }
  }

  void dispose() => _http.close();
}

Map<String, dynamic>? resultOf(Map<String, dynamic> body) =>
    (body['result'] is Map) ? body['result'] as Map<String, dynamic> : null;
