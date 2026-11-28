/// 库动作与长按上下文菜单（喜欢/加歌单/插播/声音相似/查看详情/删除）。
/// 跨域动作编排层——页面跳转一律走 routing（本层禁 import 页面文件）。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
// 引用面收口：只经 providers 取 DAO 实例，不 import data 层类型
import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../routing/app_routes.dart' show DetailType, openDetail, openTrackEdit;
import '../shared/ui_kit.dart';
import './radio_starter.dart';

/// 曲库/歌单域的轻动作集合（UI 只触达 state 层）。
final dbActionsProvider = Provider<DbActions>(DbActions.new);

class DbActions {
  DbActions(this._ref);

  final Ref _ref;

  Future<void> setFavorite(int trackId, bool fav) =>
      _ref.read(dbProvider).playlistDao.setFavorite(trackId, fav);

  Future<bool> isFavorite(int trackId) =>
      _ref.read(dbProvider).playlistDao.isFavorite(trackId);

  Future<List<Playlist>> playlists() =>
      _ref.read(dbProvider).playlistDao.watchPlaylists().first;

  Future<void> addToPlaylist(int playlistId, int trackId) =>
      _ref.read(dbProvider).playlistDao.addTrack(playlistId, trackId);

  Future<void> playNext(Track t) =>
      _ref.read(playbackProvider.notifier).playNext(t);

  /// 删除一首歌：只删音频文件并标记缺失。曲库列表不再出现、播放自动跳过，
  /// 但已建立的数据（歌单条目 / 播放历史 / 喜欢 / 歌词）全部保留；文件放回原位重扫即复活。
  Future<void> deleteTrack(Track t) async {
    try {
      final f = File(t.path);
      if (t.path.isNotEmpty && await f.exists()) {
        await f.delete();
      }
    } on Object {
      // 文件删不掉（占用/权限）也照样标缺失，行为与文件消失一致
    }
    await _ref.read(dbProvider).libraryDao.markMissing([t.id]);
  }
}

/// 歌曲长按菜单（WP 式）：插播 / 喜欢 / 加到歌单 / 查看专辑。
Future<void> showTrackMenu(
    BuildContext context, WidgetRef ref, Track track) async {
  final actions = ref.read(dbActionsProvider);
  final fav = await actions.isFavorite(track.id);
  if (!context.mounted) {
    return;
  }
  await showWpMenu(context, title: track.title, items: [
    ('插播：下一首播放', () => actions.playNext(track)),
    (
      fav ? '取消喜欢 ♥' : '喜欢 ♥',
      () async {
        await actions.setFavorite(track.id, !fav);
        if (context.mounted) {
          showWpToast(context,
              title: '喜欢',
              message: fav ? '已取消喜欢：${track.title}' : '已喜欢：${track.title}');
        }
      },
    ),
    (
      '加到歌单…',
      () async {
        final pls = await actions.playlists();
        if (!context.mounted) {
          return;
        }
        await showWpMenu(context,
            title: '加到歌单',
            items: [
              for (final p in pls)
                (
                  p.name,
                  () async {
                    await actions.addToPlaylist(p.id, track.id);
                    if (context.mounted) {
                      showWpToast(context,
                          title: '歌单', message: '已加到「${p.name}」');
                    }
                  },
                ),
            ]);
      },
    ),
    (
      '声音相似电台 ♪',
      () => startRadio(ref, context,
          strategyById(ref.read(listenStrategiesProvider), kListenStrategySimilar),
          ctx: ListenContext(seedTrackId: track.id),
          toastTitle: '声音相似电台',
          toastMessage: '以「${track.title}」的声学画像取材'),
    ),
    (
      '编辑歌曲信息…',
      () => openTrackEdit(context, track),
    ),
    (
      '查看专辑',
      () => openDetail(context, DetailType.album, albumKey(track.album)),
    ),
    ('删除此歌…', () => _confirmDeleteTrack(context, ref, track)),
  ]);
}

/// 删除确认（破坏性动作）：明确提示「连同音频文件一并删除」。
Future<void> _confirmDeleteTrack(
    BuildContext context, WidgetRef ref, Track track) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(),
      title: Text(
        '删除「${track.title}」？',
        style: TextStyle(
            fontSize: 20, fontWeight: IaType.light, color: IaColors.textHi),
      ),
      content: Text(
        '将删除音频文件并从曲库移除（播放时自动跳过）；歌单、播放记录与喜欢都会保留。',
        style: TextStyle(fontSize: 14.5, height: 1.5, color: IaColors.textMid),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('取消', style: TextStyle(color: IaColors.textLow)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('删除',
              style: TextStyle(
                  color: Theme.of(ctx).extension<IaPalette>()!.accent)),
        ),
      ],
    ),
  );
  if (ok != true) {
    return;
  }
  await ref.read(dbActionsProvider).deleteTrack(track);
  if (context.mounted) {
    showWpToast(context, title: '曲库', message: '已删除「${track.title}」');
  }
}
