/// 歌单编辑：重命名 + 自定义封面。
///
/// WP 语汇：入口在长按菜单/详情页应用栏；重命名走黑底直角对话框，
/// 封面从系统相册选取后复制进应用沙箱（歌单属于曲库数据，不随相册失效）。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playlist.dart';
import '../../state/providers.dart';
import '../shared/ui_kit.dart';

/// 歌单编辑菜单（重命名 / 设置封面；系统歌单不给重命名）。
Future<void> showPlaylistEditMenu(
    BuildContext context, WidgetRef ref, Playlist pl) async {
  if (!context.mounted) {
    return;
  }
  await showWpMenu(context, title: pl.name, items: [
    if (!pl.isSystem)
      ('重命名歌单', () => renamePlaylistDialog(context, ref, pl)),
    ('设置歌单封面', () => pickPlaylistCover(context, ref, pl)),
  ]);
}

/// 重命名对话框（黑底直角；空名不落库）。
Future<void> renamePlaylistDialog(
    BuildContext context, WidgetRef ref, Playlist pl) async {
  final ctrl = TextEditingController(text: pl.name);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(),
      title: Text(
        '重命名歌单',
        style: TextStyle(
            fontSize: 18,
            fontWeight: IaType.light,
            color: IaColors.textHi),
      ),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 40,
        style: const TextStyle(fontSize: 15, color: IaColors.textHi),
        cursorColor: Theme.of(ctx).extension<IaPalette>()!.accent,
        decoration: const InputDecoration(
          counterText: '',
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: IaColors.hairlineStrong)),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: IaColors.hairlineStrong)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消',
              style: TextStyle(color: IaColors.textLow)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('保存',
              style: TextStyle(
                  color: Theme.of(ctx).extension<IaPalette>()!.accent)),
        ),
      ],
    ),
  );
  if (ok != true) {
    return;
  }
  final name = ctrl.text.trim();
  if (name.isEmpty || name == pl.name) {
    return;
  }
  await ref.read(dbProvider).playlistDao.renamePlaylist(pl.id, name);
  if (context.mounted) {
    showWpToast(context, title: '歌单', message: '已重命名为「$name」');
  }
}

/// 从相册选封面：压缩后复制进沙箱 playlist_covers/，写回 DB。
Future<void> pickPlaylistCover(
    BuildContext context, WidgetRef ref, Playlist pl) async {
  try {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1200,
    );
    if (x == null) {
      return;
    }
    final base = await getApplicationSupportDirectory();
    final covers = Directory(
        '${base.path}${Platform.pathSeparator}playlist_covers');
    await covers.create(recursive: true);
    final src = x.path;
    final dot = src.lastIndexOf('.');
    final ext = dot > 0 && dot >= src.length - 5 ? src.substring(dot + 1) : 'jpg';
    final dest =
        '${covers.path}${Platform.pathSeparator}pl_${pl.id}.$ext';
    // 换封面清旧文件：同 id 不同扩展名时只留当前一张
    final old = await covers.list().toList();
    for (final f in old) {
      if (f is File && f.path != dest && f.path.startsWith('${covers.path}${Platform.pathSeparator}pl_${pl.id}.')) {
        try {
          await f.delete();
        } on Object {
          // 清理失败不影响换封面
        }
      }
    }
    await File(src).copy(dest);
    await ref.read(dbProvider).playlistDao.setPlaylistCover(pl.id, dest);
    if (context.mounted) {
      showWpToast(context, title: '歌单封面', message: '「${pl.name}」封面已更新');
    }
  } on Object catch (e) {
    if (context.mounted) {
      showWpToast(context,
          title: '歌单封面', message: '设置失败：$e', isError: true);
    }
  }
}
