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
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/library/track_origin.dart';
import 'package:ia_music/lyrics/lyrics_service.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/play/playback_notice.dart';
import 'package:ia_music/ui/shared/cover_art.dart';
import 'package:ia_music/ui/shared/ia_format.dart';
import 'package:ia_music/ui/shared/track_menu.dart';
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
    final t = sOf(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      key: const ValueKey('library_segments'),
      children: [
        for (final (i, label) in [
          (0, t.navTracks),
          (1, t.navAlbums),
          (2, t.navArtists),
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

  /// 多选模式（WS4：批量生成歌词入口；REQ-LYRAI-03 批量勾选排队）。
  Set<int> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

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

  /// 批量生成歌词（WS4/REQ-LYRAI-03：串行队列 + 进度；无歌词轨才跑 ASR，
  /// 已有歌词轨跳过）。完成后汇总 SnackBar（REQ-LYRAI-04 预览在歌词页做）。
  Future<void> _batchGenerateLyrics() async {
    final ids = _selected.toList(growable: false);
    if (ids.isEmpty) return;
    var done = 0, ok = 0, skip = 0, fail = 0;
    final total = ids.length;
    await showDialog<void>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlg) {
          // 串行泵（页侧 Future 链；dialog 常驻=进度面）
          unawaited(() async {
            for (final id in ids) {
              try {
                final meta = await widget.hub.data.lyrics.metaFor(id);
                if (meta != null &&
                    meta.type != LyricsSourceType.none) {
                  skip++;
                } else {
                  final outcome =
                      await widget.hub.extract.lyrics.runForTrack(id);
                  if (outcome.kind == LyricsOutcomeKind.asrGenerated) {
                    ok++;
                  } else {
                    fail++;
                  }
                }
              } on Object {
                fail++;
              }
              done++;
              setDlg(() {});
            }
            if (dlgCtx.mounted) Navigator.pop(dlgCtx);
          }());
          return AlertDialog(
            key: const ValueKey('batch_lyrics_dialog'),
            title: Text(sOf(dlgCtx).batchLyricsTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  key: const ValueKey('batch_lyrics_progress'),
                  value: total == 0 ? 0 : done / total,
                ),
                const SizedBox(height: 12),
                Text(
                  done >= total
                      ? sOf(dlgCtx)
                          .batchLyricsDone(ok, skip, fail)
                      : sOf(dlgCtx).batchLyricsRunning(done, total),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(sOf(context).batchLyricsDone(ok, skip, fail))));
    setState(() => _selected = {});
    unawaited(_reload());
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
    final t = sOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!wide && widget.onSection != null) ...[
          LibrarySegmentBar(current: 0, onPick: widget.onSection!),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                t.navTracks,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.05,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('tracks_shuffle'),
              tooltip: t.shuffleTooltip,
              onPressed: widget.onShuffleRequested,
              icon: Icon(IaIcon.shuffle, color: p.secondaryText),
            ),
            IconButton(
              key: const ValueKey('tracks_view_toggle'),
              tooltip: _grid ? t.viewListTooltip : t.viewGridTooltip,
              onPressed: () => setState(() => _grid = !_grid),
              icon: Icon(
                _grid ? IaIcon.viewList : IaIcon.gridView,
                color: p.secondaryText,
              ),
            ),
            IconButton(
              key: const ValueKey('tracks_select'),
              tooltip: t.tracksSelect,
              onPressed: () => setState(
                  () => _selected = _selected.isEmpty ? {_rows.firstOrNull?.id ?? 0} : {}),
              icon: Icon(
                _selecting ? IaIcon.close : IaIcon.check,
                color: _selecting ? p.accent : p.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _selecting
              ? t.tracksSelected(_selected.length)
              : t.trackCount(_rows.length),
          key: const ValueKey('tracks_count'),
          style: TextStyle(fontSize: 12, color: p.secondaryText),
        ),
        const SizedBox(height: 12),
        // 多选模式操作条（WS4/REQ-LYRAI-03：批量生成歌词）
        if (_selecting)
          Row(
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('tracks_batch_lyrics'),
                onPressed: _selected.isEmpty
                    ? null
                    : () => unawaited(_batchGenerateLyrics()),
                icon: Icon(IaIcon.autoFix, size: 18),
                label: Text(t.batchLyricsTitle),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _selected = {}),
                child: Text(t.cancel),
              ),
            ],
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in [
              (LibSort.recent, t.sortRecent),
              (LibSort.title, t.sortTitle),
              (LibSort.artist, t.sortArtist),
              (LibSort.duration, t.sortDuration),
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
    final msg = sOf(context);
    final t = _rows[i];
    final originLabel = t.originLabel(msg); // U1 来源统一抽象（唯一来源面）
    final missing = t.missingAt != null;
    final checked = _selected.contains(t.id);
    void toggle() => setState(() {
          _selected.contains(t.id)
              ? _selected.remove(t.id)
              : _selected.add(t.id);
        });
    return InkWell(
      key: ValueKey('track_row_${t.id}'),
      onTap: _selecting
          ? toggle
          : (missing ? null : () => unawaited(_play(i))),
      onLongPress: _selecting
          ? toggle
          : () => unawaited(showTrackMenu(
                context,
                track: t,
                hub: widget.hub,
                service: widget.service,
                onChanged: () => unawaited(_reload()),
              )),
      onSecondaryTap: _selecting
          ? toggle
          : () => unawaited(showTrackMenu(
                context,
                track: t,
                hub: widget.hub,
                service: widget.service,
                onChanged: () => unawaited(_reload()),
              )),
      child: Opacity(
        opacity: _selecting && !checked ? 0.55 : 1.0,
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
            const SizedBox(width: 12),
            // U2：标题列与专辑列 5:2 比例（比例化节奏，替代全宽 Expanded）。
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title ?? msg.untitled,
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
                              ? msg.unknownArtist
                              : t.artistDisplay!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: p.secondaryText),
                        ),
                      ),
                      if (originLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            originLabel,
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
                            msg.missingBadge,
                            key: const ValueKey('track_missing_badge'),
                            style: TextStyle(fontSize: 10, color: p.error),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // U2 展示重构：专辑列比例化（flex 2）贴住标题列——
            // 此前固定 220px 贴最右，与标题间出现大空洞；现在 标题:专辑=5:2。
            if (MediaQuery.sizeOf(context).width >= 720) ...[
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text(
                  t.albumDisplay ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.secondaryText),
                ),
              ),
            ],
            const SizedBox(width: 12),
            SizedBox(
              width: 52,
              child: Text(
                iaMmss(t.durationMs ?? 0),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: p.secondaryText,
                  fontFeatures: kIaNumericFeatures,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _gridCard(int i) {
    final p = context.ia;
    final msg = sOf(context);
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
            t.title ?? msg.untitled,
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
    final t = sOf(context);
    return Padding(
      key: const ValueKey('tracks_empty'),
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(IaIcon.musicNote, size: 56, color: p.secondaryText),
            const SizedBox(height: 16),
            Text(t.emptyLibraryTitle, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              t.emptyLibraryBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.secondaryText),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('tracks_empty_scan'),
              onPressed: onScan,
              icon: Icon(IaIcon.folder),
              label: Text(t.emptyGoSettings),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('tracks_empty_search'),
              onPressed: onSearch,
              icon: Icon(IaIcon.link),
              label: Text(t.emptyGoSearch),
            ),
          ],
        ),
      ),
    );
  }
}
