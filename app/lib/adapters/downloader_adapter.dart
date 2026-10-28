/// DownloaderAdapter —— R1 桌面 Process 形态（EXP-001 锚：`py -m yt_dlp` +
/// `C:\Users\hardstone\tools\ffmpeg`，LGPL 侧按 TECH-04 分发期复核）。
///
/// 纪律：
/// * 解析=独立进程 `-J`（simulate 语义，仅元数据；REQ-EXT-01 ≤5s 由调用方计时）；
///   下载=独立进程**不带 `--print`**（EXP-001 工程发现：--print 隐含 simulate）。
/// * Cookie：DownloadPlan.cookiesRefKey 只携 SecureStore key（C50）；值读出后写
///   临时 Netscape cookies 文件，进程终态即删；不落日志、不落库。
/// * 断点续传：yt-dlp 默认 `--continue`（.part 续传）；pause=kill（保留 .part），
///   resume 由 ExtractQueue 以原 plan 重提 download；cancel=kill+分片清理
///   （无半成品遗留，§4.3）。
/// * 重试上限=§4.3（网络退避 1s/4s/16s ≤3 次/任务）、auth 不自动重试——由
///   ExtractQueue 持账，本 adapter 只做单次真实执行与失败分类。
/// * 所有活动任务共用单 stream（§2.1 契约原文「事件携语境由调用方绑定任务行」；
///   队列=串行下载，同一时刻至多一个活动任务→绑定唯一）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:ia_music/adapters/secure_store_adapter.dart';

/// yt-dlp 进程启动方式（EXP-001：用户级模块安装，免 PATH）。
const String kYtDlpLauncherExe = 'py';
const List<String> kYtDlpLauncherArgs = ['-m', 'yt_dlp'];

/// ffmpeg 目录（EXP-001 实测位；产品分发期替换为捆绑位并复核许可）。
const String kFfmpegDir = 'C:/Users/hardstone/tools/ffmpeg';

/// B 站音频轨 DASH 质量位（§5.2 枚举族映射；30250=hires/FLAC 需登录大会员，
/// 匿名解析不出该位→由回退链兜底，不因选位失败）。
const Map<int, Quality> kBiliAudioTrackQuality = {
  30216: Quality.k64,
  30232: Quality.k128,
  30280: Quality.k192,
  30250: Quality.hires,
};

/// 失败分类（ IllegalStateException：auth 不自动重试——§4.3）。
/// unsupported=链接格式/内容受限/工具链缺失（重试无意义，诚实人话）。
enum DownloadFailureClass { auth, disk, network, unsupported }

final class DownloaderAdapter implements DownloaderPort {
  DownloaderAdapter({SecureStorePort? secureStore})
      : _secure = secureStore ?? SecureStoreAdapter() {
    _events = StreamController.broadcast();
  }

  final SecureStorePort _secure;
  late final StreamController<TaskEvent> _events;

  Process? _current;
  TaskHandle? _currentHandle;
  int _nextId = 1;

  @override
  Stream<TaskEvent> get stream => _events.stream;

