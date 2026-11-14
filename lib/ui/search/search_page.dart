/// 搜索页：即时分组结果（歌曲/艺人/专辑/歌单）+ 拼音全拼与首字母。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/playlist.dart';
import '../../state/playlist_providers.dart';
import '../../state/playback_controller.dart';
import '../detail/detail_page.dart';
import '../shared/actions.dart';
import '../shared/cover.dart';
import '../shared/ui_kit.dart';

class MusicSearchPage extends ConsumerStatefulWidget {
  const MusicSearchPage({super.key});

  @override
  ConsumerState<MusicSearchPage> createState() => _MusicSearchPageState();
}

class _MusicSearchPageState extends ConsumerState<MusicSearchPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final edge = edgeInsets(context);
    final q = _q.trim().toLowerCase();

    final tracks = ref.watch(tracksProvider(TrackSort.title)).value ?? const <Track>[];
    final artists = ref.watch(artistsProvider).value ?? const <ArtistGroup>[];
    final albums = ref.watch(albumsProvider).value ?? const <AlbumGroup>[];
    final pls = ref.watch(playlistListProvider).value ?? const <Playlist>[];

    List<T> hit<T>(Iterable<T> src, bool Function(T) test) =>
        q.isEmpty ? <T>[] : src.where(test).toList();

    final fts = q.isEmpty ? const <Track>[] : (ref.watch(ftsSearchProvider(q)).value ?? const <Track>[]);
    final hitTracks = hit(tracks, (t) => _match(q, [t.title, t.artistDisplay, t.albumDisplay]));
    for (final t in fts) {
      if (!hitTracks.any((x) => x.id == t.id)) {
        hitTracks.add(t);
      }
    }
    final hitArtists = hit(artists, (a) => _match(q, [a.artist]));
    final hitAlbums = hit(albums, (a) => _match(q, [a.album, a.artist]));
    final hitPls = hit(pls, (x) => _match(q, [x.name]));
    final playingId = ref.watch(playbackProvider.select((s) => s.current?.id));

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.m, edge.right, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setState(() => _q = v),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: IaType.light,
                          color: IaColors.textHi),
                      decoration: const InputDecoration(
                        hintText: '歌曲 / 艺人 / 专辑 / 歌单（拼音均可）',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: IaSpacing.m),
            Expanded(
              child: q.isEmpty
                  ? ListView(
                      padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 40),
                      children: const [
                        SectionLabel('搜索'),
                        SizedBox(height: IaSpacing.s),
                        Text('支持拼音全拼与首字母 · 如 zjl / zhoujielun',
                            style:
                                TextStyle(fontSize: 12.5, color: IaColors.textLow)),
                      ],
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 140),
                      children: [
                        if (hitArtists.isNotEmpty) ...[
                          const SectionLabel('艺人'),
                          for (final a in hitArtists)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) => DetailPage(
                                            type: DetailType.artist,
                                            id: artistKey(a.artist)))),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: IaSpacing.m,
                                      vertical: IaSpacing.m),
                                  decoration: const BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(color: IaColors.hairline))),
                                  child: Text(a.artist,
                                      style: const TextStyle(
                                          fontSize: IaType.list,
                                          color: IaColors.textHi)),
                                ),
                              ),
                            ),
                        ],
                        if (hitTracks.isNotEmpty) ...[
                          const SizedBox(height: IaSpacing.m),
                          const SectionLabel('歌曲'),
                          for (final t in hitTracks)
                            Row(
                              children: [
                                CoverArt(track: t, size: IaSpacing.coverSmall),
                                Expanded(
                                  child: SongRow(
                                    track: t,
                                    isPlaying: playingId == t.id,
                                    isLiked: ref
                                            .watch(favoriteProvider(t.id))
                                            .value ??
                                        false,
                                    onTap: () {
                                      final qi = hitTracks.indexOf(t);
                                      ref.read(playbackProvider.notifier).playTracks(
                                          hitTracks,
                                          startIndex: qi < 0 ? 0 : qi);
                                    },
                                    onLongPress: () => showTrackMenu(context, ref, t),
                                  ),
                                ),
                              ],
                            ),
                        ],
                        if (hitAlbums.isNotEmpty) ...[
                          const SizedBox(height: IaSpacing.m),
                          const SectionLabel('专辑'),
                          for (final a in hitAlbums)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) => DetailPage(
                                            type: DetailType.album,
                                            id: albumKey(a.album)))),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: IaSpacing.m,
                                      vertical: IaSpacing.m),
                                  decoration: const BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(color: IaColors.hairline))),
                                  child: Text('${a.album} · ${a.artist}',
                                      style: const TextStyle(
                                          fontSize: IaType.list,
                                          color: IaColors.textHi)),
                                ),
                              ),
                            ),
                        ],
                        if (hitPls.isNotEmpty) ...[
                          const SizedBox(height: IaSpacing.m),
                          const SectionLabel('歌单'),
                          for (final x in hitPls)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                        builder: (_) => DetailPage(
                                            type: DetailType.playlist,
                                            id: x.id.toString()))),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: IaSpacing.m,
                                      vertical: IaSpacing.m),
                                  decoration: const BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(color: IaColors.hairline))),
                                  child: Text(x.name,
                                      style: const TextStyle(
                                          fontSize: IaType.list,
                                          color: IaColors.textHi)),
                                ),
                              ),
                            ),
                        ],
                        if (hitTracks.isEmpty &&
                            hitArtists.isEmpty &&
                            hitAlbums.isEmpty &&
                            hitPls.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: IaSpacing.xl),
                            child: Text('没有匹配的结果',
                                style: TextStyle(
                                    fontSize: 13, color: IaColors.textLow)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _match(String q, List<String> fields) {
    if (q.isEmpty) {
      return false;
    }
    return fields.any((f) => f.toLowerCase().contains(q));
  }
}
