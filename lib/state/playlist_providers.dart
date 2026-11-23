/// 歌单 providers（v2 中散落在 UI 文件，v3 收拢到状态层）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/entities/playlist.dart';
import '../domain/entities/track.dart';

final playlistListProvider = StreamProvider<List<Playlist>>(
    (ref) => ref.watch(dbProvider).playlistDao.watchPlaylists());

final playlistTracksProvider =
    StreamProvider.family<List<Track>, int>((ref, playlistId) {
  return ref.watch(dbProvider).playlistDao.watchPlaylistTracks(playlistId);
});

/// 歌单首曲（快速播放磁贴封面用；单行 LIMIT 查询）。
final playlistFirstTrackProvider = FutureProvider.family<Track?, int>(
    (ref, playlistId) =>
        ref.watch(dbProvider).playlistDao.playlistFirstTrack(playlistId));

/// 历史去重列表（最近播放页用）。
final recentHistoryProvider = StreamProvider<List<HistoryItem>>(
    (ref) => ref.watch(dbProvider).historyDao.watchRecent(limit: 300));
