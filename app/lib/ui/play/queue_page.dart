/// 播放队列页（REQ-PLAY-06；当前曲高亮，点行跳播 + 移除单曲 + 清空——WS2）。
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

  Future<void> _confirmClear(BuildContext context) async {
    final t = sOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(t.queueClear),
        content: Text(t.queueClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            key: const ValueKey('queue_clear_confirm'),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: Text(t.queueClear),
          ),
        ],
      ),
    );
    if (ok == true) {
      await service.clearQueue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('queue_page'),
      appBar: AppBar(
        title: Text(t.queueTitle),
        actions: [
          IconButton(
            key: const ValueKey('queue_clear'),
            tooltip: t.queueClear,
            onPressed: () => unawaited(_confirmClear(context)),
            icon: Icon(IaIcon.delete),
          ),
        ],
      ),
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
              final item = queue[i];
              final current = i == curIndex;
              return InkWell(
                key: ValueKey('queue_row_$i'),
                // 跳选=服务权威 jumpTo（历史/会话一致），不再整队重建
                onTap: current ? null : () => unawaited(service.jumpTo(i)),
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
                          item.title,
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
                        iaMmss(item.durationMs),
                        style: TextStyle(
                          fontSize: 12,
                          color: p.secondaryText,
                          fontFeatures: kIaNumericFeatures,
                        ),
                      ),
                      if (!current)
                        IconButton(
                          key: ValueKey('queue_remove_$i'),
                          tooltip: t.queueRemoveTooltip,
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              unawaited(service.removeFromQueue(i)),
                          icon: Icon(IaIcon.close,
                              size: 18, color: p.secondaryText),
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
