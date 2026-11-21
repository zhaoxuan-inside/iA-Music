/// 常听与历史屏（Hub 屏5）：常听单曲网格（按播放次数）+ 最近播放单曲网格。
///
/// 单曲粒度：无专辑元数据的收集曲不会被折叠成一个「未知专辑」磁贴，
/// 播放记录与实际听到的歌一一对应。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../shared/actions.dart';
import '../shared/cover.dart';
import '../shared/search_action.dart';
import '../shared/ui_kit.dart';
import '../shared/wp_motion.dart';

class PlayedPage extends ConsumerWidget {
  const PlayedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topTracksProvider).value ?? const <TrackPlays>[];
    final recent = ref.watch(recentPlayedTracksProvider);

    return HubPage(
      header: const PageHeader(
        kicker: '回访率最高',
        title: '常听与历史',
        subtitle: '按播放次数排序 · 点封面立即播放',
        trailing: SearchAction(),
      ),
      children: [
        SectionHead(label: '常听', meta: top.isEmpty ? null : '${top.length} 首单曲'),
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
                childAspectRatio: 0.72),
            itemCount: top.length,
            itemBuilder: (_, i) => FeatherIn(
              index: i,
              child: _SongTile(
                track: top[i].track,
                meta: '${top[i].plays} 次',
                onTap: () =>
                    _playFrom(ref, top[i].track, [for (final t in top) t.track]),
                onLongPress: () => showTrackMenu(context, ref, top[i].track),
              ),
            ),
          ),
        const SizedBox(height: IaSpacing.xxl),
        SectionHead(
            label: '最近播放 · History',
            meta: recent.isEmpty ? null : '${recent.length} 首单曲'),
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
            itemBuilder: (_, i) => FeatherIn(
              index: i,
              child: _SongTile(
                track: recent[i],
                onTap: () => _playFrom(ref, recent[i], recent),
                onLongPress: () => showTrackMenu(context, ref, recent[i]),
              ),
            ),
          ),
      ],
    );
  }

  void _playFrom(WidgetRef ref, Track track, List<Track> tracks) {
    ref.read(playbackProvider.notifier).playTrack(track, queue: tracks);
  }
}

/// 单曲磁贴：封面 + 歌名 + 歌手（+ 常听次数）。
class _SongTile extends ConsumerWidget {
  const _SongTile({
    required this.track,
    required this.onTap,
    required this.onLongPress,
    this.meta,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String? meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 1, child: CoverArt(track: track, size: double.infinity)),
          const SizedBox(height: IaSpacing.s),
          Text(track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: IaColors.textHi)),
          Row(
            children: [
              Expanded(
                child: Text(track.artistDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: IaColors.textLow)),
              ),
              if (meta != null) ...[
                const SizedBox(width: IaSpacing.s),
                Text(meta!,
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).extension<IaPalette>()!.accent)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
