/// 最近添加屏（Hub 屏4）：计数行 + 两列歌曲网格（按 addedAt 倒序，歌曲维度）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/playback_controller.dart';
import '../shared/actions.dart';
import '../shared/cover.dart';
import '../shared/search_action.dart';
import '../shared/ui_kit.dart';
import '../shared/wp_motion.dart';

/// 网格最多展示的新入库歌曲数（计数行给出全库总数）。
const int _maxRecentSongs = 30;

class AddedPage extends ConsumerWidget {
  const AddedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tracksProvider(TrackSort.recentAdded)).value ??
        const <Track>[];
    final recent = tracks.where((t) => !t.missing).take(_maxRecentSongs).toList();
    final trackCount = ref.watch(trackCountProvider).value ?? 0;

    return HubPage(
      header: PageHeader(
        kicker: '库里的新鲜事',
        title: '最近添加',
        subtitle: '$trackCount 首 · 新入库在前',
        trailing: const SearchAction(),
      ),
      children: [
        if (recent.isEmpty)
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
            itemCount: recent.length,
            itemBuilder: (_, i) {
              final t = recent[i];
              return FeatherIn(
                index: i,
                child: InkWell(
                  onTap: () => ref
                      .read(playbackProvider.notifier)
                      .playTracks(recent, startIndex: i),
                  onLongPress: () => showTrackMenu(context, ref, t),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: CoverArt(track: t, size: double.infinity),
                      ),
                      const SizedBox(height: IaSpacing.s),
                      Text(t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: IaColors.textHi)),
                      Text(t.artistDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: IaColors.textLow)),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
