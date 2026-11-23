/// 独立的「从链接提取」页：搜索页直达，粘贴链接入提取队列
/// （进度统一在「设置 · 提取与补全进度」查看）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/collect_providers.dart';
import '../shared/sub_header.dart';
import '../shared/ui_kit.dart';

/// 独立的「从链接提取」页：搜索页直达，粘贴链接入提取队列
/// （进度统一在「设置 · 提取与补全进度」查看）。
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
            style: const TextStyle(fontSize: 13, color: IaColors.textHi),
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
                style: const TextStyle(fontSize: 14)),
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
    var added = 0;
    var rejected = 0;
    try {
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
        // 标题/歌手留空——提取引擎运行时用插件协议补全真实元数据
        await api.enqueue(source, url);
        added++;
      }
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
    if (added > 0) {
      _ctrl.clear();
    }
    showWpToast(context,
        title: '提取',
        message: added > 0
            ? '$added 个链接进入提取队列${rejected > 0 ? ' · $rejected 个无法识别' : ''}'
            : '没有可识别的链接');
  }
}
