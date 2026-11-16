/// 最近添加屏（Hub 屏4）：计数行 + 两列专辑网格（按 addedAt 倒序）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/quickplay.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../../state/quickplay_providers.dart';
import '../detail/detail_page.dart';
import '../shared/cover.dart';
import '../shared/search_action.dart';
import '../shared/ui_kit.dart';

class AddedPage extends ConsumerWidget {
  const AddedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(recentAddedAlbumsProvider).value ?? const <AlbumGroup>[];
    final trackCount = ref.watch(trackCountProvider).value ?? 0;
    final pad = hubPadding(context);

    return ListView(
      padding: pad,
      children: [
        const SizedBox(height: IaSpacing.xl),
        PageHeader(
          kicker: '库里的新鲜事',
          title: '最近添加',
          subtitle: '$trackCount 首 · ${albums.length} 张专辑',
          trailing: const SearchAction(),
        ),
        const SizedBox(height: IaSpacing.xl),
        if (albums.isEmpty)
          const EmptyState(title: '还没有音乐', subtitle: '在「设置 · 收集」扫描音乐目录后出现在这里')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
                childAspectRatio: 0.76),
            itemCount: albums.length,
            itemBuilder: (_, i) {
              final a = albums[i];
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
