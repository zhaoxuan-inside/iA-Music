/// AcoustID 客户端测试——/v2/lookup 只收表单编码（JSON 一律 400 的教训）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/config/acoustid_config.dart';
import 'package:ia_music/domain/errors.dart';
import 'package:ia_music/services/acoustid/acoustid_client.dart';

void main() {
  late HttpServer server;
  late String base;
  String? lastBody;
  String? lastContentType;
  int statusCode = 200;
  String responseBody = '';

  setUp(() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    base = 'http://127.0.0.1:${server.port}';
    addTearDown(server.close);
    server.listen((req) async {
      lastBody = await utf8.decoder.bind(req).join();
      lastContentType =
          req.headers.value(HttpHeaders.contentTypeHeader);
      req.response.statusCode = statusCode;
      req.response.add(utf8.encode(responseBody));
      await req.response.close();
    });
    statusCode = 200;
    responseBody = '';
  });

  AcoustidClient client() =>
      AcoustidClient(apiKey: kAcoustidClientKey, baseUrl: base);

  test('表单编码 POST：client/duration/fingerprint/meta 四字段', () async {
    responseBody =
        '{"status":"ok","results":[{"score":0.92,"recordings":['
        '{"title":"爱如潮水","artists":[{"name":"张信哲"}]}]}]}';
    final match = await client().lookup(
        fingerprint: 'FPBASE64', durationMs: 253000);

    expect(lastContentType, contains('application/x-www-form-urlencoded'),
        reason: '官方 /v2/lookup 不收 JSON——这是 400 教训');
    expect(lastBody, contains('client=${Uri.encodeQueryComponent(kAcoustidClientKey)}'));
    expect(lastBody, contains('duration=253'));
    expect(lastBody, contains('fingerprint=FPBASE64'));
    expect(lastBody,
        contains('meta=${Uri.encodeQueryComponent('recordings releases sources')}'));
    expect(match!.title, '爱如潮水');
    expect(match.artist, '张信哲');
  });

  test('HTTP 400：报错带服务端 message 原文（日志可定位）', () async {
    statusCode = 400;
    responseBody =
        '{"error":{"code":1,"message":"invalid client key"}}';
    expect(
      () => client().lookup(fingerprint: 'FP', durationMs: 60000),
      throwsA(isA<NetworkError>()),
    );
    try {
      await client().lookup(fingerprint: 'FP', durationMs: 60000);
    } on NetworkError catch (e) {
      expect('$e', contains('invalid client key'));
      expect('$e', contains('400'));
    }
  });

  test('status != ok（如 key 无效）→ NetworkError 带 message', () async {
    responseBody = '{"status":"error","error":{"message":"nope"}}';
    expect(
      () => client().lookup(fingerprint: 'FP', durationMs: 60000),
      throwsA(isA<NetworkError>()),
    );
    try {
      await client().lookup(fingerprint: 'FP', durationMs: 60000);
    } on NetworkError catch (e) {
      expect('$e', contains('nope'));
    }
  });

  test('code 4（key 无效）HTTP 400 → AuthError（配置级致命，可整链禁用）', () async {
    statusCode = 400;
    responseBody = '{"error":{"code":4,"message":"invalid API key"}}';
    expect(
      () => client().lookup(fingerprint: 'FP', durationMs: 60000),
      throwsA(isA<AuthError>()),
    );
    try {
      await client().lookup(fingerprint: 'FP', durationMs: 60000);
    } on AuthError catch (e) {
      expect('$e', contains('invalid API key'));
      expect('$e', contains('400'));
    }
  });

  test('code 4 且 HTTP 200 status:error → AuthError（两条错误路径都认）', () async {
    responseBody =
        '{"status":"error","error":{"code":4,"message":"invalid API key"}}';
    expect(
      () => client().lookup(fingerprint: 'FP', durationMs: 60000),
      throwsA(isA<AuthError>()),
    );
  });
}
