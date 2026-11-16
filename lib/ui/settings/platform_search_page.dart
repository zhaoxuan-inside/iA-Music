/// 平台站内搜索页（A 层）：搜索 → 结果列表 → 加入提取队列（真实协议）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../services/collect/bilibili_client.dart';
import '../../services/collect/platform_store.dart';
import '../../services/collect/youtube_client.dart';
import '../../state/collect_providers.dart';
import '../shared/ui_kit.dart';

class PlatformSearchPage extends ConsumerStatefulWidget {
  const PlatformSearchPage({required this.platform, super.key});

  final PlatformId platform;

  @override
  ConsumerState<PlatformSearchPage> createState() =>
      _PlatformSearchPageState();
}

class _PlatformSearchPageState extends ConsumerState<PlatformSearchPage> {
  final _ctrl = TextEditingController();
  bool _searching = false;
  String? _error;
  List<Object> _results = const [];

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final edge = edgeInsets(context);
    final name = widget.platform == PlatformId.bilibili ? 'B 站' : 'YouTube';

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
                      decoration: InputDecoration(
                        hintText: '$name 站内搜索…',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _searching ? null : _search,
                    child: Text(_searching ? '…' : '搜索',
                        style: TextStyle(fontSize: 13, color: p.accent)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: IaSpacing.m),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: edge.left),
              child: Text(
                  widget.platform == PlatformId.bilibili
                      ? '点结果加入提取队列：音频流下载 → 字幕转歌词 → 入曲库'
                      : '点结果加入提取队列：音频流下载 → 入曲库',
                  style:
                      const TextStyle(fontSize: 12, color: IaColors.textLow)),
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
                  final (title, author, dur, extra) = switch (r) {
                    BiliSearchItem b => (b.title, b.author, b.durationSec,
                        'BV${b.bvid.substring(2)}'),
                    YtSearchItem y => (y.title, y.author, y.durationSec,
                        y.album ?? 'YouTube'),
                    _ => ('', '', 0, ''),
                  };
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
                                  Text('$author · $extra · ${_dur(dur)}',
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
      final out = <Object>[
        ...switch (widget.platform) {
          PlatformId.bilibili =>
            await ref.read(bilibiliClientProvider).search(q),
          PlatformId.youtube =>
            await ref.read(youtubeClientProvider).search(q),
        }
      ];
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
  Future<void> _enqueue(Object r) async {
    final (source, url, title, artist) = switch (r) {
      BiliSearchItem b => (
          'bilibili',
          'https://www.bilibili.com/video/${b.bvid}',
          b.title,
          b.author,
        ),
      YtSearchItem y => (
          'youtube',
          'https://www.youtube.com/watch?v=${y.videoId}',
          y.title,
          y.author,
        ),
      _ => ('', '', '', ''),
    };
    if (source.isEmpty) {
      return;
    }
    await ref
        .read(collectTasksApiProvider)
        .enqueue(source, url, title: title, artist: artist);
    // 驱动执行器（后台跑，进度页可见）
    unawaited(ref.read(collectTasksApiProvider).drive());
    if (mounted) {
      showWpToast(context, title: '收集', message: '已加入提取队列：$title');
    }
  }

  static String _dur(int sec) =>
      '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
}