  @override
  Future<ResolvedMeta> resolve(String sharedUrl, {String? cookiesRefKey}) async {
    final url = extractFirstUrl(sharedUrl);
    if (url == null) {
      throw const FormatException('未在分享文本中找到链接');
    }
    final cookieFile = await _maybeCookieFile(cookiesRefKey);
    final String procOut;
    final String procErr;
    final int exitCode;
    try {
      final r = await Process.run(kYtDlpLauncherExe, [
        ...kYtDlpLauncherArgs,
        '-J', // 仅元数据（simulate 语义=解析预期行为）
        '--no-playlist',
        '--no-warnings',
        if (cookieFile != null) ...['--cookies', cookieFile.path],
        url,
      ], environment: _env);
      procOut = r.stdout as String;
      procErr = r.stderr as String;
      exitCode = r.exitCode;
    } on ProcessException {
      // 拉不起 yt-dlp 进程=环境形态不支持（Android 无桌面工具链），
      // 与「链接失效/需登录」是两类问题——人话错误必须分开（诚实红线）。
      throw const FormUnsupportedException(
          '提取功能当前为桌面端形态（Windows），Android 端将在后续版本支持');
    } finally {
      await _cleanupCookieFile(cookieFile);
    }

    if (exitCode != 0) {
      final klass = classify(procOut, procErr);
      if (klass == DownloadFailureClass.auth) {
        throw const AuthExpiredException('链接解析失败：该内容需要登录，或链接已失效。可登录 B 站账号后再试');
      }
      if (klass == DownloadFailureClass.unsupported) {
        throw const FormUnsupportedException(
            '该链接格式暂不支持提取（付费/地区/平台形态受限，或提取工具链需要更新）');
      }
      throw NetworkLostException('链接解析失败：链接可能已失效，或该内容需要登录');
    }

    final j =
        jsonDecode(procOut) as Map<String, dynamic>;
    return mapYtDlpJson(j, url);
  }

  @override
  Future<List<ResolvedMeta>> resolveAll(String sharedUrl, {String? cookiesRefKey}) async {
    final url = extractFirstUrl(sharedUrl);
    if (url == null) {
      throw const FormatException('未在分享文本中找到链接');
    }
    final cookieFile = await _maybeCookieFile(cookiesRefKey);
    final String procOut;
    final String procErr;
    final int exitCode;
    try {
      final r = await Process.run(kYtDlpLauncherExe, [
        ...kYtDlpLauncherArgs,
        '-J',
        '--flat-playlist', // 条目枚举不逐页取详情（≤5s 量级承诺不变）
        '--no-warnings',
        if (cookieFile != null) ...['--cookies', cookieFile.path],
        url,
      ], environment: _env);
      procOut = r.stdout as String;
      procErr = r.stderr as String;
      exitCode = r.exitCode;
    } on ProcessException {
      throw const FormUnsupportedException(
          '提取功能当前为桌面端形态（Windows），Android 端将在后续版本支持');
    } finally {
      await _cleanupCookieFile(cookieFile);
    }

    if (exitCode != 0) {
      final klass = classify(procOut, procErr);
      if (klass == DownloadFailureClass.auth) {
        throw const AuthExpiredException('链接解析失败：该内容需要登录，或链接已失效。可登录 B 站账号后再试');
      }
      if (klass == DownloadFailureClass.unsupported) {
        throw const FormUnsupportedException(
            '该链接格式暂不支持提取（付费/地区/平台形态受限，或提取工具链需要更新）');
      }
      throw NetworkLostException('链接解析失败：链接可能已失效，或该内容需要登录');
    }

    final j = jsonDecode(procOut) as Map<String, dynamic>;
    return mapPlaylistJson(j, url);
  }

  @override
  TaskHandle download(DownloadPlan plan) {
    final handle = TaskHandle(_nextId++);
    unawaited(_runDownload(handle, plan));
    return handle;
  }

  /// 音质位 → yt-dlp 格式选择器（B 站 DASH 音轨 format_id=30216/30232/30280/
  /// 30250 实测面；逐级回退保证匿名/低清晰度账号不因选位失败）。
  static String qualitySelector(Quality q) => switch (q) {
        Quality.k64 => 'ba[format_id=30216]/ba/bestaudio',
        Quality.k128 => 'ba[format_id=30232]/ba[format_id=30216]/ba/bestaudio',
        Quality.k192 => 'ba[format_id=30280]/ba[format_id=30232]/ba/bestaudio',
        Quality.hires =>
          'ba[format_id=30250]/ba[format_id=30280]/ba[format_id=30232]/ba/bestaudio',
      };

