/// 屏1 正在播放：在播磁贴；无会话 = 随缘大磁贴 + 最近添加长廊。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../added/added_page.dart';
import '../shared/cover.dart';
import '../shared/ui_kit.dart';

class PlayingPage extends ConsumerWidget {
  const PlayingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(playbackProvider);
    final cur = snap.current;
    final edge = edgeInsets(context);
    final p = Theme.of(context).extension<IaPalette>()!;

    return ListView(
      padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 140),
      children: [
        const SizedBox(height: IaSpacing.xl),
        const SectionLabel('I A  M U S I C'),
        const SizedBox(height: IaSpacing.s),
        Text('音乐',
            style: TextStyle(
                fontSize: IaType.hero,
                fontWeight: IaType.light,
                color: IaColors.textHi)),
        const SizedBox(height: IaSpacing.xl),
        if (cur != null) ...[
          const SectionLabel('正在播放'),
          const SizedBox(height: IaSpacing.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CoverArt(track: cur, size: 200),
              ),
              const SizedBox(width: IaSpacing.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cur.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: IaType.light,
                            color: IaColors.textHi)),
                    const SizedBox(height: IaSpacing.s),
                    Text(cur.artistDisplay,
                        style: const TextStyle(
                            fontSize: 13, color: IaColors.textMid)),
                    const SizedBox(height: IaSpacing.m),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              ref.read(playbackProvider.notifier).togglePlay(),
                          child: Text(
                              snap.playing ? '暂停' : '播放',
                              style: const TextStyle(
                                  fontSize: 13, color: IaColors.textHi)),
                        ),
                      ],
                    ),
                    const SizedBox(height: IaSpacing.m),
                    Stack(
                      children: [
                        Container(
                          height: IaSpacing.progressHairline,
                          color: IaColors.hairlineStrong,
                        ),
                        FractionallySizedBox(
                          widthFactor: (cur.durationMs > 0)
                              ? (snap.positionMs / cur.durationMs).clamp(0.0, 1.0)
                              : 0.0,
                          child: Container(
                            height: IaSpacing.progressHairline,
                            color: p.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ] else ...[
          const SectionLabel('听歌从这里开始'),
          const SizedBox(height: IaSpacing.m),
          InkWell(
            onTap: () => _listenRandom(context, ref),
            child: Container(
              padding: const EdgeInsets.all(IaSpacing.xl),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: IaColors.textLow, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('随缘听歌',
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: IaType.light,
                          color: IaColors.textHi)),
                  const SizedBox(height: IaSpacing.s),
                  const Text('全曲库随机 · 一点就开 ▶',
                      style: TextStyle(fontSize: 12, color: IaColors.textLow)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: IaSpacing.xl),
        const SectionLabel('音乐仓库 · 最近添加'),
        const SizedBox(height: IaSpacing.m),
        const _RecentStrip(),
      ],
    );
  }

  Future<void> _listenRandom(BuildContext context, WidgetRef ref) async {
    final lib = ref.read(listenLibraryProvider);
    final tracks = await lib.all();
    if (tracks.isEmpty) {
      if (context.mounted) {
        showWpToast(context, title: '随缘听歌', message: '曲库为空——先去收集音乐');
      }
      return;
    }
    await ref.read(playbackProvider.notifier).playTracks(tracks, shuffle: true);
    if (context.mounted) {
      showWpToast(context, title: '听法', message: '随缘听歌 · 全曲库随机');
    }
  }
}

/// 最近添加封面长廊（按 addedAt 倒序）。
class _RecentStrip extends ConsumerWidget {
  const _RecentStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tracksProvider(TrackSort.recentAdded)).value ??
        const <Track>[];
    final seen = <String>{};
    final albums = <Track>[];
    for (final t in tracks) {
      if (seen.add(t.albumDisplay)) {
        albums.add(t);
      }
      if (albums.length >= 8) {
        break;
      }
    }
    if (albums.isEmpty) {
      return const Text('30 首歌在库里等你',
          style: TextStyle(fontSize: 12, color: IaColors.textLow));
    }
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: albums.length,
        separatorBuilder: (_, _) => const SizedBox(width: IaSpacing.m),
        itemBuilder: (_, i) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(track: albums[i], size: 132),
            const SizedBox(height: IaSpacing.s),
            SizedBox(
              width: 132,
              child: Text(albums[i].albumDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: IaColors.textMid)),
            ),
          ],
        ),
      ),
    );
  }
}
