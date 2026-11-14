/// 歌单域 DAO：CRUD + 喜欢（system 歌单）+ 去重拦截。
library;

import 'package:drift/drift.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../database.dart';
import '../tables.dart';

part 'playlist_dao.g.dart';

@DriftAccessor(tables: [Playlists, PlaylistTracks, Tracks])
class PlaylistDao extends DatabaseAccessor<IaDatabase> with _$PlaylistDaoMixin {
  PlaylistDao(super.db);

  static const String favoritesName = '我喜欢的音乐';

  // ── 歌单面 ──────────────────────────────────────────────────────────

  Stream<List<Playlist>> watchPlaylists() {
    return select(playlists).watch().asyncMap((rows) async {
      final cnt = playlistTracks.id.count();
      final countQuery = selectOnly(playlistTracks)
        ..addColumns([playlistTracks.playlistId, cnt])
        ..groupBy([playlistTracks.playlistId]);
      final counts = <int, int>{};
      for (final row in await countQuery.get()) {
        final pid = row.read(playlistTracks.playlistId);
        if (pid != null) {
          counts[pid] = row.read(cnt) ?? 0;
        }
      }
      return rows
          .map((r) => Playlist(
                id: r.id,
                name: r.name,
                kind: r.kind == PlaylistKindCol.favorites
                    ? PlaylistKind.favorites
                    : PlaylistKind.user,
                trackCount: counts[r.id] ?? 0,
                createdAt: r.createdAt,
                pendingCount: r.pending,
              ))
          .toList()
        ..sort((a, b) {
          if (a.isSystem != b.isSystem) {
            return a.isSystem ? -1 : 1;
          }
          return a.createdAt.compareTo(b.createdAt);
        });
    });
  }

  Future<int> createPlaylist(String name) async {
    final dup = await (select(playlists)
          ..where((p) => p.name.equals(name) & p.kind.equals(PlaylistKindCol.user.name)))
        .getSingleOrNull();
    if (dup != null) {
      return dup.id;
    }
    return into(playlists).insert(PlaylistsCompanion.insert(
      name: name,
      kind: PlaylistKindCol.user,
    ));
  }

  Future<void> renamePlaylist(int id, String name) {
    return (update(playlists)..where((p) => p.id.equals(id)))
        .write(PlaylistsCompanion(name: Value(name)));
  }

  Future<void> deletePlaylist(int id) {
    return transaction(() async {
      await (delete(playlistTracks)..where((pt) => pt.playlistId.equals(id))).go();
      await (delete(playlists)..where((p) => p.id.equals(id))).go();
    });
  }

  // ── 条目面 ──────────────────────────────────────────────────────────

  Stream<List<Track>> watchPlaylistTracks(int playlistId) {
    final q = select(playlistTracks).join([
      innerJoin(tracks, tracks.id.equalsExp(playlistTracks.trackId)),
    ])
      ..where(playlistTracks.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(playlistTracks.position)]);
    return q.watch().map((rows) => rows.map((r) {
          final t = r.readTable(tracks);
          return _rowToTrack(t);
        }).toList());
  }

  /// 追加；歌单内重复静默忽略（DB 级 UNIQUE 兜底）。返回是否真的加入。
  Future<bool> addTrack(int playlistId, int trackId) async {
    final maxPos = await (select(playlistTracks)
          ..where((pt) => pt.playlistId.equals(playlistId)))
        .get()
        .then((rows) => rows.isEmpty ? 0 : rows.map((r) => r.position).reduce((a, b) => a > b ? a : b));
    try {
      await into(playlistTracks).insert(PlaylistTracksCompanion.insert(
        playlistId: playlistId,
        trackId: trackId,
        position: maxPos + 1,
      ));
      return true;
    } on Object {
      return false; // UNIQUE(playlist, track) 冲突 = 已存在
    }
  }

  Future<void> removeTrack(int playlistId, int trackId) {
    return (delete(playlistTracks)
          ..where((pt) => pt.playlistId.equals(playlistId) & pt.trackId.equals(trackId)))
        .go();
  }

  // ── 喜欢（system_favorite 歌单是唯一事实源） ─────────────────────────

  /// 喜欢电台取材：收藏夹曲目快照（非流；按当前位置序）。
  Future<List<Track>> favoritesTracks() async {
    final id = await ensureFavorites();
    return watchPlaylistTracks(id).first;
  }

  Future<int> ensureFavorites() async {
    final row = await (select(playlists)
          ..where((p) => p.kind.equals(PlaylistKindCol.favorites.name)))
        .getSingleOrNull();
    if (row != null) {
      return row.id;
    }
    return into(playlists).insert(PlaylistsCompanion.insert(
      name: favoritesName,
      kind: PlaylistKindCol.favorites,
    ));
  }

  Stream<bool> watchFavorite(int trackId) {
    return watchPlaylistIdsOfTrack(trackId).map((ids) => ids.isNotEmpty);
  }

  Future<bool> isFavorite(int trackId) async {
    final favId = await _favoritesId();
    if (favId == null) {
      return false;
    }
    final row = await (select(playlistTracks)
          ..where((pt) => pt.playlistId.equals(favId) & pt.trackId.equals(trackId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> setFavorite(int trackId, bool fav) async {
    final favId = await ensureFavorites();
    if (fav) {
      await addTrack(favId, trackId);
    } else {
      await removeTrack(favId, trackId);
    }
  }

  Future<int?> _favoritesId() async {
    final row = await (select(playlists)
          ..where((p) => p.kind.equals(PlaylistKindCol.favorites.name)))
        .getSingleOrNull();
    return row?.id;
  }

  Stream<List<int>> watchPlaylistIdsOfTrack(int trackId) {
    final q = selectOnly(playlistTracks)
      ..addColumns([playlistTracks.playlistId])
      ..where(playlistTracks.trackId.equals(trackId));
    return q.watch().map(
          (rows) => rows.map((r) => r.read(playlistTracks.playlistId)!).toList(),
        );
  }

  Track _rowToTrack(TrackRow r) => Track(
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
