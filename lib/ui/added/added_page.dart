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

/// 网格展示上限（只看最近 24 小时入库的歌曲）。
const int _maxRecentSongs = 20;

class AddedPage extends ConsumerWidget {
  const AddedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tracksProvider(TrackSort.recentAdded)).value ??
        const <Track>[];
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final recent = tracks
        .where((t) => !t.missing && t.addedAt.isAfter(cutoff))
        .take(_maxRecentSongs)
        .toList();

    return HubPage(
      header: PageHeader(
        kicker: '库里的新鲜事',
        title: '最近添加',
        subtitle: recent.isEmpty
            ? '最近 24 小时没有新入库'
            : '${recent.length} 首 · 最近 24 小时入库',
        trailing: const SearchAction(),
      ),
      children: [
        if (recent.isEmpty)
          const EmptyState(
              title: '暂时没有新歌',
              subtitle: '最近 24 小时入库的歌曲会出现在这里——先去「设置 · 存储」扫描')
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
