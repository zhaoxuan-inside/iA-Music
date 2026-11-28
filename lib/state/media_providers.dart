/// 封面与歌词的按需决议 provider（family 按 trackId + 已知缓存位键控）。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/entities/lyrics.dart';

/// 封面决议结果。键含 coverPath：DB 缓存位变化 → 新键 → 重新决议。
/// keepAlive：决议一次全会话复用——autoDispose 会在滚动中反复建/销，
/// 是列表卡顿与 Provider 噪音的来源。
final coverProvider = FutureProvider.family<File?, (int, String?)>((ref, key) async {
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

/// 歌词决议（按 trackId；封面/歌词变更经键控重决议）。
final trackLyricsProvider = FutureProvider.autoDispose
    .family<LyricsResult?, int>((ref, trackId) async {
  final pipeline = await ref.watch(lyricsPipelineProvider.future);
  final track = await ref.watch(dbProvider).libraryDao.trackById(trackId);
  if (track == null) {
    return null;
  }
  return pipeline.resolve(track);
});

/// 歌词动作（state 层收口）：用户调整偏移并刷新决议。
final lyricsActionsProvider = Provider<LyricsActions>(LyricsActions.new);

class LyricsActions {
  LyricsActions(this._ref);

  final Ref _ref;

  /// 写入 LyricsMeta.offsetMs（>0=歌词延后播放），并触发重新决议。
  Future<void> setOffset(int trackId, int offsetMs) async {
    final pipeline = await _ref.read(lyricsPipelineProvider.future);
    final track = await _ref.read(dbProvider).libraryDao.trackById(trackId);
    if (track == null) {
      return;
    }
    await pipeline.setOffset(track, offsetMs);
    _ref.invalidate(trackLyricsProvider(trackId));
  }

  /// 编辑歌曲信息页预填：sidecar/pasted 的 .lrc 原文；无落盘文件 → null
  /// （内嵌歌词不预填——编辑结果只落新 sidecar，不改音频文件）。
  Future<String?> loadRawLyrics(int trackId) async {
    final meta = await _ref.read(dbProvider).lyricsDao.metaOf(trackId);
    final path = meta?.lrcPath;
    if (path == null || path.isEmpty) {
      return null;
    }
    final f = File(path);
    if (!await f.exists()) {
      return null;
    }
    return f.readAsString();
  }

  /// 编辑歌曲信息页保存歌词：走粘贴管道（kind=pasted、edited=true，
  /// 在线歌词永不覆盖），并触发歌词重新决议。
  Future<void> savePasted(int trackId, String text) async {
    final pipeline = await _ref.read(lyricsPipelineProvider.future);
    final track = await _ref.read(dbProvider).libraryDao.trackById(trackId);
    if (track == null) {
      return;
    }
    await pipeline.savePasted(track, text);
    _ref.invalidate(trackLyricsProvider(trackId));
  }
}
