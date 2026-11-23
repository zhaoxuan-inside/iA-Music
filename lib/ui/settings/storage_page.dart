/// 存储子页：音乐目录交互式管理（添加/移除/重扫）+ 曲库统计 + 索引状态。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/diagnostics.dart';
import '../../state/library_providers.dart';
import '../../state/scan_controller.dart';
import '../shared/sub_header.dart';
import '../shared/tri_state_bar.dart';
import '../shared/ui_kit.dart';
import 'directory_picker_page.dart';

/// 存储子页：音乐目录交互式管理（添加/移除/重扫）+ 曲库统计 + 索引状态。
class StorageSubPage extends ConsumerStatefulWidget {
  const StorageSubPage({super.key});

  @override
  ConsumerState<StorageSubPage> createState() => _StorageSubPageState();
}

class _StorageSubPageState extends ConsumerState<StorageSubPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(trackCountProvider).value ?? 0;
    final roots = ref.watch(rootsProvider).value ?? const [];
    final scan = ref.watch(scanProvider);
    final edge = edgeInsets(context);
    final p = Theme.of(context).extension<IaPalette>()!;

    Future<void> add() async {
      final ok =
          await ref.read(scanProvider.notifier).ensureAudioPermission();
      if (!ok) {
        if (context.mounted) {
          showWpToast(context, title: '存储', message: '存储权限未授予——先在系统设置中允许', isError: true);
        }
        return;
      }
      if (!context.mounted) {
        return;
      }
      final picked = await Navigator.of(context).push<String>(
          zuneRoute(builder: (_) => const DirectoryPickerPage()));
      if (picked == null) {
        return;
      }
      setState(() => _busy = true);
      String result;
      try {
        result = await ref.read(scanProvider.notifier).addRoot(picked);
      } on Object catch (e, st) {
        result = '';
        if (context.mounted) {
          // 常驻错误条：真实原因完整可读，点按关闭
          showWpToast(context, title: '存储', message: '添加目录失败：$e', isError: true);
          unawaited(ref
              .read(diagnosticsProvider.notifier)
              .record('添加目录', e, st));
        }
      }
      if (!context.mounted) {
        return;
      }
      setState(() => _busy = false);
      final err = ref.read(scanProvider).lastError;
      if (err != null) {
        showWpToast(context,
            title: '存储 · 扫描失败', message: err, isError: true);
        return;
      }
      showWpToast(context,
          title: '存储',
          message: result == 'exists'
              ? '目录已存在 · 已重新扫描'
              : '已添加目录并完成扫描');
    }

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const SubHeader(title: '存储'),
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('音乐目录'),
            const SizedBox(height: IaSpacing.m),
            for (final r in roots)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onLongPress: () => showWpMenu(context, title: r.path, items: [
                    (
                      '移除此目录',
                      () async {
                        await ref.read(scanProvider.notifier).removeRoot(r.id);
                        if (context.mounted) {
                          showWpToast(context, title: '存储', message: '已移除：${r.path}');
                        }
                      },
                    ),
                    (
                      '立即重扫此目录',
                      () async {
                        setState(() => _busy = true);
                        try {
                          await ref
                              .read(scanProvider.notifier)
                              .addRoot(r.path); // 已存在路径 = 重扫
                        } on Object catch (e) {
                          if (context.mounted) {
                            showWpToast(context,
                                title: '存储 · 重扫失败', message: '$e', isError: true);
                          }
                        }
                        if (!context.mounted) {
                          return;
                        }
                        setState(() => _busy = false);
                        final err = ref.read(scanProvider).lastError;
                        if (err != null) {
                          showWpToast(context,
                              title: '存储 · 扫描失败', message: err, isError: true);
                        } else {
                          showWpToast(context, title: '存储', message: '扫描完成');
                        }
                      },
                    ),
                  ]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: IaSpacing.m, vertical: IaSpacing.l),
                    decoration: const BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: IaColors.hairline))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(r.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: IaType.list, color: IaColors.textHi)),
                        ),
                        const Text('音乐目录',
                            style:
                                TextStyle(fontSize: 12, color: IaColors.textLow)),
                      ],
                    ),
                  ),
                ),
              ),
            if (roots.isEmpty)
              const Text('尚未添加音乐目录——点下方按钮手动选择',
                  style: TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.m),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : add,
                child: Text(_busy ? '扫描中…' : '＋ 添加音乐目录',
                    style: const TextStyle(fontSize: 13, color: IaColors.textHi)),
              ),
            ),
            if (scan.scanning) ...[
              const SizedBox(height: IaSpacing.m),
              Text(scan.total > 0
                  ? '扫描中 ${scan.done}/${scan.total}'
                  : '扫描中…',
                  style: TextStyle(fontSize: 12, color: p.accent)),
              const SizedBox(height: IaSpacing.s),
              HairlineProgress(
                fraction: scan.total > 0 ? scan.done / scan.total : 0.0,
                color: p.accent,
              ),
            ],
            const SizedBox(height: IaSpacing.xl),
            const SectionLabel('曲库统计'),
            const SizedBox(height: IaSpacing.m),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.m, vertical: IaSpacing.l),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: IaColors.hairline))),
              child: Row(
                children: [
                  const Text('可用曲目',
                      style:
                          TextStyle(fontSize: IaType.list, color: IaColors.textHi)),
                  const Spacer(),
                  Text('$count 首',
                      style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
                ],
              ),
            ),
            const SizedBox(height: IaSpacing.s),
            Text(scan.lastSummary.isEmpty
                ? 'FTS 拼音索引就绪'
                : '上次扫描：${scan.lastSummary}',
                style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.m),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy || scan.scanning
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await ref.read(scanProvider.notifier).rescanAll();
                        } on Object catch (e) {
                          if (context.mounted) {
                            showWpToast(context,
                                title: '存储 · 重扫失败', message: '$e', isError: true);
                          }
                        }
                        if (!context.mounted) {
                          return;
                        }
                        setState(() => _busy = false);
                        final err = ref.read(scanProvider).lastError;
                        if (err != null) {
                          showWpToast(context,
                              title: '存储 · 扫描失败', message: err, isError: true);
                        } else {
                          showWpToast(context, title: '存储', message: '全量重扫完成');
                        }
                      },
                child: const Text('⟳ 全量重扫',
                    style: TextStyle(fontSize: 13, color: IaColors.textHi)),
              ),
            ),
            // ── 诊断（常驻）：任何来源的最近错误都钉在这里，可复制/清除 ──
            const _DiagnosticsBlock(),
          ],
        ),
      ),
    );
  }
}

