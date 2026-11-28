/// AcoustID 查询客户端（/v2/lookup，**表单编码 POST**——官方接口不收 JSON）。
/// 指纹 → 最佳匹配录音（歌名/歌手）。client key 在 lib/app/config。
/// 报错带服务端 message 原文，便于日志追踪定位（400 = key/参数问题）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../app/config/acoustid_config.dart';
import '../../domain/errors.dart';

class AcoustidMatch {
  const AcoustidMatch({
    required this.title,
    required this.artist,
    required this.score,
    this.album = '',
    this.trackNo = 0,
  });

  final String title;
  final String artist;
  final double score;

  /// 专辑名（AcoustID releases 来源；无专辑信息为空串）。
  final String album;

  /// 音轨号（release medium 的 track position；无信息为 0）。
  final int trackNo;
}

class AcoustidClient {
  AcoustidClient({String? apiKey, HttpClient? client, String? baseUrl})
      : apiKey = apiKey ?? kAcoustidClientKey,
        _client = client ?? HttpClient(),
        baseUrl = baseUrl ?? kAcoustidLookupUrl;

  /// AcoustID client key（默认官方文档测试键，限速；正式发布建议注册专属 key）。
  final String apiKey;
  final HttpClient _client;

  /// 查询端点（测试可注入本地服务）。
  final String baseUrl;

  /// 指纹查询：返回最佳匹配（歌名/歌手）；无匹配 → null；请求/服务错误 →
  /// [NetworkError]（message 含服务端返回原文）。
  Future<AcoustidMatch?> lookup({
    required String fingerprint,
    required int durationMs,
  }) async {
    try {
      final req = await _client.postUrl(Uri.parse(baseUrl));
      req.headers.set(HttpHeaders.contentTypeHeader,
          'application/x-www-form-urlencoded');
      // 官方 /v2/lookup 只收表单编码：meta 为一个空格分隔的字段；
      // releases 提供专辑名/音轨号（补全管道的 专辑/音轨 阶段来源）。
      final body = 'client=${Uri.encodeQueryComponent(apiKey)}'
          '&duration=${(durationMs / 1000).round()}'
          '&fingerprint=${Uri.encodeQueryComponent(fingerprint)}'
          '&meta=${Uri.encodeQueryComponent('recordings releases sources')}';
      req.add(utf8.encode(body));
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        final err = _errorMap(text);
        // code 4 = client key 无效：配置级致命（重试无意义）→ AuthError
        // 供上层整链禁用；其余 400 仍是单曲网络错误的 NetworkError。
        if (err?['code'] == 4) {
          throw AuthError(
              detail: 'AcoustID key 无效（HTTP ${res.statusCode} · '
                  '${err?['message'] ?? 'invalid API key'}）');
        }
        throw NetworkError(
            detail: 'AcoustID 查询失败：HTTP ${res.statusCode} · ${_serverMessage(text)}');
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 'ok') {
        final err = decoded is Map<String, dynamic> ? decoded['error'] : null;
        final msg = err is Map<String, dynamic> ? err['message'] : null;
        if (err is Map<String, dynamic> && err['code'] == 4) {
          throw AuthError(
              detail: 'AcoustID key 无效（${msg ?? 'invalid API key'}）');
        }
        throw NetworkError(
            detail: 'AcoustID 查询失败：${msg ?? 'status != ok'}');
      }
      final results = decoded['results'] as List?;
      if (results == null || results.isEmpty) {
        return null;
      }
      // 按 score 取最佳结果，录音取第一个（AcoustID 已按音轨排序）
      for (final r in results) {
        if (r is! Map<String, dynamic>) {
          continue;
        }
        final recordings = r['recordings'] as List?;
        if (recordings == null || recordings.isEmpty) {
          continue;
        }
        for (final rec in recordings) {
          if (rec is! Map<String, dynamic>) {
            continue;
          }
          final title = (rec['title'] as String?)?.trim() ?? '';
          if (title.isEmpty) {
            continue;
          }
          var artist = '';
          final arts = rec['artists'] as List?;
          if (arts != null && arts.isNotEmpty) {
            final names = <String>[];
            for (final a in arts) {
              if (a is Map<String, dynamic> && (a['name'] as String?) != null) {
                names.add(a['name'] as String);
              }
            }
            artist = names.join(' / ');
          }
          final (album, trackNo) = _releaseOf(rec);
          return AcoustidMatch(
            title: title,
            artist: artist,
            score: (r['score'] as num?)?.toDouble() ?? 0,
            album: album,
            trackNo: trackNo,
          );
        }
      }
      return null;
    } on ContractError {
      // 契约错误（NetworkError/AuthError…）原样放行——兜底只收编野异常。
      rethrow;
    } on Object catch (e, st) {
      Error.throwWithStackTrace(NetworkError(detail: 'AcoustID 查询失败：$e'), st);
    }
  }

  /// 录音的发行信息解析：取第一个专辑名非空的 release——
  /// album = release.title；trackNo = 该碟内录音所在音轨的 position
  /// （缺 tracks 退碟位，再缺为 0）。录音可能是合辑多碟多版本，
  /// AcoustID 已按相关性排序，首个即最佳。
  (String, int) _releaseOf(Map<String, dynamic> rec) {
    final releases = rec['releases'] as List?;
    if (releases == null) {
      return ('', 0);
    }
    for (final rel in releases) {
      if (rel is! Map<String, dynamic>) {
        continue;
      }
      final album = (rel['title'] as String?)?.trim() ?? '';
      if (album.isEmpty) {
        continue;
      }
      final mediums = rel['mediums'] as List?;
      if (mediums == null || mediums.isEmpty) {
        return (album, 0);
      }
      final medium = mediums.first;
      var trackNo = 0;
      if (medium is Map<String, dynamic>) {
        final tracks = medium['tracks'] as List?;
        if (tracks != null && tracks.isNotEmpty && tracks.first is Map<String, dynamic>) {
          trackNo = (tracks.first as Map<String, dynamic>)['position'] as int? ?? 0;
        }
        trackNo = trackNo > 0 ? trackNo : (medium['position'] as int? ?? 0);
      }
      return (album, trackNo);
    }
    return ('', 0);
  }

  /// 服务端错误对象（{"error":{...}}），非 JSON → null。
  Map<String, dynamic>? _errorMap(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map<String, dynamic> && j['error'] is Map<String, dynamic>) {
        return j['error'] as Map<String, dynamic>;
      }
    } on Object {
      // 非 JSON：走裸文本分支
    }
    return null;
  }

  /// 服务端错误原文（{"error":{"message":…}} 或裸文本）。
  String _serverMessage(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map<String, dynamic>) {
        final err = j['error'];
        if (err is Map<String, dynamic> && err['message'] != null) {
          return '${err['message']}';
        }
        if (err is String) {
          return err;
        }
      }
    } on Object {
      // 非 JSON：截断原文
    }
    return body.length > 120 ? '${body.substring(0, 120)}…' : body;
  }
}
