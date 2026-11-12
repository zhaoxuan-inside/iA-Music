/// 封面与歌词的按需决议 provider（family 按 trackId + 已知缓存位键控）。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/lyrics.dart';
import '../domain/entities/track.dart';
import 'playback_controller.dart';
import 'providers.dart';

/// 封面决议结果。键含 coverPath：DB 缓存位变化 → 新键 → 重新决议。
final coverProvider = FutureProvider.autoDispose
    .family<File?, (int, String?)>((ref, key) async {
  final (trackId, coverPath) = key;
  final chain = await ref.watch(coverChainProvider.future);
  final track = await ref.watch(dbProvider).libraryDao.trackById(trackId);
  if (track == null) {
    return null;
  }
  // 已有缓存位且文件在：直接读，避免每帧走链
  if (coverPath != null && coverPath.isNotEmpty && File(coverPath).existsSync()) {
    return File(coverPath);
  }
  return chain.coverFor(track, allowOnline: true);
});

/// 当前播放曲目 id（歌词决议的触发点；位置变化不触发）。
final currentTrackProvider = Provider<Track?>((ref) {
  return ref.watch(playbackProvider.select((s) => s.current));
});

final trackLyricsProvider = FutureProvider.autoDispose
    .family<LyricsResult?, int>((ref, trackId) async {
  final pipeline = await ref.watch(lyricsPipelineProvider.future);
  final track = await ref.watch(dbProvider).libraryDao.trackById(trackId);
  if (track == null) {
    return null;
  }
  return pipeline.resolve(track);
});
