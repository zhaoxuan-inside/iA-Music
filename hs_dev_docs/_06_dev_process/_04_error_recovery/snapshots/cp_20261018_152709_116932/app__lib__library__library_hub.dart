/// LibraryHub —— 仓库管理/扫描/监听协调器（S2 纵切装配点；壳层与页面共用）。
///
/// 职责：
/// * `addRepositoryAndScan`：插根行（path 唯一，重复 → StateError）→
///   挂 Watcher（先挂防竞态：扫描期到达的事件排 `_dirty` 补扫）→
///   全量扫描（ScanProgress=实时计数流；ScanDone=终态）→ 返回终态报告。
/// * `events`：扫描事件广播（ScanProgress/ScanDone 含 watcher 增量报告副本）。
/// * `rescanNow`：显式再扫（REQ-LIB-05 锚「触发下一次扫描」）。
/// * `dispose`：停全部 watcher（持有真事件流，勿泄漏）。
library;

import 'dart:async';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/library_service.dart';
import 'package:ia_music/scan/root_watcher.dart';
import 'package:ia_music/scan/scan_service.dart';

final class LibraryHub {
  LibraryHub(this._db)
      : _scan = ScanService(db: _db),
        _lib = LibraryService(db: _db),
        _dao = DataAccess(_db).library {
    _events = StreamController.broadcast();
  }

  final IaDatabase _db;
  final ScanService _scan;
  final LibraryService _lib;
  final LibraryDao _dao;

  /// 数据门面直通（S3 播放域/设置清空等页面级消费；DAO 聚合一次性注入）。
  DataAccess get data => DataAccess(_db);

  /// 页面/壳层装配访问器（hub=组合根；持有 DAO 与域服务）。
  LibraryDao get dao => _dao;
  LibraryService get library => _lib;

  /// 页面快照取数（edit/remove/scan 后由 revisions 事件驱动重取）。
  Future<List<RepositoryRoot>> rootsSnapshot() => _dao.rootsSnapshot();
  Future<List<Track>> trackRowsSnapshot(LibSort sort) => _dao.liveTracksOnce(sort);

  late final StreamController<ScanEvent> _events;
  Stream<ScanEvent> get events => _events.stream;

  /// 页面刷新事件源（revision：任何库态变化自增）——ake watch 流替代形态，
  /// 实测 FakeAsync 下 drift watch 流与运行时副作用互相拖挂（scan 挂死已
  /// 实证）——页面一律「revision 事件 → Future 重取快照」消费数据。
  final StreamController<int> _revisions = StreamController.broadcast();
  int _revCounter = 0;
  Stream<int> get revisions => _revisions.stream;

  void _bump() {
    _revCounter++;
    if (!_revisions.isClosed) {
      _revisions.add(_revCounter);
    }
  }

  final Map<int, RootWatcher> _watchers = {};

  /// 添加仓库并全量扫描（REQ-LIB-01）。
  Future<ScanReport> addRepositoryAndScan(
    String path, {
    void Function(int processed, int admitted, int skipped)? onProgress,
  }) async {
    final existed = await (_db.select(_db.repositoryRoots)
          ..where((r) => r.path.equals(path)))
        .getSingleOrNull();
    if (existed != null) {
      throw StateError('repository already exists: $path');
    }
    final rootId = await _db.into(_db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(
            path: path,
            mode: RepositoryMode.directory,
            addedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    // watcher 先挂（扫描与其后变更的竞态统一由 RootWatcher._dirty 补扫）；
    // 增量报告也走同一事件流（REQ-LIB-02 入库即见）。
    final watcher = RootWatcher(
      db: _db,
      scanService: _scan,
      rootId: rootId,
      rootPath: path,
    );
    _watchers[rootId] = watcher;
    final watchSub = watcher.reports.listen((r) {
      if (!_events.isClosed) {
        _events.add(ScanDone(r)); // 增量终态与全量终态同流
      }
      _bump();
    });
    await watcher.start();
    try {
      return await _runFullScan(rootId, onProgress: onProgress);
    } finally {
      await watchSub.cancel();
    }
  }

  /// 显式全量再扫（REQ-LIB-05「触发下一次扫描」锚位）。
  Future<ScanReport> rescanNow({required int rootId, ScanMode mode = ScanMode.full}) async {
    return _runFullScan(rootId);
  }

  /// 编辑标题（页面入口：域服务 + revision 递增）。
  Future<void> editTrackTitle(int trackId, String newTitle, {required int nowMs}) async {
    await _lib.editTrackTitle(trackId, newTitle, nowMs: nowMs);
    _bump();
  }

  /// 移除（页面入口：域服务 + revision 递增）。
  Future<void> removeTrack(int trackId, {required int nowMs}) async {
    await _lib.removeTrack(trackId, nowMs: nowMs);
    _bump();
  }

  /// 全量扫描事件桥：进度回调 + 事件广播 + revision 递增（终态返回）。
  Future<ScanReport> _runFullScan(
    int rootId, {
    void Function(int processed, int admitted, int skipped)? onProgress,
  }) async {
    final events = await _scan.scan(rootId: rootId).toList();
    final done = events.whereType<ScanDone>().last;
    for (final e in events) {
      if (!_events.isClosed) {
        _events.add(e);
      }
      _bump(); // 扫描实时计数/终态 → 页面快照重取
      if (e is ScanProgress && onProgress != null) {
        onProgress(e.processed, e.admitted, e.skipped);
      }
    }
    return done.report;
  }

  Future<void> dispose() async {
    for (final w in _watchers.values) {
      await w.stop();
    }
    _watchers.clear();
    await _events.close();
    await _revisions.close();
  }
}
