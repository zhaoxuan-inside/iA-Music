/// AcoustID 查询客户端（/v2/lookup，JSON POST）。
/// 指纹 → 最佳匹配录音（歌名/歌手）。client key 在 lib/app/config（默认官方测试键）。
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
  AcoustidClient({String? apiKey, HttpClient? client})
      : apiKey = apiKey ?? kAcoustidClientKey,
        _client = client ?? HttpClient();

  /// AcoustID client key（默认官方测试键，正式发布建议注册专属 key）。
  final String apiKey;
  final HttpClient _client;

  /// 指纹查询：返回最佳匹配（歌名/歌手）；无匹配/失败 → null。
  Future<AcoustidMatch?> lookup({
    required String fingerprint,
    required int durationMs,
  }) async {
    try {
      final req = await _client.postUrl(
          Uri.parse(kAcoustidLookupUrl));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final payload = jsonEncode({
        'client': apiKey,
        'duration': (durationMs / 1000).round(),
        'fingerprint': fingerprint,
        'meta': ['recordings', 'sources'],
      });
      req.add(utf8.encode(payload));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        throw NetworkError(detail: 'AcoustID 查询失败：HTTP ${res.statusCode}');
      }
      final decoded = jsonDecode(body);
      if (decoded['status'] != 'ok') {
        return null;
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
}
