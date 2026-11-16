/// 听法与聚合 providers：流派 / 常听 / 历史 / 分类取材。
///
/// 三分离红线：这里只有真实数据库查询的组合，没有任何预置内容。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/entities/track.dart';
import 'library_providers.dart';
import 'providers.dart';

/// 听法取材与浏览查询的真实数据门面（UI 只调方法，不触库）。
class ListenLibrary {
  ListenLibrary(this._db, this._playlistDao);

  final IaDatabase _db;
  final PlaylistDao _playlistDao;

  /// 随缘听歌取材：全库可用曲目。
  Future<List<Track>> all() => _db.libraryDao.availableTracks();

  /// 喜欢电台取材：收藏夹曲目快照。
  Future<List<Track>> favorites() => _playlistDao.favoritesTracks();

  /// 常听电台取材：常听专辑（PlayHistory 次数 Top6）的曲目并集。
  Future<List<Track>> top() async {
    final albums = await _db.libraryDao.watchTopAlbums(limit: 6).first;
    final out = <Track>[];
    for (final al in albums) {
      out.addAll(await _db.libraryDao.watchAlbumTracks(albumKey(al.album)).first);
    }
    return out;
  }

  /// 最近添加取材：按 addedAt 倒序的全部曲目。
  Future<List<Track>> recent() =>
      _db.libraryDao.watchTracks(sort: TrackSort.recentAdded).first;

  /// 历史回放取材：去重后的历史曲目序列（最新在前，不打乱）。
  Future<List<Track>> history() async {
    final items = await _db.historyDao.watchRecent(limit: 100).first;
    final seen = <int>{};
    return [for (final h in items) if (seen.add(h.track.id)) h.track];
  }
}

final listenLibraryProvider = Provider<ListenLibrary>(
    (ref) => ListenLibrary(ref.watch(dbProvider), ref.watch(dbProvider).playlistDao));

/// 流派列表（真实标签聚合；无流派数据即为空列表 → UI 隐藏入口）。
final genresProvider = StreamProvider<List<GenreGroup>>(
    (ref) => ref.watch(dbProvider).libraryDao.watchGenres());

/// 某流派的专辑聚合。
final genreAlbumsProvider = StreamProvider.family<List<AlbumGroup>, String>(
    (ref, genre) => ref.watch(dbProvider).libraryDao.watchGenreAlbums(genre));

/// 常听专辑（PlayHistory 播放次数聚合；未播过为空）。
final topAlbumsProvider = StreamProvider<List<AlbumGroup>>(
    (ref) => ref.watch(dbProvider).libraryDao.watchTopAlbums(limit: 12));

/// FTS 拼音检索（标题/艺人/专辑/拼音全拼/首字母）。
final ftsSearchProvider =
    StreamProvider.family<List<Track>, String>((ref, q) {
  return ref.watch(dbProvider).libraryDao.watchSearchResults(q);
});

/// 播放历史（原始流；上限 100）。
final historyProvider = StreamProvider<List<HistoryItem>>(
    (ref) => ref.watch(dbProvider).historyDao.watchRecent(limit: 100));

/// 历史去重后的曲目序列（最新在前）。
/// 最近播放专辑（demo renderHistRow：历史顺序专辑去重，上限 8）。
final recentPlayedAlbumsProvider = Provider<List<AlbumGroup>>((ref) {
  final items = ref.watch(historyProvider).value ?? const <HistoryItem>[];
  final albums = ref.watch(albumsProvider).value ?? const <AlbumGroup>[];
  final byNorm = {for (final a in albums) albumKey(a.album): a};
  final seen = <String>{};
  final out = <AlbumGroup>[];
  for (final it in items) {
    final key = albumKey(it.track.album);
    if (!seen.add(key)) {
      continue;
    }
    final a = byNorm[key];
    if (a != null) {
      out.add(a);
    }
    if (out.length >= 8) {
      break;
    }
  }
  return out;
});

/// 最近入库专辑：按曲目 addedAt 倒序给专辑组排序（最新专辑在前）。
final recentAddedAlbumsProvider = StreamProvider<List<AlbumGroup>>((ref) {
  final tracks = ref.watch(tracksProvider(TrackSort.recentAdded)).value ??
      const <Track>[];
  final albums = ref.watch(albumsProvider).value ?? const <AlbumGroup>[];
  final byNorm = {for (final a in albums) albumKey(a.album): a};
  final seen = <String>{};
  final out = <AlbumGroup>[];
  for (final t in tracks) {
    final g = byNorm[albumKey(t.album)];
    if (g != null && seen.add(albumKey(g.album))) {
      out.add(g);
    }
  }
  return Stream.value(out);
});
