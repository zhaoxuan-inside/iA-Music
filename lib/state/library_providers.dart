/// 曲库数据面：drift watch → StreamProvider 细粒度刷新（禁全局 revision）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/entities/track.dart';
import 'providers.dart';

final tracksProvider = StreamProvider.family<List<Track>, TrackSort>((ref, sort) {
  return ref.watch(dbProvider).libraryDao.watchTracks(sort: sort);
});

final albumsProvider =
    StreamProvider.autoDispose<List<AlbumGroup>>((ref) {
  return ref.watch(dbProvider).libraryDao.watchAlbums();
});

final artistsProvider =
    StreamProvider.autoDispose<List<ArtistGroup>>((ref) {
  return ref.watch(dbProvider).libraryDao.watchArtists();
});

final albumTracksProvider =
    StreamProvider.autoDispose.family<List<Track>, String>((ref, albumNorm) {
  return ref.watch(dbProvider).libraryDao.watchAlbumTracks(albumNorm);
});

final artistTracksProvider =
    StreamProvider.autoDispose.family<List<Track>, String>((ref, artistNorm) {
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

/// 单曲收藏态（红心即时反馈）。
final favoriteProvider = StreamProvider.autoDispose.family<bool, int>((ref, trackId) {
  return ref.watch(dbProvider).playlistDao.watchFavorite(trackId);
});

/// 专辑 norm 键（GROUP BY 键 = 显示名规整）。
String albumKey(String album) => album.trim().toLowerCase();
String artistKey(String artist) => artist.trim().toLowerCase();
