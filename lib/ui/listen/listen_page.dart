/// 听法（负一屏）：随缘 / 喜欢电台 / 常听电台 / 最近添加 / 历史回放。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../shared/ui_kit.dart';

class ListenPage extends ConsumerWidget {
  const ListenPage({super.key});

  Future<void> _start(WidgetRef ref, BuildContext context,
      Future<List<dynamic>> Function() fetch, bool shuffle, String label) async {
    final tracks = (await fetch()).cast<dynamic>().toList();
    if (!context.mounted) {
      return;
    }
    if (tracks.isEmpty) {
      showWpToast(context, title: label, message: '曲库为空——先去收集音乐');
      return;
    }
    await ref.read(playbackProvider.notifier).playTracks(
          tracks.cast(),
          shuffle: shuffle,
        );
    if (context.mounted) {
      showWpToast(context, title: '听法', message: label);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edge = edgeInsets(context);
    final items = <(String, String, VoidCallback)>[
      (
        '随缘听歌',
        '全曲库随机，闭眼开播',
        () => _start(ref, context, () async => (await ref.read(listenLibraryProvider).all()), true,
            '随缘听歌 · 全曲库随机'),
      ),
      (
        '喜欢电台',
        '从红心歌出发随机',
        () => _start(ref, context, () => ref.read(listenLibraryProvider).favorites(), true,
            '喜欢电台'),
      ),
      (
        '常听电台',
        '播放次数 Top6 专辑并集',
        () => _start(ref, context, () => ref.read(listenLibraryProvider).top(), true,
            '常听电台'),
      ),
      (
        '最近添加',
        '新入库先听',
        () => _start(ref, context, () => ref.read(listenLibraryProvider).recent(), true,
            '最近添加电台'),
      ),
      (
        '历史回放',
        '去重后的播放序列，不打乱',
        () => _start(ref, context, () => ref.read(listenLibraryProvider).history(), false,
            '历史回放'),
      ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 140),
      children: [
        const SizedBox(height: IaSpacing.xl),
        const SectionLabel('听法'),
        const SizedBox(height: IaSpacing.m),
        Text('怎么听',
            style: TextStyle(
                fontSize: IaType.page,
                fontWeight: IaType.light,
                color: IaColors.textHi)),
        const SizedBox(height: IaSpacing.m),
        for (final (n, d, act) in items)
          BigRow(title: n, subtitle: d, onTap: act),
        const SizedBox(height: IaSpacing.xl),
        const Text(
          '负一屏 · 左滑回正在播放',
          style: TextStyle(fontSize: 11, color: IaColors.textLow),
        ),
      ],
    );
  }
}
