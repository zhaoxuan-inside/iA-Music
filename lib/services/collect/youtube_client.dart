/// YouTube 客户端：InnerTube 站内搜索 / 播放流解析 / cookie 登录。
///
/// 真实协议实现（无 Mock）：端点与客户端语境在 collect_config.KYt。
/// 搜索与流解析走 InnerTube 公开客户端语境；登录采用浏览器 cookie 导入
/// （与 yt-dlp 的 cookies 通道同构——账号态由用户在自己浏览器里完成）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../app/config/collect_config.dart' as cfg;
import 'collect_ports.dart';
import 'download_guard.dart';
import 'platform_store.dart';

class YtSearchItem {
  const YtSearchItem({
    required this.videoId,
    required this.title,
    required this.author,
    required this.durationSec,
    this.album,
  });

  final String videoId;
  final String title;
  final String author;
  final int durationSec;
  final String? album;
}

/// 解析出的音频流。
class YtAudioStream {
  const YtAudioStream({
    required this.url,
    required this.ext,
    required this.bitrate,
    this.contentLength,
  });

  final String url;
  final String ext; // m4a / webm
  final int bitrate;
  final int? contentLength;
}

/// cookie 导入校验结果。
class YtCookieCheck {
  const YtCookieCheck(this.ok, {this.message});

  final bool ok;
  final String? message;
}

class YoutubeClient implements YtCollectApi {
  YoutubeClient(this._store);

  final PlatformStore _store;
  HttpClient? _http;

  HttpClient get _client => _http ??= HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  /// ── 登录（cookie 导入） ───────────────────────────────────────────

  /// 校验并保存 cookie。要求包含 SAPISID（谷歌登录态依据）。
  Future<YtCookieCheck> importCookies(String header) async {
    final map = PlatformStore.cookieMap(header);
    if (map.isEmpty) {
      return const YtCookieCheck(false, message: '没有解析到任何 cookie');
    }
    final hasLogin = cfg.KYt.requiredCookieNames.any(map.containsKey);
    if (!hasLogin) {
      return const YtCookieCheck(false,
          message: '缺少 SAPISID——请粘贴已登录 YouTube 的浏览器 Cookie 头');
    }
    await _store.saveCookies(PlatformId.youtube, header);
    // 登录名：从 cookie 无法可靠取到昵称，展示为「已登录账号」
    await _store.saveAccount(PlatformId.youtube,
        const PlatformAccount(name: '已登录账号', extra: {}));
    return const YtCookieCheck(true);
  }

  /// ── 站内搜索（WEB_REMIX 语境） ────────────────────────────────────

  Future<List<YtSearchItem>> search(String keyword) async {
    final body = jsonEncode({
      'context': _webRemixContext(),
      'query': keyword,
    });
    final json = await _postJson(
        '${cfg.KYt.search}&key=${cfg.KYt.webRemixKey}', body);
    final items = <YtSearchItem>[];
    _walk(json, (node) {
      if (node is Map<String, dynamic> &&
          node.containsKey('musicResponsiveListItemRenderer')) {
        final r = node['musicResponsiveListItemRenderer'] as Map<String, dynamic>;
        final v = _parseSearchRow(r);
        if (v != null) {
          items.add(v);
        }
      }
    });
    return items.take(20).toList();
  }

  /// Web 内嵌框架列（flexColumnRenderer → text runs）。
  YtSearchItem? _parseSearchRow(Map<String, dynamic> r) {
    final flex = r['flexColumns'] as List? ?? const [];
    String title = '', author = '';
    int dur = 0;
    String? album;
    for (final col in flex) {
      if (col is! Map<String, dynamic>) {
        continue;
      }
      final meta = col['musicResponsiveListItemFlexColumnRenderer']
          as Map<String, dynamic>?;
      final runs = meta?['text']?['runs'] as List?;
      if (runs == null || runs.isEmpty) {
        continue;
      }
      final text = (runs[0] as Map<String, dynamic>)['text'] as String? ?? '';
      final firstRun = runs[0] as Map<String, dynamic>;
      final navEndpoint =
          firstRun['navigationEndpoint'] as Map<String, dynamic>?;
      final navStyle = navEndpoint?['watchEndpoint'] as Map<String, dynamic>?;
      if (navStyle != null && navStyle['videoId'] is String) {
        title = text;
        continue;
      }
      // 副列：作者 · 专辑 · 时长
      if (text.isNotEmpty && author.isEmpty) {
        final segs = text.split(' • ');
        if (segs.isNotEmpty) {
          author = segs.first.trim();
        }
        if (segs.length > 1) {
          album = segs[1].trim();
        }
        final last = segs.last.trim();
        dur = _parseDur(last);
      }
    }
    final videoId = _findVideoId(r);
    if (videoId == null || title.isEmpty) {
      return null;
    }
    return YtSearchItem(
        videoId: videoId, title: title, author: author, durationSec: dur, album: album);
  }

  String? _findVideoId(Map<String, dynamic> r) {
    String? found;
    _walk(r, (node) {
      if (found != null) {
        return;
      }
      if (node is Map<String, dynamic> &&
          node['watchEndpoint'] is Map<String, dynamic>) {
        final id = (node['watchEndpoint'] as Map<String, dynamic>)['videoId'];
        if (id is String) {
          found = id;
        }
      }
    });
    return found;
  }

