/// 编辑歌曲信息子页：封面 / 基础信息（歌名·歌手·专辑·流派·音轨号）/ 歌词。
///
/// 只改库内显示（不写回音频文件 tag）：
/// * 基础信息 → `editTrackMeta`（norm 列 + FTS 由 DAO 单事务重建）；
/// * 歌词 → 粘贴管道落 sidecar（kind=pasted，edited=true 永不被在线覆盖）；
/// * 封面 → 相册选图复制进沙箱 track_covers/ 后写 coverPath（缓存位首级，
///   决议链直接命中）。引擎 MediaItem 的 artUri 在装队列时快照，通知栏/
///   锁屏的封面与文字重进队列后才刷新（会话级，列表/详情即时生效）。
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/media_providers.dart';
import '../components/mapped/cover.dart';
import '../layout/sub_header.dart';
import '../shared/ui_kit.dart';

/// 编辑歌曲信息页（长按菜单「编辑歌曲信息…」直达）。
class TrackEditPage extends ConsumerStatefulWidget {
  const TrackEditPage({required this.track, super.key});

  final Track track;

  @override
  ConsumerState<TrackEditPage> createState() => _TrackEditPageState();
}

class _TrackEditPageState extends ConsumerState<TrackEditPage> {
  late final TextEditingController _title;
  late final TextEditingController _artist;
  late final TextEditingController _album;
  late final TextEditingController _genre;
  late final TextEditingController _trackNo;
  final TextEditingController _lyrics = TextEditingController();

  /// 封面缓存位（本地态：选图后立即刷新预览，不等外层列表流回灌）。
  late String? _coverPath;
  bool _savingMeta = false;
  bool _savingLyrics = false;