  /// 产物命名目标（音频=音质扩展名；视频=mp4 封装不入库）。
  static String stagedExt(DownloadPlan plan) => !plan.audioOnly
      ? 'mp4'
      : plan.quality == Quality.hires
          ? 'flac'
          : 'mp3';

  /// stderr/stdout 语料 → 最后一条 yt-dlp ERROR 行（截 300 字；失败人话的
  /// 真实依据——B 站风控 -412/付费墙/格式不支持都只有这里有信息）。
  static String? firstErrorLine(String captured) {
    for (final line in captured.split('\n').reversed) {
      final l = line.trim();
      if (l.contains('ERROR:')) {
        final i = l.indexOf('ERROR:');
        final err = l.substring(i);
        return err.length > 300 ? '${err.substring(0, 300)}…' : err;
      }
    }
    return null;
  }

  Future<void> _runDownload(TaskHandle handle, DownloadPlan plan) async {
    File? cookieFile;
    final ext = stagedExt(plan);
    final stagedPath =
        '${plan.outputDir.replaceAll('\\', '/')}/${plan.sourceId}.$ext';
    final args = <String>[
      ...kYtDlpLauncherArgs,
      '--no-playlist',
      '--newline', // 进度逐行（百分比解析）
      '--no-warnings',
      if (plan.audioOnly) ...[
        // 音质位真实接线（2026-10-24 能力补齐）：此前 quality 从未进参数，
        // 64/128/192/hires 产物完全相同=假选择。
        '-f',
        qualitySelector(plan.quality),
        '-x',
        '--audio-format',
        ext,
        '--audio-quality',
        '5', // EXP-001 锚：mp3 重近源码率（细节=VBR 5）
        '--embed-thumbnail',
        '--embed-metadata',
      ] else ...[
        '-S', 'ext:mp4', // 优先 mp4 容器（画质对齐 B 站 DASH）
        '--merge-output-format', 'mp4',
      ],
      '--ffmpeg-location',
      kFfmpegDir,
      '-o',
      '${plan.outputDir.replaceAll('\\', '/')}/%(id)s.%(ext)s',
    ];
    final captured = <String>[]; // stdout 尾部（失败分类语料；不含 Cookie 内容）
    try {
      if (plan.cookiesRefKey != null) {
        final v = await _secure.read(plan.cookiesRefKey!);
        if (v != null && v.isNotEmpty) {
          cookieFile = await _writeCookieFile(v);
          args.addAll(['--cookies', cookieFile.path]);
        }
      }
      args.add(plan.url);

      final p = await Process.start(kYtDlpLauncherExe, args, environment: _env);
      _current = p;
      _currentHandle = handle;

      final sub = p.stdout.transform(utf8.decoder).listen((chunk) {
        captured.add(chunk);
        for (final line in chunk.split('\n')) {
          final l = line.trim();
          final m = RegExp(r'\[download\]\s+([\d.]+)%').firstMatch(l);
          if (m != null) {
            _events.add(TaskProgress(double.parse(m.group(1)!)));
          }
        }
      });
      p.stderr.transform(utf8.decoder).listen(captured.add);

      final code = await p.exitCode;
      await sub.cancel();
      if (_currentHandle != handle) {
        return; // 已被 cancel/pause 取代：终态由调用方记账
      }
      if (code == 0) {
        // 产物定位：精确名优先；兜底=目录内最新媒体文件（裸多 P URL 经
        // --no-playlist 实下 P1，产物 id 带 _pN 后缀 ≠ 预计算名——实测面）。
        final staged = File(stagedPath);
        final found = staged.existsSync()
            ? staged
            : _newestMediaFile(plan.outputDir);
        if (found != null) {
          _events.add(TaskStaged(found.path));
        } else {
          _events.add(TaskFailed(DownloadError.transcode,
              detail: 'postprocess output missing: $stagedPath'));
        }
      } else {
        final klass = classify(captured.join(), '');
        // 真实错误行透传（此前 detail=exit=$code——B 站风控/付费墙/格式限制
        // 的唯一信息源被丢弃，用户只见「提取失败」无法诊断）。
        final err = firstErrorLine(captured.join());
        _events.add(TaskFailed(_map(klass),
            detail: err == null ? 'exit=$code' : 'exit=$code; $err'));
      }
    } catch (e) {
      if (_currentHandle == handle) {
        _events.add(TaskFailed(DownloadError.network, detail: e.toString()));
      }
    } finally {
      if (cookieFile != null) {
        try {
          await cookieFile.delete();
        } on Exception {
          // 同目录临时件一并清理（目录级）
        }
        await cookieFile.parent
            .delete(recursive: true)
            .then((_) {}, onError: (_) {});
      }
      if (_currentHandle == handle) {
        _current = null;
        _currentHandle = null;
      }
    }
  }

