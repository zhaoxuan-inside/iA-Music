/// B 站客户端：扫码登录 / wbi 签名站内搜索 / 视频信息 / DASH 音频流 / 字幕。
///
/// 真实协议实现（无 Mock）：所有端点在 collect_config.KBili。
/// 登录凭据经 PlatformStore 存取；请求按登录态携带 Cookie。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show md5;

import '../../app/config/collect_config.dart' as cfg;
import 'collect_ports.dart';
import 'download_guard.dart';
import 'platform_store.dart';

/// 扫码登录轮询态。
enum BiliQrState { waiting, scanned, expired, success, error }

class BiliQrCode {
  const BiliQrCode({required this.url, required this.qrcodeKey});

  /// 二维码内容（渲染用）。
  final String url;
  final String qrcodeKey;
}

class BiliQrPoll {
  const BiliQrPoll(this.state, {this.cookies, this.message});

  final BiliQrState state;
  final Map<String, String>? cookies;
  final String? message;
}

/// 站内搜索结果条目。
class BiliSearchItem {
  const BiliSearchItem({
    required this.bvid,
    required this.title,
    required this.author,
    required this.durationSec,
    this.coverUrl,
    this.description,
  });

  final String bvid;
  final String title;
  final String author;
  final int durationSec;
  final String? coverUrl;
  final String? description;
}

/// 视频信息（提取用元数据）。
class BiliVideoInfo {
  const BiliVideoInfo({
    required this.bvid,
    required this.title,
    required this.owner,
    required this.cid,
    required this.pages,
    required this.durationSec,
    this.aid,
  });

  final String bvid;
  final String title;
  final String owner;
  final int cid;
  final List<({int cid, String part})> pages;
  final int durationSec;
  final String? aid;
}

/// DASH 音频流地址。
class BiliAudioStream {
  const BiliAudioStream({
    required this.url,
    required this.sizeBytes,
    required this.ext,
    required this.qualityId,
  });

  final String url;
  final int sizeBytes;
  final String ext; // m4a / mp4
  final int qualityId;
}

/// 字幕轨。
class BiliSubtitle {
  const BiliSubtitle({required this.name, required this.url});

  final String name;
  final String url;
}

class BilibiliClient implements BiliCollectApi {
  BilibiliClient(this._store, {String? apiBase, String? passportBase})
      : apiBase = apiBase ?? cfg.KBili.host,
        passportBase = passportBase ?? cfg.KBili.passportHost;

  final PlatformStore _store;

  /// API 域（测试注入本地服务地址）。
  final String apiBase;

  /// passport 域（扫码登录；测试注入本地服务地址）。
  final String passportBase;

  HttpClient? _http;

  HttpClient get _client => _http ??= HttpClient()
    ..userAgent = cfg.KBili.userAgent
    ..connectionTimeout = const Duration(seconds: 15)
    ..findProxy = _findProxy;

  /// 调试/模拟器专用 HTTP 代理（--dart-define=IA_HTTP_PROXY=10.0.2.2:3128）；
  /// 发布包不传该 define，保持 DIRECT。
  static String _findProxy(Uri _) {
    const proxy = String.fromEnvironment('IA_HTTP_PROXY');
    return proxy.isEmpty ? 'DIRECT' : 'PROXY $proxy';
  }

  /// ── 登录 ─────────────────────────────────────────────────────────

  Future<BiliQrCode> generateQr() async {
    final json = await _getJson('$passportBase${cfg.KBili.qrGeneratePath}');
    final d = json['data'] as Map<String, dynamic>;
    return BiliQrCode(url: d['url'] as String, qrcodeKey: d['qrcode_key'] as String);
  }