  /// 深度遍历（JSON 树遍历）。
  static void _walk(Object? node, void Function(Object? data) visit) {
    visit(node);
    if (node is Map<String, dynamic>) {
      for (final v in node.values) {
        _walk(v, visit);
      }
    } else if (node is List) {
      for (final v in node) {
        _walk(v, visit);
      }
    }
  }

  /// ── 播放流（ANDROID 语境） ────────────────────────────────────────

  /// 从任意 YouTube URL 提取 videoId。
  static String? videoIdFrom(String url) {
    final m = RegExp(r'(?:v=|youtu\.be/|shorts/|embed/)([0-9A-Za-z_-]{11})')
        .firstMatch(url);
    if (m != null) {
      return m.group(1);
    }
    if (RegExp(r'^[0-9A-Za-z_-]{11}$').hasMatch(url.trim())) {
      return url.trim();
    }
    return null;
  }

  /// 视频元数据 + 音频流（一次 player 调用同时给出）。
  @override
  Future<(Map<String, dynamic> videoDetails, YtAudioStream stream)>
      resolveAudio(String videoId) async {
    final body = jsonEncode({
      'context': _androidContext(),
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
    });
    final json = await _postJson(cfg.KYt.player, body,
        extraHeaders: {
          HttpHeaders.userAgentHeader: cfg.KYt.androidUserAgent,
          'X-YouTube-Client-Name': '29',
          'X-YouTube-Client-Version': cfg.KYt.androidVersion,
        },
        withCookies: true);
    final status = json['playabilityStatus']?['status'] as String?;
    if (status != 'OK') {
      final reason = json['playabilityStatus']?['reason'] as String? ?? status;
      throw Exception('YouTube 播放不可用：$reason');
    }
    final details = json['videoDetails'] as Map<String, dynamic>? ?? {};
    final formats = json['streamingData']?['adaptiveFormats'] as List?;
    if (formats == null || formats.isEmpty) {
      throw Exception('没有可提取的音频流');
    }
    YtAudioStream? best;
    for (final f in formats) {
      if (f is! Map<String, dynamic>) {
        continue;
      }
      final mime = f['mimeType'] as String? ?? '';
      if (!mime.startsWith('audio/')) {
        continue;
      }
      final url = f['url'] as String?;
      if (url == null) {
        continue; // 需要签名的流跳过（ANDROID 语境通常直出）
      }
      final bitrate = f['bitrate'] as int? ?? 0;
      if (best == null || bitrate > best.bitrate) {
        best = YtAudioStream(
          url: url,
          ext: mime.contains('webm') ? 'webm' : 'm4a',
          bitrate: bitrate,
          contentLength: f['contentLength'] as int?,
        );
      }
    }
    if (best == null) {
      throw Exception('音频流需要签名解密——本片暂不支持提取');
    }
    return (details, best);
  }

  /// ── HTTP 基件 ─────────────────────────────────────────────────────

  Map<String, dynamic> _webRemixContext() => {
        'client': {
          'clientName': cfg.KYt.webRemixName,
          'clientVersion': cfg.KYt.webRemixVersion,
          'hl': 'zh-CN',
          'gl': 'CN',
        },
      };

  Map<String, dynamic> _androidContext() => {
        'client': {
          'clientName': cfg.KYt.androidName,
          'clientVersion': cfg.KYt.androidVersion,
          'androidSdkVersion': cfg.KYt.androidSdk,
          'hl': 'zh-CN',
          'gl': 'CN',
        },
      };

  Future<Map<String, dynamic>> _postJson(String url, String body,
      {Map<String, String>? extraHeaders, bool withCookies = false}) async {
    final req = await _client.openUrl('POST', Uri.parse(url));
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    req.headers.set(HttpHeaders.userAgentHeader, cfg.KYt.androidUserAgent);
    extraHeaders?.forEach(req.headers.set);
    if (withCookies) {
      final cookie = await _store.cookies(PlatformId.youtube);
      if (cookie != null && cookie.isNotEmpty) {
        req.headers.set(HttpHeaders.cookieHeader, cookie);
      }
    }
    req.add(utf8.encode(body));
    final res = await req.close();
    if (res.statusCode != 200) {
      throw Exception('YouTube 请求失败：HTTP ${res.statusCode}');
    }
    final text = await res.transform(utf8.decoder).join();
    return jsonDecode(text) as Map<String, dynamic>;
  }

  /// 音频流下载（googlevideo 直链）。
  @override
  Future<String> downloadAudio(YtAudioStream stream, String filePath,
      {void Function(int received, int total)? onProgress}) async {
    final req = await _client.openUrl('GET', Uri.parse(stream.url));
    req.headers.set(HttpHeaders.userAgentHeader, cfg.KYt.androidUserAgent);
    final res = await req.close();
    if (res.statusCode != 200) {
      throw Exception('音频流下载失败：HTTP ${res.statusCode}');
    }
    final total = res.contentLength > 0 ? res.contentLength : 0;
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

  static int _parseDur(String s) {
    final parts = s.split(':');
    var sec = 0;
    for (final p in parts) {
      sec = sec * 60 + (int.tryParse(p) ?? 0);
    }
    return sec;
  }

  void dispose() {
    _http?.close();
    _http = null;
  }
}
