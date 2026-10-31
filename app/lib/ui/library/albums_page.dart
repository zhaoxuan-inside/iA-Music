/// ALBUMS 专辑页（资料库中心 · Harmonoid 封面网格 + 详情页，DEC-012）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/playback/playback_service.dart';
import 'package:ia_music/ui/library/tracks_page.dart' show LibrarySegmentBar;
import 'package:ia_music/ui/shared/cover_art.dart';
import 'package:ia_music/ui/shared/ia_format.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class AlbumsPage extends StatefulWidget {
  const AlbumsPage({
    super.key,
    required this.hub,
    required this.playTracks,
    required this.onPlayRequested,
    this.onSection,
  });

  final LibraryHub hub;
  final Future<PlaybackService> Function(List<int> ids, {int startIndex})
      playTracks;
  final VoidCallback onPlayRequested;
  final ValueChanged<int>? onSection;

  @override
  State<AlbumsPage> createState() => AlbumsPageState();
}

class AlbumsPageState extends State<AlbumsPage> {
  List<({Album album, int count, int sampleTrackId})> _rows = const [];
  bool _loaded = false;
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
      final rows = await widget.hub.data.library.albumsWithCounts();
      if (mounted) setState(() { _rows = rows; _loaded = true; });
    } finally {
      _inflight = false;
    }
  }

  Future<void> _open(int i) async {
    final entry = _rows[i];
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AlbumDetailPage(
        hub: widget.hub,
        album: entry.album,
        count: entry.count,
        sampleTrackId: entry.sampleTrackId,
        playTracks: widget.playTracks,
        onPlayRequested: widget.onPlayRequested,
      ),
    ));
    unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    return Scaffold(
      key: const ValueKey('albums_page'),
      body: LayoutBuilder(builder: (context, cons) {
        final cross = wide
            ? (cons.maxWidth / 200).floor().clamp(3, 8)
            : (cons.maxWidth / 160).floor().clamp(2, 4);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!wide && widget.onSection != null) ...[
                      LibrarySegmentBar(current: 1, onPick: widget.onSection!),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      t.navAlbums,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.albumCount(_rows.length),
                      style:
                          TextStyle(fontSize: 12, color: p.secondaryText),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_loaded && _rows.isEmpty)
              SliverFillRemaining(
                child: Center(
                  key: const ValueKey('albums_empty'),
                  child: Text(t.albumsEmpty),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final e = _rows[i];
                      return InkWell(
                        key: ValueKey('album_card_${e.album.id}'),
                        onTap: () => unawaited(_open(i)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: CoverArt(
                                trackId: e.sampleTrackId,
                                title: e.album.name,
                                data: widget.hub.data,
                                chain: widget.hub.covers,
                                size: double.infinity,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              e.album.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              t.trackCount(e.count),
                              style: TextStyle(
                                fontSize: 11,
                                color: p.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: _rows.length,
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// 专辑详情（大封面 + 标题/计数 + PLAY ALL/SHUFFLE + 曲目表）。
final class AlbumDetailPage extends StatefulWidget {
  const AlbumDetailPage({
    super.key,
    required this.hub,
    required this.album,
    required this.count,
    required this.sampleTrackId,
    required this.playTracks,
    required this.onPlayRequested,
  });

  final LibraryHub hub;
  final Album album;
  final int count;
  final int sampleTrackId;
  final Future<PlaybackService> Function(List<int> ids, {int startIndex})
      playTracks;
  final VoidCallback onPlayRequested;

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  List<Track> _tracks = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final rows =
        await widget.hub.data.library.tracksOfAlbum(widget.album.id);
    if (mounted) setState(() => _tracks = rows);
  }

  Future<void> _play({int startIndex = 0}) async {
    if (_tracks.isEmpty) return;
    await widget.playTracks(
      [for (final t in _tracks) t.id],
      startIndex: startIndex,
    );
    widget.onPlayRequested();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    return Scaffold(
      key: const ValueKey('album_detail'),
      appBar: AppBar(title: Text(widget.album.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LayoutBuilder(builder: (context, cons) {
            final wide = cons.maxWidth >= 640;
            final cover = ClipRRect(
              borderRadius: BorderRadius.circular(IaRadius.cover),
              child: SizedBox(
                width: wide ? 240 : double.infinity,
                height: wide ? 240 : cons.maxWidth,
                child: CoverArt(
                  trackId: widget.sampleTrackId,
                  title: widget.album.name,
                  data: widget.hub.data,
                  chain: widget.hub.covers,
                  size: double.infinity,
                ),
              ),
            );
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.album.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.albumTrackCount(
                      _tracks.isEmpty ? widget.count : _tracks.length),
                  style: TextStyle(fontSize: 13, color: p.secondaryText),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('album_play_all'),
                      onPressed: () => unawaited(_play()),
                      icon: Icon(IaIcon.play),
                      label: Text(t.playAll),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      key: const ValueKey('album_shuffle'),
                      onPressed: () => unawaited(_play(
                          startIndex:
                              (_tracks.length > 1 ? _tracks.length : 1) ~/
                              2)), // 专辑内随机起点（随机池语义在曲库页）
                      icon: Icon(IaIcon.shuffle),
                      label: Text(t.shuffleShort),
                    ),
                  ],
                ),
              ],
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cover,
                      const SizedBox(width: 24),
                      Expanded(child: info),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [cover, const SizedBox(height: 16), info],
                  );
          }),
          const SizedBox(height: 20),
          for (var i = 0; i < _tracks.length; i++)
            _trackRow(p, _tracks[i], i),
        ],
      ),
    );
  }

  Widget _trackRow(dynamic p, Track t, int i) {
    return InkWell(
      key: ValueKey('album_track_${t.id}'),
      onTap: () => unawaited(_play(startIndex: i)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 12,
                color: p.secondaryText,
                fontFeatures: kIaNumericFeatures,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                t.title ?? sOf(context).untitled,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
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
}
