/// 存储子页：音乐目录交互式管理（添加/移除/重扫）+ 曲库统计 + 索引状态。
///
/// 唯一入口 = 设置页直达；风格与 Hub 页同基线（PageHeader 固定页头，
/// 无返回钮——返回走系统手势）。诊断/日志展示统一收敛到「关于」页。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/diagnostics.dart';
import '../../state/library_providers.dart';
import '../../state/scan_controller.dart';
import '../components/kit/scan_ring.dart';
import '../components/kit/tri_state_bar.dart';
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
      body: HubPage(
        header: const PageHeader(
          kicker: '应用',
          title: '存储',
          subtitle: '音乐目录 · 曲库统计 · 扫描',
        ),
        children: [
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
                  decoration: BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: IaColors.hairline))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(r.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: IaType.list, color: IaColors.textHi)),
                      ),
                      Text('音乐目录',
                          style:
                              TextStyle(fontSize: 13.5, color: IaColors.textLow)),
                    ],
                  ),
                ),
              ),
            ),
          if (roots.isEmpty)
            Text('尚未添加音乐目录——点下方按钮手动选择',
                style: TextStyle(fontSize: 13.5, color: IaColors.textLow)),
          const SizedBox(height: IaSpacing.m),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy ? null : add,
              child: Text(_busy ? '扫描中…' : '＋ 添加音乐目录',
                  style: TextStyle(fontSize: 14.5, color: IaColors.textHi)),
            ),
          ),
          if (scan.scanning) ...[
            const SizedBox(height: IaSpacing.m),
            Text(scan.total > 0
                ? '扫描中 ${scan.done}/${scan.total}'
                : '扫描中…',
                style: TextStyle(fontSize: 13.5, color: p.accent)),
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
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: IaColors.hairline))),
            child: Row(
              children: [
                Text('可用曲目',
                    style:
                        TextStyle(fontSize: IaType.list, color: IaColors.textHi)),
                const Spacer(),
                Text('$count 首',
                    style: TextStyle(fontSize: 13.5, color: IaColors.textLow)),
              ],
            ),
          ),
          const SizedBox(height: IaSpacing.l),
          // ── 扫描环形图：上次扫描四段（新入库/更新/缺失/复活）+ 扫描中实时进度 ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ScanRing(
                ins: scan.lastIns,
                upd: scan.lastUpd,
                miss: scan.lastMiss,
                rev: scan.lastRev,
                scanning: scan.scanning,
                done: scan.done,
                total: scan.total,
                accent: p.accent,
              ),
              const SizedBox(width: IaSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, (color, label)) in scanSegments(p.accent).indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, color: color),
                            const SizedBox(width: IaSpacing.s),
                            Text(label,
                                style: TextStyle(
                                    fontSize: 13.5, color: IaColors.textMid)),
                            const Spacer(),
                            Text('${scanCounts(scan)[i]}',
                                style: TextStyle(
                                    fontSize: 13.5, color: IaColors.textHi)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
              child: Text('⟳ 全量重扫',
                  style: TextStyle(fontSize: 14.5, color: IaColors.textHi)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 环形图四段计数（与 scanSegments 颜色序一一对应）。
List<int> scanCounts(ScanState scan) =>
    [scan.lastIns, scan.lastUpd, scan.lastMiss, scan.lastRev];
