/// 迷你条：封面 + 歌名 + accent 进度线；横滑切歌；点击展开 NP。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
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
    final bottom = MediaQuery.of(context).padding.bottom;
    final edge = MediaQuery.of(context).padding;

    if (cur == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 10 + edge.left,
      right: 10 + edge.right,
      bottom: 18 + (bottom > 6 ? bottom : 0),
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
          height: IaSpacing.miniHeight,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.92),
            border: Border.all(color: IaColors.hairlineStrong),
          ),
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
              Row(
                children: [
                  const SizedBox(width: IaSpacing.m),
                  CoverArt(track: cur, size: 38),
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
                    onPressed: () => ref.read(playbackProvider.notifier).togglePlay(),
                    icon: Icon(
                        snap.playing
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: IaColors.textHi),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref.read(playbackProvider.notifier).next(),
                    icon: Icon(Icons.skip_next,
                        size: 20, color: IaColors.textMid),
                  ),
                  const SizedBox(width: IaSpacing.s),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 打开 NP 的统一入口（上滑展开 + 磁贴翻开）。
void openNowPlaying(BuildContext context) {
  Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionsBuilder: (_, anim, _, child) {
      return SlideTransition(
        position:
            Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
  ));
}