/// 最近错误常驻区块（跨重启持久化）：完整文本 + 复制 + 清除。
class _DiagnosticsBlock extends ConsumerWidget {
  const _DiagnosticsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(diagnosticsProvider);
    if (entry == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: IaSpacing.xl),
      padding: const EdgeInsets.all(IaSpacing.m),
      decoration: BoxDecoration(
        border: Border.all(color: IaColors.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('诊断 · 最近一次错误',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: IaType.semibold,
                  letterSpacing: 1.2,
                  color: IaColors.error)),
          const SizedBox(height: IaSpacing.xs),
          Text(
              '${entry.at.month}-${entry.at.day} '
              '${entry.at.hour}:${entry.at.minute.toString().padLeft(2, '0')}'
              ' · ${entry.source}',
              style: const TextStyle(fontSize: 11, color: IaColors.textLow)),
          const SizedBox(height: IaSpacing.s),
          SelectableText(entry.detail,
              style: const TextStyle(
                  fontSize: 12, color: IaColors.textHi, height: 1.5)),
          const SizedBox(height: IaSpacing.m),
          Row(children: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: '${entry.source}: ${entry.detail}'));
                if (context.mounted) {
                  showWpToast(context, title: '诊断', message: '已复制到剪贴板');
                }
              },
              child: const Text('复制',
                  style: TextStyle(fontSize: 12.5, color: IaColors.textHi)),
            ),
            const SizedBox(width: IaSpacing.m),
            TextButton(
              onPressed: () => ref.read(diagnosticsProvider.notifier).clear(),
              child: const Text('清除',
                  style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
            ),
          ]),
          const SizedBox(height: IaSpacing.xs),
        ],
      ),
    );
  }
}
