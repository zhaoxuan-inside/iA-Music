/// B 站客户端协议测试：本地 HttpServer 假扮 passport/api 域。
///
/// 重点回归（2024-11 实测修复）：
/// * 扫码成功态 data 体里没有 cookies 字段——cookie 必须从
///   Set-Cookie 响应头与 data.url 跨域回跳参数提取；
/// * SESSDATA 值内含逗号，解析不得截断；
/// * 86038 过期必须映射到 BiliQrState.expired（登录页据此自动换码）；
/// * 匿名 buvid 补齐（防 api 域 -412）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/services/collect/bilibili_client.dart';
import 'package:ia_music/services/collect/platform_store.dart';
import 'package:ia_music/services/settings/settings_service.dart';

void main() {
  late HttpServer server;
  late String base;
  late IaDatabase db;
  late PlatformStore store;
  late BilibiliClient client;

  /// 请求侧快照（断言 cookie 头）。
  final seenCookies = <String?>[];
  int spiHits = 0;

  setUp(() async {
    seenCookies.clear();
    spiHits = 0;
    server = await HttpServer.bind('127.0.0.1', 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      seenCookies.add(req.headers.value(HttpHeaders.cookieHeader));
      final path = req.uri.path;
      if (path == '/x/passport-login/web/qrcode/generate') {
        await _json(req, {
          'code': 0,
          'data': {
            'url': 'https://account.bilibili.com/h5/account-h5/auth/scan-web?qrcode_key=k1',
            'qrcode_key': 'k1',
          },
        });
      } else if (path == '/x/passport-login/web/qrcode/poll') {
        await _pollScenario(req, req.uri.queryParameters['qrcode_key'] ?? '');
      } else if (path == '/x/frontend/finger/spi') {
        spiHits++;
        await _json(req, {
          'code': 0,
          'data': {'b_3': 'B3TEST', 'b_4': 'B4TEST'},
        });
      } else if (path == '/x/web-interface/view') {
        await _json(req, {
          'code': 0,
          'data': {
            'title': '测试视频',
            'owner': {'name': '测试UP'},
            'cid': 7,
            'pages': [
              {'cid': 7, 'part': 'P1'},
            ],
            'duration': 180,
            'aid': 999,
          },
        });
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    store = PlatformStore(SettingsService(db.settingsDao));
    client = BilibiliClient(store, apiBase: base, passportBase: base);
  });

  tearDown(() async {
    client.dispose();
    await server.close(force: true);
    await db.close();
  });

  test('generateQr：取 url 与 qrcode_key', () async {
    final qr = await client.generateQr();
    expect(qr.qrcodeKey, 'k1');
    expect(qr.url, contains('qrcode_key=k1'));
  });

  test('pollQr：未扫码 86101 → waiting', () async {
    final poll = await client.pollQr('wait');
    expect(poll.state, BiliQrState.waiting);
  });

  test('pollQr：二维码过期 86038 → expired（登录页据此自动换码）', () async {
    final poll = await client.pollQr('expired');
    expect(poll.state, BiliQrState.expired);
  });

  test('pollQr：成功 → Set-Cookie 头提取（SESSDATA 逗号不截断）+ mid', () async {
    final poll = await client.pollQr('success');
    expect(poll.state, BiliQrState.success);
    final cookies = poll.cookies!;
    expect(cookies['SESSDATA'], 'abc,def');
    expect(cookies['bili_jct'], 'tok');
    expect(cookies['DedeUserID'], '42');
    expect(cookies['DedeUserID__ckMd5'], 'md5');
    expect(poll.message, 'mid=42');
  });

  test('pollQr：成功且无 Set-Cookie → data.url 跨域参数兜底', () async {
    final poll = await client.pollQr('success-urlonly');
    expect(poll.state, BiliQrState.success);
    expect(poll.cookies!['SESSDATA'], 'abc,def');
    expect(poll.cookies!['bili_jct'], 'tok');
    expect(poll.message, 'mid=42');
  });

  test('匿名请求自动补 buvid（防 -412）', () async {
    final info = await client.videoInfo('BV1TEST12345');
    expect(info.title, '测试视频');
    expect(spiHits, 1, reason: '首次请求应获取一次 buvid');
    expect(seenCookies.last, contains('buvid3=B3TEST'));
    // 第二次请求复用缓存
    await client.videoInfo('BV1TEST12345');
    expect(spiHits, 1);
  });

  test('已带 buvid3 的登录态：不再额外获取 buvid', () async {
    await store.saveCookies(
        PlatformId.bilibili, 'SESSDATA=s1; buvid3=OWN');
    await client.videoInfo('BV1TEST12345');
    expect(spiHits, 0);
    expect(seenCookies.last, 'SESSDATA=s1; buvid3=OWN');
  });
}

Map<String, Object> _pollBody(int code, {String? url}) => {
      'code': 0,
      'data': {
        'code': code,
        'url': url ?? '',
        'refresh_token': '',
        'timestamp': 0,
        'message': '0',
      },
    };

Future<void> _pollScenario(HttpRequest req, String scenario) async {
  switch (scenario) {
    case 'wait':
      await _json(req, _pollBody(86101));
    case 'expired':
      await _json(req, _pollBody(86038));
    case 'success':
      req.response.headers.add(
          'set-cookie',
          'SESSDATA=abc,def; Path=/; Domain=.bilibili.com; '
          'Secure; HttpOnly');
      req.response.headers.add(
          'set-cookie', 'bili_jct=tok; Path=/; Domain=.bilibili.com');
      req.response.headers.add(
          'set-cookie', 'DedeUserID=42; Path=/; Domain=.bilibili.com');
      req.response.headers.add(
          'set-cookie', 'DedeUserID__ckMd5=md5; Path=/; Domain=.bilibili.com');
      await _json(req, _pollBody(0, url: _crossDomainUrl));
    case 'success-urlonly':
      await _json(req, _pollBody(0, url: _crossDomainUrl));
    default:
      req.response.statusCode = 404;
      await req.response.close();
  }
}

const String _crossDomainUrl =
    'https://passport.biligame.com/x/passport-login/web/crossDomain'
    '?DedeUserID=42&DedeUserID__ckMd5=md5&Expires=30'
    '&SESSDATA=abc%2Cdef&bili_jct=tok'
    '&gourl=https%3A%2F%2Fwww.bilibili.com%2F';

Future<void> _json(HttpRequest req, Object map) async {
  req.response.headers.contentType = ContentType.json;
  req.response.write(jsonEncode(map));
  await req.response.close();
}
