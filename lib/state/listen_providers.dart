/// 听法与聚合 providers：流派 / 常听 / 历史 / 分类取材。
///
/// 三分离红线：这里只有真实数据库查询的组合，没有任何预置内容。
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/config/embedding_config.dart';
import '../app/providers.dart';
import '../domain/entities/track.dart';
import 'library_providers.dart';
import 'vector_providers.dart';

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
    final tops = await _db.libraryDao.getTopTracks(limit: 12);
    return [for (final t in tops) t.track];
  }

  /// 最近添加取材：按 addedAt 倒序的全部曲目。
  Future<List<Track>> recent() =>
      _db.libraryDao.getTracks(sort: TrackSort.recentAdded);

  /// 历史回放取材：去重后的历史曲目序列（最新在前，不打乱）。
  Future<List<Track>> history() async {
    final items = await _db.historyDao.recent(limit: 100);
    final seen = <int>{};
    return [for (final h in items) if (seen.add(h.track.id)) h.track];
  }

  /// 声音相似电台取材：种子曲的声学近邻（余弦 top-K，现读现算不缓存——
  /// 向量补全是后台增量，个人库规模全量重读 <10ms）。
  /// 种子无向量或全库无向量 → 空表（UI 引导先跑补全）。
  Future<List<Track>> similarTo(int trackId, {int limit = 24}) async {
    final rows = await _db.vectorDao.allVectors(kEmbeddingModel);
    final vecs = <int, Float32List>{};
    for (final r in rows) {
      if (r.dim != kEmbeddingDim) {
        continue; // 维度不符（换模型混入旧数据）——防御性丢弃
      }
      vecs[r.trackId] = Float32List.sublistView(r.vec);
    }
    final ids = vectorTopK(trackId, vecs, limit: limit);
    final tracks = <Track>[];
    for (final id in ids) {
      final t = await _db.libraryDao.trackById(id);
      if (t != null && !t.missing) {
        tracks.add(t);
      }
    }
    return tracks;
  }
}

final listenLibraryProvider = Provider<ListenLibrary>(
    (ref) => ListenLibrary(ref.watch(dbProvider), ref.watch(dbProvider).playlistDao));

/// 参数化策略的种子曲 id（声音相似是唯一带种子的策略）。
const String kListenStrategySimilar = 'similar';

/// 随缘策略 id（playing_page 大磁贴直接开播用）。
const String kListenStrategyRandom = 'random';

/// 取材上下文：参数化策略的入参（磁贴场景无种子）。
class ListenContext {
  const ListenContext({this.seedTrackId});

  final int? seedTrackId;
}

/// 听法策略：一种电台取材的完整定义——文案（磁贴/成功/空库三处）+
/// 编排参数（shuffle）+ 取材动作。
///
/// 「有哪些电台」只在 [listenStrategiesProvider] 目录声明：加策略 = 加
/// 一条目录项，UI 与编排零改动。取材动作 = ListenLibrary 的查询组合，
/// 策略层不触库。
class ListenStrategy {
  const ListenStrategy({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.fetch,
    this.toastMessage,
    this.shuffle = true,
    this.requiresSeed = false,
    this.emptyHint = '曲库为空——先去收集音乐',
  });

  final String id;
  final String label;
  final String subtitle;

  /// 取材动作（磁贴传空 ctx；参数化策略由菜单传种子）。
  final Future<List<Track>> Function(ListenContext ctx) fetch;

  /// 成功 toast 文案（null = 用 label）。
  final String? toastMessage;

  /// 开播是否打乱（历史回放不打乱）。
  final bool shuffle;

  /// 需要种子曲（磁贴跳过此类策略，入口=曲目长按菜单）。
  final bool requiresSeed;

  /// 取材为空时的引导文案。
  final String emptyHint;

  String get successToast => toastMessage ?? label;
}

/// 听法策略目录——电台清单的唯一事实源。
final listenStrategiesProvider = Provider<List<ListenStrategy>>((ref) {
  final lib = ref.watch(listenLibraryProvider);
  return [
    ListenStrategy(
      id: 'random',
      label: '随缘听歌',
      subtitle: '全曲库随机，闭眼开播',
      toastMessage: '随缘听歌 · 全曲库随机',
      fetch: (ctx) => lib.all(),
    ),
    ListenStrategy(
      id: 'favorites',
      label: '喜欢电台',
      subtitle: '从红心歌出发随机',
      fetch: (ctx) => lib.favorites(),
    ),
    ListenStrategy(
      id: 'top',
      label: '常听电台',
      subtitle: '播放次数 Top12 单曲',
      fetch: (ctx) => lib.top(),
    ),
    ListenStrategy(
      id: 'recent-added',
      label: '最近添加',
      subtitle: '新入库先听',
      toastMessage: '最近添加电台',
      fetch: (ctx) => lib.recent(),
    ),
    ListenStrategy(
      id: 'history',
      label: '历史回放',
      subtitle: '去重后的播放序列，不打乱',
      shuffle: false,
      fetch: (ctx) => lib.history(),
    ),
    ListenStrategy(
      id: kListenStrategySimilar,
      label: '声音相似电台',
      subtitle: '以种子曲的声学近邻随机开播',
      requiresSeed: true,
      emptyHint: '暂无声学向量——先在「歌曲处理」跑一轮补全',
      // 种子缺失属编程错误而非运行态——返回空表走空库引导，不炸 UI
      fetch: (ctx) async =>
          ctx.seedTrackId == null ? [] : lib.similarTo(ctx.seedTrackId!),
    ),
  ];
});

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
/// plays 为曲目累计播放次数（tracks.plays 物化列随历史 join 直读），
/// 磁贴翻面口径与常听排序一致。
final recentPlayedTracksProvider = Provider<List<TrackPlays>>((ref) {
  final items = ref.watch(historyProvider).value ?? const <HistoryItem>[];
  final seen = <int>{};
  return [
    for (final it in items)
      if (seen.add(it.track.id)) TrackPlays(track: it.track, plays: it.plays),
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
