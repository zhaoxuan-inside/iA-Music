/// 库动作与长按上下文菜单（喜欢/加歌单/插播/查看详情）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/providers.dart';
// 引用面收口：只经 providers 取 DAO 实例，不 import data 层类型
import '../../state/playback_controller.dart';
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
      () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => DetailPage(
                type: DetailType.album, id: albumKey(track.album)),
          )),
    ),
  ]);
}
