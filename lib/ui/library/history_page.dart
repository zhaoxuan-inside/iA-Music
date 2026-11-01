/// 播放历史页（WS2/REQ-PL-05：按日期分组 + 分页 + 清空；入口=歌单页历史卡）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/shared/cover_art.dart';
import 'package:ia_music/ui/shared/ia_format.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.data,
    required this.ensurePlayback,
    this.onChanged,
  });

  final DataAccess data;
  final Future<PlaybackService> Function() ensurePlayback;
  final VoidCallback? onChanged;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  /// 历史=本地表不参与同步（daos.dart 口径），但同曲目只保留最近一次+次数
  /// 的语义由记录批写承担；本页=按 playedAt DESC 分页读。
  static const _pageSize = 100;

  List<(PlayHistoryData, Track)> _rows = const [];
  bool _loaded = false;
  int _page = 0;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    final rows = await widget.data.history.historyPage(
      page: _page,
      pageSize: _pageSize,
    );
    if (!mounted) return;
    setState(() {
      if (_page == 0) {
        _rows = rows;
      } else {
        _rows = [..._rows, ...rows];
      }
      _hasMore = rows.length == _pageSize;
      _page += 1;
      _loaded = true;
    });
  }

  Future<void> _clearAll() async {
    final t = sOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.historyClear),
        content: Text(t.historyClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            key: const ValueKey('history_clear_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.historyClear),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.data.history.clearAllHistory();
    widget.onChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(sOf(context).historyCleared)));
    setState(() {
      _page = 0;
      _rows = const [];
      _loaded = true;
    });
  }

  Future<void> _play(int index) async {
    final svc = await widget.ensurePlayback();
    // 从该行起连播历史序（跳过缺失行）
    final playable = <int>[
      for (final (_, tr) in _rows.sublist(index))
        if (tr.missingAt == null) tr.id,
    ];
    if (playable.isEmpty) return;
    await svc.playTrackIds(playable, startIndex: 0);
  }

  /// 日期分组头（REQ-PL-05 按日期分组）：今天/昨天/其余 yyyy-MM-dd。
  String _groupLabelFor(int playedAtMs) {
    final day = DateTime.fromMillisecondsSinceEpoch(playedAtMs);
    final today = DateTime.now();
    final dayOnly = DateTime(day.year, day.month, day.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    final t = sOf(context);
    if (dayOnly == todayOnly) return t.historyToday;
    if (dayOnly == todayOnly.subtract(const Duration(days: 1))) {
      return t.historyYesterday;
    }
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return '${day.year}-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('history_page'),
      appBar: AppBar(
        title: Text(t.historyTitle),
        actions: [
          if (_rows.isNotEmpty)
            IconButton(
              key: const ValueKey('history_clear'),
              tooltip: t.historyClear,
              onPressed: () => unawaited(_clearAll()),
              icon: Icon(IaIcon.delete),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Text(
                    t.historyEmpty,
                    style: TextStyle(fontSize: 13, color: p.secondaryText),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _rows.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _rows.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: FilledButton.tonal(
                            key: const ValueKey('history_load_more'),
                            onPressed: () => unawaited(_loadMore()),
                            child: Icon(IaIcon.refresh),
                          ),
                        ),
                      );
                    }
                    final (rec, tr) = _rows[i];
                    final label = _groupLabelFor(rec.playedAt);
                    final showHeader = i == 0 ||
                        _groupLabelFor(_rows[i - 1].$1.playedAt) != label;
                    final missing = tr.missingAt != null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: p.secondaryText,
                                fontFeatures: kIaNumericFeatures,
                              ),
                            ),
                          ),
                        InkWell(
                          key: ValueKey('history_row_${rec.id}'),
                          onTap: missing ? null : () => unawaited(_play(i)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 6),
                            child: Row(
                              children: [
                                CoverArt(
                                  trackId: tr.id,
                                  title: tr.title ?? '',
                                  data: widget.data,
                                  size: 44,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr.title ?? t.untitled,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: missing
                                              ? p.secondaryText
                                              : p.mainText,
                                        ),
                                      ),
                                      Text(
                                        tr.artistDisplay ??
                                            t.unknownArtist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: p.secondaryText),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  iaHHmm(rec.playedAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.secondaryText,
                                    fontFeatures: kIaNumericFeatures,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
