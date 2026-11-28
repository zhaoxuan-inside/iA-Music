/// 独立的「从链接提取」页：搜索页直达，粘贴链接入提取队列
/// （进度统一在「设置 · 歌曲处理」查看）。
///
/// 多子曲目来源（B站多P/合集）提交时先预览 resolve 弹出勾选层，
/// 只入队勾选的分P；单P/失败/超量批量回退直接入队（运行时行为不变）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/collect_providers.dart';
import '../layout/sub_header.dart';
import '../shared/ui_kit.dart';
import 'link_extract_picker.dart';

/// 超过这个行数的插件链接批量跳过预览勾选——百行批量粘贴不因逐条
/// resolve 卡住提交，勾选属于少链接的精细操作（超量走全量拆分现状）。
const kPreviewBatchLimit = 10;

/// 独立的「从链接提取」页：搜索页直达，粘贴链接入提取队列
/// （进度统一在「设置 · 歌曲处理」查看）。
class LinkExtractPage extends ConsumerWidget {
  const LinkExtractPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edge = edgeInsets(context);
    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 40),
          children: const [
            SubHeader(title: '从链接提取'),
            SizedBox(height: IaSpacing.xl),
            _LinkExtractForm(),
          ],
        ),
      ),
    );
  }
}

/// 从链接提取表单：链接逐条解析 → 任务落库 → 驱动执行器。
class _LinkExtractForm extends ConsumerStatefulWidget {
  const _LinkExtractForm();

  @override
  ConsumerState<_LinkExtractForm> createState() => _LinkExtractFormState();
}

class _LinkExtractFormState extends ConsumerState<_LinkExtractForm> {
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: IaSpacing.m, vertical: IaSpacing.s),
          decoration:
              BoxDecoration(border: Border.all(color: IaColors.hairlineStrong)),
          child: TextField(
            controller: _ctrl,
            maxLines: 3,
            style: TextStyle(fontSize: 14.5, color: IaColors.textHi),
            decoration: const InputDecoration(
              hintText: '粘贴任意音频源插件支持的链接…（多行批量）',
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: IaSpacing.s),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? '解析中…' : '提取',
                style: const TextStyle(fontSize: 15.5)),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      if (mounted) {
        showWpToast(context, title: '提取', message: '先粘贴链接');
      }
      return;
    }
    setState(() => _submitting = true);
    final api = ref.read(collectTasksApiProvider);
    var pinnedAdded = 0;
    var plainAdded = 0;
    var rejected = 0;
    try {
      // ① 路由：逐行识别来源（不可识别计数，行为同从前）
      final candidates = <(String, String)>[]; // (source, url)
      for (final line in raw.split(RegExp(r'[\s]+'))) {
        final url = line.trim();
        if (url.isEmpty) {
          continue;
        }
        final source = await api.routeSource(url);
        if (source == null) {
          rejected++;
          continue;
        }
        candidates.add((source, url));
      }
      // ② 预览：resolve 出多子曲目（B站多P/合集）的进勾选层，其余直接入队。
      //    4 条一并发；预览自身任何失败 → null → 回退直接入队。
      final multi = <SourcePreview>[];
      final plain = <(String, String)>[];
      if (candidates.length <= kPreviewBatchLimit) {
        for (var i = 0; i < candidates.length; i += 4) {
          final end =
              i + 4 <= candidates.length ? i + 4 : candidates.length;
          final chunk = candidates.sublist(i, end);
          final previews = <Future<SourcePreview?>>[
            for (final (_, url) in chunk)
              _previewSafe(api, url),
          ];
          for (var j = 0; j < chunk.length; j++) {
            final pv = await previews[j];
            if (pv != null) {
              multi.add(pv);
            } else {
              plain.add(chunk[j]);
            }
          }
        }
      } else {
        plain.addAll(candidates);
      }
      // ③ 勾选层：只对多子曲目来源弹；关闭弹层 = 放弃该批勾选（其余照常）
      var picked = const <(SourcePreview, Set<int>)>[];
      if (multi.isNotEmpty && mounted) {
        picked =
            await showLinkExtractPicker(context, multi) ?? const [];
      }
      // ④ 入队：勾选分P 定点 pin（跳过运行时全量拆分），其余原样。
      //    标题/歌手留空由运行时补全——勾选件已随入队预填真实曲名。
      for (final (pv, idxs) in picked) {
        for (final t in pv.tracks) {
          if (!idxs.contains(t.index)) {
            continue;
          }
          await api.enqueuePinned(pv, t);
          pinnedAdded++;
        }
      }
      for (final (source, url) in plain) {
        await api.enqueue(source, url);
        plainAdded++;
      }
      final added = pinnedAdded + plainAdded;
      if (added > 0) {
        // 合集可能有上百个任务：只入队，下载在后台跑，避免提交按钮卡死。
        // 重复链接虽不重复入队，也要驱动一轮——僵尸 running 任务由此获得回收。
        unawaited(api.drive());
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
    if (!mounted) {
      return;
    }
    final added = pinnedAdded + plainAdded;
    if (added > 0) {
      _ctrl.clear();
    }
    showWpToast(context, title: '提取', message: _resultText(
      added: added,
      pinnedAdded: pinnedAdded,
      plainAdded: plainAdded,
      rejected: rejected,
    ));
  }

  /// 预览兜底：previewTracks 已自吞业务失败，这里再兜住路由/句柄层的野错误。
  Future<SourcePreview?> _previewSafe(CollectTasksApi api, String url) async {
    try {
      return await api.previewTracks(url);
    } on Object {
      return null;
    }
  }

  String _resultText({
    required int added,
    required int pinnedAdded,
    required int plainAdded,
    required int rejected,
  }) {
    if (added == 0) {
      return rejected > 0 ? '没有可识别的链接' : '未选择任何分P';
    }
    final main = [
      if (pinnedAdded > 0) '勾选 $pinnedAdded 个分P',
      if (plainAdded > 0) '$plainAdded 个链接',
    ].join(' · ');
    return rejected > 0
        ? '$main进入提取队列 · $rejected 个无法识别'
        : '$main进入提取队列';
  }
}
