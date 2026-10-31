/// ARTISTS 艺术家页（圆形头像网格 + 详情，Harmonoid 形态 · DEC-012）。
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
import 'package:ia_music/ui/shared/track_menu.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

final class ArtistsPage extends StatefulWidget {
  const ArtistsPage({
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
  State<ArtistsPage> createState() => ArtistsPageState();
}

class ArtistsPageState extends State<ArtistsPage> {
  List<({Artist artist, int count, int sampleTrackId})> _rows = const [];
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
      final rows = await widget.hub.data.library.artistsWithCounts();
      if (mounted) setState(() { _rows = rows; _loaded = true; });
    } finally {
      _inflight = false;
    }
  }

  Future<void> _open(int i) async {
    final e = _rows[i];
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ArtistDetailPage(
        hub: widget.hub,
        artist: e.artist,
        sampleTrackId: e.sampleTrackId,
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
      key: const ValueKey('artists_page'),
      body: LayoutBuilder(builder: (context, cons) {
        final cross =
            wide ? (cons.maxWidth / 140).floor().clamp(4, 10) : (cons.maxWidth / 104).floor().clamp(3, 6);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!wide && widget.onSection != null) ...[
                      LibrarySegmentBar(current: 2, onPick: widget.onSection!),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      t.navArtists,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.artistCount(_rows.length),
                      style: TextStyle(fontSize: 12, color: p.secondaryText),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_loaded && _rows.isEmpty)
              SliverFillRemaining(
                child: Center(
                  key: const ValueKey('artists_empty'),
                  child: Text(t.artistsEmpty),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.86,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final e = _rows[i];
                      return InkWell(
                        key: ValueKey('artist_card_${e.artist.id}'),
                        onTap: () => unawaited(_open(i)),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipOval(
                                child: CoverArt(
                                  trackId: e.sampleTrackId,
                                  title: e.artist.name,
                                  data: widget.hub.data,
                                  chain: widget.hub.covers,
                                  size: double.infinity,
                                  radius: 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              e.artist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              t.trackCount(e.count),
                              style: TextStyle(
                                fontSize: 10,
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

/// 艺术家详情（圆头像 + 名 + PLAY ALL + 曲目表）。
final class ArtistDetailPage extends StatefulWidget {
  const ArtistDetailPage({
    super.key,
    required this.hub,
    required this.artist,
    required this.sampleTrackId,
    required this.playTracks,
    required this.onPlayRequested,
  });

  final LibraryHub hub;
  final Artist artist;
  final int sampleTrackId;
  final Future<PlaybackService> Function(List<int> ids, {int startIndex})
      playTracks;
  final VoidCallback onPlayRequested;

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  List<Track> _tracks = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final rows =
        await widget.hub.data.library.tracksOfArtist(widget.artist.id);
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
      key: const ValueKey('artist_detail'),
      appBar: AppBar(title: Text(widget.artist.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ClipOval(
              child: SizedBox(
                width: 160,
                height: 160,
                child: CoverArt(
                  trackId: widget.sampleTrackId,
                  title: widget.artist.name,
                  data: widget.hub.data,
                  chain: widget.hub.covers,
                  size: double.infinity,
                  radius: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              widget.artist.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              t.artistTrackCount(_tracks.length),
              style: TextStyle(fontSize: 13, color: p.secondaryText),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              key: const ValueKey('artist_play_all'),
              onPressed: () => unawaited(_play()),
              icon: Icon(IaIcon.play),
              label: Text(t.playAll),
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < _tracks.length; i++)
            InkWell(
              key: ValueKey('artist_track_${_tracks[i].id}'),
              onTap: () => unawaited(_play(startIndex: i)),
              onLongPress: () => unawaited(showTrackMenu(
                context,
                track: _tracks[i],
                hub: widget.hub,
                onChanged: () => unawaited(_load()),
              )),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _tracks[i].title ?? t.untitled,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      iaMmss(_tracks[i].durationMs ?? 0),
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
      ),
    );
  }
}
