/// 扫描域 UI 状态：加根/移除/重扫 + 进度。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/config/collect_config.dart';
import 'diagnostics.dart';
import 'enrich_controller.dart';
import 'providers.dart';

class ScanState {
  const ScanState({
    this.scanning = false,
    this.done = 0,
    this.total = 0,
    this.lastSummary = '',
    this.lastError,
  });

  final bool scanning;
  final int done;
  final int total;
  final String lastSummary;

  /// 最近一次扫描失败的真实原因（成功时置 null）。
  final String? lastError;

  ScanState copyWith({
    bool? scanning,
    int? done,
    int? total,
    String? lastSummary,
    Object? lastError = _unset,
  }) =>
      ScanState(
        scanning: scanning ?? this.scanning,
        done: done ?? this.done,
        total: total ?? this.total,
        lastSummary: lastSummary ?? this.lastSummary,
        lastError: lastError == _unset ? this.lastError : lastError as String?,
      );
}

/// copyWith 哨兵：区分「不改 lastError」与「清空 lastError」。
const Object _unset = Object();

class ScanController extends Notifier<ScanState> {
  @override
  ScanState build() {
    // 挂根目录监听（一次性；根集合变化由调用方 sync）
    unawaited(_attachWatcher());
    return const ScanState();
  }

  Future<void> _attachWatcher() async {
    try {
      await _syncWatcher();
    } on Object {
      // watcher 不可用不阻断
    }
  }

  /// 根目录监听重挂（失败不阻断主流程；异常仅记录）。
  Future<void> _syncWatcher() async {
    try {
      await ref.read(rootWatcherProvider).sync();
    } on Object {
      // watch 不可用（平台/挂载点限制）
    }
  }

  /// Android 预置目录集合（授权后可用；预置列表在配置层）。
  Future<List<String>> androidPresetFolders() async {
    return [for (final p in kPresetMusicDirs) if (Directory(p).existsSync()) p];
  }

  /// 请求音频读取权限（Android）。
  Future<bool> ensureAudioPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    var status = await Permission.audio.status;
    if (!status.isGranted) {
      status = await Permission.audio.request();
    }
    if (status.isGranted) {
      return true;
    }
    final legacy = await Permission.storage.request();
    return legacy.isGranted;
  }

  Future<String> addRoot(String path) async {
    final db = ref.read(dbProvider);
    final normalized = path.endsWith(Platform.pathSeparator)
        ? path.substring(0, path.length - 1)
        : path;
    final existing = await db.libraryDao.allRoots();
    if (existing.any((r) => r.path == normalized)) {
      // 已存在：立即重扫一次，保证「交互式更改」即点即生效
      final r0 = existing.firstWhere((r) => r.path == normalized);
      await _scanOne(r0.id, normalized);
      await _syncWatcher();
      return 'exists';
    }
    final id = await db.libraryDao.addRoot(normalized);
    await _scanOne(id, normalized);
    await _syncWatcher();
    return 'ok';
  }

  Future<void> removeRoot(int rootId) async {
    await ref.read(dbProvider).libraryDao.removeRoot(rootId);
    await ref.read(rootWatcherProvider).sync();
  }

  Future<void> rescanAll() => _scanAll();

  Future<void> _scanAll() async {
    if (state.scanning) {
      return;
    }
    state = state.copyWith(scanning: true, done: 0, total: 0);
    final scan = ref.read(scanServiceProvider);
    final prev = scan.onProgress;
    scan.onProgress = (p) {
      state = state.copyWith(done: p.done, total: p.total);
    };
    try {
      final summary = await scan.scanAll();
      state = state.copyWith(
        scanning: false,
        lastSummary: 'ins=${summary.inserted} upd=${summary.updated} '
            'miss=${summary.missing} rev=${summary.revived}',
        lastError: null,
      );
      // 扫完即补全：元数据缺失件自动入补全队列（补全进度见收集页）
      unawaited(ref.read(enrichProvider.notifier).runOnce());
    } on Object catch (e, st) {
      // 不吞：真实原因入状态 + 诊断持久化（常驻「存储」页可读）
      state = state.copyWith(
          scanning: false, lastSummary: '扫描失败', lastError: '$e');
      unawaited(
          ref.read(diagnosticsProvider.notifier).record('扫描', e, st));
    } finally {
      scan.onProgress = prev;
    }
  }

  Future<void> _scanOne(int rootId, String path) async {
    if (state.scanning) {
      return; // 大扫进行中：增量件等下轮
    }
    state = state.copyWith(scanning: true, done: 0, total: 0);
    final scan = ref.read(scanServiceProvider);
    final prev = scan.onProgress;
    scan.onProgress = (p) {
      state = state.copyWith(done: p.done, total: p.total);
    };
    try {
      final summary = await scan.scanRoot(rootId, path);
      state = state.copyWith(
        scanning: false,
        lastSummary: 'ins=${summary.inserted} upd=${summary.updated} '
            'miss=${summary.missing} rev=${summary.revived}',
        lastError: null,
      );
      // 扫完即补全：元数据缺失件自动入补全队列
      unawaited(ref.read(enrichProvider.notifier).runOnce());
    } on Object catch (e, st) {
      // 不吞：真实原因入状态 + 诊断持久化（常驻「存储」页可读）
      state = state.copyWith(
          scanning: false, lastSummary: '扫描失败', lastError: '$e');
      unawaited(
          ref.read(diagnosticsProvider.notifier).record('扫描', e, st));
    } finally {
      scan.onProgress = prev;
    }
  }
}

final scanProvider = NotifierProvider<ScanController, ScanState>(ScanController.new);
