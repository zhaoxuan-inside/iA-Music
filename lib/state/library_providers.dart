/// 曲库数据面：drift watch → StreamProvider 细粒度刷新（禁全局 revision）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/entities/track.dart';
import 'letter.dart';

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

/// 专辑/艺人首曲（磁贴封面用；单行 LIMIT 查询，磁贴不再 watch 整表流）。
final albumFirstTrackProvider = FutureProvider.family<Track?, String>(
    (ref, albumNorm) => ref.watch(dbProvider).libraryDao.albumFirstTrack(albumNorm));

final artistFirstTrackProvider = FutureProvider.family<Track?, String>(
    (ref, artistNorm) =>
        ref.watch(dbProvider).libraryDao.artistFirstTrack(artistNorm));

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

/// 曲库列表槽位（字母组头 / 歌曲行）——UI 侧定高渲染的视图模型。
class SongSlot {
  const SongSlot.header(this.letter) : track = null;
  const SongSlot.song(this.track) : letter = null;

  final String? letter;
  final Track? track;
}

/// 曲库分组结果：展平槽位 + 字母表 + 字母 → 组头槽位号（精确跳转用）。
class SongSlots {
  const SongSlots({
    required this.slots,
    required this.letters,
    required this.headerSlots,
  });

  final List<SongSlot> slots;
  final List<String> letters;
  final Map<String, int> headerSlots;
}

/// 曲库字母分组（只依赖曲目数据）：
///
/// 显示序在 Dart 侧自排——SQL 按 titleNorm 码点序（中文≠拼音序），直接用
/// 会让同组歌曲散落、组头只在首现处出现。按（拼音首字母，歌名）排序后
/// 一遍建槽，组才真正连续、字母轨才能跳到整组。放 provider 里缓存：
/// 收藏/播放态变化不再触发全库 O(n·log n) 重排序（原每次 build 都重排）。
final songSlotsProvider = Provider<SongSlots>((ref) {
  final tracks =
      ref.watch(tracksProvider(TrackSort.title)).value ?? const <Track>[];
  final display = [
    for (final t in tracks) (t, letterKey(t.title)),
  ]..sort((a, b) {
    final c = a.$2.compareTo(b.$2);
    return c != 0
        ? c
        : a.$1.title.toLowerCase().compareTo(b.$1.title.toLowerCase());
  });
  final headerSlots = <String, int>{};
  final letters = <String>[];
  final slots = <SongSlot>[];
  for (final (t, key) in display) {
    if (!headerSlots.containsKey(key)) {
      headerSlots[key] = slots.length;
      letters.add(key);
      slots.add(SongSlot.header(key));
    }
    slots.add(SongSlot.song(t));
  }
  return SongSlots(slots: slots, letters: letters, headerSlots: headerSlots);
});