  @override
  void initState() {
    super.initState();
    final t = widget.track;
    _title = TextEditingController(text: t.title);
    _artist = TextEditingController(text: t.artist);
    _album = TextEditingController(text: t.album);
    _genre = TextEditingController(text: t.genre);
    _trackNo = TextEditingController(text: t.trackNo > 0 ? '${t.trackNo}' : '');
    _coverPath = t.coverPath;
    // 歌词预填（sidecar/pasted 的 .lrc 原文；内嵌不预填——只允许覆写）
    Future.microtask(() async {
      final text =
          await ref.read(lyricsActionsProvider).loadRawLyrics(widget.track.id);
      if (mounted && text != null && text.trim().isNotEmpty) {
        _lyrics.text = text;
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    _genre.dispose();
    _trackNo.dispose();
    _lyrics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final edge = edgeInsets(context);
    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const SubHeader(title: '编辑歌曲信息'),
            const SizedBox(height: IaSpacing.xl),
            _buildCover(context),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('基础信息'),
            const SizedBox(height: IaSpacing.m),
            _Field(label: '歌名', controller: _title, autofocus: true),
            _Field(label: '歌手', controller: _artist),
            _Field(label: '专辑', controller: _album),
            _Field(label: '流派', controller: _genre),
            _Field(
                label: '音轨号',
                controller: _trackNo,
                keyboardType: TextInputType.number),
            const SizedBox(height: IaSpacing.l),
            // 空歌名禁确认（同歌单重命名对话框口径）
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _title,
              builder: (_, v, _) => SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _savingMeta || v.text.trim().isEmpty
                      ? null
                      : _saveMeta,
                  child: Text(_savingMeta ? '保存中…' : '保存信息',
                      style: const TextStyle(fontSize: 15.5)),
                ),
              ),
            ),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('歌词'),
            const SizedBox(height: IaSpacing.m),
            Container(
              padding: const EdgeInsets.all(IaSpacing.m),
              decoration: BoxDecoration(
                  border: Border.all(color: IaColors.hairlineStrong)),
              child: TextField(
                controller: _lyrics,
                maxLines: 8,
                minLines: 4,
                style: TextStyle(
                    fontSize: 14, height: 1.6, color: IaColors.textHi),
                decoration: InputDecoration(
                  hintText: '粘贴 LRC 歌词，或从文件导入…',
                  hintStyle: TextStyle(fontSize: 14, color: IaColors.textLow),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: IaSpacing.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _importLrc,
                  child: const Text('导入 .lrc 文件',
                      style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: IaSpacing.m),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _lyrics,
                  builder: (_, v, _) => TextButton(
                    onPressed:
                        _savingLyrics || v.text.trim().isEmpty ? null : _saveLyrics,
                    child: Text(_savingLyrics ? '保存中…' : '保存歌词',
                        style: TextStyle(
                            fontSize: 14,
                            color: v.text.trim().isEmpty
                                ? IaColors.textLow
                                : Theme.of(context)
                                    .extension<IaPalette>()!
                                    .accent)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 封面 ────────────────────────────────────────────────────────────

  Widget _buildCover(BuildContext context) {
    final track = widget.track.copyWith(coverPath: _coverPath);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('封面'),
        const SizedBox(height: IaSpacing.m),
        Row(
          children: [
            CoverArt(track: track, size: 96),
            const SizedBox(width: IaSpacing.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: _pickCover,
                    child: const Text('更换封面',
                        style: TextStyle(fontSize: 14.5)),
                  ),
                  const SizedBox(height: IaSpacing.xs),
                  Text(
                    '仅改库内显示；歌单、播放记录与歌词不受影响。',
                    style:
                        TextStyle(fontSize: 13.5, color: IaColors.textMid),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 相册选封面：压缩后复制进沙箱 track_covers/，写回 coverPath。
  /// 沙箱目录独立于封面决议缓存（covers/），不受会话缓存语义影响。
  Future<void> _pickCover() async {
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
          '${base.path}${Platform.pathSeparator}track_covers');
      await covers.create(recursive: true);
      final src = x.path;
      final dot = src.lastIndexOf('.');
      final ext = dot > 0 && dot >= src.length - 5 ? src.substring(dot + 1) : 'jpg';
      final dest = '${covers.path}${Platform.pathSeparator}tr_${widget.track.id}.$ext';
      // 换封面清旧文件：同 id 不同扩展名时只留当前一张
      final old = await covers.list().toList();
      for (final f in old) {
        if (f is File &&
            f.path != dest &&
            f.path.startsWith('${covers.path}${Platform.pathSeparator}tr_${widget.track.id}.')) {
          try {
            await f.delete();
          } on Object {
            // 清理失败不影响换封面
          }
        }
      }
      await File(src).copy(dest);
      await ref
          .read(dbProvider)
          .libraryDao
          .updateCover(widget.track.id, dest);
      if (mounted) {
        setState(() => _coverPath = dest);
        showWpToast(context,
            title: '封面', message: '「${_title.text}」封面已更新');
      }
    } on Object catch (e) {
      if (mounted) {
        showWpToast(context,
            title: '封面', message: '设置失败：$e', isError: true);
      }
    }
  }

  // ── 基础信息 ────────────────────────────────────────────────────────

  Future<void> _saveMeta() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      return;
    }
    setState(() => _savingMeta = true);
    try {
      await ref.read(dbProvider).libraryDao.editTrackMeta(
            id: widget.track.id,
            title: title,
            artist: _artist.text.trim(),
            album: _album.text.trim(),
            genre: _genre.text.trim(),
            trackNo: int.tryParse(_trackNo.text.trim()) ?? 0,
          );
      if (!mounted) {
        return;
      }
      showWpToast(context, title: '歌曲信息', message: '已保存「$title」');
      Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) {
        showWpToast(context,
            title: '歌曲信息', message: '保存失败：$e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _savingMeta = false);
      }
    }
  }

  // ── 歌词 ────────────────────────────────────────────────────────────

  /// 导入 .lrc/.txt：读文本填进编辑框，用户确认后再保存（不直接落盘）。
  Future<void> _importLrc() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['lrc', 'txt'],
      );
      final path = files.singleOrNull?.path;
      if (path == null) {
        return;
      }
      final text = await File(path).readAsString();
      if (mounted) {
        setState(() => _lyrics.text = text);
        showWpToast(context, title: '歌词', message: '已导入，点「保存歌词」落盘');
      }
    } on Object catch (e) {
      if (mounted) {
        showWpToast(context,
            title: '歌词', message: '导入失败：$e', isError: true);
      }
    }
  }

  Future<void> _saveLyrics() async {
    final text = _lyrics.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() => _savingLyrics = true);
    try {
      await ref.read(lyricsActionsProvider).savePasted(widget.track.id, text);
      if (mounted) {
        showWpToast(context, title: '歌词', message: '歌词已保存');
      }
    } on Object catch (e) {
      if (mounted) {
        showWpToast(context,
            title: '歌词', message: '保存失败：$e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _savingLyrics = false);
      }
    }
  }
}

/// 下划线输入框（黑底 WP 语言，同歌单名对话框）。
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: IaSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style:
                    TextStyle(fontSize: 14, color: IaColors.textMid)),
          ),
          const SizedBox(width: IaSpacing.m),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              keyboardType: keyboardType,
              style: TextStyle(fontSize: 16.5, color: IaColors.textHi),
              cursorColor: Theme.of(context).extension<IaPalette>()!.accent,
              decoration: InputDecoration(
                isDense: true,
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: IaColors.hairlineStrong)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: IaColors.hairlineStrong)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
