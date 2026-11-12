/// 扫描域 UI 状态：加根/移除/重扫 + 进度。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'providers.dart';

class ScanState {
  const ScanState({
    this.scanning = false,
    this.done = 0,
    this.total = 0,
    this.lastSummary = '',
  });

  final bool scanning;
  final int done;
  final int total;
  final String lastSummary;

  ScanState copyWith({
    bool? scanning,
    int? done,
    int? total,
    String? lastSummary,
  }) =>
      ScanState(
        scanning: scanning ?? this.scanning,
        done: done ?? this.done,
        total: total ?? this.total,
        lastSummary: lastSummary ?? this.lastSummary,
      );
}

class ScanController extends Notifier<ScanState> {
  @override
  ScanState build() {
    // 挂根目录监听（一次性；根集合变化由调用方 sync）
    unawaited(_attachWatcher());
    return const ScanState();
  }

  Future<void> _attachWatcher() async {
    try {
      await ref.read(rootWatcherProvider).sync();
    } on Object {
      // watcher 不可用不阻断
    }
  }

  /// Android 预置目录集合（授权后可用）。
  Future<List<String>> androidPresetFolders() async {
    const presets = [
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
    ];
    return [for (final p in presets) if (Directory(p).existsSync()) p];
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
      return 'exists';
    }
    final id = await db.libraryDao.addRoot(normalized);
    unawaited(_scanOne(id, normalized));
    await ref.read(rootWatcherProvider).sync();
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
      );
    } on Object {
      state = state.copyWith(scanning: false);
    } finally {
      scan.onProgress = prev;
    }
  }

  Future<void> _scanOne(int rootId, String path) async {
    if (state.scanning) {
      return; // 大扫进行中：增量件等下轮
    }
    final scan = ref.read(scanServiceProvider);
    try {
      await scan.scanRoot(rootId, path);
    } on Object {
      // 单根失败不冒泡
    }
  }
}

final scanProvider = NotifierProvider<ScanController, ScanState>(ScanController.new);
