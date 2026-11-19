/// 迷你条：吸底整宽黑条 + accent 细进度线；横滑切歌；点击展开 NP。
/// 长歌名走 WP8 音乐播放器的走马灯；切歌时标题/歌手上滑过渡。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/playback_controller.dart';
import '../shared/cover.dart';
import '../shared/ui_kit.dart';
import '../shared/wp_motion.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(playbackProvider);
    final cur = snap.current;
    final p = Theme.of(context).extension<IaPalette>()!;
    final mq = MediaQuery.of(context);
    final bottom = mq.padding.bottom > 6 ? mq.padding.bottom : 0.0;
    // 条宽 = 页面内容宽（与各页列表左右安全边距一致，不铺满曲面屏黑边）。
    final edge = edgeInsets(context);

    if (cur == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: edge.left,
      right: edge.right,
      bottom: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -120) {
            ref.read(playbackProvider.notifier).next();
          } else if (v > 120) {
            ref.read(playbackProvider.notifier).previous();
          }
        },
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.94),
            border: const Border(
              top: BorderSide(color: IaColors.hairlineStrong),
            ),
          ),
          padding: EdgeInsets.only(bottom: bottom),
          child: Stack(
            children: [
              // accent 进度线（贴顶）
              Positioned(
                left: 0,
                top: 0,
                child: FractionallySizedBox(
                  widthFactor: cur.durationMs > 0
                      ? (snap.positionMs / cur.durationMs).clamp(0.0, 1.0)
                      : 0.0,
                  child: Container(
                    height: IaSpacing.progressHairline,
                    color: p.accent,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  IaSpacing.m,
                  IaSpacing.s,
                  IaSpacing.xs,
                  IaSpacing.s,
                ),
                child: Row(
                  children: [
                    CoverArt(track: cur, size: 40),
                    const SizedBox(width: IaSpacing.m),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: IaMotion.trackSlide,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.5),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Column(
                          key: ValueKey('mini-${cur.id}'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // WP8 走马灯：长歌名匀速横滚
                            MarqueeText(
                              cur.title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: IaColors.textHi,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cur.artistDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: IaColors.textLow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          ref.read(playbackProvider.notifier).togglePlay(),
                      icon: Icon(
                        snap.playing ? Icons.pause : Icons.play_arrow,
                        size: 22,
                        color: IaColors.textHi,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_up,
                      size: 20,
                      color: IaColors.textLow,
                    ),
                    const SizedBox(width: IaSpacing.xs),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
