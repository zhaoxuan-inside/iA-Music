/// 曲库域 DAO：查询/排序/搜索/扫描写入原语。业务裁决不在这里。
library;

import 'package:drift/drift.dart';

import '../../domain/entities/track.dart';
import '../database.dart';
import '../pinyin_text.dart';
import '../tables.dart';

part 'library_dao.g.dart';

@DriftAccessor(tables: [RepositoryRoots, Tracks])
class LibraryDao extends DatabaseAccessor<IaDatabase> with _$LibraryDaoMixin {
  LibraryDao(super.db);

  Track _map(TrackRow r) => Track(
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

  // ── 查询面 ──────────────────────────────────────────────────────────

  Stream<List<Track>> watchTracks({TrackSort sort = TrackSort.recentAdded}) {
    final q = select(tracks);
    switch (sort) {
      case TrackSort.title:
        q.orderBy([(u) => OrderingTerm.asc(u.titleNorm)]);
      case TrackSort.artist:
        q.orderBy([(u) => OrderingTerm.asc(u.artistNorm), (u) => OrderingTerm.asc(u.titleNorm)]);
      case TrackSort.album:
        q.orderBy([
          (u) => OrderingTerm.asc(u.albumNorm),
          (u) => OrderingTerm.asc(u.trackNo),
          (u) => OrderingTerm.asc(u.titleNorm),
        ]);
      case TrackSort.recentAdded:
        q.orderBy([(u) => OrderingTerm.desc(u.addedAt)]);
    }
    return q.watch().map((rows) => rows.map(_map).toList());
  }

  Stream<List<Track>> watchTracksByIds(List<int> ids) {
    if (ids.isEmpty) {
      return Stream.value(const <Track>[]);
    }
    return (select(tracks)..where((t) => t.id.isIn(ids))).watch().map(
          (rows) => rows.map(_map).toList(),
        );
  }

  Future<Track?> trackById(int id) async {
    final row = await (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  Future<List<Track>> tracksByIds(List<int> ids) async {
    if (ids.isEmpty) {
      return const <Track>[];
    }
    final rows = await (select(tracks)..where((t) => t.id.isIn(ids))).get();
    return rows.map(_map).toList();
  }

  /// 会话恢复用：按绝对路径批量取曲目（保序）。
  Future<List<Track>> tracksByPaths(List<String> paths) async {
    if (paths.isEmpty) {
      return const <Track>[];
    }
    final rows = await (select(tracks)..where((t) => t.path.isIn(paths))).get();
    final byPath = {for (final r in rows) r.path: _map(r)};
    return [for (final p in paths) if (byPath[p] != null) byPath[p]!];
  }

  /// 全库可用曲目（非缺失），供随机/全部播放取材。
  Future<List<Track>> availableTracks() async {
    final rows = await (select(tracks)..where((t) => t.missingAt.isNull())).get();
    return rows.map(_map).toList();
  }

  Stream<int> watchAvailableCount() {
    final count = tracks.id.count();
    final q = selectOnly(tracks)..addColumns([count])..where(tracks.missingAt.isNull());
    return q.watchSingle().map((r) => r.read(count) ?? 0);
  }

  // ── 聚合面 ──────────────────────────────────────────────────────────

  Stream<List<AlbumGroup>> watchAlbums() {
    final album = tracks.album;
    final artist = tracks.artist;
    final albumNorm = tracks.albumNorm;
    final cnt = tracks.id.count();
    final dur = tracks.durationMs.sum();
    final q = selectOnly(tracks)
      ..addColumns([album, artist, albumNorm, cnt, dur])
      ..where(tracks.missingAt.isNull())
      ..groupBy([albumNorm])
      ..orderBy([OrderingTerm.asc(albumNorm)]);
    return q.watch().map(
          (rows) => rows
              .map((r) => AlbumGroup(
                    album: r.read(album) ?? '',
                    artist: r.read(artist) ?? '',
                    trackCount: r.read(cnt) ?? 0,
                    totalDurationMs: r.read(dur) ?? 0,
                  ))
              .toList(),
        );
  }

  Stream<List<Track>> watchAlbumTracks(String albumNorm) {
    return (select(tracks)
          ..where((t) => t.albumNorm.equals(albumNorm) & t.missingAt.isNull())
          ..orderBy([
            (u) => OrderingTerm.asc(u.trackNo),
            (u) => OrderingTerm.asc(u.titleNorm),
          ]))
        .watch()
        .map((rows) => rows.map(_map).toList());
  }

  Stream<List<ArtistGroup>> watchArtists() {
    final artist = tracks.artist;
    final artistNorm = tracks.artistNorm;
    final cnt = tracks.id.count();
    final q = selectOnly(tracks)
      ..addColumns([artist, artistNorm, cnt])
      ..where(tracks.missingAt.isNull())
      ..groupBy([artistNorm])
      ..orderBy([OrderingTerm.asc(artistNorm)]);
    return q.watch().map(
          (rows) => rows
              .map((r) => ArtistGroup(
                    artist: r.read(artist) ?? '',
                    trackCount: r.read(cnt) ?? 0,
                  ))
              .toList(),
        );
  }

  Stream<List<Track>> watchArtistTracks(String artistNorm) {
    return (select(tracks)
          ..where((t) => t.artistNorm.equals(artistNorm) & t.missingAt.isNull())
          ..orderBy([
            (u) => OrderingTerm.asc(u.albumNorm),
            (u) => OrderingTerm.asc(u.trackNo),
          ]))
        .watch()
        .map((rows) => rows.map(_map).toList());
  }

  // ── 搜索面（FTS 五列前缀 AND；rank 排序） ────────────────────────────

  Stream<List<Track>> watchSearchResults(String query) {
    final match = buildFtsMatch(query);
    if (match.isEmpty) {
      return Stream.value(const <Track>[]);
    }
    return customSelect(
      'SELECT t.id AS t_id, t.root_id, t.rel_path, t.path, t.title, t.artist, '
      't.album, t.duration_ms, t.size_bytes, t.content_hash, t.audio_format, '
      't.track_no, t.cover_path, t.added_at, t.missing_at '
      'FROM track_index f JOIN tracks t ON t.id = f.track_id '
      'WHERE track_index MATCH ? AND t.missing_at IS NULL '
      'ORDER BY rank LIMIT 200',
      variables: [Variable(match)],
      readsFrom: {tracks},
    ).watch().map((rows) {
      return rows
          .map((r) => Track(
                id: r.read<int>('t_id'),
                rootId: r.read<int>('root_id'),
                relPath: r.read<String>('rel_path'),
                path: r.read<String>('path'),
                title: r.read<String>('title'),
                artist: r.read<String>('artist'),
                album: r.read<String>('album'),
                durationMs: r.read<int>('duration_ms'),
                sizeBytes: r.read<int>('size_bytes'),
                contentHash: r.read<String>('content_hash'),
                audioFormat: r.read<String>('audio_format'),
                trackNo: r.read<int>('track_no'),
                coverPath: r.readNullable<String>('cover_path'),
                addedAt: r.read<DateTime>('added_at'),
                missing: r.readNullable<DateTime>('missing_at') != null,
              ))
          .toList();
    });
  }

  // ── 扫描写入原语 ────────────────────────────────────────────────────

  Stream<List<RepositoryRoot>> watchRoots() => select(repositoryRoots).watch();

  Future<List<RepositoryRoot>> allRoots() => select(repositoryRoots).get();

  Future<int> addRoot(String path) =>
      into(repositoryRoots).insert(RepositoryRootsCompanion.insert(path: path));

  Future<void> removeRoot(int rootId) {
    return transaction(() async {
      final ids = await (select(tracks)..where((t) => t.rootId.equals(rootId)))
          .map((r) => r.id)
          .get();
      for (final id in ids) {
        await _deleteFts(id);
      }
      await (delete(tracks)..where((t) => t.rootId.equals(rootId))).go();
      await (delete(repositoryRoots)..where((r) => r.id.equals(rootId))).go();
    });
  }

  /// 某根目录下已入库的 (relPath, sizeBytes, hash, missingAt, id) 供 diff。
  Future<List<ScannedExisting>> existingForRoot(int rootId) async {
    final rows = await (select(tracks)..where((t) => t.rootId.equals(rootId))).get();
    return rows
        .map((r) => ScannedExisting(
              id: r.id,
              relPath: r.relPath,
              sizeBytes: r.sizeBytes,
              contentHash: r.contentHash,
              missing: r.missingAt != null,
            ))
        .toList();
  }

  /// 批量落库（≤200 一事务）：tracks upsert + FTS 同事务增删。
  Future<void> upsertScannedBatch(List<TrackUpsert> batch) {
    return transaction(() async {
      for (final u in batch) {
        final companion = TracksCompanion.insert(
          rootId: u.rootId,
          relPath: u.relPath,
          path: u.path,
          title: u.title,
          titleNorm: normKey(u.title),
          artist: u.artist,
          artistNorm: normKey(u.artist),
          album: u.album,
          albumNorm: normKey(u.album),
          trackNo: Value(u.trackNo),
          durationMs: Value(u.durationMs),
          sizeBytes: Value(u.sizeBytes),
          contentHash: Value(u.contentHash),
          audioFormat: Value(u.audioFormat),
        );
        final id = await into(tracks).insert(
          companion,
          onConflict: DoUpdate((_) => companion, target: [tracks.path]),
        );
        await _deleteFts(id);
        // 拼音列按字段分别生成（粘连 token 不得跨字段，否则歌手整串前缀无法命中）
        final py = [
          pinyinFull(u.title),
          pinyinFull(u.artist),
          pinyinFull(u.album),
        ].where((s) => s.isNotEmpty).join(' ');
        final pyHead = [
          pinyinInitials(u.title),
          pinyinInitials(u.artist),
          pinyinInitials(u.album),
        ].where((s) => s.isNotEmpty).join(' ');
        await customInsert(
          'INSERT INTO track_index(track_id, title, artist, album, pinyin_full, pinyin_initials) '
          'VALUES(?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withInt(id),
            Variable.withString(ftsText(u.title)),
            Variable.withString(ftsText(u.artist)),
            Variable.withString(ftsText(u.album)),
            Variable.withString(py),
            Variable.withString(pyHead),
          ],
        );
      }
    });
  }

  /// 标记缺失（诚实灰显；不删除行）。
  Future<void> markMissing(List<int> ids) {
    if (ids.isEmpty) {
      return Future.value();
    }
    return (update(tracks)..where((t) => t.id.isIn(ids) & t.missingAt.isNull()))
        .write(TracksCompanion(missingAt: Value(DateTime.now())));
  }

  /// 复活（文件回来了）。
  Future<void> revive(List<int> ids) {
    if (ids.isEmpty) {
      return Future.value();
    }
    return (update(tracks)..where((t) => t.id.isIn(ids)))
        .write(const TracksCompanion(missingAt: Value(null)));
  }

  Future<void> updateCover(int trackId, String? coverPath) {
    return (update(tracks)..where((t) => t.id.equals(trackId))).write(
      TracksCompanion(coverPath: Value(coverPath), coverCheckedAt: Value(DateTime.now())),
    );
  }

  Future<void> _deleteFts(int trackId) => customUpdate(
        'DELETE FROM track_index WHERE track_id = ?',
        variables: [Variable.withInt(trackId)],
      );
}

/// 扫描 diff 用的已入库行快照。
class ScannedExisting {
  const ScannedExisting({
    required this.id,
    required this.relPath,
    required this.sizeBytes,
    required this.contentHash,
    required this.missing,
  });

  final int id;
  final String relPath;
  final int sizeBytes;
  final String contentHash;
  final bool missing;
}

/// 扫描批写入载荷（service 组装，DAO 只落库）。
class TrackUpsert {
  const TrackUpsert({
    required this.rootId,
    required this.relPath,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.trackNo,
    required this.durationMs,
    required this.sizeBytes,
    required this.contentHash,
    required this.audioFormat,
  });

  final int rootId;
  final String relPath;
  final String path;
  final String title;
  final String artist;
  final String album;
  final int trackNo;
  final int durationMs;
  final int sizeBytes;
  final String contentHash;
  final String audioFormat;
}
