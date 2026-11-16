/// 常听与历史屏（Hub 屏5）：常听专辑网格（按播放次数）+ 最近播放网格。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/quickplay.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/quickplay_providers.dart';
import '../detail/detail_page.dart';
import '../shared/cover.dart';
import '../shared/search_action.dart';
import '../shared/ui_kit.dart';

class PlayedPage extends ConsumerWidget {
  const PlayedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topAlbumsProvider).value ?? const <AlbumGroup>[];
    final recent = ref.watch(recentPlayedAlbumsProvider);
    final pad = hubPadding(context);

    return ListView(
      padding: pad,
      children: [
        const SizedBox(height: IaSpacing.xl),
        const PageHeader(
          kicker: '回访率最高',
          title: '常听与历史',
          subtitle: '按播放次数排序 · 点封面进入专辑',
          trailing: SearchAction(),
        ),
        const SizedBox(height: IaSpacing.xl),
        SectionHead(label: '常听', meta: '${top.length} 张专辑'),
        const SizedBox(height: IaSpacing.m),
        if (top.isEmpty)
          const Text('还没有播放记录——先听几首',
              style: TextStyle(fontSize: 12, color: IaColors.textLow))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
                childAspectRatio: 0.76),
            itemCount: top.length,
            itemBuilder: (_, i) {
              final a = top[i];
              return InkWell(
                onTap: () => Navigator.of(context).push(zuneRoute<void>(
                    builder: (_) =>
                        DetailPage(type: DetailType.album, id: albumKey(a.album)))),
                onLongPress: () => _albumMenu(context, ref, a),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: _TopCover(albumNorm: albumKey(a.album)),
                    ),
                    const SizedBox(height: IaSpacing.s),
                    Text(a.album,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: IaColors.textHi)),
                    Text(a.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: IaColors.textLow)),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: IaSpacing.xxl),
        SectionHead(label: '最近播放 · History', meta: '${recent.length} 张专辑'),
        const SizedBox(height: IaSpacing.m),
        if (recent.isEmpty)
          const Text('还没有播放记录',
              style: TextStyle(fontSize: 12, color: IaColors.textLow))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
                childAspectRatio: 0.76),
            itemCount: recent.length,
            itemBuilder: (_, i) => InkWell(
              onTap: () => Navigator.of(context).push(zuneRoute<void>(
                  builder: (_) => DetailPage(
                      type: DetailType.album,
                      id: albumKey(recent[i].album)))),
              onLongPress: () => _albumMenu(context, ref, recent[i]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _TopCover(albumNorm: albumKey(recent[i].album)),
                  ),
                  const SizedBox(height: IaSpacing.s),
                  Text(recent[i].album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: IaColors.textHi)),
                  Text(recent[i].artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: IaColors.textLow)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _albumMenu(BuildContext context, WidgetRef ref, AlbumGroup a) {
    final pin = QuickplayPin(
      kind: QuickplayKind.album,
      key: albumKey(a.album),
      title: a.album,
      subtitle: a.artist,
    );
    final pinned =
        ref.read(quickplayProvider).isPinned(QuickplayKind.album, pin.key);
    showWpMenu(context, title: a.album, items: [
      (
        pinned ? '解除快速播放固定' : '固定到快速播放',
        () async {
          await ref.read(quickplayProvider.notifier).toggle(pin);
        },
      ),
      (
        '打开专辑',
        () => Navigator.of(context).push(zuneRoute<void>(
            builder: (_) =>
                DetailPage(type: DetailType.album, id: albumKey(a.album)))),
      ),
    ]);
  }
}

class _TopCover extends ConsumerWidget {
  const _TopCover({required this.albumNorm});

  final String albumNorm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(albumTracksProvider(albumNorm)).value ?? const <Track>[];
    final first = tracks.firstOrNull;
    if (first == null) {
      return Container(color: IaColors.hairline);
    }
    return CoverArt(track: first, size: double.infinity);
  }
}
