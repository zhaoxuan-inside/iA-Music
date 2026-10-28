/// TRACKS 曲目页（资料库中心首页 · DEC-012 D12-3，从零重写）。
///
/// 性能纪律（2026-10-25 修复）：行/网格一律 **sliver builder 懒构建**——
/// 急切 Column/shrinkWrap 在大曲库下主线程全量构件 + 封面决议风暴。
///
/// * SectionCaps 大写大标题 + 曲目数 + 工具行（排序 chips + 列表⇄网格 + 随机）。
/// * 行：封面 48 + 标题/歌手 + 来源角标（D12-5）+ 时长；缺失灰显。
/// * 移动端顶部 TRACKS/ALBUMS/ARTISTS 分段器（切壳层子面）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/play/playback_notice.dart';
import 'package:ia_music/ui/shared/cover_art.dart';
import 'package:ia_music/ui/shared/ia_format.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

/// 资料库子面分段器（移动端；三页共用）。
class LibrarySegmentBar extends StatelessWidget {
  const LibrarySegmentBar({
    super.key,
    required this.current,
    required this.onPick,
  });

  final int current; // 0 tracks / 1 albums / 2 artists
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      key: const ValueKey('library_segments'),
      children: [
        for (final (i, label) in const [
          (0, 'TRACKS'),
          (1, 'ALBUMS'),
          (2, 'ARTISTS'),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: ValueKey('library_segment_$i'),
              label: Text(label),
              selected: current == i,
              onSelected: (_) => onPick(i),
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: current == i ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.05,
                color:
                    current == i ? scheme.onSecondaryContainer : p.secondaryText,
              ),
            ),
          ),
      ],
    );
  }
}

final class TracksPage extends StatefulWidget {
  const TracksPage({
    super.key,
    required this.hub,
    required this.ensurePlayback,
    required this.playTracks,
    required this.onPlayRequested,
    required this.onShuffleRequested,
    this.onSection,
    this.onNavigate,
    this.service,
  });

  final LibraryHub hub;
  final Future<PlaybackService> Function() ensurePlayback;
  final Future<PlaybackService> Function(List<int> ids, {int startIndex})
      playTracks;
  final VoidCallback onPlayRequested;
  final VoidCallback onShuffleRequested;

  /// 移动端分段器回调（0/1/2 → 壳层子面）。
  final ValueChanged<int>? onSection;

  /// 空态引导跳转（壳层目的地 index：4=search / 5=settings）。
  final ValueChanged<int>? onNavigate;

  /// 壳层播放域（可选：有则显示服务提示横幅）。
  final PlaybackService? service;

  @override
  State<TracksPage> createState() => TracksPageState();
}

class TracksPageState extends State<TracksPage> {
  LibSort _sort = LibSort.recent;
  List<Track> _rows = const [];
  bool _loaded = false;
  bool _grid = false;
  bool _inflight = false;
  StreamSubscription<int>? _revSub;

  @override
  void initState() {
    super.initState();
    _revSub = widget.hub.revisions.listen((_) => unawaited(_reload()));
    unawaited(_reload());
  }

  @override
  void dispose() {
    unawaited(_revSub?.cancel());
    super.dispose();
  }

  Future<void> _reload() async {
    if (_inflight) return;
    _inflight = true;
    try {
      final rows = await widget.hub.data.library.liveTracksOnce(_sort);
      if (mounted) {
        setState(() {
          _rows = rows;
          _loaded = true;
        });
      }
    } finally {
      _inflight = false;
    }
  }

