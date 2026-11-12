/// 曲库区：曲目/专辑/艺术家三视图（分段切换）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../l10n/app_localizations.dart';
import '../../state/library_providers.dart';
import '../../state/playback_controller.dart';
import '../../state/providers.dart';
import '../../state/scan_controller.dart';
import '../shared/common.dart';

class LibrarySection extends ConsumerStatefulWidget {
  const LibrarySection({super.key});

  @override
  ConsumerState<LibrarySection> createState() => _LibrarySectionState();
}

class _LibrarySectionState extends ConsumerState<LibrarySection> {
  int _tab = 0; // 0 曲目 1 专辑 2 艺术家
  TrackSort _sort = TrackSort.recentAdded;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.ia;
    final count = ref.watch(trackCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: count == 0
          ? EmptyState(
              icon: Icons.library_music_outlined,
              title: s.emptyLibraryTitle,
              subtitle: s.emptyLibraryHint,
              action: FilledButton.icon(
                onPressed: () => ref.read(scanProvider.notifier).rescanAll(),
                icon: const Icon(Icons.refresh),
                label: Text(s.rescanAll),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      IaSpacing.xl, IaSpacing.l, IaSpacing.xl, IaSpacing.s),
                  child: Row(
                    children: [
                      Text(s.navLibrary,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: p.mainText)),
                      const Spacer(),
                      _playAllButton(context),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: IaSpacing.xl),
                  child: Row(
                    children: [
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(value: 0, label: Text(s.tabTracks)),
                          ButtonSegment(value: 1, label: Text(s.tabAlbums)),
                          ButtonSegment(value: 2, label: Text(s.tabArtists)),
                        ],
                        selected: {_tab},
                        showSelectedIcon: false,
                        onSelectionChanged: (sel) =>
                            setState(() => _tab = sel.first),
                      ),
                      const Spacer(),
                      if (_tab == 0) _sortChips(s, p),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (_tab) {
                    1 => _AlbumsGrid(onTapAlbum: _openAlbum),
                    2 => _ArtistsGrid(onTapArtist: _openArtist),
                    _ => _TracksList(sort: _sort),
                  },
                ),
              ],
            ),
    );
  }

  Widget _playAllButton(BuildContext context) {
    final s = S.of(context);
    return Row(children: [
      OutlinedButton.icon(
        onPressed: () async {
          final tracks = await ref.read(dbProvider).libraryDao.availableTracks();
          if (tracks.isNotEmpty && context.mounted) {
            await ref.read(playbackProvider.notifier).playTracks(
                  tracks,
                  shuffle: true,
                );
          }
        },
        icon: const Icon(Icons.shuffle, size: 18),
        label: Text(s.shuffleAll),
      ),
      const SizedBox(width: IaSpacing.s),
      FilledButton.icon(
        onPressed: () async {
          final tracks = await ref.read(dbProvider).libraryDao.availableTracks();
          if (tracks.isNotEmpty && context.mounted) {
            final sorted = [...tracks]..sort((a, b) => a.title.compareTo(b.title));
            await ref
                .read(playbackProvider.notifier)
                .playTracks(sorted, startIndex: 0);
          }
        },
        icon: const Icon(Icons.play_arrow, size: 18),
        label: Text(s.playAll),
      ),
    ]);
  }

  Widget _sortChips(S s, IaPalette p) {
    final entries = [
      (TrackSort.recentAdded, s.sortRecent),
      (TrackSort.title, s.sortTitle),
      (TrackSort.artist, s.sortArtist),
      (TrackSort.album, s.sortAlbum),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (mode, label) in entries)
          Padding(
            padding: const EdgeInsets.only(left: IaSpacing.xs),
            child: ChoiceChip(
              label: Text(label, style: const TextStyle(fontSize: 12.5)),
              selected: _sort == mode,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _sort = mode),
            ),
          ),
      ],
    );
  }

  void _openAlbum(AlbumGroup album) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _AlbumDetailPage(album: album),
    ));
  }

  void _openArtist(ArtistGroup artist) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _ArtistDetailPage(artist: artist),
    ));
  }
}

class _TracksList extends ConsumerWidget {
  const _TracksList({required this.sort});

  final TrackSort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tracksProvider(sort)).value;
    if (tracks == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: IaSpacing.xl, vertical: IaSpacing.s),
      itemCount: tracks.length,
      itemBuilder: (_, i) => TrackRow(tracks: tracks, index: i),
    );
  }
}

