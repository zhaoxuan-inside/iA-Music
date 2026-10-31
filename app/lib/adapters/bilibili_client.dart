/// BilibiliClient —— B 站开放 Web 接口共用底座（搜索/登录两域共享）。
///
/// 职责（EXP-2026-10-24 实测锚）：
/// * Cookie 池：登录 Cookie（SecureStore，C50 红线）+ 免登录 buvid3/buvid4
///   （`finger/spi` 引导）合并；请求头 UA/Referer 对齐 Web 面。
/// * wbi 签名：`nav` 取 img/sub key → mixin 表重排 32 位 → 参数排序
///   RFC3986 + md5（搜索面 -412 风控的通行证）。
/// * Set-Cookie 手工管理：dart:io 语义与 Netscape 格式互转（yt-dlp 消费面）。
///
/// 纪律：Cookie 值不落日志/DB；`debugPrint` 一律只出键名不出值。
library;

import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:crypto/crypto.dart';
import 'package:ia_music/adapters/secure_store_adapter.dart';
import 'package:ia_music/l10n/s.dart';

/// wbi 参数重排表（社区公开常量，实测通行；失效症状=搜索 -412）。
const List<int> kMixinKeyEncTab = [
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, //
  33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40,
  61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11,
  36, 20, 34, 44, 52,
];

const String kUaWeb =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/// 单条解析后的 Cookie（Netscape 双向转换载体）。
final class BiliCookie {
  const BiliCookie({
    required this.domain,
    required this.path,
    required this.name,
    required this.value,
    required this.expiresAtMs,
    required this.secure,
  });

  final String domain;
  final String path;
  final String name;
  final String value;
  final int expiresAtMs;
  final bool secure;
}

final class BilibiliClient {
  BilibiliClient({SecureStorePort? secureStore})
      : _secure = secureStore ?? SecureStoreAdapter();

  final SecureStorePort _secure;
  final HttpClient _http = HttpClient()..userAgent = kUaWeb;

  /// 登录 Cookie（SecureStore 装载）+ 免登录 buvid 合并池。
  final Map<String, BiliCookie> _jar = {};
  bool _bootstrapped = false;
  String? _mixinKey;

  /// SecureStore 登录键（=ExtractQueue.kCookieKey 同字面；写入方=登录域）。
  static const String kCookieKey = 'bilibili.cookies';

  /// 会话引导（幂等）：装载登录 Cookie → 缺 buvid 则 spi 补。
  /// 全程容错（SecureStore 平台缺失/网络失败≠搜索不可用；登录态尽力装载）。
  Future<void> ensureBootstrapped() async {
    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;
    try {
      final saved = await _secure.read(kCookieKey);
      if (saved != null && saved.isNotEmpty) {
        mergeNetscapeCookies(saved);
      }
    } catch (_) {
      // SecureStore 不可达（测试环境/平台缺通道；含 Error 面binding 未初始化）
      // =按匿名继续（登录态尽力装载，不拦搜索）
    }
    if (!_jar.containsKey('buvid3')) {
      try {
        final j = await getJson(
            Uri.parse('https://api.bilibili.com/x/frontend/finger/spi'));
        final d = (j['data'] as Map?)?.cast<String, dynamic>();
        final b3 = '${d?['b_3'] ?? ''}';
        final b4 = '${d?['b_4'] ?? ''}';
        final now = DateTime.now();
        if (b3.isNotEmpty) {
          _upsert(BiliCookie(
            domain: '.bilibili.com',
            path: '/',
            name: 'buvid3',
            value: b3,
            expiresAtMs: now.add(const Duration(days: 365)).millisecondsSinceEpoch,
            secure: true,
          ));
        }
        if (b4.isNotEmpty) {
          _upsert(BiliCookie(
            domain: '.bilibili.com',
            path: '/',
            name: 'buvid4',
            value: b4,
            expiresAtMs: now.add(const Duration(days: 365)).millisecondsSinceEpoch,
            secure: true,
          ));
        }
      } on Exception {
        // spi 失败不拦搜索（风控可能在无 buvid 下仍放行；失败面留给调用方）
      }
    }
  }

  /// 是否已有登录态 Cookie（SESSDATA 在池即视为已登录）。
  bool get hasLoginCookie => _jar.containsKey('SESSDATA');

