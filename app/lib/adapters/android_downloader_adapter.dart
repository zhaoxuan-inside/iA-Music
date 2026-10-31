/// AndroidDownloaderAdapter —— T9A（S6 Android 侧）R1 AAR 形态
/// （DEC-008① 锁定：ffmpegkit-maintained/yt-dlp-android 2.0.2，MIT，内嵌
///  CPython 3.13 + yt_dlp + chaquopy_java 17.0.0；通道 `ia_extract/engine`
///  调用面 + `ia_extract/events` 事件面）。
///
/// 纪律（与桌面 Process 形态同语义）：
/// * resolve=yt_dlp `extract_info(download=False)`（=桌面 `-J` simulate 语义）；
///   下载=引擎真实 DASH 流 URL + Kotlin 分段下载 + ffmpeg-kit（MIT）转录 mp3。
/// * Cookie：plan.cookiesRefKey 只携 SecureStore key；值在 Dart 侧读出后经通道
///   内存传递，Kotlin 写应用私有 cacheDir 临时 cookies.txt，任务终态即删（C50）。
/// * 事件终态契约：download() 立即返回，**终态一律经事件面**（staged=成功、
///   paused=用户中止、failed=失败）——Kotlin 侧不抛终态异常（单活动任务语境，
///   泵=串行，handle 绑定唯一）。
/// * 断点续传：pause 保留 .part（Kotlin 协作中断在进度钩子逐步检查）；resume 由
///   ExtractQueue 以原 plan 重提（Range 续传）；cancel 删半成品（队列 Dart 侧）。
library;

import 'dart:async';

import 'dart:convert';

import 'package:contracts/contracts.dart';
import 'package:flutter/services.dart';
import 'package:ia_music/l10n/s.dart';

import 'package:ia_music/adapters/downloader_adapter.dart';
import 'package:ia_music/adapters/secure_store_adapter.dart';

final class AndroidDownloaderAdapter implements DownloaderPort {
  AndroidDownloaderAdapter({SecureStorePort? secureStore})
      : _secure = secureStore ?? SecureStoreAdapter() {
    _events = StreamController.broadcast();
    _listenNativeEvents();
  }

  static const MethodChannel _ch = MethodChannel('ia_extract/engine');
  static const EventChannel _evCh = EventChannel('ia_extract/events');

  final SecureStorePort _secure;
  late final StreamController<TaskEvent> _events;
  TaskHandle? _activeHandle;
  int _nextId = 1;
  bool _cancelFlagSent = false;

  @override
  Stream<TaskEvent> get stream => _events.stream;

  void _listenNativeEvents() {
    _evCh.receiveBroadcastStream().listen((dynamic ev) {
      if (ev is! Map) {
        return;
      }
      final type = '${ev['type']}';
      switch (type) {
        case 'progress':
          if (_activeHandle != null) {
            // Kotlin 侧 percent 为 double（占位 string 解析是桌面 Process 形态遗风）。
            final p = ev['percent'];
            final percent =
                (p is num ? p.toDouble() : (num.tryParse('$p') ?? 0)).toDouble();
            _events.add(TaskProgress(percent));
          }
        case 'staged':
          if (_activeHandle != null) {
            _events.add(TaskStaged('${ev['path']}'));
          }
        case 'paused':
          if (_activeHandle != null) {
            _activeHandle = null;
            _cancelFlagSent = false;
            _events.add(TaskPaused('${ev['reason']}'));
          }
        case 'failed':
          if (_activeHandle != null && !_cancelFlagSent) {
            final code = DownloadError.values.firstWhere(
              (c) => c.name == '${ev['code']}',
              orElse: () => DownloadError.network,
            );
            _activeHandle = null;
            _cancelFlagSent = false;
            _events.add(TaskFailed(
              code,
              detail: '${ev['detail'] ?? ''}',
            ));
          }
      }
    }, onError: (Object e) {
      if (_activeHandle != null && !_cancelFlagSent) {
        _activeHandle = null;
        _events.add(TaskFailed(DownloadError.network, detail: '$e'));
      }
    });
  }

  @override
  Future<ResolvedMeta> resolve(String sharedUrl, {String? cookiesRefKey}) async {
    final url = extractFirstUrl(sharedUrl);
    if (url == null) {
      throw FormatException(msg.noLinkInShareText);
    }
    final String j;
    try {
      j = await _ch.invokeMethod<String>('resolve', {'url': url}) ?? '';
    } on PlatformException catch (e) {
      throw _mapResolveException(e);
    } on MissingPluginException {
      throw FormUnsupportedException(msg.engineNotInit);
    }
    if (j.isEmpty) {
      throw NetworkLostException(msg.linkParseDead);
    }
    return mapYtDlpJson(jsonDecode(j) as Map<String, dynamic>, url);
  }