  /// 轮询一次扫码状态（状态全在 data.code；外层 code 恒为 0）。
  ///
  /// 成功时的登录 cookie 按优先级三路汇源（实测 data 体里没有 cookies 字段，
  /// cookie 只出现在响应头与跨域回跳 URL 里）：
  /// ① data.cookies（旧口径，兜底）② data.url 回跳参数 ③ Set-Cookie 响应头（权威）。
  Future<BiliQrPoll> pollQr(String qrcodeKey) async {
    final (json, setCookies) = await _getJsonWithHeaders(
        '$passportBase${cfg.KBili.qrPollPath}?qrcode_key=$qrcodeKey');
    final d = json['data'] as Map<String, dynamic>;
    final stateCode = d['code'] as int? ?? -1;
    if (stateCode == cfg.KBili.pollExpired) {
      return const BiliQrPoll(BiliQrState.expired);
    }
    if (stateCode == cfg.KBili.pollSuccess) {
      final cookies = <String, String>{};
      final arr = d['cookies'];
      if (arr is List) {
        for (final c in arr) {
          if (c is Map<String, dynamic> &&
              c['name'] is String &&
              c['value'] is String) {
            cookies[c['name'] as String] = c['value'] as String;
          }
        }
      }
      final url = d['url'] as String?;
      if (url != null && url.isNotEmpty) {
        cookies.addAll(_cookiesFromCrossDomain(url));
      }
      cookies.addAll(_cookiesFromSetCookie(setCookies));
      final account = url == null || url.isEmpty ? null : _accountFromUrl(url);
      return BiliQrPoll(BiliQrState.success,
          cookies: cookies,
          message: account == null ? null : 'mid=$account');
    }
    if (stateCode == cfg.KBili.pollScanned) {
      return const BiliQrPoll(BiliQrState.scanned);
    }
    if (stateCode == cfg.KBili.pollWaiting) {
      return const BiliQrPoll(BiliQrState.waiting);
    }
    return BiliQrPoll(BiliQrState.error, message: 'code=$stateCode');
  }

