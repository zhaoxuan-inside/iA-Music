/// 多P/合集勾选弹层：提交时预览 resolve 出的子曲目清单按视频分组展示。
/// 纯 UI 组件（不依赖 riverpod/db）——勾选结果回传页面侧完成入队与 pin 构造。
library;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/collect_providers.dart';

/// URL query 里的 `p=N`（B站分P 页码）→ 预选该页；无参/越界 → 全选。
/// （用户粘贴 `?p=3` 的意图通常就是只要那一P。）
Set<int> defaultPickedPage(String url, int trackCount) {
  final m = RegExp(r'[?&]p=(\d+)').firstMatch(url);
  final n = m == null ? null : int.tryParse(m.group(1)!);
  if (n != null && n >= 1 && n <= trackCount) {
    return {n};
  }
  return {for (var i = 1; i <= trackCount; i++) i};
}

/// 弹出勾选弹层。确认 → 每个视频一组 (预览, 勾选的 1-based index 集)，
/// 未勾选任何分P 的视频不在结果里；关闭 → null。
Future<List<(SourcePreview, Set<int>)>?> showLinkExtractPicker(
    BuildContext context, List<SourcePreview> items) {
  return showModalBottomSheet<List<(SourcePreview, Set<int>)>>(
    context: context,
    backgroundColor: Colors.black,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    shape: const RoundedRectangleBorder(),
    isScrollControlled: true,
    builder: (_) => LinkExtractPickerSheet(items: items),
  );
}

/// WP 式勾选弹层：黑底 + accent 上缘 2px（同 showWpMenu 的容器语言），
/// 勾选框仿 WpSwitch 自绘（方角 hairline 边框方块，选中 accent 填充）。
class LinkExtractPickerSheet extends StatefulWidget {
  const LinkExtractPickerSheet({required this.items, super.key});

  final List<SourcePreview> items;

  @override
  State<LinkExtractPickerSheet> createState() => _LinkExtractPickerSheetState();
}

class _LinkExtractPickerSheetState extends State<LinkExtractPickerSheet> {
  /// 按 items 下标存各视频勾选的子曲目 index 集（1-based）。
  late final Map<int, Set<int>> _picked;

  @override
  void initState() {
    super.initState();
    _picked = {
      for (var i = 0; i < widget.items.length; i++)
        i: defaultPickedPage(
            widget.items[i].url, widget.items[i].tracks.length),
    };
  }

  int get _total => _picked.values.fold(0, (a, s) => a + s.length);

  void _toggleSection(int i) {
    final tracks = widget.items[i].tracks;
    final allPicked = _picked[i]!.length == tracks.length;
    setState(() {
      _picked[i] = allPicked
          ? <int>{}
          : {for (final t in tracks) t.index};
    });
  }

  void _toggleTrack(int i, int index) {
    setState(() {
      final s = _picked[i]!;
      if (!s.remove(index)) {
        s.add(index);
      }
    });
  }

  void _confirm() {
    final result = <(SourcePreview, Set<int>)>[
      for (var i = 0; i < widget.items.length; i++)
        if (_picked[i]!.isNotEmpty) (widget.items[i], Set<int>.of(_picked[i]!)),
    ];
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final screenH = MediaQuery.sizeOf(context).height;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.accent, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IaSpacing.xl,
              IaSpacing.l,
              IaSpacing.xl,
              IaSpacing.s,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '勾选要提取的分P',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: IaType.semibold,
                  letterSpacing: 1.2,
                  color: p.accent,
                ),
              ),
            ),
          ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenH * 0.55),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < widget.items.length; i++) ...[
                    _sectionHeader(i),
                    for (final t in widget.items[i].tracks)
                      _trackRow(i, t),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IaSpacing.xl, IaSpacing.s, IaSpacing.xl, IaSpacing.l,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _total == 0 ? null : _confirm,
                child: Text(_total == 0 ? '未选择任何分P' : '提取所选（$_total 个分P）',
                    style: const TextStyle(fontSize: 15.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 节头：视频标题 + UP主/分P数 + 右侧全选/全不选。
  Widget _sectionHeader(int i) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final v = widget.items[i];
    final allPicked = _picked[i]!.length == v.tracks.length;
    final sub = [
      if (v.artist.isNotEmpty) v.artist,
      '共 ${v.tracks.length} 个分P',
    ].join(' · ');
    return InkWell(
      onTap: () => _toggleSection(i),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: IaSpacing.xl, vertical: IaSpacing.m,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: IaColors.hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.title.isEmpty ? v.url : v.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15.5, color: IaColors.textHi)),
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12.5, color: IaColors.textLow)),
                ],
              ),
            ),
            const SizedBox(width: IaSpacing.m),
            Text(allPicked ? '全不选' : '全选',
                style: TextStyle(
                    fontSize: 13.5,
                    letterSpacing: 1,
                    color: allPicked ? IaColors.textLow : p.accent)),
          ],
        ),
      ),
    );
  }

  /// 分P 行：序号 + 标题 + 右侧方角勾选框。
  Widget _trackRow(int i, SourcePreviewTrack t) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final checked = _picked[i]!.contains(t.index);
    return InkWell(
      onTap: () => _toggleTrack(i, t.index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: IaSpacing.xl, vertical: IaSpacing.m,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: IaColors.hairline)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text('${t.index}',
                  style: TextStyle(
                      fontSize: 13.5, color: IaColors.textLow)),
            ),
            Expanded(
              child: Text(t.title.isEmpty ? '分P ${t.index}' : t.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14.5, color: IaColors.textHi)),
            ),
            const SizedBox(width: IaSpacing.m),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: checked ? p.accent : Colors.transparent,
                border: Border.all(
                    color: checked ? p.accent : IaColors.hairlineStrong),
              ),
              child: checked
                  ? Icon(Icons.check,
                      size: 14, color: IaColors.onAccent)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
