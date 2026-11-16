/// B 站扫码登录落库事务：真实 HTTP 协议解析 → cookie 汇源 → 落库 → 读回校验。
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/services/collect/bili_login.dart';
import 'package:ia_music/services/collect/bilibili_client.dart';
import 'package:ia_music/services/collect/platform_store.dart';
import 'package:ia_music/services/settings/settings_service.dart';

void main() {
  late IaDatabase db;
  late PlatformStore store;
  late BilibiliClient client;
  late HttpServer server;
  late String base;

  /// 轮询成功响应：cookie 只出现在回跳 URL 与 Set-Cookie 头里
  /// （与线上实测一致），data.cookies 故意留空。
  const crossDomainUrl =
      'https://passport.biligame.com/crossDomain?DedeUserID=42'
      '&DedeUserID__ckMd5=ckmd5&Expires=123&SESSDATA=sess%2Cdata'
      '&bili_jct=csrf&gourl=https%3A%2F%2Fwww.bilibili.com';

  setUp(() async {
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get(); // 触发建表
    store = PlatformStore(SettingsService(db.settingsDao));

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    client = BilibiliClient(store, apiBase: base, passportBase: base);

    server.listen((req) async {
      final res = req.response;
      switch (req.uri.path) {
        case '/x/passport-login/web/qrcode/generate':
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode({
            'code': 0,
            'message': 'OK',
            'data': {
              'url': 'https://account.bilibili.com/scan?qrcode_key=KEY',
              'qrcode_key': 'KEY',
            },
          }));
        case '/x/passport-login/web/qrcode/poll':
          res.headers.contentType = ContentType.json;
          res.headers.add('set-cookie',
              'buvid3=fromheader; Path=/; Domain=.bilibili.com');
          res.write(jsonEncode({
            'code': 0,
            'message': 'OK',
            'data': {'code': 0, 'url': crossDomainUrl, 'refresh_token': 'r'},
          }));
        case '/x/frontend/finger/spi':
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode({
            'code': 0,
            'data': {'b_3': 'b3-value', 'b_4': 'b4-value'},
          }));
        default:
          res.statusCode = 404;
      }
      await res.close();
    });
  });

  tearDown(() async {
    client.dispose();
    await server.close(force: true);
    await db.close();
  });

  test('poll 成功 → 落库 → 读回校验 → 登录态保持', () async {
    final poll = await client.pollQr('KEY');
    expect(poll.state, BiliQrState.success);
    expect(poll.cookies, isNotNull);
    // 回跳 URL 是 cookie 的主来源（含 SESSDATA/bili_jct/DedeUserID）。
    expect(poll.cookies!['SESSDATA'], 'sess,data');
    expect(poll.cookies!['bili_jct'], 'csrf');

    final commit = await commitBiliLogin(
        client: client, store: store, poll: poll);
    expect(commit.ok, isTrue);
    expect(commit.cookieHeader, isNotNull);

    // 关键：落库内容既能被 loggedIn 读到，也带齐后续请求需要的字段。
    expect(await store.loggedIn(PlatformId.bilibili), isTrue);
    final saved = await store.cookies(PlatformId.bilibili);
    expect(saved, contains('SESSDATA='));
    expect(saved, contains('bili_jct=csrf'));
    expect(saved, contains('buvid3='));
    expect(saved, isNot(contains('buvid3=fromheader')),
        reason: 'spi 拿到的 buvid 应覆盖响应头里的临时值');

    final account = await store.account(PlatformId.bilibili);
    expect(account?.name, 'B 站用户 42');
  });

  test('空 cookie 的“成功”不覆盖已有登录态', () async {
    await store.saveCookies(PlatformId.bilibili, 'SESSDATA=keep-me');

    final commit = await commitBiliLogin(
      client: client,
      store: store,
      poll: const BiliQrPoll(BiliQrState.success),
    );
    expect(commit.ok, isFalse);
    expect(await store.cookies(PlatformId.bilibili), 'SESSDATA=keep-me');
    expect(await store.loggedIn(PlatformId.bilibili), isTrue);
  });

  test('退出登录清空后 loggedIn=false，重新落库可恢复', () async {
    final poll = await client.pollQr('KEY');
    await commitBiliLogin(client: client, store: store, poll: poll);
    expect(await store.loggedIn(PlatformId.bilibili), isTrue);

    await store.clearCookies(PlatformId.bilibili);
    await store.clearAccount(PlatformId.bilibili);
    expect(await store.loggedIn(PlatformId.bilibili), isFalse);

    final again = await commitBiliLogin(
        client: client, store: store, poll: poll);
    expect(again.ok, isTrue);
    expect(await store.loggedIn(PlatformId.bilibili), isTrue);
  });
}