class _AlbumsGrid extends ConsumerWidget {
  const _AlbumsGrid({required this.onTapAlbum});

  final ValueChanged<AlbumGroup> onTapAlbum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumsProvider).value;
    if (albums == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return GridView.builder(
      padding: const EdgeInsets.all(IaSpacing.xl),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: IaSpacing.l,
        crossAxisSpacing: IaSpacing.l,
        childAspectRatio: 0.82,
      ),
      itemCount: albums.length,
      itemBuilder: (_, i) {
        final album = albums[i];
        return InkWell(
          borderRadius: BorderRadius.circular(IaSpacing.radiusM),
          onTap: () => onTapAlbum(album),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _AlbumCover(album: album)),
              const SizedBox(height: IaSpacing.s),
              Text(album.album.isEmpty ? S.of(context).unknownAlbum : album.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              Text(album.artist.isEmpty ? S.of(context).unknownArtist : album.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.ia.secondaryText)),
            ],
          ),
        );
      },
    );
  }
}

/// 专辑封面 = 该专辑首曲走封面链。
class _AlbumCover extends ConsumerWidget {
  const _AlbumCover({required this.album});

  final AlbumGroup album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = ref.watch(albumTracksProvider(albumKey(album.album))).value?.firstOrNull;
    if (first == null) {
      return Container(
        decoration: BoxDecoration(
          color: context.ia.lifted,
          borderRadius: BorderRadius.circular(IaSpacing.radiusM),
        ),
        child: const Center(child: Icon(Icons.album_outlined)),
      );
    }
    return CoverArt(track: first, size: double.infinity);
  }
}

class _ArtistsGrid extends ConsumerWidget {
  const _ArtistsGrid({required this.onTapArtist});

  final ValueChanged<ArtistGroup> onTapArtist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider).value;
    if (artists == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return GridView.builder(
      padding: const EdgeInsets.all(IaSpacing.xl),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: IaSpacing.l,
        crossAxisSpacing: IaSpacing.l,
        childAspectRatio: 0.9,
      ),
      itemCount: artists.length,
      itemBuilder: (_, i) {
        final artist = artists[i];
        return InkWell(
          borderRadius: BorderRadius.circular(IaSpacing.radiusL),
          onTap: () => onTapArtist(artist),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.ia.lifted,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    artist.artist.isEmpty ? '?' : artist.artist.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: context.ia.accent),
                  ),
                ),
              ),
              const SizedBox(height: IaSpacing.s),
              Text(artist.artist.isEmpty ? S.of(context).unknownArtist : artist.artist,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }
}

class _AlbumDetailPage extends ConsumerWidget {
  const _AlbumDetailPage({required this.album});

  final AlbumGroup album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final p = context.ia;
    final tracks = ref.watch(albumTracksProvider(albumKey(album.album))).value;

    return Scaffold(
      appBar: AppBar(title: Text(album.album.isEmpty ? s.unknownAlbum : album.album)),
      body: tracks == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(IaSpacing.xl),
                  child: Row(
                    children: [
                      if (tracks.isNotEmpty) CoverArt(track: tracks.first, size: 120),
                      const SizedBox(width: IaSpacing.l),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(album.artist.isEmpty ? s.unknownArtist : album.artist,
                                style: TextStyle(fontSize: 16, color: p.mainText)),
                            Text(s.playlistCount(tracks.length),
                                style: TextStyle(fontSize: 13, color: p.secondaryText)),
                            const SizedBox(height: IaSpacing.m),
                            FilledButton.icon(
                              onPressed: tracks.isEmpty
                                  ? null
                                  : () => ref
                                      .read(playbackProvider.notifier)
                                      .playTracks(tracks),
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: Text(s.playAll),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: IaSpacing.xxl),
                    itemCount: tracks.length,
                    itemBuilder: (_, i) => TrackRow(tracks: tracks, index: i),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ArtistDetailPage extends ConsumerWidget {
  const _ArtistDetailPage({required this.artist});

  final ArtistGroup artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final tracks = ref.watch(artistTracksProvider(artistKey(artist.artist))).value;

    return Scaffold(
      appBar: AppBar(title: Text(artist.artist.isEmpty ? s.unknownArtist : artist.artist)),
      body: tracks == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: IaSpacing.s),
              itemCount: tracks.length,
              itemBuilder: (_, i) => TrackRow(tracks: tracks, index: i),
            ),
    );
  }
}