  /// 登录成功后由登录域合入 Cookie 并持久化（Netscape 全量覆写）。
  Future<void> adoptLoginCookies(List<BiliCookie> cookies) async {
    for (final c in cookies) {
      _upsert(c);
    }
    await _secure.write(kCookieKey, toNetscape());
  }

  /// 登出（SecureStore 清除 + 池内登录 Cookie 摘除；buvid 保留）。
  Future<void> clearLoginCookies() async {
    _jar.remove('SESSDATA');
    _jar.remove('bili_jct');
    _jar.remove('DedeUserID');
    _jar.remove('DedeUserID__ckMd5');
    await _secure.delete(kCookieKey);
  }

  /// 原样覆盖持久化（Cookie 粘贴导入路径）。
  Future<void> persistJar() => _secure.write(kCookieKey, toNetscape());

  /// 手工导入（粘贴的 Cookie 串 `k=v; k2=v2` 或 Netscape 文本）；返回是否含登录键。
  bool importCookieText(String raw) {
    final text = raw.trim();
    if (text.contains('\t') && text.contains('SESSDATA')) {
      mergeNetscapeCookies(text);
    } else {
      for (final pair in text.split(';')) {
        final i = pair.indexOf('=');
        if (i <= 0) {
          continue;
        }
        final name = pair.substring(0, i).trim();
        final value = pair.substring(i + 1).trim();
        if (name.isEmpty || value.isEmpty) {
          continue;
        }
        _upsert(BiliCookie(
          domain: '.bilibili.com',
          path: '/',
          name: name,
          value: value,
          expiresAtMs:
              DateTime.now().add(const Duration(days: 180)).millisecondsSinceEpoch,
          secure: true,
        ));
      }
    }
    return hasLoginCookie;
  }

  // ── HTTP ────────────────────────────────────────────────

