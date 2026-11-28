/// 提取任务详情：实时任务流逐条列出（状态 + 百分比 + 细进度条 + 行内
/// 开始/暂停/删除操作）+ 继续/重试/清理记录。由歌曲处理页的提取行点入。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/design_tokens.dart';
import '../../state/collect_providers.dart';
import '../components/kit/tri_state_bar.dart';
import '../layout/sub_header.dart';
import '../shared/ui_kit.dart';

String _statusLabel(CollectStatusCol status) => switch (status) {
      CollectStatusCol.pending => '等待',
      CollectStatusCol.running => '提取中',
      CollectStatusCol.done => '完成',
      CollectStatusCol.blocked => '待处理',
      CollectStatusCol.failed => '失败',
      CollectStatusCol.paused => '已暂停',
    };

/// 提取任务详情：实时任务流逐条列出（状态 + 百分比 + 细进度条 + 行内
/// 开始/暂停/删除操作）+ 继续/重试/清理记录。由歌曲处理页的提取行点入。
class ExtractTasksPage extends ConsumerWidget {
  const ExtractTasksPage({super.key});

  /// 行内操作钮（按状态）：WP 风格 12px 文字钮。
  List<Widget> _taskActions(
      BuildContext context, WidgetRef ref, CollectTaskRow t) {
    final api = ref.read(collectTasksApiProvider);
    final p = Theme.of(context).extension<IaPalette>()!;
    void del() => unawaited(api.deleteTask(t.id));
    final actions = switch (t.status) {
      CollectStatusCol.pending => [
          ('暂停', () => unawaited(api.pauseTask(t.id))),
          ('删除', del),
        ],
      CollectStatusCol.running => [
          ('暂停', () => unawaited(api.pauseTask(t.id))),
        ],
      CollectStatusCol.paused => [
          ('开始', () => unawaited(api.startTask(t.id))),
          ('删除', del),
        ],
      CollectStatusCol.failed => [
          ('重试', () => unawaited(api.startTask(t.id))),
          ('删除', del),
        ],
      CollectStatusCol.done => [('删除', del)],
      CollectStatusCol.blocked => [('删除', del)],
    };
    return [
      for (final (label, onTap) in actions)
        GestureDetector(
          onTap: onTap,
          child: Text(label, style: TextStyle(fontSize: 13.5, color: p.accent)),
        ),
    ];
  }

  /// 行内操作区（无操作返回空，不打间距）。
  List<Widget> _actionRow(BuildContext context, WidgetRef ref, CollectTaskRow t) {
    final buttons = _taskActions(context, ref, t);
    if (buttons.isEmpty) {
      return const [];
    }
    return [
      const SizedBox(height: IaSpacing.xs),
      Wrap(
        spacing: IaSpacing.l,
        runSpacing: IaSpacing.xs,
        children: buttons,
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(collectTasksProvider).value ?? const [];
    final edge = edgeInsets(context);
    final p = Theme.of(context).extension<IaPalette>()!;
    final failed =
        tasks.where((t) => t.status == CollectStatusCol.failed).length;
    final pending =
        tasks.where((t) => t.status == CollectStatusCol.pending).length;
    final finished = failed +
        tasks.where((t) => t.status == CollectStatusCol.done).length;

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: [
            const SubHeader(title: '提取详情'),
            const SizedBox(height: IaSpacing.s),
            Text('${tasks.length} 项任务 · 完成后自动入库',
                style: TextStyle(fontSize: 13.5, color: IaColors.textLow)),
            if (pending > 0 || failed > 0)
              Row(
                children: [
                  if (pending > 0)
                    TextButton(
                      onPressed: () =>
                          unawaited(ref.read(collectTasksApiProvider).drive()),
                      child: Text('继续 $pending',
                          style: TextStyle(fontSize: 13.5, color: p.accent)),
                    ),
                  if (failed > 0)
                    TextButton(
                      onPressed: () async {
                        final api = ref.read(collectTasksApiProvider);
                        final n = await api.retryFailed();
                        unawaited(api.drive());
                        if (context.mounted) {
                          showWpToast(context,
                              title: '提取', message: '已重试 $n 个失败任务');
                        }
                      },
                      child: Text('重试失败 $failed',
                          style: TextStyle(fontSize: 13.5, color: p.accent)),
                    ),
                  if (finished > 0)
                    TextButton(
                      onPressed: () async {
                        // 清理提取结果 = 只清任务记录行（音频/歌词文件不动）
                        final n = await ref
                            .read(collectTasksApiProvider)
                            .clearFinished();
                        if (context.mounted) {
                          showWpToast(context,
                              title: '提取', message: '已清理 $n 条任务记录');
                        }
                      },
                      child: Text('清理记录 $finished',
                          style: TextStyle(fontSize: 13.5, color: p.accent)),
                    ),
                ],
              ),
            const SizedBox(height: IaSpacing.l),
            if (tasks.isEmpty)
              Text('当前没有进行中的任务——歌曲处理都在后台自动运行',
                  style: TextStyle(fontSize: 14, color: IaColors.textLow)),
            for (final t in tasks) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: IaSpacing.m, vertical: IaSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(t.title.isEmpty ? t.url : t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: IaType.list,
                                  color: t.status == CollectStatusCol.failed
                                      ? IaColors.error
                                      : IaColors.textHi)),
                        ),
                        Text(
                            '${t.source} · ${_statusLabel(t.status)} · '
                            '${t.status == CollectStatusCol.done ? 100 : t.progress}%',
                            style: TextStyle(
                                fontSize: 13.5,
                                color: t.status == CollectStatusCol.failed
                                    ? IaColors.error
                                    : t.status == CollectStatusCol.done
                                        ? p.accent
                                        : IaColors.textLow)),
                      ],
                    ),
                    if (t.status == CollectStatusCol.failed &&
                        (t.errorText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: IaSpacing.xs),
                      // 失败原因原文（任务行 errorText，重试后清空）
                      Text(t.errorText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5, color: IaColors.error)),
                    ],
                    ..._actionRow(context, ref, t),
                    const SizedBox(height: IaSpacing.s),
                    HairlineProgress(
                      fraction: t.progress / 100,
                      color: t.status == CollectStatusCol.failed
                          ? IaColors.error
                          : p.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: IaSpacing.m),
            ],
            const SizedBox(height: IaSpacing.l),
          ],
        ),
      ),
    );
  }
}
