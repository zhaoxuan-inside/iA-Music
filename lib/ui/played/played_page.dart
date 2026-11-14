/// 常听与历史屏（Hub 屏5）：常听专辑网格（按播放次数）+ 最近播放网格。
library;

import 'package:flutter/material.dart';
import '../../state/library_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/listen_providers.dart';
import '../detail/detail_page.dart';
import '../shared/cover.dart';
import '../shared/ui_kit.dart';

class PlayedPage extends ConsumerWidget {
  const PlayedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topAlbumsProvider).value ?? const <AlbumGroup>[];
    final recent = ref.watch(recentPlayedTracksProvider);
    final edge = edgeInsets(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 140),
      children: [
        const SectionLabel('回访率最高'),
        const SizedBox(height: IaSpacing.s),
        Text('常听',
            style: TextStyle(
                fontSize: IaType.page,
                fontWeight: IaType.light,
                color: IaColors.textHi)),
        const SizedBox(height: IaSpacing.s),
        Text('按播放次数 · ${top.length} 张专辑',
            style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
        const SizedBox(height: IaSpacing.l),
        if (top.isEmpty)
          const Text('还没有播放记录——先听几首',
              style: TextStyle(fontSize: 12, color: IaColors.textLow))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 18),
            itemCount: top.length,
            itemBuilder: (_, i) {
              final a = top[i];
              return InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        DetailPage(type: DetailType.album, id: albumKey(a.album)))),
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
        const SizedBox(height: IaSpacing.xl),
        const SectionLabel('最近播放'),
        const SizedBox(height: IaSpacing.s),
        Text('${recent.length} 首',
            style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
        const SizedBox(height: IaSpacing.l),
        if (recent.isEmpty)
          const Text('还没有播放记录',
              style: TextStyle(fontSize: 12, color: IaColors.textLow))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 18),
            itemCount: recent.length,
            itemBuilder: (_, i) => InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => DetailPage(
                      type: DetailType.album, id: albumKey(recent[i].album)))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: CoverArt(track: recent[i], size: double.infinity),
                  ),
                  const SizedBox(height: IaSpacing.s),
                  Text(recent[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: IaColors.textHi)),
                  Text(recent[i].artistDisplay,
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