  @override
  Future<List<ResolvedMeta>> resolveAll(String sharedUrl, {String? cookiesRefKey}) async {
    final url = extractFirstUrl(sharedUrl);
    if (url == null) {
      throw FormatException(msg.noLinkInShareText);
    }
    final String j;
    try {
      j = await _ch.invokeMethod<String>('resolveAll', {'url': url}) ?? '';
    } on PlatformException catch (e) {
      throw _mapResolveException(e);
    } on MissingPluginException {
      throw FormUnsupportedException(msg.engineNotInit);
    }
    if (j.isEmpty) {
      throw NetworkLostException(msg.linkParseDead);
    }
    return mapPlaylistJson(jsonDecode(j) as Map<String, dynamic>, url);
  }

  ContractException _mapResolveException(PlatformException e) {
    // 与桌面 classify 语义对齐：auth/login 语料→auth；超时/网络语料→network
    // （Kotlin 侧透传 yt-dlp stderr 原文——raw 细节不进用户面，人话红线）。
    final t =
        '${e.code} ${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();
    if (t.contains('需要登录') || t.contains('请登录') ||
        (t.contains('login') && t.contains('cookie')) || t.contains('sign in')) {
      return AuthExpiredException(msg.linkNeedLogin);
    }
    if (t.contains('timed out') ||
        t.contains('timeout') ||
        t.contains('unable to download') ||
        t.contains('transporterror') ||
        t.contains('connection') ||
        t.contains('network')) {
      return NetworkLostException(msg.linkParseTimeout);
    }
    if (t.contains('unsupported url') || t.contains('not a valid url')) {
      return NetworkLostException(msg.linkParseUnrecognized);
    }
    if (e.code == 'engine') {
      return FormUnsupportedException(msg.engineErrorAndroid(e.message ?? e.code));
    }
    return NetworkLostException('链接解析失败：链接可能已失效，或该内容需要登录');
  }

  @override
  TaskHandle download(DownloadPlan plan) {
    final handle = TaskHandle(_nextId++);
    _activeHandle = handle;
    _cancelFlagSent = false;
    unawaited(_launchDownload(handle, plan)); // 终态经事件面（Kotlin 不抛终态异常）
    return handle;
  }

  Future<void> _launchDownload(TaskHandle handle, DownloadPlan plan) async {
    String? cookies;
    if (plan.cookiesRefKey != null) {
      final v = await _secure.read(plan.cookiesRefKey!);
      if (v != null && v.isNotEmpty) {
        cookies = v; // C50：内存传递，Kotlin 侧临时文件随终态即删
      }
    }
    try {
      await _ch.invokeMethod<dynamic>('download', {
        'url': plan.url,
        'outputDir': plan.outputDir.replaceAll('\\', '/'),
        'quality': plan.quality.name,
        'cookies': cookies,
      });
      // 终态（staged/paused/failed）经事件面处理；此处只应答 launch。
    } on PlatformException {
      if (_activeHandle == handle && !_cancelFlagSent) {
        _activeHandle = null;
        _events.add(TaskFailed(DownloadError.network,
            detail: 'launch/download channel error'));
      }
    } finally {
      // 不在此清 _activeHandle：终态（staged/paused/failed 事件）负责收账。
    }
  }

  @override
  Future<void> pause(TaskHandle handle) async {
    if (_activeHandle != handle) {
      return;
    }
    _cancelFlagSent = true; // Kotlin 协作中断后回 emit paused（终点由事件清账）
    try {
      await _ch.invokeMethod<dynamic>('pause');
    } finally {
      _cancelFlagSent = false; // 后续 paused 事件照常通过
    }
  }

  @override
  Future<void> resume(TaskHandle handle) async {
    throw UnimplementedError('resume 由 ExtractQueue 以原 plan 重提 download（--continue 续传）');
  }

  @override
  Future<void> cancel(TaskHandle handle) async {
    if (_activeHandle != handle) {
      return;
    }
    _cancelFlagSent = true; // cancel 后 Kotlin 不终态事件；清账在这里
    try {
      await _ch.invokeMethod<dynamic>('cancel');
    } finally {
      if (_activeHandle == handle) {
        _activeHandle = null;
        _cancelFlagSent = false;
      }
    }
  }
}