  /// Windows 树杀（chained ffmpeg 子进程一并回收，§4.3 资源释放）。
  Future<void> _kill(Process p) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', '${p.pid}', '/T', '/F']);
      } else {
        p.kill();
      }
    } on Exception {
      // 已退出=语义等效
    }
  }

  @override
  Future<void> pause(TaskHandle handle) async {
    // pause=kill（.part 保留，续传 Found 在 resume 重提时「continue」）
    final p = _current;
    if (p != null && _currentHandle == handle) {
      await _kill(p);
      _current = null;
      _currentHandle = null;
      _events.add(TaskPaused('user'));
    }
  }

  @override
  Future<void> resume(TaskHandle handle) async {
    throw UnimplementedError('resume 由 ExtractQueue 以原 plan 重提 download（--continue 续传）');
  }

  @override
  Future<void> cancel(TaskHandle handle) async {
    final p = _current;
    if (_currentHandle == handle && p != null) {
      await _kill(p);
      _current = null;
      _currentHandle = null;
    }
  }

  /// 该 sourceId 半成品清理（cancel 语义：无半成品遗留——§4.3）。
  Future<void> cleanupPartial(String outputDir, String sourceId) async {
    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      return;
    }
    await for (final e in dir.list()) {
      final n = e.path.split(Platform.pathSeparator).last;
      if (n.startsWith(sourceId) &&
          (n.endsWith('.part') ||
              n.endsWith('.ytdl') ||
              n.endsWith('.part-temp'))) {
        try {
          await e.delete();
        } on Exception {
          // 由调用方快照面记录
        }
      }
    }
  }

  /// 目录内最新媒体产物（.part/.ytdl 除外）。
  static File? _newestMediaFile(String dir) {
    final d = Directory(dir);
    if (!d.existsSync()) {
      return null;
    }
    File? best;
    DateTime bestAt = DateTime.fromMillisecondsSinceEpoch(0);
    for (final e in d.listSync()) {
      if (e is! File) {
        continue;
      }
      final n = e.path.toLowerCase();
      if (!(n.endsWith('.mp3') ||
          n.endsWith('.mp4') ||
          n.endsWith('.flac') ||
          n.endsWith('.m4a'))) {
        continue;
      }
      final m = e.statSync().modified;
      if (m.isAfter(bestAt)) {
        bestAt = m;
        best = e;
      }
    }
    return best;
  }

  /// 失败分类（stderr/stdout 语料小写比对；默认 network——Auto 重试唯一类）。
  /// unsupported=格式/内容/工具链受限（重试无意义）：yt-dlp 无法提取、内容
  /// 需大会员/付费（premium/充电）、ffmpeg 缺失。
  static DownloadFailureClass classify(String stdoutText, String stderrText) {
    final text = (stdoutText + stderrText).toLowerCase();
    if ((text.contains('login') && text.contains('cookie')) ||
        text.contains('sign in') ||
        text.contains('需要登录') ||
        text.contains('请登录')) {
      return DownloadFailureClass.auth;
    }
    if (text.contains('unable to extract') ||
        text.contains('unsupported url') ||
        text.contains('ffmpeg not found') ||
        text.contains('ffmpeg is not') ||
        text.contains('premium member') ||
        text.contains('大会员') ||
        text.contains('充电专属')) {
      return DownloadFailureClass.unsupported;
    }
    if (text.contains('no space') || text.contains('disk full')) {
      return DownloadFailureClass.disk;
    }
    return DownloadFailureClass.network;
  }

  DownloadError _map(DownloadFailureClass k) {
    switch (k) {
      case DownloadFailureClass.auth:
        return DownloadError.auth;
      case DownloadFailureClass.disk:
        return DownloadError.disk;
      case DownloadFailureClass.unsupported:
        return DownloadError.transcode; // 契约枚举无 unsupported 位：最贴近的终态码
      case DownloadFailureClass.network:
        return DownloadError.network;
    }
  }

  /// SecureStore 键 → 临时 Netscape cookies 文件（无 Cookie/键空=null；C50：
  /// 值不落日志，进程终态即删）。
  Future<File?> _maybeCookieFile(String? refKey) async {
    if (refKey == null) {
      return null;
    }
    final v = await _secure.read(refKey);
    if (v == null || v.isEmpty) {
      return null;
    }
    return _writeCookieFile(v);
  }

  Future<void> _cleanupCookieFile(File? f) async {
    if (f == null) {
      return;
    }
    try {
      await f.delete();
    } on Exception {
      // 目录级清理兜底
    }
    await f.parent.delete(recursive: true).then((_) {}, onError: (_) {});
  }

  Future<File> _writeCookieFile(String content) async {
    final dir = await Directory.systemTemp.createTemp('ia_cookies');
    final f = File('${dir.path}/cookies.txt');
    await f.writeAsString(content, flush: true);
    return f;
  }

  /// EXP-001 环境底数：Windows 下 Python 输出编码必须显式 UTF-8。
  static Map<String, String> get _env => {
        ...Platform.environment,
        'PYTHONIOENCODING': 'utf-8',
      };

  /// 同族适配器（字幕面）共用进程环境（UTF-8 语料面一致）。
  static Map<String, String> get env => _env;
}

