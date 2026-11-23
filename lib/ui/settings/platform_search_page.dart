/// 音频源插件站内搜索页（A 层）：搜索 → 结果列表 → 加入提取队列。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/collect_providers.dart';
import '../shared/ui_kit.dart';

class PlatformSearchPage extends ConsumerStatefulWidget {
  const PlatformSearchPage({required this.pluginId, required this.name, super.key});

  final String pluginId;
  final String name;

  @override
  ConsumerState<PlatformSearchPage> createState() => _PlatformSearchPageState();
}

class _PlatformSearchPageState extends ConsumerState<PlatformSearchPage> {
  final _ctrl = TextEditingController();
  bool _searching = false;
  String? _error;
  List<Map<String, Object?>> _results = const [];

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final edge = edgeInsets(context);

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.m, edge.right, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      onSubmitted: (_) => _search(),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: IaType.light,
                          color: IaColors.textHi),
                      decoration: const InputDecoration(
                          hintText: '搜索后回车', border: InputBorder.none),
                    ),
                  ),
                  IconButton(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.search, color: p.accent),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.s, edge.right, 0),
              child: Text(
                '点结果加入提取队列：音频流下载 → 入曲库（凭据只在插件沙箱）',
                style: const TextStyle(fontSize: 12, color: IaColors.textLow),
              ),
            ),
            const SizedBox(height: IaSpacing.s),
            if (_error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: edge.left),
                child: Text(_error!,
                    style:
                        const TextStyle(fontSize: 12.5, color: IaColors.error)),
              ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 140),
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final r = _results[i];
                  final title = '${r['title'] ?? ''}';
                  final author = '${r['artist'] ?? ''}';
                  final dur = (r['durationSec'] as num?)?.toInt() ?? 0;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _enqueue(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: IaSpacing.m, vertical: IaSpacing.m),
                        decoration: const BoxDecoration(
                            border: Border(
                                bottom:
                                    BorderSide(color: IaColors.hairline))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: IaType.list,
                                          color: IaColors.textHi)),
                                  const SizedBox(height: IaSpacing.xs),
                                  Text('$author · ${_dur(dur)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: IaColors.textLow)),
                                ],
                              ),
                            ),
                            const SizedBox(width: IaSpacing.m),
                            Icon(Icons.download_for_offline_outlined,
                                size: 20, color: p.accent),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _results = const [];
    });
    try {
      final handles = await ref.read(sourceHandlesProvider.future);
      final handle = handles.where((h) => h.id == widget.pluginId).firstOrNull;
      if (handle == null) {
        if (mounted) {
          setState(() => _error = '插件未安装或未启用');
        }
        return;
      }
      final out = await handle.search(q);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = out;
        if (out.isEmpty) {
          _error = '没有结果';
        }
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  /// 加入提取队列（真实落库）→ 立即驱动执行器。
  Future<void> _enqueue(Map<String, Object?> r) async {
    final url = '${r['url'] ?? ''}';
    final title = '${r['title'] ?? ''}';
    if (url.isEmpty) {
      return;
    }
    await ref
        .read(collectTasksApiProvider)
        .enqueue(widget.pluginId, url,
            title: title, artist: '${r['artist'] ?? ''}');
    // 驱动执行器（后台跑，进度页可见）
    unawaited(ref.read(collectTasksApiProvider).drive());
    if (mounted) {
      showWpToast(context, title: '收集', message: '已加入提取队列：$title');
    }
  }

  static String _dur(int sec) =>
      '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
}