  /// 跨域回跳 URL 里的登录 cookie 参数（SESSDATA / bili_jct / DedeUserID）。
  static Map<String, String> _cookiesFromCrossDomain(String url) {
    const names = ['SESSDATA', 'bili_jct', 'DedeUserID', 'DedeUserID__ckMd5'];
    final out = <String, String>{};
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return out;
    }
    for (final name in names) {
      final v = uri.queryParameters[name];
      if (v != null && v.isNotEmpty) {
        out[name] = v;
      }
    }
    return out;
  }

  /// Set-Cookie 头 → name=value（取各条首个分号前的键值，值内逗号原样保留）。
  static Map<String, String> _cookiesFromSetCookie(List<String> lines) {
    final out = <String, String>{};
    for (final line in lines) {
      final kv = line.split(';').first.trim();
      final i = kv.indexOf('=');
      if (i <= 0) {
        continue;
      }
      final name = kv.substring(0, i).trim();
      if (name.isEmpty) {
        continue;
      }
      out[name] = kv.substring(i + 1).trim();
    }
    return out;
  }

  /// 登录成功后的 cookie 头（SET-Cookie 汇出形式）。
  String cookieHeaderFrom(Map<String, String> cookies) {
    final buf = StringBuffer();
    for (final e in cookies.entries) {
      if (buf.isNotEmpty) {
        buf.write('; ');
      }
      buf.write('${e.key}=${e.value}');
    }
    return buf.toString();
  }

  /// 登录回跳 URL 里的用户 id（crossDomain 口径 DedeUserID=，兼容 mid=）。
  static String? _accountFromUrl(String url) {
    for (final key in const ['DedeUserID', 'mid']) {
      final i = url.indexOf('$key=');
      if (i < 0) {
        continue;
      }
      var rest = url.substring(i + key.length + 1);
      final amp = rest.indexOf('&');
      if (amp >= 0) {
        rest = rest.substring(0, amp);
      }
      final v = Uri.decodeComponent(rest).trim();
      if (v.isNotEmpty) {
        return v;
      }
    }
    return null;
  }

  /// ── 搜索（wbi 签名） ──────────────────────────────────────────────

  Future<List<BiliSearchItem>> search(String keyword, {int page = 1}) async {
    final wbi = await _wbiKeys();
    final params = <String, String>{
      'search_type': 'video',
      'keyword': keyword,
      'page': '$page',
    };
    final signed = _wbiSign(params, wbi.$1, wbi.$2);
    final qs = signed.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final json = await _getJson('$apiBase${cfg.KBili.searchTypePath}?$qs',
        requireReferer: true);
    final results = json['data'] as Map<String, dynamic>;
    final list = results['result'] as List? ?? const [];
    return [
      for (final r in list)
        if (r is Map<String, dynamic> &&
            (r['type'] as String?) == 'video' &&
            r['bvid'] is String)
          BiliSearchItem(
            bvid: r['bvid'] as String,
            title: _stripEm(r['title'] as String? ?? ''),
            author: r['author'] as String? ?? '',
            durationSec: _parseDur(r['duration'] as String? ?? ''),
            coverUrl: r['pic'] as String?,
            description: r['description'] as String?,
          ),
    ];
  }

  /// wbi 密钥（nav 接口 img_key/sub_url 末段）。
  Future<(String, String)> _wbiKeys() async {
    final json = await _getJson('$apiBase${cfg.KBili.wbiNavPath}');
    final wbi = json['data']?['wbi_img'] as Map<String, dynamic>?;
    if (wbi == null) {
      return ('', '');
    }
    final img = (wbi['img_url'] as String? ?? '').split('/').last.split('.').first;
    final sub = (wbi['sub_url'] as String? ?? '').split('/').last.split('.').first;
    return (img, sub);
  }

  /// wbi 签名（mixin key 固定重排表 + md5(query+salt)）。
  static const List<int> _mixinKeyTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
    33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40,
    61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11,
    36, 20, 34, 44, 52,
  ];

  static Map<String, String> _wbiSign(
      Map<String, String> params, String imgKey, String subKey) {
    final mixin = StringBuffer();
    final raw = imgKey + subKey;
    for (final i in _mixinKeyTab) {
      if (i < raw.length) {
        mixin.write(raw[i]);
      }
    }
    final salt = mixin.toString().substring(0, 32);
    final all = <String, String>{...params};
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    all['wts'] = '$now';
    // 键排序 + 值去干扰字符
    final keys = all.keys.toList()..sort();
    final qs = keys
        .map((k) => '${Uri.encodeQueryComponent(k)}='
            '${Uri.encodeQueryComponent(_sanitizeWbi(all[k]!))}')
        .join('&');
    final sign = md5.convert(utf8.encode('$qs$salt')).toString();
    return {...all, 'w_rid': sign};
  }

  static String _sanitizeWbi(String v) =>
      v.replaceAll(RegExp(r"[!'()*]"), '');

  /// 搜索结果里 <em class=...> 高亮标记剥离。
  static String _stripEm(String s) =>
      s.replaceAll(RegExp(r'</?em[^>]*>'), '');

  static int _parseDur(String s) {
    final parts = s.split(':');
    var sec = 0;
    for (final p in parts) {
      sec = sec * 60 + (int.tryParse(p) ?? 0);
    }
    return sec;
  }

  /// ── 视频信息 / 播放地址 / 字幕 ────────────────────────────────────

  /// 从任意 B 站 URL / BV 号提取 bvid。
  static String? bvidFrom(String url) {
    final m = RegExp(r'(BV[0-9A-Za-z]{10})').firstMatch(url);
    return m?.group(1);
  }

  @override
  Future<BiliVideoInfo> videoInfo(String bvid) async {
    final json = await _getJson('$apiBase${cfg.KBili.videoInfoPath}?bvid=$bvid',
        requireReferer: true);
    if (json['code'] != 0) {
      throw Exception('B 站视频信息获取失败：${json['message']}');
    }
    final d = json['data'] as Map<String, dynamic>;
    final pages = <({int cid, String part})>[];
    for (final p in d['pages'] as List? ?? const []) {
      if (p is Map<String, dynamic> && p['cid'] is int) {
        pages.add((cid: p['cid'] as int, part: p['part'] as String? ?? ''));
      }
    }
    return BiliVideoInfo(
      bvid: bvid,
      title: d['title'] as String? ?? bvid,
      owner: (d['owner'] as Map<String, dynamic>)['name'] as String? ?? '',
      cid: pages.isEmpty ? (d['cid'] as int? ?? 0) : pages.first.cid,
      pages: pages,
      durationSec: d['duration'] as int? ?? 0,
      aid: d['aid']?.toString(),
    );
  }

  /// DASH 音频流（按质量档位从高到低选第一个可用的）。
  @override
  Future<BiliAudioStream> audioStream(String bvid, String aid, int cid) async {
    final qs = 'bvid=$bvid&cid=$cid&fnval=16&qn=0'
        '${aid.isNotEmpty ? '&aid=$aid' : ''}';
    final json = await _getJson('$apiBase${cfg.KBili.playurlPath}?$qs',
        requireReferer: true);
    if (json['code'] != 0) {
      throw Exception('B 站播放地址获取失败：${json['message']}');
    }
    final dash = json['data']?['dash'] as Map<String, dynamic>?;
    final audioList = dash?['audio'] as List?;
    if (audioList == null || audioList.isEmpty) {
      throw Exception('该视频没有可提取的音频流');
    }
    for (final qid in cfg.KBili.audioQualityIds) {
      for (final a in audioList) {
        if (a is Map<String, dynamic> && a['id'] == qid) {
          return BiliAudioStream(
            url: a['baseUrl'] as String? ?? a['base_url'] as String,
            sizeBytes: a['size'] as int? ?? 0,
            ext: ((a['mimeType'] as String? ?? 'audio/mp4').contains('mp4'))
                ? 'm4a'
                : 'mp3',
            qualityId: qid,
          );
        }
      }
    }
    // 无匹配档位：取第一个
    final first = audioList.first as Map<String, dynamic>;
    return BiliAudioStream(
      url: first['baseUrl'] as String? ?? first['base_url'] as String,
      sizeBytes: first['size'] as int? ?? 0,
      ext: ((first['mimeType'] as String? ?? 'audio/mp4').contains('mp4'))
          ? 'm4a'
          : 'mp3',
      qualityId: first['id'] as int? ?? 0,
    );
  }

  /// 字幕轨列表。
  @override
  Future<List<BiliSubtitle>> subtitles(String? aid, int cid) async {
    if (aid == null || aid.isEmpty) {
      return const [];
    }
    final json = await _getJson(
        '$apiBase${cfg.KBili.playerInfoPath}?aid=$aid&cid=$cid',
        requireReferer: true);
    final sub = json['data']?['subtitle'] as Map<String, dynamic>?;
    final list = sub?['subtitles'] as List? ?? const [];
    return [
      for (final s in list)
        if (s is Map<String, dynamic> && s['subtitle_url'] is String)
          BiliSubtitle(
            name: ((s['lan'] as String?) ?? '') == 'ai-zh' ? 'AI 中文字幕' :
                (s['lan_doc'] as String? ?? '字幕'),
            url: (s['subtitle_url'] as String).startsWith('//')
                ? 'https:${s['subtitle_url']}'
                : s['subtitle_url'] as String,
          ),
    ];
  }

  /// 字幕 JSON → LRC 正文（不带头）。
  @override
  Future<String?> subtitleLrc(String subtitleUrl) async {
    final body = await _getText(subtitleUrl, requireReferer: true);
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final items = json['body'] as List?;
      if (items == null) {
        return null;
      }
      final buf = StringBuffer();
      for (final it in items) {
        if (it is Map<String, dynamic> &&
            it['from'] is num &&
            it['content'] is String) {
          buf.writeln(
              '${_lrcTime((it['from'] as num).toDouble())}${it['content']}');
        }
      }
      return buf.isEmpty ? null : buf.toString();
    } on Object {
      return null;
    }
  }

  static String _lrcTime(double sec) {
    final m = sec ~/ 60;
    final s = (sec - m * 60).toStringAsFixed(2).padLeft(5, '0');
    return '[${m.toString().padLeft(2, '0')}:$s]';
  }

  /// 音频流下载（带 Referer；返回落盘路径）。
  @override
  Future<String> downloadAudio(
      BiliAudioStream stream, String filePath,
      {void Function(int received, int total)? onProgress}) async {
    final req = await _client.openUrl('GET', Uri.parse(stream.url));
    req.headers.set(HttpHeaders.refererHeader, cfg.KBili.referer);
    req.headers.set(HttpHeaders.userAgentHeader, cfg.KBili.userAgent);
    final res = await req.close();
    if (res.statusCode != 200) {
      throw Exception('音频流下载失败：HTTP ${res.statusCode}');
    }
    final total = res.contentLength > 0
        ? res.contentLength
        : (stream.sizeBytes > 0 ? stream.sizeBytes : 0);
    final sink = File(filePath).openWrite();
    await pumpDownload(
      source: res,
      sink: sink,
      onChunk: (r) async {
        if (onProgress != null && total > 0) {
          onProgress(r, total);
        }
      },
    );
    await sink.flush();
    await sink.close();
    return filePath;
  }

  /// ── HTTP 基件 ─────────────────────────────────────────────────────

  /// 匿名设备指纹缓存（buvid3/buvid4）。
  Map<String, String>? _buvid;

  /// 匿名设备指纹（finger/spi）：api 域无 buvid 常触发 -412，
  /// 登录与未登录请求统一补齐（进程内缓存；失败静默不阻断主链路）。
  Future<Map<String, String>?> anonymousBuvid() async {
    if (_buvid != null) {
      return _buvid;
    }
    try {
      final req =
          await _client.openUrl('GET', Uri.parse('$apiBase${cfg.KBili.fingerSpiPath}'));
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final d = (jsonDecode(body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>?;
        final b3 = d?['b_3'] as String?;
        final b4 = d?['b_4'] as String?;
        if (b3 != null && b3.isNotEmpty) {
          _buvid = {'buvid3': b3, if (b4 != null && b4.isNotEmpty) 'buvid4': b4};
        }
      }
    } on Object {
      // 拿不到 buvid：继续无 cookie 请求，由调用方按错误处理
    }
    return _buvid;
  }

  /// 汇出本次请求的 Cookie 头：登录态 + 缺失的 buvid。
  Future<String?> _effectiveCookie() async {
    final map = <String, String>{};
    final stored = await _store.cookies(PlatformId.bilibili);
    if (stored != null && stored.isNotEmpty) {
      map.addAll(PlatformStore.cookieMap(stored));
    }
    if (!map.containsKey('buvid3')) {
      final buvid = await anonymousBuvid();
      if (buvid != null) {
        map.addAll(buvid);
      }
    }
    return map.isEmpty ? null : cookieHeaderFrom(map);
  }

  Future<(Map<String, dynamic>, List<String>)> _getJsonWithHeaders(String url,
      {bool requireReferer = false}) async {
    final req = await _client.openUrl('GET', Uri.parse(url));
    req.headers.set(HttpHeaders.userAgentHeader, cfg.KBili.userAgent);
    if (requireReferer) {
      req.headers.set(HttpHeaders.refererHeader, cfg.KBili.referer);
    }
    final cookie = await _effectiveCookie();
    if (cookie != null) {
      req.headers.set(HttpHeaders.cookieHeader, cookie);
    }
    final res = await req.close();
    if (res.statusCode != 200) {
      throw Exception('B 站请求失败：HTTP ${res.statusCode}');
    }
    final body = await res.transform(utf8.decoder).join();
    return (
      jsonDecode(body) as Map<String, dynamic>,
      res.headers['set-cookie'] ?? const <String>[],
    );
  }

  Future<Map<String, dynamic>> _getJson(String url,
          {bool requireReferer = false}) async =>
      (await _getJsonWithHeaders(url, requireReferer: requireReferer)).$1;

  Future<String> _getText(String url, {bool requireReferer = false}) async {
    final req = await _client.openUrl('GET', Uri.parse(url));
    req.headers.set(HttpHeaders.userAgentHeader, cfg.KBili.userAgent);
    if (requireReferer) {
      req.headers.set(HttpHeaders.refererHeader, cfg.KBili.referer);
    }
    final cookie = await _effectiveCookie();
    if (cookie != null) {
      req.headers.set(HttpHeaders.cookieHeader, cookie);
    }
    final res = await req.close();
    if (res.statusCode != 200) {
      throw Exception('字幕下载失败：HTTP ${res.statusCode}');
    }
    return res.transform(utf8.decoder).join();
  }

  void dispose() {
    _http?.close();
    _http = null;
  }
}
