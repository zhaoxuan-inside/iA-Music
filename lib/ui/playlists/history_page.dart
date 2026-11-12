/// 最近播放页：按时间倒序的曲目列表 + 清空。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../data/database.dart' hide TrackRow;
import '../../l10n/app_localizations.dart';
import '../../state/playback_controller.dart';
import '../../state/providers.dart';
import '../shared/common.dart' hide DbActions;

/// 播放历史流。
final historyProvider = StreamProvider.autoDispose<List<HistoryItem>>((ref) {
  return ref.watch(dbProvider).historyDao.watchRecent();
});

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final p = context.ia;
    final items = ref.watch(historyProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.historyTitle),
        actions: [
          IconButton(
            tooltip: s.clearHistory,
            icon: Icon(Icons.delete_sweep_outlined, color: p.secondaryText),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(s.clearHistory),
                  content: Text(s.clearHistoryConfirm),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(s.cancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(s.confirm)),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(dbProvider).historyDao.clearAll();
              }
            },
          ),
        ],
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? EmptyState(icon: Icons.history, title: s.emptyHistory)
              : Builder(builder: (_) {
                  // 同曲多条记录只保留最新一条
                  final seen = <int>{};
                  final tracks = [
                    for (final it in items)
                      if (seen.add(it.track.id)) it.track,
                  ];
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: IaSpacing.s),
                    itemCount: tracks.length,
                    itemBuilder: (_, i) => TrackRow(tracks: tracks, index: i),
                  );
                }),
    );
  }
}
