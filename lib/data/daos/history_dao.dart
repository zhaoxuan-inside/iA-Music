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
  Future<void> record(int trackId, {required bool completed}) {
    return into(playHistory).insert(
      PlayHistoryCompanion.insert(trackId: trackId, completed: Value(completed)),
    );
  }

  Stream<List<HistoryItem>> watchRecent({int limit = 300}) {
    final q = select(playHistory).join([
      innerJoin(tracks, tracks.id.equalsExp(playHistory.trackId)),
    ])
      ..orderBy([OrderingTerm.desc(playHistory.playedAt)])
      ..limit(limit);
    return q.watch().map((rows) => rows.map((r) {
          final h = r.readTable(playHistory);
          final t = r.readTable(tracks);
          return HistoryItem(track: _toTrack(t), playedAt: h.playedAt, completed: h.completed);
        }).toList());
  }

  Future<void> clearAll() => delete(playHistory).go();

  Track _toTrack(TrackRow r) => Track(
        id: r.id,
        rootId: r.rootId,
        relPath: r.relPath,
        path: r.path,
        title: r.title,
        artist: r.artist,
        album: r.album,
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
  const HistoryItem({required this.track, required this.playedAt, required this.completed});

  final Track track;
  final DateTime playedAt;
  final bool completed;
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
