/// 设置页-音乐仓库管理（S2 纵切入口；REQ-LIB-01/02/05 的 UI 面）。
///
/// * 空态「尚未配置仓库」+「添加音乐仓库」→ `pickDirectory`（壳层装配系统
///   目录选择器；S10 分发前落地真 picker）→ `hub.addRepositoryAndScan`。
/// * 状态行：实时计数（ScanProgress → 「已发现 N 首」）与终态
///   （「入库 N · 跳过 M [· 缺失 K]」——真实计数红线的 UI 表达）。
/// * 「立即扫描」（REQ-LIB-05 锚「触发下一次扫描」）→ `hub.rescanNow`。
/// * 「进入音乐空间」→ 曲库列表页（REQ-LIB-01 收口）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/scan/scan_service.dart';
import 'package:ia_music/ui/library/library_list_page.dart';

final class RepositorySettingsPage extends StatefulWidget {
  const RepositorySettingsPage({super.key, required this.hub, this.pickDirectory});

  final LibraryHub hub;

  /// 系统目录选择器缝（壳层装配；测试注入的函数返回**真实存在的目录**——
  /// 无替身数据；S10 分发前由 Windows 壳层接真 picker）。
  final Future<String?> Function()? pickDirectory;

  @override
  State<RepositorySettingsPage> createState() => RepositorySettingsPageState();
}

class RepositorySettingsPageState extends State<RepositorySettingsPage> {
  bool _busy = false;
  String? _statusText;

  Future<void> _add() async {
    if (_busy) {
      return;
    }
    final picker = widget.pickDirectory;
    if (picker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目录选择器未装配（分发期接入）')));
      return;
    }
    final picked = await picker();
    if (picked == null) {
      return;
    }
    await addAndShow(picked);
  }

  /// 选定目录后的编排入口（真实用户链=tap→picker→本方法；测试经同一入口驱动）。
  /// * 实时计数：ScanProgress → 状态行「已发现 N 首」。
  /// * 终态：状态行「已完成：入库 N · 跳过 M」（真实计数红线 UI 表达）。
  /// * REQ-LIB-01 收口：仓库扫描完成 → pushReplacement 音乐空间。
  Future<void> addAndShow(String path) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _statusText = '扫描中…';
    });
    try {
      final report = await widget.hub.addRepositoryAndScan(
        path,
        onProgress: (processed, admitted, skipped) {
          if (!mounted) {
            return;
          }
          setState(() => _statusText = '已发现 $admitted 首');
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = '已完成：入库 ${report.total} · 跳过 ${report.skipped}';
      });
    } on StateError {
      if (mounted) {
        setState(() => _statusText = '仓库已存在或不可用');
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    if (!mounted) {
      return;
    }
    // pushReplacement 的 Future 依赖路由闭合（测试 runAsync 会因此挂起）——
    // 与入库编排无关，弃接（Navigator 自身在帧循环内完成切换）。
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LibraryListPage(hub: widget.hub)));
  }

  /// REQ-PLAY-04 末句收口：清空少播名单 → 被少播曲重新可随机。
  /// （墓碑语义=S6；此处物理全表删除沿用 DAO 纪律。）
  Future<void> clearFewWatch() async {
    await widget.hub.data.history.clearFewWatch();
    if (mounted) {
      setState(() => _statusText = '少播名单已清空，这些歌重新进入随机池');
    }
  }

  Widget _fewWatchTile() => ListTile(
        key: const ValueKey('clear_few_watch'),
        leading: const Icon(Icons.delete_sweep),
        title: const Text('清空少播名单'),
        subtitle: const Text('被减少推荐的歌将重新进入随机池'),
        trailing: TextButton(
          onPressed: () => unawaited(clearFewWatch()),
          child: const Text('清空'),
        ),
      );

  Future<void> _rescan(int rootId, {ScanMode mode = ScanMode.full}) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final report = await widget.hub
          .rescanNow(rootId: rootId, mode: mode)
          .timeout(const Duration(minutes: 10));
      if (mounted) {
        setState(() => _statusText =
            '已完成：入库 ${report.total} · 跳过 ${report.skipped} · 缺失 ${report.missing}');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _statusLine() =>
      Padding(padding: const EdgeInsets.only(top: 8), child: Text(_statusText ?? ''));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置 · 音乐仓库')),
      body: StreamBuilder<int>(
        stream: widget.hub.revisions,
        initialData: 0,
        builder: (context, rev) => FutureBuilder<List<RepositoryRoot>>(
          key: ValueKey('roots_${rev.data}'),
          future: widget.hub.rootsSnapshot(),
          builder: (context, snapshot) {
            final roots = snapshot.data ?? const <RepositoryRoot>[];
          if (roots.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('尚未配置仓库'),
                  if (widget.pickDirectory != null) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _busy ? null : _add,
                        child: const Text('添加音乐仓库')),
                  ],
                  if (_statusText != null) _statusLine(),
                  _fewWatchTile(),
                ],
              ),
            );
          }
          return ListView(
            children: [
              _fewWatchTile(),
              for (final r in roots)
                ListTile(
                  title: Text(r.path),
                  subtitle: Text(_statusText ?? '监听中：目录变更自动入库'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '立即扫描',
                        onPressed: _busy ? null : () => _rescan(r.id),
                        icon: const Icon(Icons.refresh),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => LibraryListPage(hub: widget.hub))),
                        child: const Text('进入音乐空间'),
                      ),
                    ],
                  ),
                ),
              if (widget.pickDirectory != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton(
                      onPressed: _busy ? null : _add,
                      child: const Text('添加音乐仓库')),
                ),
            ],
          );
          },
        ),
      ),
    );
  }
}
