/// 迷你条：吸底整宽黑条 + accent 细进度线；横滑切歌；点击展开 NP。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/playback_controller.dart';
import '../shared/cover.dart';

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

    if (cur == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
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
                top: BorderSide(color: IaColors.hairlineStrong)),
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
                padding: EdgeInsets.fromLTRB(
                    mq.padding.left + IaSpacing.m,
                    IaSpacing.s,
                    mq.padding.right + IaSpacing.xs,
                    IaSpacing.s),
                child: Row(
                  children: [
                    CoverArt(track: cur, size: 40),
                    const SizedBox(width: IaSpacing.m),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cur.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13.5, color: IaColors.textHi)),
                          const SizedBox(height: 2),
                          Text(cur.artistDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: IaColors.textLow)),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          ref.read(playbackProvider.notifier).togglePlay(),
                      icon: Icon(
                          snap.playing ? Icons.pause : Icons.play_arrow,
                          size: 22,
                          color: IaColors.textHi),
                    ),
                    const Icon(Icons.keyboard_arrow_up,
                        size: 20, color: IaColors.textLow),
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
