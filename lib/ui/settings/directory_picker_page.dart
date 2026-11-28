/// 目录浏览器（手动配置音乐目录）：系统存储根起步逐层进入，确认所选目录。
///
/// Zune 语汇：细体大标题 + 发丝分隔行 + 底部常驻「选此目录」。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/collect_config.dart';
import '../../app/theme/design_tokens.dart';
import '../../state/scan_controller.dart';
import '../shared/ui_kit.dart';

class DirectoryPickerPage extends ConsumerStatefulWidget {
  const DirectoryPickerPage({super.key});

  @override
  ConsumerState<DirectoryPickerPage> createState() =>
      _DirectoryPickerPageState();
}

class _DirectoryPickerPageState extends ConsumerState<DirectoryPickerPage> {
  /// 当前所在目录（浏览位置）；选择目标由用户按底部按钮确认。
  late String _current = kDirectoryBrowserRoot;
  List<Directory> _subs = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _enter(kDirectoryBrowserRoot);
  }

  Future<void> _enter(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // 无权限时先请求（首次进入生效；拒绝后列出失败原因）
    final ok = await ref.read(scanProvider.notifier).ensureAudioPermission();
    if (!ok) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '存储权限未授予——系统设置里允许「音乐和音频」后重试';
        });
      }
      return;
    }
    try {
      final dir = Directory(path);
      final subs = <Directory>[];
      for (final e in dir.listSync(followLinks: false)) {
        if (e is Directory) {
          final name = e.path
              .substring(path.length)
              .replaceAll(Platform.pathSeparator, '');
          if (name.isNotEmpty && !name.startsWith('.')) {
            subs.add(e);
          }
        }
      }
      subs.sort((a, b) =>
          a.path.toLowerCase().compareTo(b.path.toLowerCase()));
      if (!mounted) {
        return;
      }
      setState(() {
        _current = path;
        _subs = subs;
        _loading = false;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '无法读取该目录：$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final edge = edgeInsets(context);
    final bottom = bottomInset(context);
    final inRoot = _current == kDirectoryBrowserRoot;

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.m, edge.right, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                        inRoot
                            ? Icons.arrow_back_ios_new
                            : Icons.arrow_upward,
                        size: 18),
                    onPressed: inRoot
                        ? () => Navigator.of(context).maybePop()
                        : () => _enter(
                            _current.substring(0, _current.lastIndexOf(Platform.pathSeparator))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: IaSpacing.m),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: edge.left),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('选择音乐目录',
                      style: TextStyle(
                          fontSize: IaType.page,
                          fontWeight: IaType.light,
                          color: IaColors.textHi)),
                  const SizedBox(height: IaSpacing.s),
                  Text(_current,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, color: p.accent)),
                ],
              ),
            ),
            const SizedBox(height: IaSpacing.m),
            if (_error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: edge.left),
                child: Text(_error!,
                    style: TextStyle(
                        fontSize: 14, color: IaColors.error)),
              )
            else if (_loading)
              Padding(
                padding: EdgeInsets.all(IaSpacing.xl),
                child: Text('读取中…',
                    style: TextStyle(fontSize: 14, color: IaColors.textLow)),
              )
            else if (_subs.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: edge.left),
                child: Text('没有子目录——直接选此目录即可',
                    style: TextStyle(
                        fontSize: 14, color: IaColors.textLow)),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 20),
                  itemCount: _subs.length,
                  itemBuilder: (_, i) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _enter(_subs[i].path),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: IaSpacing.m, vertical: IaSpacing.l),
                        decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: IaColors.hairline))),
                        child: Row(
                          children: [
                            Icon(Icons.folder_outlined,
                                size: 20, color: IaColors.textMid),
                            const SizedBox(width: IaSpacing.m),
                            Expanded(
                              child: Text(_dirName(_subs[i].path),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: IaType.list,
                                      color: IaColors.textHi)),
                            ),
                            Icon(Icons.chevron_right,
                                size: 20, color: IaColors.textLow),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_subs.isNotEmpty) const SizedBox(height: IaSpacing.m),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  edge.left, IaSpacing.m, edge.right, IaSpacing.l + bottom),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_current),
                  child: const Text('选此目录',
                      style: TextStyle(fontSize: 15.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dirName(String path) {
    final seg = path.substring(_current.length).split(Platform.pathSeparator);
    return seg.where((s) => s.isNotEmpty).first;
  }
}
