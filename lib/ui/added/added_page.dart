/// 最近添加屏（Hub 屏4）：计数行 + 两列专辑网格（按 addedAt 倒序）。
library;

import 'package:flutter/material.dart';
import '../../state/library_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../detail/detail_page.dart';
import '../shared/cover.dart';
import '../shared/ui_kit.dart';

class AddedPage extends ConsumerWidget {
  const AddedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(recentAddedAlbumsProvider).value ?? const <AlbumGroup>[];
    final trackCount = ref.watch(trackCountProvider).value ?? 0;
    final edge = edgeInsets(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 140),
      children: [
        const SectionLabel('库里的新鲜事'),
        const SizedBox(height: IaSpacing.s),
        Text('最近添加',
            style: TextStyle(
                fontSize: IaType.page,
                fontWeight: IaType.light,
                color: IaColors.textHi)),
        const SizedBox(height: IaSpacing.s),
        Text('$trackCount 首 · ${albums.length} 张专辑',
            style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
        const SizedBox(height: IaSpacing.l),
        if (albums.isEmpty)
          const EmptyState(title: '还没有音乐', subtitle: '在「设置 · 收集」扫描音乐目录后出现在这里')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 18),
            itemCount: albums.length,
            itemBuilder: (_, i) {
              final a = albums[i];
              return InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        DetailPage(type: DetailType.album, id: albumKey(a.album)))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: _FirstCover(albumNorm: albumKey(a.album)),
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
      ],
    );
  }
}

/// 网格封面：取该专辑首曲封面。
class _FirstCover extends ConsumerWidget {
  const _FirstCover({required this.albumNorm});

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

/// 专辑曲目数（网格副题用）。
int albumTrackCount(Iterable<Track> tracks, String albumNorm) =>
    tracks.where((t) => albumKey(t.album) == albumNorm).length;

/// 播放直通（供未来磁贴长按菜单复用）。
void playAlbumNow(WidgetRef ref, List<Track> tracks, String albumNorm) {
  final list = tracks.where((t) => albumKey(t.album) == albumNorm).toList();
  ref.read(playbackProvider.notifier).playTracks(list, startIndex: 0);
}
