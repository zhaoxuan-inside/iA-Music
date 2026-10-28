/// SubtitleAdapter —— 平台字幕文本提取（REQ-EXT 内容可选面「文字」）。
///
/// 通道一（桌面 Process 形态；Android 原生引擎暂无字幕面=诚实降级返回 null）：
/// * yt-dlp `--write-subs --write-auto-subs --skip-download` 拉字幕（B 站
///   AI 字幕需登录态 → cookiesRefKey 同 DownloadPlan 纪律，临时文件即删）；
/// * 产物 vtt/srt → LRC 文本（`[mm:ss.xx] 行`；重复行/纯标记行剔除）；
/// * 语种择优：ai-zh / zh-CN / zh-Hans 优先，其次任意首个。
///
/// 通道二（2026-10-24 能力补齐：B 站 player API 直达，不依赖 yt-dlp 字幕抓取）：
/// * `x/web-interface/view?bvid=` 取 cid（多 P 按 ?p=N 取对应分 P）→
///   `x/player/wbi/v2?bvid&cid`（wbi 签名走 BilibiliClient，登录池随行）→
///   `data.subtitle.subtitles[]`（CC + 登录可见的 ai-zh）→ subtitle_url 的
///   JSON body → LRC。通道一空手时自动尝试（多为 AI 字幕=登录专属）。
///
/// 纪律：不落日志的只有 Cookie；字幕正文属公开内容可正常流转。
library;

import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:ia_music/adapters/bilibili_client.dart';
import 'package:ia_music/adapters/downloader_adapter.dart';
import 'package:ia_music/adapters/secure_store_adapter.dart';

final class SubtitleAdapter {
  SubtitleAdapter({SecureStorePort? secureStore, BilibiliClient? bilibili})
      : _secure = secureStore ?? SecureStoreAdapter(),
        _client = bilibili;

  final SecureStorePort _secure;

  /// B 站 API 直达通道（null=仅 yt-dlp 通道；组合根注入共享 Cookie 池）。
  final BilibiliClient? _client;

