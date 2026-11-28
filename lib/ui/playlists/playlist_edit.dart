/// 歌单编辑：新建 + 重命名 + 自定义封面。
///
/// WP 语汇：新建走歌单屏「新建歌单」磁贴，重命名入口在长按菜单/详情页
/// 应用栏；名字走黑底直角对话框，封面从系统相册选取后复制进应用沙箱
/// （歌单属于曲库数据，不随相册失效）。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playlist.dart';
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

/// 黑底直角歌单名对话框（新建/重命名共用；空名禁确认）。
Future<String?> _playlistNameDialog(
    BuildContext context, {
    required String title,
    String? initial,
    required String confirm,
  }) async {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(),
      title: Text(
        title,
        style: TextStyle(
            fontSize: 20,
            fontWeight: IaType.light,
            color: IaColors.textHi),
      ),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 40,
        style: TextStyle(fontSize: 16.5, color: IaColors.textHi),
        cursorColor: Theme.of(ctx).extension<IaPalette>()!.accent,
        decoration: InputDecoration(
          counterText: '',
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: IaColors.hairlineStrong)),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: IaColors.hairlineStrong)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('取消',
              style: TextStyle(color: IaColors.textLow)),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: ctrl,
          builder: (_, v, _) => TextButton(
            onPressed: v.text.trim().isEmpty
                ? null
                : () => Navigator.of(ctx).pop(v.text.trim()),
            child: Text(confirm,
                style: TextStyle(
                    color: Theme.of(ctx).extension<IaPalette>()!.accent)),
          ),
        ),
      ],
    ),
  );
}

/// 重命名对话框（黑底直角；空名/未改动不落库）。
Future<void> renamePlaylistDialog(
    BuildContext context, WidgetRef ref, Playlist pl) async {
  final name = await _playlistNameDialog(context,
      title: '重命名歌单', initial: pl.name, confirm: '保存');
  if (name == null || name.isEmpty || name == pl.name) {
    return;
  }
  await ref.read(dbProvider).playlistDao.renamePlaylist(pl.id, name);
  if (context.mounted) {
    showWpToast(context, title: '歌单', message: '已重命名为「$name」');
  }
}

/// 新建歌单对话框（歌单屏「新建歌单」磁贴入口；同名已存在时 DAO 返回
/// 既有歌单不重复建）。
Future<void> createPlaylistDialog(BuildContext context, WidgetRef ref) async {
  final name = await _playlistNameDialog(context, title: '新建歌单', confirm: '创建');
  if (name == null || name.isEmpty) {
    return;
  }
  await ref.read(dbProvider).playlistDao.createPlaylist(name);
  if (context.mounted) {
    showWpToast(context, title: '歌单', message: '已创建「$name」');
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