  /// GET JSON（Cookie 池自动携带；返回顶层 {code,message,data}）。
  Future<Map<String, dynamic>> getJson(Uri uri,
      {Map<String, String>? extraHeaders}) async {
    final req = await _http.getUrl(uri);
    req.headers.set(HttpHeaders.refererHeader, 'https://www.bilibili.com/');
    req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');
    final cookieHeader = _cookieHeader();
    if (cookieHeader.isNotEmpty) {
      req.headers.set(HttpHeaders.cookieHeader, cookieHeader);
    }
    extraHeaders?.forEach(req.headers.set);
    final res = await req.close();
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: uri);
    }
    final body = await res.transform(utf8.decoder).join();
    final j = jsonDecode(body);
    if (j is! Map<String, dynamic>) {
      throw FormatException(msg.responseNotJson);
    }
    // 响应新 Cookie 合池（buvid 轮换等）。
    final setCookies = res.headers[HttpHeaders.setCookieHeader];
    if (setCookies != null) {
      for (final sc in setCookies) {
        final c = _parseSetCookie(sc);
        if (c != null) {
          _upsert(c);
        }
      }
    }
    return j;
  }

  /// wbi 签名后的搜索型 GET（自动补 wts/w_rid；缺 key 自举）。
  Future<Map<String, dynamic>> getJsonSigned(
      Uri base, Map<String, String> params) async {
    await ensureBootstrapped();
    final mixin = _mixinKey ?? await _loadMixinKey();
    final all = {...params, 'wts': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}'};
    final q = _signQuery(all);
    return getJson(Uri.parse('$base?$q&w_rid=${_md5(q + mixin)}'));
  }

  String _cookieHeader() =>
      _jar.values.map((c) => '${c.name}=${c.value}').join('; ');

  void _upsert(BiliCookie c) => _jar[c.name] = c;

  Future<String> _loadMixinKey() async {
    final nav = await getJson(Uri.parse('https://api.bilibili.com/x/web-interface/nav'));
    final d = (nav['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final wbi = (d['wbi_img'] as Map?)?.cast<String, dynamic>() ?? const {};
    final img = '${wbi['img_url'] ?? ''}'.rsplit('/', 1).split('.').first;
    final sub = '${wbi['sub_url'] ?? ''}'.rsplit('/', 1).split('.').first;
    final raw = img + sub;
    final buf = StringBuffer();
    for (final i in kMixinKeyEncTab) {
      if (i < raw.length) {
        buf.write(raw[i]);
      }
    }
    _mixinKey = buf.toString().substring(0, buf.length >= 32 ? 32 : buf.length);
    return _mixinKey!;
  }

  /// wbi 查询串（按 key 排序 + RFC3986 变体编码；空值剔除）。
  static String _signQuery(Map<String, String> params) {
    final keys = params.keys.where((k) => params[k] != null && params[k]!.isNotEmpty).toList()
      ..sort();
    return keys
        .map((k) => '$k=${_rfc3986(params[k]!)}')
        .join('&');
  }

  /// RFC3986 编码变体（`!'()*` 显式转义——wbi 服务端校验面）。
  static String _rfc3986(String v) => Uri.encodeComponent(v)
      .replaceAll('!', '%21')
      .replaceAll("'", '%27')
      .replaceAll('(', '%28')
      .replaceAll(')', '%29')
      .replaceAll('*', '%2A');

  static String _md5(String s) => md5.convert(utf8.encode(s)).toString();

  // ── Cookie 双向转换 ─────────────────────────────────────

  /// Set-Cookie 单行 → BiliCookie（dart:io 分行送达，无逗号折叠问题）。
  static BiliCookie? _parseSetCookie(String line) {
    final parts = line.split(';');
    if (parts.isEmpty || !parts.first.contains('=')) {
      return null;
    }
    final nv = parts.first.indexOf('=');
    final name = parts.first.substring(0, nv).trim();
    final value = parts.first.substring(nv + 1).trim();
    if (name.isEmpty) {
      return null;
    }
    var domain = '.bilibili.com';
    var path = '/';
    var secure = false;
    var expiresAtMs =
        DateTime.now().add(const Duration(days: 180)).millisecondsSinceEpoch;
    for (final attr in parts.skip(1)) {
      final a = attr.trim();
      final lower = a.toLowerCase();
      if (lower.startsWith('domain=')) {
        domain = a.substring(7).trim();
        if (!domain.startsWith('.')) {
          domain = '.$domain';
        }
      } else if (lower.startsWith('path=')) {
        path = a.substring(5).trim();
      } else if (lower == 'secure') {
        secure = true;
      } else if (lower.startsWith('expires=')) {
        try {
          expiresAtMs = HttpDate.parse(a.substring(8).trim())
              .millisecondsSinceEpoch;
        } on FormatException {
          // 缺省保留 +180d
        }
      }
    }
    return BiliCookie(
      domain: domain,
      path: path,
      name: name,
      value: value,
      expiresAtMs: expiresAtMs,
      secure: secure,
    );
  }

  /// Netscape 文本（yt-dlp `--cookies` 消费面；值不落日志）。
  String toNetscape() {
    final buf = StringBuffer('# Netscape HTTP Cookie File\n');
    for (final c in _jar.values) {
      final exp = (c.expiresAtMs ~/ 1000).toString();
      buf.write('${c.domain}\tTRUE\t${c.path}\t'
          '${c.secure ? 'TRUE' : 'FALSE'}\t$exp\t${c.name}\t${c.value}\n');
    }
    return buf.toString();
  }

  /// Netscape 文本合池（登录 Cookie 装载）。
  void mergeNetscapeCookies(String content) {
    for (final line in content.split('\n')) {
      final l = line.trim();
      if (l.isEmpty || l.startsWith('#')) {
        continue;
      }
      final cols = l.split('\t');
      if (cols.length < 7) {
        continue;
      }
      _upsert(BiliCookie(
        domain: cols[0],
        path: cols[2],
        secure: cols[3].toUpperCase() == 'TRUE',
        expiresAtMs: int.tryParse(cols[4]) != null
            ? int.parse(cols[4]) * 1000
            : DateTime.now().add(const Duration(days: 180)).millisecondsSinceEpoch,
        name: cols[5],
        value: cols[6],
      ));
    }
  }

  void dispose() => _http.close();
}

extension _RSplit on String {
  String rsplit(String sep, int n) {
    final i = lastIndexOf(sep);
    return i < 0 ? this : substring(i + sep.length);
  }
}
