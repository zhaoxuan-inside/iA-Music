/// 播放服务提示横幅（缺失/损坏跳过、少播、异常原话面；REQ-PLAY-08）。
library;

import 'package:flutter/material.dart';


import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';

final class PlaybackNoticeBar extends StatelessWidget {
  const PlaybackNoticeBar({super.key, required this.service});

  final PlaybackService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackNotice?>(
      initialData: service.lastNotice,
      stream: service.notices,
      builder: (context, snap) {
        final n = snap.data;
        if (n == null) return const SizedBox.shrink();
        final color = switch (n.kind) {
          PlaybackNoticeKind.serviceBroken => const Color(0xFF7A1F1F),
          PlaybackNoticeKind.missingSkip => const Color(0xFF8A4B00),
          PlaybackNoticeKind.corruptSkip => const Color(0xFF8A4B00),
          _ => const Color(0xFF1F3D2E),
        };
        return Material(
          color: color,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(IaIcon.warning, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    n.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
