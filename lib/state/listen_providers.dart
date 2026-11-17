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

  /// 常听电台取材：播放次数 Top12 单曲（单曲粒度，专辑缺失不折叠）。
  Future<List<Track>> top() async {
    final tops = await _db.libraryDao.watchTopTracks(limit: 12).first;
    return [for (final t in tops) t.track];
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

/// 常听单曲（PlayHistory 播放次数聚合；未播过为空）。
final topTracksProvider = StreamProvider<List<TrackPlays>>(
    (ref) => ref.watch(dbProvider).libraryDao.watchTopTracks(limit: 12));

/// FTS 拼音检索（标题/艺人/专辑/拼音全拼/首字母）。
final ftsSearchProvider =
    StreamProvider.family<List<Track>, String>((ref, q) {
  return ref.watch(dbProvider).libraryDao.watchSearchResults(q);
});

/// 播放历史（原始流；上限 100）。
final historyProvider = StreamProvider<List<HistoryItem>>(
    (ref) => ref.watch(dbProvider).historyDao.watchRecent(limit: 100));

/// 最近播放单曲（历史去重，最新在前；上限 12）。
/// 单曲粒度：无专辑元数据的收集曲不再被折叠成一个「未知专辑」磁贴。
final recentPlayedTracksProvider = Provider<List<Track>>((ref) {
  final items = ref.watch(historyProvider).value ?? const <HistoryItem>[];
  final seen = <int>{};
  return [
    for (final it in items)
      if (seen.add(it.track.id)) it.track,
  ].take(12).toList();
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
