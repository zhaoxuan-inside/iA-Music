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
  });

  final String title;
  final String artist;
  final double score;
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
      // 官方 /v2/lookup 只收表单编码：meta 为一个空格分隔的字段
      final body = 'client=${Uri.encodeQueryComponent(apiKey)}'
          '&duration=${(durationMs / 1000).round()}'
          '&fingerprint=${Uri.encodeQueryComponent(fingerprint)}'
          '&meta=${Uri.encodeQueryComponent('recordings sources')}';
      req.add(utf8.encode(body));
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        throw NetworkError(
            detail: 'AcoustID 查询失败：HTTP ${res.statusCode} · ${_serverMessage(text)}');
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic> || decoded['status'] != 'ok') {
        final err = decoded is Map<String, dynamic> ? decoded['error'] : null;
        final msg = err is Map<String, dynamic> ? err['message'] : null;
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
          return AcoustidMatch(
            title: title,
            artist: artist,
            score: (r['score'] as num?)?.toDouble() ?? 0,
          );
        }
      }
      return null;
    } on NetworkError {
      rethrow;
    } on Object catch (e, st) {
      Error.throwWithStackTrace(NetworkError(detail: 'AcoustID 查询失败：$e'), st);
    }
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
