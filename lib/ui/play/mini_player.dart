/// 迷你播放条：宽屏通栏 / 移动悬浮胶囊。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/playback_controller.dart';
import '../shared/common.dart';
import '../shell/app_shell.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({required this.capsule, super.key});

  final bool capsule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(playbackProvider);
    final p = context.ia;
    final track = snap.current;
    if (track == null) {
      return const SizedBox.shrink();
    }

    final content = Row(
      children: [
        CoverArt(track: track, size: capsule ? 42 : 46),
        const SizedBox(width: IaSpacing.m),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: p.mainText)),
              Text(track.artistDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: p.secondaryText)),
            ],
          ),
        ),
        _RoundIcon(
          icon: snap.playing ? Icons.pause : Icons.play_arrow,
          onTap: () => ref.read(playbackProvider.notifier).togglePlay(),
          filled: true,
        ),
        const SizedBox(width: IaSpacing.xs),
        _RoundIcon(
          icon: Icons.skip_next,
          onTap: () => ref.read(playbackProvider.notifier).next(),
        ),
        if (!capsule) const SizedBox(width: IaSpacing.s),
      ],
    );

    final inner = InkWell(
      onTap: () => openNowPlaying(context),
      child: capsule
          ? Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.s, vertical: IaSpacing.s),
              child: content,
            )
          : Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.l, vertical: IaSpacing.s),
              child: content,
            ),
    );

    if (!capsule) {
      return Container(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.separator)),
        ),
        child: inner,
      );
    }
    return Material(
      color: p.surface.withValues(alpha: 0.96),
      elevation: 6,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(999),
      child: inner,
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: filled ? 36 : 34,
        height: filled ? 36 : 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? p.accent : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: filled ? 20 : 22,
          color: filled ? p.onAccent : p.mainText,
        ),
      ),
    );
  }
}
