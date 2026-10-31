/// LibraryService —— 曲库域业务（DoD3/DoD4 锚）。
///
/// 红线：
/// * **编辑不写原文件**（REQ-LIB-03）：rename 只动库行 + FTS 同事务
///   （`LibraryDao.reconcileTrackMeta`）；原文件字节/mtime/size/hash 纹丝不动。
/// * **移除=软删**（REQ-LIB-07）：`deleted_at` 置位 → 列表/随机池/搜索不可见；
///   物理文件保留（删除仅解除记录，永不触盘）。
library;

import 'dart:io';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';

final class LibraryService {
  LibraryService({required IaDatabase db})
      : _dao = DataAccess(db).library,
        _db = db;

  final LibraryDao _dao;
  final IaDatabase _db;
  DataAccess get _access => DataAccess(_db);

  /// 编辑标题（DoD3）。即时生效=库行即真相（列表流消费库行）。
  Future<void> editTrackTitle(
    int trackId,
    String newTitle, {
    required int nowMs,
  }) async {
    final row = await _dao.rowById(trackId);
    if (row == null) {
      throw StateError('track not found: $trackId');
    }
    await _dao.reconcileTrackMeta(
      trackId,
      title: newTitle,
      artist: row.artistDisplay,
      album: row.albumDisplay,
      durationMs: row.durationMs,
      nowMs: nowMs,
    );
  }

  /// 移除（DoD4 前半：记录消失 + 文件保留）。
  /// WS6：软删前登记墓碑（REQ-SYNC-05 跨端删除传播；远端文件永不删除）。
  Future<void> removeTrack(int trackId, {required int nowMs}) async {
    await _access.sync.recordTombstone(
      TombstoneKind.track,
      localId: trackId,
      deletedByDevice: 'ia-${Platform.operatingSystem}',
      nowMs: nowMs,
    );
    await _dao.softDeleteTrack(trackId, nowMs);
  }
}
