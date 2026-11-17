/// 库动作与长按上下文菜单（喜欢/加歌单/插播/查看详情/删除）。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
// 引用面收口：只经 providers 取 DAO 实例，不 import data 层类型
import '../../state/playback_controller.dart';
import '../../state/providers.dart';
import '../detail/detail_page.dart';
import 'ui_kit.dart';

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

  /// 从曲库彻底删除一首歌：音频文件 + 曲库行（歌单条目/历史/歌词元数据一并清）。
  Future<void> deleteTrack(Track t) async {
    try {
      final f = File(t.path);
      if (t.path.isNotEmpty && await f.exists()) {
        await f.delete();
      }
    } on Object {
      // 文件删不掉（占用/权限）仍清曲库行，避免幽灵条目
    }
    await _ref.read(dbProvider).libraryDao.purgeTrack(t.id);
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
      '查看专辑',
      () => Navigator.of(context).push(zuneRoute<void>(
            builder: (_) => DetailPage(
                type: DetailType.album, id: albumKey(track.album)),
          )),
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
            fontSize: 18, fontWeight: IaType.light, color: IaColors.textHi),
      ),
      content: const Text(
        '将从曲库移除并删除音频文件，歌单条目与播放记录一并清除，不可恢复。',
        style: TextStyle(fontSize: 13, height: 1.5, color: IaColors.textMid),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消', style: TextStyle(color: IaColors.textLow)),
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
