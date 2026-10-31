/// 播放队列页（REQ-PLAY-06；当前曲高亮，点行跳播）。
library;

import 'dart:async';

import 'package:contracts/contracts.dart';

import 'package:flutter/material.dart';

import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/shared/ia_format.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class QueuePage extends StatelessWidget {
  const QueuePage({super.key, required this.service});

  final PlaybackService service;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('queue_page'),
      appBar: AppBar(title: Text(t.queueTitle)),
      body: StreamBuilder<PlaybackSnapshot>(
        initialData: service.snapshot,
        stream: service.status,
        builder: (context, snap) {
          final s = snap.data;
          final queue = s?.queue ?? const <TrackLite>[];
          final curIndex = s?.currentIndex ?? -1;
          if (queue.isEmpty) {
            return Center(child: Text(t.queueEmpty));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: queue.length,
            itemBuilder: (context, i) {
              final t = queue[i];
              final current = i == curIndex;
              return InkWell(
                key: ValueKey('queue_row_$i'),
                onTap: () => unawaited(service.playTrackIds(
                  [for (final q in queue) q.id],
                  startIndex: i,
                )),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: current
                            ? Icon(
                                (s?.playing ?? false)
                                    ? IaIcon.pause
                                    : IaIcon.play,
                                size: 16,
                                fill: 1.0,
                                color: p.accent,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.secondaryText,
                                  fontFeatures: kIaNumericFeatures,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                current ? FontWeight.w700 : FontWeight.w500,
                            color: current ? p.accent : p.mainText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        iaMmss(t.durationMs),
                        style: TextStyle(
                          fontSize: 12,
                          color: p.secondaryText,
                          fontFeatures: kIaNumericFeatures,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
