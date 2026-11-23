/// 提取与补全进度子页：补全三态进度置顶 + 提取聚合进度（点入任务详情）。
/// 唯一入口 = 设置页直达。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/collect_providers.dart';
import '../../state/enrich_controller.dart';
import '../shared/sub_header.dart';
import '../shared/tri_state_bar.dart';
import '../shared/ui_kit.dart';
import 'extract_tasks_page.dart';

/// 提取与补全进度子页：补全三态进度置顶 + 提取聚合进度（点入任务详情）。
/// 唯一入口 = 设置页直达。
class ExtractPage extends ConsumerWidget {
  const ExtractPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(collectTasksProvider).value ?? const [];
    final edge = edgeInsets(context);
    final p = Theme.of(context).extension<IaPalette>()!;
    final done = tasks.where((t) => t.status == CollectStatusCol.done).length;
    final failed =
        tasks.where((t) => t.status == CollectStatusCol.failed).length;

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const SubHeader(title: '提取与补全进度'),
            const SizedBox(height: IaSpacing.s),
            // ── 补全进度区块（置顶）：歌名/歌手/歌词 三条独立阶段进度（持久化） ──
            const SectionLabel('补全进度（元数据三阶段）'),
            const SizedBox(height: IaSpacing.s),
            const Text(
                '缺失歌名 / 歌手的曲目自动入队，逐条给出三阶段结论；进度已落库，中断重启不从头。'
                '绿从左进=成功 · 红从右进=失败 · 中灰=待处理',
                style: TextStyle(fontSize: 12, color: IaColors.textLow)),
            const SizedBox(height: IaSpacing.m),
            const _EnrichSection(),
            const SizedBox(height: IaSpacing.l),
            // ── 提取进度：聚合三态条（绿=完成 红=失败 灰=进行中/等待），点入详情 ──
            const SectionLabel('提取进度'),
            const SizedBox(height: IaSpacing.s),
            if (tasks.isEmpty)
              const Text('当前没有进行中的任务——提取与补全都在后台自动运行',
                  style: TextStyle(fontSize: 12.5, color: IaColors.textLow))
            else
              InkWell(
                onTap: () => Navigator.of(context).push(
                    zuneRoute<void>(builder: (_) => const ExtractTasksPage())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: IaSpacing.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                                '${tasks.length} 项任务 · 完成 $done · 失败 $failed · '
                                '进行中/等待 ${tasks.length - done - failed}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: IaType.list,
                                    color: IaColors.textHi)),
                          ),
                          Text('详情 ›',
                              style:
                                  TextStyle(fontSize: 12, color: p.accent)),
                        ],
                      ),
                      const SizedBox(height: IaSpacing.s),
                      TriStateBar(
                        successFraction: done / tasks.length,
                        failedFraction: failed / tasks.length,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: IaSpacing.l),
          ],
        ),
      ),
    );
  }
}

/// 补全进度区块：三条独立阶段进度条（歌名/歌手/歌词）+ 当前曲目 +
/// 手动「开始补全」（清零失败计数重试）。进度数据 = tracks 行直读（持久化）。
class _EnrichSection extends ConsumerWidget {
  const _EnrichSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(enrichProvider);
    final stages = ref.watch(enrichStagesProvider).value ?? const <EnrichStage>[];
    final p = Theme.of(context).extension<IaPalette>()!;

    Widget stageRow(EnrichStage s) {
      // 三态条：底灰=待处理；成功绿从左往右；失败红从右往左。
      const okGreen = Color(0xFF60A917);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: IaSpacing.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.label,
                      style: const TextStyle(
                          fontSize: IaType.list, color: IaColors.textHi)),
                ),
                Text('成 ${s.done} · 败 ${s.failed} · 待 ${s.pending}',
                    style: TextStyle(
                        fontSize: 12,
                        color: s.total > 0 && s.pending == 0 && s.failed == 0
                            ? okGreen
                            : IaColors.textLow)),
              ],
            ),
            const SizedBox(height: IaSpacing.s),
            TriStateBar(
                successFraction: s.successFraction,
                failedFraction: s.failedFraction),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                st.running
                    ? (st.currentTitle.isEmpty ? '补全中…' : '补全中 · ${st.currentTitle}')
                    : (st.lastSummary.isEmpty ? '队列空闲 · 扫描完成后自动运行' : st.lastSummary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: IaType.list, color: IaColors.textHi),
              ),
            ),
          ],
        ),
        const SizedBox(height: IaSpacing.m),
        if (stages.isEmpty)
          const Text('进度读取中…',
              style: TextStyle(fontSize: 12, color: IaColors.textLow)),
        for (final s in stages) stageRow(s),
        const SizedBox(height: IaSpacing.s),
        TextButton(
          onPressed: st.running
              ? null
              : () => ref.read(enrichProvider.notifier).runOnce(reset: true),
          child: Text(st.running ? '补全中…' : '开始补全（重试全部失败项）',
              style: TextStyle(
                  fontSize: 12.5,
                  color: st.running ? IaColors.textLow : p.accent)),
        ),
      ],
    );
  }
}