/// yt-dlp `-J` JSON → ResolvedMeta（桌面/Android 两端共用映射； qualities=B 站音轨枚举族）。
ResolvedMeta mapYtDlpJson(Map<String, dynamic> j, String url) {
  final qualitySet = <Quality>{};
  for (final f in (j['formats'] as List? ?? [])) {
    final q = kBiliAudioTrackQuality[int.tryParse('${f['format_id']}')];
    if (q != null) {
      qualitySet.add(q);
    }
  }
  final qualities = qualitySet.isEmpty
      ? const <Quality>[Quality.k64]
      : (qualitySet.toList()..sort((a, b) => b.index.compareTo(a.index)));

  return ResolvedMeta(
    sourceType: 'bilibili',
    sourceId: '${j['id']}',
    url: url,
    title: '${j['title']}',
    uploader: '${j['uploader'] ?? j['channel'] ?? ''}',
    durationMs: ((num.tryParse('${j['duration']}') ?? 0) * 1000).round(),
    qualities: qualities,
    coverUrl: j['thumbnail'] as String?,
  );
}

/// 从分享文本提取首个 URL（PRD §3 链接输入：自动从整段文本取 URL）。
String? extractFirstUrl(String text) {
  final m = RegExp(r'https?://[^\s\u4e00-\u9fff]+').firstMatch(text);
  return m?.group(0);
}

