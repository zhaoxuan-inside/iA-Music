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

/// B 站音频轨 DASH 质量位（§5.2 枚举族映射）。
const Map<int, Quality> kBiliAudioTrackQuality = {
  30216: Quality.k64,
  30232: Quality.k128,
  30280: Quality.k192,
};

/// 失败分类（ IllegalStateException：auth 不自动重试——§4.3）。
enum DownloadFailureClass { auth, disk, network }

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
  Future<ResolvedMeta> resolve(String sharedUrl) async {
    final url = extractFirstUrl(sharedUrl);
    if (url == null) {
      throw const FormatException('未在分享文本中找到链接');
    }
    final r = await Process.run(kYtDlpLauncherExe, [
      ...kYtDlpLauncherArgs,
      '-J', // 仅元数据（simulate 语义=解析预期行为）
      '--no-playlist',
      '--no-warnings',
      url,
    ], environment: _env);

    if (r.exitCode != 0) {
      final klass = classify(r.stdout.toString(), r.stderr.toString());
      if (klass == DownloadFailureClass.auth) {
        throw const AuthExpiredException('链接解析失败：该内容需要登录，或链接已失效。可登录 B 站账号后再试');
      }
      throw NetworkLostException('链接解析失败：链接可能已失效，或该内容需要登录');
    }

    final j = jsonDecode(r.stdout.toString()) as Map<String, dynamic>;
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

  @override
  TaskHandle download(DownloadPlan plan) {
    final handle = TaskHandle(_nextId++);
    unawaited(_runDownload(handle, plan));
    return handle;
  }

  Future<void> _runDownload(TaskHandle handle, DownloadPlan plan) async {
    File? cookieFile;
    final ext = plan.quality == Quality.hires ? 'flac' : 'mp3';
    final stagedPath =
        '${plan.outputDir.replaceAll('\\', '/')}/${plan.sourceId}.$ext';
    final args = <String>[
      ...kYtDlpLauncherArgs,
      '--no-playlist',
      '--newline', // 进度逐行（百分比解析）
      '--no-warnings',
      '-x',
      '--audio-format',
      ext,
      '--audio-quality',
      '5', // EXP-001 锚：mp3 重近源码率（细节=VBR 5）
      '--embed-thumbnail',
      '--embed-metadata',
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
        final staged = File(stagedPath);
        if (staged.existsSync()) {
          _events.add(TaskStaged(stagedPath));
        } else {
          _events.add(TaskFailed(DownloadError.transcode,
              detail: 'postprocess output missing: $stagedPath'));
        }
      } else {
        final klass = classify(captured.join(), '');
        _events.add(TaskFailed(_map(klass), detail: 'exit=$code'));
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

  /// 失败分类（stderr/stdout 语料小写比对；默认 network——Auto 重试唯一类）。
  static DownloadFailureClass classify(String stdoutText, String stderrText) {
    final text = (stdoutText + stderrText).toLowerCase();
    if ((text.contains('login') && text.contains('cookie')) ||
        text.contains('sign in') ||
        text.contains('需要登录') ||
        text.contains('请登录')) {
      return DownloadFailureClass.auth;
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
      case DownloadFailureClass.network:
        return DownloadError.network;
    }
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
}

/// 从分享文本提取首个 URL（PRD §3 链接输入：自动从整段文本取 URL）。
String? extractFirstUrl(String text) {
  final m = RegExp(r'https?://[^\s\u4e00-\u9fff]+').firstMatch(text);
  return m?.group(0);
}
