/// 目录层级递进浏览器（安卓仓库选择 · 2026-10-25 用户反馈落地）。
///
/// 交互：从公共存储根 `/storage/emulated/0` 起，点击子目录逐级下钻；
/// AppBar 上一级键回退；当前层显示路径与直挂音频数；底部「选择此目录」
/// 确认回传。进入即申请 READ_MEDIA_AUDIO（无权限时给授权引导与重试）。
/// 隐藏目录过滤；单条不可读项跳过（不阻断整层）。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ia_music/scan/scan_service.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

/// 浏览起点与上界（越过即到系统噪音区，无意义）。
const String kAndroidStorageRoot = '/storage/emulated/0';

final class DirectoryBrowserPage extends StatefulWidget {
  const DirectoryBrowserPage({
    super.key,
    required this.onPick,
    this.initialPath = kAndroidStorageRoot,
  });

  /// 选定回调（页面自行 pop 后回传路径）。
  final void Function(String path) onPick;
  final String initialPath;

  @override
  State<DirectoryBrowserPage> createState() => _DirectoryBrowserPageState();
}

class _DirectoryBrowserPageState extends State<DirectoryBrowserPage> {
  late String _path = widget.initialPath;
  List<Directory> _dirs = const [];
  int _audioCount = 0;
  bool _loading = true;
  String? _error;
  bool _permitted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_ensurePermissionThenLoad());
  }

  Future<void> _ensurePermissionThenLoad() async {
    final status = await Permission.audio.request();
    if (!mounted) return;
    setState(() => _permitted = status.isGranted);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = Directory(_path);
      if (!await dir.exists()) {
        setState(() {
          _loading = false;
          _error = sOf(context).dirMissing(_path);
        });
        return;
      }
      final entities = <FileSystemEntity>[];
      await for (final e
          in dir.list(followLinks: false).handleError((_) {})) {
        entities.add(e);
      }
      entities.sort((a, b) => a.path.compareTo(b.path));
      final dirs = entities
          .whereType<Directory>()
          .where((d) => !d.path.split('/').last.startsWith('.'))
          .toList(growable: false);
      final audio = entities
          .whereType<File>()
          .where((f) => ScanService.isAudioEntry(f.path))
          .length;
      if (!mounted) return;
      setState(() {
        _dirs = dirs;
        _audioCount = audio;
        _loading = false;
      });
    } on FileSystemException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = sOf(context)
            .dirReadFailed(e.osError?.message ?? sOf(context).permissionDenied);
      });
    }
  }

  void _enter(String sub) {
    setState(() => _path = sub);
    unawaited(_load());
  }

  void _up() {
    if (_path == kAndroidStorageRoot) return;
    final parent =
        _path.substring(0, _path.lastIndexOf('/')).trim();
    _enter(parent.isEmpty ? kAndroidStorageRoot : parent);
  }

  void _confirm() {
    final picked = _path;
    Navigator.of(context).pop();
    widget.onPick(picked);
  }

  Future<void> _openSystemSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    final name = _path == kAndroidStorageRoot ? t.internalStorage : _path.split('/').last;
    return Scaffold(
      key: const ValueKey('dir_browser'),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, key: const ValueKey('dir_browser_name')),
            Text(
              _path,
              key: const ValueKey('dir_browser_path'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: p.secondaryText,
                fontFeatures: kIaNumericFeatures,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('dir_browser_up'),
            tooltip: t.levelUpTooltip,
            onPressed: _path == kAndroidStorageRoot ? null : _up,
            icon: Icon(IaIcon.back),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Icon(IaIcon.folder, size: 18, color: p.secondaryText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.dirBrowserStat(_dirs.length, _audioCount),
                    key: const ValueKey('dir_browser_stat'),
                    style: TextStyle(fontSize: 12, color: p.secondaryText),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    key: ValueKey('dir_browser_loading'),
                    child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(
                        error: _error!,
                        permitted: _permitted,
                        onRetry: () => unawaited(_ensurePermissionThenLoad()),
                        onSettings: () => unawaited(_openSystemSettings()),
                      )
                        : _dirs.isEmpty
                            ? Center(
                                key: const ValueKey('dir_browser_no_subdirs'),
                                child: Text(
                                  t.noSubdirs,
                                  style: TextStyle(
                                      fontSize: 13, color: p.secondaryText),
                                ),
                              )
                        : ListView.builder(
                            key: const ValueKey('dir_browser_list'),
                            itemCount: _dirs.length,
                            itemBuilder: (context, i) {
                              final d = _dirs[i];
                              return ListTile(
                                key: ValueKey('dir_browser_item_$i'),
                                dense: true,
                                leading: Icon(IaIcon.folder,
                                    size: 20, color: p.secondaryText),
                                title: Text(
                                  d.path.split('/').last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                trailing: Icon(IaIcon.arrowForward,
                                    size: 16, color: p.secondaryText),
                                onTap: () => _enter(d.path),
                              );
                            },
                          ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('dir_browser_confirm'),
                  onPressed: _confirm,
                  icon: Icon(IaIcon.check),
                  label: Text(t.pickThisDir(name)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.permitted,
    required this.onRetry,
    required this.onSettings,
  });

  final String error;
  final bool permitted;
  final VoidCallback onRetry;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Center(
      key: const ValueKey('dir_browser_error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(IaIcon.lock, size: 44, color: p.secondaryText),
            const SizedBox(height: 14),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: p.error)),
            if (!permitted) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('dir_browser_grant'),
                onPressed: onRetry,
                icon: Icon(IaIcon.shield),
                label: Text(t.grantAudioPermission),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('dir_browser_open_settings'),
                onPressed: onSettings,
                child: Text(t.openSystemSettings),
              ),
            ] else ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: Icon(IaIcon.refresh),
                label: Text(t.retryAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
