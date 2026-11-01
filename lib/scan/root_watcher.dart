/// RootWatcher —— 根目录**真事件**监听（REQ-LIB-02：新文件 ≤15s 入库）。///
/// 链路：Directory.watch（真事件）→ **全事件脏信号**（不过滤扩展名！）→ 防抖
/// → **增量扫描（ScanMode.incremental）** → 报告流出。
///
/// 纪律（实测教训——probe3 实证）：
/// * dart:io `File.copy`（Windows）先写随机临时名再改名落位——最终名的
///   create 事件**不可达**；文件管理器另有 rename 进位路径。故事件只作
///   **脏信号**不做内容源：新文件的发现一律由增量枚举 diff（盘 vs 库）承担。
/// * 扫描期到达的信号 → `_dirty` 排队，扫描完成后补一轮（不丢变更）。
/// * 扫描本体由 ScanService 自行 isolate 化（§3.1 不占 UI isolate）——无替身。
/// * stop() 后事件丢弃、报告流关闭。
library;

import 'dart:async';
import 'dart:io';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/scan/scan_service.dart';
final class RootWatcher {
  RootWatcher({
    required IaDatabase db,
    required this.scanService,
    required this.rootId,
    required this.rootPath,
    this.debounceMs = 1500,
  }) : _dao = DataAccess(db).library;

  final ScanService scanService;
  final int rootId;

  /// 监听源（真路径；与库内根行互校）。
  final String rootPath;
  final int debounceMs;

  final LibraryDao _dao;

  final StreamController<ScanReport> _reports = StreamController.broadcast();
  StreamSubscription<FileSystemEvent>? _sub;
  Timer? _timer;
  bool _scanning = false;
  bool _dirty = false;

  /// 每轮增量扫描的终态报告（REQ-LIB-02 语义锚）。
  Stream<ScanReport> get reports => _reports.stream;

  Future<void> start() async {
    // 根路径以库行校验（真路径；构造参数仅作监听源）
    final root = await _dao.rootById(rootId);
    if (root == null) {
      throw StateError('watch root not found: $rootId');
    }
    final dir = Directory(rootPath);
    // 全事件=脏信号（不过滤扩展名——File.copy 改名落位的最终名无 create 事件，
    // 且目录删除/改名也需触发 diff；新文件发现交给增量枚举）
    _sub = dir.watch(recursive: true).listen(_onEvent,
        onError: (Object e) {/* 监听器异常=下轮防抖自愈；不中断 */});
  }

  void _onEvent(FileSystemEvent _) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: debounceMs), () {
      unawaited(_drain());
    });
  }

  Future<void> _drain() async {
    if (_scanning) {
      _dirty = true; // 扫描期到达的事件：完成后补扫
      return;
    }
    _scanning = true;
    try {
      do {
        _dirty = false;
        final events = await scanService
            .scan(rootId: rootId, mode: ScanMode.incremental)
            .toList();
        final last = events.whereType<ScanDone>().last;
        if (!_reports.isClosed) {
          _reports.add(last.report);
        }
      } while (_dirty);
    } finally {
      _scanning = false;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    await _sub?.cancel();
    await _reports.close();
  }
}
