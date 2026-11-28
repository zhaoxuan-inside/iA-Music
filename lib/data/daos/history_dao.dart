/// 播放历史与歌词元数据 DAO（小域，各一个类）。
library;

import 'package:drift/drift.dart';

import '../../domain/entities/track.dart';
import '../database.dart';
import '../tables.dart';

part 'history_dao.g.dart';

@DriftAccessor(tables: [PlayHistory, Tracks])
class HistoryDao extends DatabaseAccessor<IaDatabase> with _$HistoryDaoMixin {
  HistoryDao(super.db);

  /// 记录一次播放（completed=完整听完的诚实位；同曲短时间内去重交给 service）。
  ///
  /// 同事务内物化递增 tracks.plays——常听统计 O(1) 直读，
  /// 不再每次播放对 play_history 全表 GROUP BY。
  Future<void> record(int trackId, {required bool completed}) {
    return transaction(() async {
      await into(playHistory).insert(
        PlayHistoryCompanion.insert(trackId: trackId, completed: Value(completed)),
      );
      await customStatement(
        'UPDATE tracks SET plays = plays + 1 WHERE id = ?',
        [trackId],
      );
    });
  }

  /// 历史修剪：只保留最近 [keep] 条（启动时调用一次，限制表无限增长；
  /// 播放次数已在 tracks.plays 物化，修剪不影响常听统计）。
  Future<void> prune({int keep = 2000}) {
    return customStatement(
      'DELETE FROM play_history WHERE id NOT IN '
      '(SELECT id FROM play_history ORDER BY played_at DESC LIMIT ?)',
      [keep],
    );
  }

  /// 历史一次性取用（听法取材只读一次，不开常驻 watch 流）。
  Future<List<HistoryItem>> recent({int limit = 300}) async {
    final rows = await _recentQuery(limit).get();
    return rows.map(_itemOf).toList();
  }

  Stream<List<HistoryItem>> watchRecent({int limit = 300}) {
    return _recentQuery(limit).watch().map((rows) => rows.map(_itemOf).toList());
  }

  HistoryItem _itemOf(TypedResult r) {
    final h = r.readTable(playHistory);
    final t = r.readTable(tracks);
    return HistoryItem(
      track: _toTrack(t),
      playedAt: h.playedAt,
      completed: h.completed,
      plays: t.plays,
    );
  }

  JoinedSelectStatement _recentQuery(int limit) {
    return select(playHistory).join([
      innerJoin(tracks, tracks.id.equalsExp(playHistory.trackId)),
    ])
      ..orderBy([OrderingTerm.desc(playHistory.playedAt)])
      ..limit(limit);
  }

  Track _toTrack(TrackRow r) => Track(
        id: r.id,
        rootId: r.rootId,
        relPath: r.relPath,
        path: r.path,
        title: r.title,
        artist: r.artist,
        album: r.album,
        genre: r.genre,
        durationMs: r.durationMs,
        sizeBytes: r.sizeBytes,
        contentHash: r.contentHash,
        audioFormat: r.audioFormat,
        trackNo: r.trackNo,
        coverPath: r.coverPath,
        addedAt: r.addedAt,
        missing: r.missingAt != null,
      );
}

/// 历史条目（含曲目）。
class HistoryItem {
  const HistoryItem({
    required this.track,
    required this.playedAt,
    required this.completed,
    required this.plays,
  });

  final Track track;
  final DateTime playedAt;
  final bool completed;

  /// 曲目累计播放次数（tracks.plays 物化列，join 行直读零额外查询）——
  /// 常听/历史磁贴翻面的展示口径与常听排序一致。
  final int plays;
}

@DriftAccessor(tables: [LyricsMeta])
class LyricsDao extends DatabaseAccessor<IaDatabase> with _$LyricsDaoMixin {
  LyricsDao(super.db);

  Future<LyricsMetaRow?> metaOf(int trackId) {
    return (select(lyricsMeta)..where((m) => m.trackId.equals(trackId))).getSingleOrNull();
  }

  Future<void> upsert(int trackId, LyricsMetaCompanion entry) {
    return into(lyricsMeta).insertOnConflictUpdate(
      entry.copyWith(trackId: Value(trackId)),
    );
  }
}
