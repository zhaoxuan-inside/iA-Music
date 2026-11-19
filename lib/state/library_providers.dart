/// 曲库数据面：drift watch → StreamProvider 细粒度刷新（禁全局 revision）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/entities/track.dart';
import 'providers.dart';

final tracksProvider = StreamProvider.family<List<Track>, TrackSort>((ref, sort) {
  return ref.watch(dbProvider).libraryDao.watchTracks(sort: sort);
});

/// 专辑/艺人曲目流：keepAlive（进过一次详情后常驻容器）。
/// autoDispose 会在网格滚动时反复创建/销毁——既是卡顿源，也会在加载中
/// 被销毁时抛 ProviderDisposedException 噪音。
final albumsProvider =
    StreamProvider<List<AlbumGroup>>((ref) {
  return ref.watch(dbProvider).libraryDao.watchAlbums();
});

final artistsProvider =
    StreamProvider<List<ArtistGroup>>((ref) {
  return ref.watch(dbProvider).libraryDao.watchArtists();
});

final albumTracksProvider =
    StreamProvider.family<List<Track>, String>((ref, albumNorm) {
  return ref.watch(dbProvider).libraryDao.watchAlbumTracks(albumNorm);
});

final artistTracksProvider =
    StreamProvider.family<List<Track>, String>((ref, artistNorm) {
  return ref.watch(dbProvider).libraryDao.watchArtistTracks(artistNorm);
});

final searchResultsProvider =
    StreamProvider.autoDispose.family<List<Track>, String>((ref, query) {
  return ref.watch(dbProvider).libraryDao.watchSearchResults(query);
});

final trackCountProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(dbProvider).libraryDao.watchAvailableCount();
});

final rootsProvider = StreamProvider.autoDispose<List<RepositoryRoot>>((ref) {
  return ref.watch(dbProvider).libraryDao.watchRoots();
});

/// 全库收藏集合（单流）。列表行查红心 = 集合内查询，
/// 不再每行开一条 drift watch 流（滚动卡顿 + Provider 噪音来源）。
final favoritesSetProvider = StreamProvider<Set<int>>((ref) {
  return ref.watch(dbProvider).playlistDao.watchFavoriteTrackIds();
});

/// 专辑 norm 键（GROUP BY 键 = 显示名规整）。
String albumKey(String album) => album.trim().toLowerCase();
String artistKey(String artist) => artist.trim().toLowerCase();
