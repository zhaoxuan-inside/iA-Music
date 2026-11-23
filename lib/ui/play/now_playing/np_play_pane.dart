/// 播放屏：封面倒影 + 切歌过渡 + 进度环 + 控制 + 喜欢/睡眠定时 + 下一首预告。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../domain/entities/playback.dart';
import '../../../domain/entities/track.dart';
import '../../../state/library_providers.dart';
import '../../../state/playback_controller.dart';
import '../../shared/actions.dart';
import '../../shared/ambient.dart';
import '../../shared/ui_kit.dart';

/// 播放屏（pivot 第 0 屏）。
class NpPlayPane extends ConsumerWidget {
  const NpPlayPane({
    required this.snap,
    required this.cur,
    required this.edge,
    required this.dragValue,
    required this.onSeek,
    required this.onSeekEnd,
    super.key,
  });

  final PlaybackSnapshot snap;
  final Track cur;
  final EdgeInsets edge;
  final double? dragValue;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onSeekEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final pos =
        (dragValue ??
                (snap.durationMs > 0 ? snap.positionMs / snap.durationMs : 0.0))
            .clamp(0.0, 1.0);
    final cover = math.min(
      MediaQuery.sizeOf(context).width - edge.horizontal - 12,
      IaSpacing.coverHeroMax,
    );
    final liked =
        (ref.watch(favoritesSetProvider).value ?? const <int>{}).contains(cur.id);
    final next = snap.queue.isEmpty
        ? null
        : snap.queue[(snap.index + 1) % snap.queue.length];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(edge.left, 16, edge.right, 20),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: GestureDetector(
              key: ValueKey('art-${cur.id}'),
              onTap: () => ref.read(playbackProvider.notifier).togglePlay(),
              child: AlbumArt(track: cur, size: cover, reflection: true),
            ),
          ),
          const SizedBox(height: 26),
          // 切歌：标题/歌手整体上滑淡入（WP8 Now Playing 的文字过渡）。
          AnimatedSwitcher(
            duration: IaMotion.trackSlide,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey('meta-${cur.id}'),
              children: [
                Text(
                  cur.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.18,
                    fontWeight: IaType.light,
                    letterSpacing: IaType.titleTracking,
                    color: IaColors.textHi,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${cur.artistDisplay} · ${cur.albumDisplay}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: IaColors.textMid,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          ZuneSeekBar(
            value: pos,
            onSeek: snap.durationMs > 0 ? onSeek : null,
            onSeekEnd: snap.durationMs > 0 ? onSeekEnd : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Text(
                  formatDuration(snap.positionMs),
                  style: const TextStyle(fontSize: 11, color: IaColors.textLow),
                ),
                const Spacer(),
                Text(
                  formatDuration(snap.durationMs),
                  style: const TextStyle(fontSize: 11, color: IaColors.textLow),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () =>
                    ref.read(playbackProvider.notifier).toggleShuffle(),
                icon: Icon(
                  Icons.shuffle,
                  size: 20,
                  color: snap.shuffle ? p.accent : IaColors.textMid,
                ),
              ),
              IconButton(
                onPressed: () => ref.read(playbackProvider.notifier).previous(),
                icon: const Icon(
                  Icons.skip_previous,
                  size: 34,
                  color: IaColors.textHi,
                ),
              ),
              InkWell(
                onTap: () => ref.read(playbackProvider.notifier).togglePlay(),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: p.accent, width: 1.2),
                  ),
                  child: Icon(
                    snap.playing ? Icons.pause : Icons.play_arrow,
                    size: 34,
                    color: IaColors.textHi,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => ref.read(playbackProvider.notifier).next(),
                icon: const Icon(
                  Icons.skip_next,
                  size: 34,
                  color: IaColors.textHi,
                ),
              ),
              IconButton(
                onPressed: () async {
                  final nextMode = snap.repeat == RepeatMode.off
                      ? RepeatMode.all
                      : snap.repeat == RepeatMode.all
                      ? RepeatMode.one
                      : RepeatMode.off;
                  await ref
                      .read(playbackProvider.notifier)
                      .setRepeatMode(nextMode);
                },
                icon: Icon(
                  snap.repeat == RepeatMode.one
                      ? Icons.repeat_one
                      : Icons.repeat,
                  size: 20,
                  color: snap.repeat != RepeatMode.off
                      ? p.accent
                      : IaColors.textMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await ref.read(dbActionsProvider).setFavorite(cur.id, !liked);
                },
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_outline,
                  size: 18,
                  color: liked ? p.accent : IaColors.textMid,
                ),
                label: Text(
                  liked ? '已喜欢' : '喜欢',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: liked ? p.accent : IaColors.textMid,
                  ),
                ),
              ),
              const SizedBox(width: IaSpacing.l),
              TextButton(
                onPressed: () => _sleepMenu(context, ref),
                child: Text(
                  snap.sleepEndsAt != null
                      ? '睡眠定时 · 至 ${snap.sleepEndsAt!.hour}:${snap.sleepEndsAt!.minute.toString().padLeft(2, '0')}'
                      : '睡眠定时',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: IaColors.textMid,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 18,
            child: next == null || next.id == cur.id
                ? null
                : Text(
                    '下一首   ${next.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                      color: IaColors.textLow,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 睡眠定时：WP 菜单（15 / 30 / 60 分钟 / 取消）。
  void _sleepMenu(BuildContext context, WidgetRef ref) {
    final snap = ref.read(playbackProvider);
    showWpMenu(
      context,
      title: '睡眠定时',
      items: [
        for (final min in const [15, 30, 60])
          (
            '$min 分钟（淡出）',
            () => ref.read(playbackProvider.notifier).setSleepTimer(min),
          ),
        if (snap.sleepEndsAt != null)
          (
            '取消定时',
            () => ref.read(playbackProvider.notifier).cancelSleepTimer(),
          ),
      ],
    );
  }
}
