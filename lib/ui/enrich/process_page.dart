/// 歌曲处理子页：提取 / 歌名 / 歌词 / 封面 / 歌手 / 专辑 / 音轨 / 向量
/// 八行三态进度置顶，失败倒序列表收尾（点一条复制其失败日志原文）。
///
/// 唯一入口 = 设置页直达；风格与 Hub 页同基线（PageHeader 固定页头，
/// 无返回钮——返回走系统手势）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/collect_providers.dart';
import '../../state/enrich_controller.dart';
import '../../state/process_failures.dart';
import '../components/kit/tri_state_bar.dart';
import '../routing/app_routes.dart' show openExtractTasks;
import '../shared/ui_kit.dart';

class ProcessPage extends ConsumerWidget {
  const ProcessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(collectTasksProvider).value ?? const [];
    final stages =
        ref.watch(enrichStagesProvider).value ?? const <EnrichStage>[];
    final enrich = ref.watch(enrichProvider);
    final failures = ref.watch(processFailuresProvider);
    final done = tasks.where((t) => t.status == CollectStatusCol.done).length;
    final failed =
        tasks.where((t) => t.status == CollectStatusCol.failed).length;

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: HubPage(
        header: const PageHeader(
          kicker: '后台任务',
          title: '歌曲处理',
          subtitle: '提取 · 歌名 · 歌词 · 封面 · 歌手 · 专辑 · 音轨 · 向量',
        ),
        children: [
          // ── 提取：点入任务详情（继续/重试/清理/逐任务操作都在详情页） ──
          _ProcessRow(
            label: '提取',
            current: [
              for (final t in tasks)
                if (t.status == CollectStatusCol.running) t.title,
            ].firstOrNull ?? '',
            done: done,
            failed: failed,
            total: tasks.length,
            onTap: tasks.isEmpty ? null : () => openExtractTasks(context),
            trailing: tasks.isEmpty ? null : '详情 ›',
          ),
          // ── 歌名/歌词/封面/歌手/专辑/音轨/向量：补全管道七阶段（持久化于 tracks 行） ──
          // 当前曲 = 补全循环正在处理的曲（封面/向量无逐曲文案，不挂当前曲）
          for (final s in stages)
            _ProcessRow(
              label: s.label,
              current: s.label == '封面' ? '' : enrich.currentTitle,
              done: s.done,
              failed: s.failed,
              total: s.total,
              missed: s.missed,
              // 歌词/专辑/音轨行成功口径=有值：「确认无」单列灰档，不虚计入成功
              doneLabel: switch (s.label) {
                '歌词' => '有词',
                '专辑' => '有专辑',
                '音轨' => '有音轨',
                _ => null,
              },
            ),
          TextButton(
            onPressed: enrich.running
                ? null
                : () => ref.read(enrichProvider.notifier).runOnce(reset: true),
            child: Text(enrich.running ? '运行中…' : '重试全部失败项',
                style: TextStyle(
                    fontSize: 14,
                    color:
                        enrich.running ? IaColors.textLow : null)),
          ),
          // ── 失败倒序列表：类型 + 歌名，点击复制失败日志原文 ──
          for (final f in failures)
            InkWell(
              onTap: () => _copyFailure(context, f),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: IaSpacing.s),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                        fontSize: 14, color: IaColors.textMid),
                    children: [
                      TextSpan(text: f.kind),
                      TextSpan(
                          text: ' · ', style: TextStyle(color: IaColors.textLow)),
                      TextSpan(
                          text: f.title,
                          style: TextStyle(color: IaColors.error)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 复制失败日志（原文入剪贴板 + WP toast 反馈）。
  void _copyFailure(BuildContext context, ProcessFailure f) {
    final log = f.detail.isEmpty ? '（无日志原文）' : f.detail;
    unawaited(Clipboard.setData(
        ClipboardData(text: '${f.kind} · ${f.title}\n$log')));
    showWpToast(context,
        title: '已复制', message: '${f.kind} · ${f.title} 的失败日志');
  }
}

/// 处理进度行：『标签： 当前曲（≤7 字符…截断）』+ 成功/失败/等待计数 +
/// 三态进度条。总盘为空 = 全绿（无事可做，与阶段实体口径一致）。
class _ProcessRow extends StatelessWidget {
  const _ProcessRow({
    required this.label,
    required this.done,
    required this.failed,
    required this.total,
    this.missed = 0,
    this.doneLabel,
    this.current = '',
    this.onTap,
    this.trailing,
  });

  final String label;

  /// 当前正在处理的歌名（空 = 该项没有逐曲管道，只显标签）。
  final String current;
  final int done;
  final int failed;
  final int total;

  /// 已结论但无产出条数（歌词行「确认无词」，灰档非失败；0 = 不显示）。
  final int missed;

  /// 成功档文案（默认「成功」；歌词行=「有词」——有词才算成功）。
  final String? doneLabel;
  final VoidCallback? onTap;

  /// 行尾弱提示（如提取行的「详情 ›」）。
  final String? trailing;

  /// 歌名最多 7 个字符，超出以 ... 代替。
  static String _trunc(String t) =>
      t.length <= 7 ? t : '${t.substring(0, 7)}...';

  @override
  Widget build(BuildContext context) {
    const okGreen = Color(0xFF60A917);
    final pending = (total - done - failed - missed).clamp(0, total);
    // 有「无词」档在就不算全绿——绿灯应只意味着全部拿到词/有产出
    final allGreen = total > 0 && pending == 0 && failed == 0 && missed == 0;
    final successFraction = total <= 0 ? 1.0 : (done / total).clamp(0.0, 1.0);
    final failedFraction = total <= 0 ? 0.0 : (failed / total).clamp(0.0, 1.0);
    final countColor = allGreen ? okGreen : IaColors.textLow;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: IaSpacing.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    current.isEmpty ? label : '$label： ${_trunc(current)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: IaType.list, color: IaColors.textHi),
                  ),
                ),
                if (trailing != null) ...[
                  Text(trailing!,
                      style: TextStyle(
                          fontSize: 13.5,
                          color:
                              Theme.of(context).extension<IaPalette>()!.accent)),
                  const SizedBox(width: IaSpacing.m),
                ],
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 13.5, color: countColor),
                    children: [
                      TextSpan(text: '${doneLabel ?? '成功'} '),
                      TextSpan(text: '$done'),
                      if (missed > 0) ...[
                        const TextSpan(text: '  无词 '),
                        TextSpan(text: '$missed'),
                      ],
                      TextSpan(
                          text: '  失败 $failed',
                          style: failed > 0 && !allGreen
                              ? TextStyle(color: IaColors.error)
                              : null),
                      TextSpan(text: '  等待 $pending'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: IaSpacing.s),
            TriStateBar(
                successFraction: successFraction,
                failedFraction: failedFraction),
          ],
        ),
      ),
    );
  }
}
