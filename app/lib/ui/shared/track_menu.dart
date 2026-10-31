/// 曲目行上下文菜单（WS2/REQ-LIB-03/07、REQ-PL-03、REQ-PLAY-06）：
/// 长按（触控）/右键（桌面）→ 下一首播放 / 加入歌单 / 编辑标题 / 从曲库移除。
/// 服务能力此前全在域层，本组件是统一 UI 入口（行组件复用）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

/// 弹出曲目上下文菜单（各列表行 onLongPress/onSecondaryTap 统一调此函数）。
/// [service] 为空（未起播）时隐藏「下一首播放」。
Future<void> showTrackMenu(
  BuildContext context, {
  required Track track,
  required LibraryHub hub,
  PlaybackService? service,
  required VoidCallback onChanged,
}) {
  final t = sOf(context);
  final displayTitle = track.title ?? t.untitled;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) {
      final p = sheetCtx.ia;
      final tt = sOf(sheetCtx);
      Future<void> addToPlaylist() async {
        final digests = await hub.data.playlists.listAll();
        if (!sheetCtx.mounted) {
          return;
        }
        final picked = await showModalBottomSheet<int>(
          context: sheetCtx,
          showDragHandle: true,
          builder: (pickCtx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final (pl, _) in digests)
                  ListTile(
                    key: ValueKey('menu_pl_${pl.id}'),
                    leading: Icon(
                      pl.kind == PlaylistKind.system_favorite
                          ? IaIcon.heart
                          : IaIcon.playlist,
                      color: pl.kind == PlaylistKind.system_favorite
                          ? pickCtx.ia.heart
                          : pickCtx.ia.secondaryText,
                    ),
                    title: Text(pl.name),
                    onTap: () => Navigator.pop(pickCtx, pl.id),
                  ),
              ],
            ),
          ),
        );
        if (picked == null) {
          return;
        }
        final ok = await hub.data.playlists
            .addTrack(picked, track.id, nowMs: _nowMs());
        if (!sheetCtx.mounted) {
          return;
        }
        final name =
            digests.where((d) => d.$1.id == picked).map((d) => d.$1.name).firstOrNull ??
                '';
        ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(
          content: Text(ok
              ? tt.addedToPlaylist(name)
              : tt.alreadyInPlaylist(displayTitle, name)),
        ));
        onChanged();
      }

      Future<void> editTitle() async {
        final controller = TextEditingController(text: track.title ?? '');
        final newTitle = await showDialog<String>(
          context: sheetCtx,
          builder: (dlgCtx) => AlertDialog(
            title: Text(tt.menuEditTitle),
            content: TextField(
              key: const ValueKey('edit_title_input'),
              controller: controller,
              autofocus: true,
              decoration:
                  InputDecoration(labelText: tt.editTitleLabel),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text(tt.cancel),
              ),
              FilledButton(
                key: const ValueKey('edit_title_save'),
                onPressed: () =>
                    Navigator.pop(dlgCtx, controller.text.trim()),
                child: Text(tt.save),
              ),
            ],
          ),
        );
        if (newTitle == null || newTitle.isEmpty || newTitle == track.title) {
          return;
        }
        await hub.editTrackTitle(track.id, newTitle, nowMs: _nowMs());
        if (!sheetCtx.mounted) {
          return;
        }
        ScaffoldMessenger.of(sheetCtx).showSnackBar(
          SnackBar(content: Text(tt.renamed)),
        );
        onChanged();
      }

      Future<void> removeFromLibrary() async {
        final confirmed = await showDialog<bool>(
          context: sheetCtx,
          builder: (dlgCtx) => AlertDialog(
            title: Text(tt.menuRemoveTrack),
            content: Text(tt.removeTrackConfirm(displayTitle)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx, false),
                child: Text(tt.cancel),
              ),
              FilledButton(
                key: const ValueKey('remove_track_confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: p.error,
                ),
                onPressed: () => Navigator.pop(dlgCtx, true),
                child: Text(tt.menuRemoveTrack),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          return;
        }
        await hub.removeTrack(track.id, nowMs: _nowMs());
        if (!sheetCtx.mounted) {
          return;
        }
        ScaffoldMessenger.of(sheetCtx).showSnackBar(
          SnackBar(content: Text(tt.trackRemoved)),
        );
        onChanged();
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: p.mainText),
              ),
            ),
            if (service != null)
              ListTile(
                key: const ValueKey('menu_play_next'),
                leading: Icon(IaIcon.sequence, color: p.mainText),
                title: Text(tt.menuPlayNext),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  unawaited(service.insertNextId(track.id));
                },
              ),
            ListTile(
              key: const ValueKey('menu_add_to_playlist'),
              leading: Icon(IaIcon.playlist, color: p.mainText),
              title: Text(tt.menuAddToPlaylist),
              onTap: () {
                Navigator.pop(sheetCtx);
                unawaited(addToPlaylist());
              },
            ),
            ListTile(
              key: const ValueKey('menu_edit_title'),
              leading: Icon(IaIcon.edit, color: p.mainText),
              title: Text(tt.menuEditTitle),
              onTap: () {
                Navigator.pop(sheetCtx);
                unawaited(editTitle());
              },
            ),
            ListTile(
              key: const ValueKey('menu_remove_track'),
              leading: Icon(IaIcon.delete, color: p.error),
              title:
                  Text(tt.menuRemoveTrack, style: TextStyle(color: p.error)),
              onTap: () {
                Navigator.pop(sheetCtx);
                unawaited(removeFromLibrary());
              },
            ),
          ],
        ),
      );
    },
  );
}

int _nowMs() => DateTime.now().millisecondsSinceEpoch;