  /// 拉取字幕并转 LRC 文本（无字幕/失败=null——调用方按「无字幕文本」降级）。
  /// 通道一（yt-dlp）先试；空手且 API 通道可用时试通道二（CC/AI 字幕）。
  Future<String?> fetchLrcText({
    required String url,
    required String workDir,
    String? cookiesRefKey,
  }) async {
    final dir = Directory(workDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    File? cookieFile;
    try {
      if (cookiesRefKey != null) {
        final v = await _secure.read(cookiesRefKey);
        if (v != null && v.isNotEmpty) {
          final tmp = await Directory.systemTemp.createTemp('ia_cookies');
          cookieFile = File('${tmp.path}/cookies.txt');
          await cookieFile.writeAsString(v, flush: true);
        }
      }
      final viaProcess = await _viaYtDlp(dir, url, cookieFile);
      if (viaProcess != null) {
        return viaProcess;
      }
      return await _viaBiliApi(url); // 通道二（多为 AI 字幕：登录专属）
    } on Exception {
      return null; // 拉不起进程/网络失败=无字幕文本（人话面由调用方组织）
    } finally {
      if (cookieFile != null) {
        try {
          await cookieFile.delete();
          await cookieFile.parent.delete(recursive: true);
        } on Exception {
          // 临时目录 OS 回收兜底
        }
      }
    }
  }

  /// 通道一：yt-dlp 字幕文件落 workDir → 择优转 LRC（无字幕/失败=null）。
  Future<String?> _viaYtDlp(Directory dir, String url, File? cookieFile) async {
    try {
      final r = await Process.run(kYtDlpLauncherExe, [
        ...kYtDlpLauncherArgs,
        '--skip-download',
        '--write-subs',
        '--write-auto-subs',
        '--sub-langs',
        '.*',
        '--sub-format',
        'vtt/srt/best',
        '--no-warnings',
        if (cookieFile != null) ...['--cookies', cookieFile.path],
        '-o',
        '${dir.path}/%(id)s.%(ext)s',
        url,
      ], environment: DownloaderAdapter.env);
      if (r.exitCode != 0) {
        return null;
      }
      return _pickAndConvert(dir);
    } on Exception {
      return null;
    }
  }

  /// 通道二：B 站 player API 直达（CC + 登录可见 AI 字幕；无 client=跳过）。
  Future<String?> _viaBiliApi(String url) async {
    final client = _client;
    if (client == null) {
      return null;
    }
    final bvid = _bvidOf(url);
    if (bvid == null) {
      return null;
    }
    try {
      final view = await client.getJson(Uri.parse(
          'https://api.bilibili.com/x/web-interface/view?bvid=$bvid'));
      if (view['code'] != 0 || view['data'] is! Map) {
        return null;
      }
      final data = (view['data'] as Map).cast<String, dynamic>();
      final cid = _cidOf(data, url);
      if (cid == null) {
        return null;
      }
      final player = await client.getJsonSigned(
        Uri.parse('https://api.bilibili.com/x/player/wbi/v2'),
        {'bvid': bvid, 'cid': '$cid'},
      );
      if (player['code'] != 0 || player['data'] is! Map) {
        return null;
      }
      final pdata = (player['data'] as Map).cast<String, dynamic>();
      final sub = (pdata['subtitle'] as Map?)?.cast<String, dynamic>() ?? const {};
      final list = (sub['subtitles'] as List? ?? const []);
      if (list.isEmpty) {
        return null;
      }
      final picked = _pickSubtitle(list);
      if (picked == null) {
        return null;
      }
      final raw = await client.getJson(
          Uri.parse(_abs(picked['subtitle_url'] ?? '')));
      return apiSubtitleJsonToLrc(raw);
    } on Exception {
      return null;
    }
  }

  /// 字幕轨择优：ai-zh > zh* > 首条（与通道一同序）。
  static Map<String, dynamic>? _pickSubtitle(List<Object?> list) {
    Map<String, dynamic>? best;
    var bestScore = 99;
    for (final e in list) {
      if (e is! Map) {
        continue;
      }
      final m = Map<String, dynamic>.from(e.cast<Object?, Object?>());
      final lan = '${m['lan'] ?? ''}'.toLowerCase();
      final score = lan == 'ai-zh'
          ? 0
          : lan.startsWith('zh')
              ? 1
              : 2;
      if (score < bestScore) {
        best = m;
        bestScore = score;
      }
    }
    return best;
  }

  static String _abs(String raw) {
    if (raw.startsWith('//')) {
      return 'https:$raw';
    }
    return raw.startsWith('http') ? raw : 'https:$raw';
  }

  /// 视频页 URL → BV 号（搜索/分享面均为 /video/BV… 形态）。
  static String? _bvidOf(String url) {
    final m = RegExp(r'/video/(BV[0-9A-Za-z]+)').firstMatch(url);
    return m?.group(1);
  }

  /// view data → 目标分 P cid（`?p=N` 取 pages[N-1]；单 P 用顶层 cid）。
  static int? _cidOf(Map<String, dynamic> data, String url) {
    final pm = RegExp(r'[?&]p=(\d+)').firstMatch(url);
    if (pm != null) {
      final pages = (data['pages'] as List? ?? const []);
      final idx = int.parse(pm.group(1)!) - 1;
      if (idx >= 0 && idx < pages.length && pages[idx] is Map) {
        return ((pages[idx] as Map)['cid'] as num?)?.toInt();
      }
      return null;
    }
    return (data['cid'] as num?)?.toInt();
  }

  /// 工作目录内择优字幕 → LRC 文本（ai-zh 优先；vtt/srt 后缀面）。
  String? _pickAndConvert(Directory dir) {
    final files = <File>[];
    for (final e in dir.listSync()) {
      if (e is File) {
        final n = e.path.toLowerCase();
        if (n.endsWith('.vtt') || n.endsWith('.srt')) {
          files.add(e);
        }
      }
    }
    if (files.isEmpty) {
      return null;
    }
    int score(File f) {
      final p = f.path.toLowerCase();
      if (p.contains('ai-zh')) {
        return 0; // B 站 AI 中字
      }
      if (p.contains('-zh') || p.contains('zh-hans') || p.contains('zh-cn')) {
        return 1;
      }
      return 2;
    }

    files.sort((a, b) => score(a).compareTo(score(b)));
    return subtitleToLrc(files.first.readAsStringSync());
  }

  void dispose() {} // 形态对齐（Process 常驻资源=无）
}

/// player API 字幕 JSON（{body:[{from,content}]}）→ LRC 文本（毫秒起点行）。
String apiSubtitleJsonToLrc(Map<String, dynamic> raw) {
  final body = (raw['body'] as List? ?? const []);
  final out = <String>[];
  String? last;
  for (final e in body) {
    if (e is! Map) {
      continue;
    }
    final m = Map<String, dynamic>.from(e.cast<Object?, Object?>());
    final from = (m['from'] as num?)?.toDouble();
    final content = '${m['content'] ?? ''}'.trim();
    if (from == null || content.isEmpty || content == last) {
      continue;
    }
    last = content;
    final totalSec = from.floor();
    final mm = (totalSec ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSec % 60).toString().padLeft(2, '0');
    final cs = ((from - totalSec) * 100).round().toString().padLeft(2, '0');
    out.add('[$mm:$ss.$cs]$content');
  }
  return out.join('\n');
}

/// vtt/srt → LRC 文本（时间轴行取起点；重复行去重；WEBVTT 头/序号行剔除）。
String subtitleToLrc(String raw) {
  final out = <String>[];
  String? lastText;
  final tsRe = RegExp(r'(\d{1,2}):(\d{2}):(\d{2})[.,](\d{1,3})\s*-->');
  final lines = raw.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final m = tsRe.firstMatch(lines[i]);
    if (m == null) {
      continue;
    }
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final s = int.parse(m.group(3)!);
    final msStr = (m.group(4)!).padRight(2, '0').substring(0, 2);
    // 文本行：时间轴行之后直到空行
    final textLines = <String>[];
    for (var j = i + 1; j < lines.length; j++) {
      final t = lines[j].trim();
      if (t.isEmpty) {
        break;
      }
      if (tsRe.hasMatch(t)) {
        break;
      }
      textLines.add(_stripVttMarkup(t));
      i = j;
    }
    final text = textLines.where((t) => t.isNotEmpty).join(' ').trim();
    if (text.isEmpty || text == lastText) {
      continue;
    }
    lastText = text;
    final mmss = '${(h * 60 + min).toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}.$msStr';
    out.add('[$mmss]$text');
  }
  return out.join('\n');
}

/// vtt 行内标记剥离（`<c>`/`<00:00:01.000>`/`&nbsp;` 等）。
String _stripVttMarkup(String line) => line
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