/// 分享文本 URL 归一（REQ-SEARCH 双入口，2026-10-24）：
/// 显式 `https?://` 直取；无协议头的域名形态（B 站分享/输入法截断后的
/// `www.bilibili.com/video/BV…`、`b23.tv/xxx`）补 `https://` 后归一。
/// 纯关键词（无域名形态）→ null=走搜索分支。
String? normalizeShareUrl(String text) {
  final explicit = extractFirstUrl(text);
  if (explicit != null) {
    return explicit;
  }
  final m = RegExp(
    r'([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?:com|cn|tv|net|org|cc|io|me)(?:/\S*)?)',
  ).firstMatch(text);
  return m == null ? null : 'https://${m.group(1)}';
}

/// yt-dlp flat-playlist JSON → 条目集（B 站多 P/合集拆分；开发裁决 2026-10-19）。
///
/// flat 枚举不逐页取详情：条目 title/duration/cover 由下载任务以条目 url
/// （`?p=N`）二次 resolve 补全；故这里只做最小真实映射——
/// * url = 条目 url（flat 面真实携带）；
/// * sourceId = `BVID_pN`（由 url 派生，与全量 resolve 的 `j['id']` 同构）；
/// * qualities = B 站 DASH 音轨枚举族（契约 §5.2 唯一事实源，非实测伪造面——
///   逐条任务二次 resolve 仍会真读 formats 复核）；
/// * 单视频（无 entries）→ 与 [mapYtDlpJson] 同路。
List<ResolvedMeta> mapPlaylistJson(Map<String, dynamic> j, String sharedUrl) {
  final rawEntries = j['entries'] as List?;
  if (rawEntries == null || rawEntries.isEmpty) {
    return [mapYtDlpJson(j, sharedUrl)];
  }
  final baseTitle = '${j['title'] ?? ''}'.trim();
  final out = <ResolvedMeta>[];
  for (final e in rawEntries) {
    if (e is! Map) {
      continue;
    }
    final m = Map<String, dynamic>.from(e.cast<Object?, Object?>());
    final entryUrl = '${m['url'] ?? ''}'.trim();
    if (entryUrl.isEmpty) {
      continue;
    }
    final page = _biliPageNumber(entryUrl);
    final bvid = _biliBvid(entryUrl) ?? 'bilibili_${out.length}';
    final entryTitle =
        ('${m['title'] ?? ''}'.trim().isNotEmpty ? '${m['title']}'.trim() : null) ??
            (page != null && baseTitle.isNotEmpty
                ? '$baseTitle p${page.toString().padLeft(2, '0')}'
                : null) ??
            bvid;
    out.add(ResolvedMeta(
      sourceType: 'bilibili',
      sourceId: page != null ? '${bvid}_p$page' : bvid,
      url: entryUrl,
      title: entryTitle,
      uploader: '${m['uploader'] ?? m['uploader2'] ?? j['uploader'] ?? ''}',
      durationMs: 0, // flat 面无条目时长；任务二次 resolve 补全（不伪造）。
      qualities: const [Quality.k192, Quality.k128, Quality.k64],
      coverUrl: null, // 逐条封面由任务转录侧真取（B 站页 thumbnail）。
    ));
  }
  if (out.isEmpty) {
    return [mapYtDlpJson(j, sharedUrl)];
  }
  return out;
}

/// `?p=N` → N（多 P 页码；无参/非 B 站 → null）。
int? _biliPageNumber(String url) {
  final m = RegExp(r'[?&]p=(\d+)').firstMatch(url);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// B 站 BV 号（/video/BV… 路径段）。
String? _biliBvid(String url) {
  final m = RegExp(r'/video/(BV[0-9A-Za-z]+)').firstMatch(url);
  return m?.group(1);
}

/// URL → 本地派生 sourceId（零网络；与全量 resolve 的 `j['id']` 同构：
/// `BVxxx` / `BVxxx_pN`）。非 B 站视频形态（短链 b23.tv 等）→ null。
String? bilibiliSourceIdOf(String url) {
  final bvid = _biliBvid(url);
  if (bvid == null) {
    return null;
  }
  final page = _biliPageNumber(url);
  return page != null ? '${bvid}_p$page' : bvid;
}