  Future<void> _play(int index) async {
    await widget.playTracks(
      [for (final t in _rows) t.id],
      startIndex: index,
    );
    widget.onPlayRequested();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    return Scaffold(
      key: const ValueKey('tracks_page'),
      body: CustomScrollView(
        key: const ValueKey('tracks_scroll'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            sliver: SliverToBoxAdapter(child: _header(context, wide)),
          ),
          if (_loaded && _rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyLibrary(
                onScan: () => widget.onNavigate?.call(5),
                onSearch: () => widget.onNavigate?.call(4),
              ),
            )
          else if (_grid)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final cross =
                      (constraints.crossAxisExtent / 150).floor().clamp(2, 8);
                  return SliverGrid(
                    key: const ValueKey('tracks_grid'),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _gridCard(i),
                      childCount: _rows.length,
                    ),
                  );
                },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _row(i),
                  childCount: _rows.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, bool wide) {
    final p = context.ia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!wide && widget.onSection != null) ...[
          LibrarySegmentBar(current: 0, onPick: widget.onSection!),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            const Expanded(
              child: Text(
                'TRACKS',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.05,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('tracks_shuffle'),
              tooltip: '随机播放（随机池=全库−少播）',
              onPressed: widget.onShuffleRequested,
              icon: Icon(IaIcon.shuffle, color: p.secondaryText),
            ),
            IconButton(
              key: const ValueKey('tracks_view_toggle'),
              tooltip: _grid ? '列表视图' : '网格视图',
              onPressed: () => setState(() => _grid = !_grid),
              icon: Icon(
                _grid ? IaIcon.viewList : IaIcon.gridView,
                color: p.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${_rows.length} 首',
          style: TextStyle(fontSize: 12, color: p.secondaryText),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in const [
              (LibSort.recent, '最近'),
              (LibSort.title, '标题'),
              (LibSort.artist, '歌手'),
              (LibSort.duration, '时长'),
            ])
              ChoiceChip(
                key: ValueKey('tracks_sort_${entry.$1.name}'),
                label: Text(entry.$2),
                selected: _sort == entry.$1,
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  if (_sort == entry.$1) return;
                  setState(() => _sort = entry.$1);
                  unawaited(_reload());
                },
              ),
          ],
        ),
        if (widget.service != null) ...[
          const SizedBox(height: 8),
          PlaybackNoticeBar(service: widget.service!),
        ],
      ],
    );
  }

  Widget _row(int i) {
    final p = context.ia;
    final t = _rows[i];
    final missing = t.missingAt != null;
    return InkWell(
      key: ValueKey('track_row_${t.id}'),
      onTap: missing ? null : () => unawaited(_play(i)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            CoverArt(
              trackId: t.id,
              title: t.title ?? '',
              data: widget.hub.data,
              chain: widget.hub.covers,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title ?? '未命名',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: missing ? p.secondaryText : p.mainText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          t.artistDisplay?.isEmpty == true
                              ? '未知歌手'
                              : t.artistDisplay!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: p.secondaryText),
                        ),
                      ),
                      if (t.sourceType == 'bilibili')
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            'B站',
                            style: TextStyle(
                              fontSize: 10,
                              color: p.secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (missing)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            '文件缺失',
                            key: const ValueKey('track_missing_badge'),
                            style: TextStyle(fontSize: 10, color: p.error),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              iaMmss(t.durationMs ?? 0),
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
  }

  Widget _gridCard(int i) {
    final p = context.ia;
    final t = _rows[i];
    return InkWell(
      key: ValueKey('track_grid_${t.id}'),
      onTap: () => unawaited(_play(i)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CoverArt(
              trackId: t.id,
              title: t.title ?? '',
              data: widget.hub.data,
              chain: widget.hub.covers,
              size: double.infinity,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.title ?? '未命名',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            t.artistDisplay ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: p.secondaryText),
          ),
        ],
      ),
    );
  }
}

/// 空曲库引导（D12-3：无音乐空间页，引导落在 TRACKS 首屏）。
final class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({this.onScan, this.onSearch});

  final VoidCallback? onScan;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    return Padding(
      key: const ValueKey('tracks_empty'),
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(IaIcon.musicNote, size: 56, color: p.secondaryText),
            const SizedBox(height: 16),
            const Text('曲库是空的', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              '扫描本地音乐目录，或从 B 站搜索提取你的第一首歌。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.secondaryText),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('tracks_empty_scan'),
              onPressed: onScan,
              icon: Icon(IaIcon.folder),
              label: const Text('去设置添加仓库'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('tracks_empty_search'),
              onPressed: onSearch,
              icon: Icon(IaIcon.link),
              label: const Text('去 B 站搜索提取'),
            ),
          ],
        ),
      ),
    );
  }
}
