/// 分类列表页（pivot 横滑：艺人|专辑|歌曲|歌单）+ 字母速查轨 + 长按菜单。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../state/letter.dart';
import '../../state/library_providers.dart';
import '../../state/playback_controller.dart';
import '../../state/playlist_providers.dart';
import '../detail/detail_page.dart';
import '../shared/actions.dart';
import '../shared/album_tile.dart';
import '../shared/cover.dart';
import '../shared/ui_kit.dart';

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({required this.initialTab, super.key});

  /// artists | albums | songs | playlists
  final String initialTab;

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> {
  late String _tab = widget.initialTab;
  final _listKey = <String, GlobalKey>{};
  late final PageController _pc;

  static const tabs = ['artists', 'albums', 'songs', 'playlists'];
  static const titles = {'artists': '艺人', 'albums': '专辑', 'songs': '歌曲', 'playlists': '歌单'};

  @override
  void initState() {
    super.initState();
    _pc = PageController(initialPage: tabs.indexOf(widget.initialTab));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _switchTo(String tab) {
    final i = tabs.indexOf(tab);
    if (i >= 0 && _pc.page?.round() != i) {
      _pc.animateToPage(i,
          duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final edge = edgeInsets(context);
    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 0),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: IaSpacing.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '分类浏览',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: IaType.semibold,
                          letterSpacing: IaType.kickerTracking,
                          color: Theme.of(context)
                              .extension<IaPalette>()!
                              .accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('音乐',
                          style: TextStyle(
                              fontSize: IaType.hub,
                              height: 1.05,
                              fontWeight: IaType.light,
                              letterSpacing: IaType.titleTracking,
                              color: IaColors.textHi)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: IaSpacing.m),
            // pivot 头部（点击/横滑切换）
            GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                final i = tabs.indexOf(_tab);
                if (v < 0 && i < tabs.length - 1) {
                  _switchTo(tabs[i + 1]);
                } else if (v > 0 && i > 0) {
                  _switchTo(tabs[i - 1]);
                }
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: edge.left),
                child: Row(
                  children: [
                    for (final t in tabs)
                      GestureDetector(
                        onTap: () => _switchTo(t),
                        child: Padding(
                          padding: const EdgeInsets.only(right: IaSpacing.l),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // DESIGN「Pivot 横滑」：当前项 Light 放大过渡。
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                    fontSize: _tab == t
                                        ? IaType.pivotCur
                                        : IaType.pivotIdle,
                                    fontWeight: _tab == t
                                        ? IaType.light
                                        : IaType.regular,
                                    color: _tab == t
                                        ? IaColors.textHi
                                        : IaColors.textMid),
                                child: Text(titles[t]!),
                              ),
                              const SizedBox(height: 8),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: _tab == t ? 24 : 0,
                                height: 2,
                                color: Theme.of(context)
                                    .extension<IaPalette>()!
                                    .accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: IaSpacing.m),
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _tab = tabs[i]),
                children: [
                  _ArtistsList(letterKeyOf: _bumpKey),
                  _AlbumsGrid(),
                  _SongsList(),
                  _PlaylistsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  GlobalKey _bumpKey(String l) => _listKey.putIfAbsent('$_tab-$l', GlobalKey.new);
}

/* ── 艺人列表 ─────────────────────────────────────────────────────── */

class _ArtistsList extends ConsumerWidget {
  const _ArtistsList({required this.letterKeyOf});

  final GlobalKey Function(String) letterKeyOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider).value ?? const <ArtistGroup>[];
    final groups = <String, List<ArtistGroup>>{};
    for (final a in artists) {
      groups.putIfAbsent(letterKey(a.artist), () => []).add(a);
    }
    final letters = groups.keys.toList();
    final edge = edgeInsets(context);

    final slots = <Widget>[];
    groups.forEach((L, list) {
      slots.add(Container(
        key: letterKeyOf(L),
        padding: const EdgeInsets.only(top: IaSpacing.l, bottom: IaSpacing.s),
        child: Text(L,
            style: TextStyle(
                fontSize: 12,
                fontWeight: IaType.semibold,
                letterSpacing: 1.2,
                color: Theme.of(context).extension<IaPalette>()!.accent)),
      ));
      for (final a in list) {
        slots.add(Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(zuneRoute<void>(
                builder: (_) => DetailPage(
                    type: DetailType.artist, id: artistKey(a.artist)))),
            onLongPress: () => showWpMenu(context,
                title: a.artist,
                items: [
                  (
                    '播放全部（随机）',
                    () async {
                      final tracks = await ref
                          .read(dbProvider)
                          .libraryDao
                          .watchArtistTracks(artistKey(a.artist))
                          .first;
                      if (context.mounted) {
                        unawaited(ref
                            .read(playbackProvider.notifier)
                            .playTracks(tracks, shuffle: true));
                      }
                    },
                  ),
                ]),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: IaSpacing.m, vertical: IaSpacing.m),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: IaColors.hairline))),
              child: Row(
                children: [
                  Text(a.artist,
                      style: const TextStyle(
                          fontSize: IaType.list, color: IaColors.textHi)),
                  const Spacer(),
                  Text('${a.trackCount} 首',
                      style: const TextStyle(
                          fontSize: 12, color: IaColors.textLow)),
                ],
              ),
            ),
          ),
        ));
      }
    });

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 140),
          children: [for (final w in slots) w],
        ),
        Positioned(
          right: edge.right > IaSpacing.gutter ? 4 : 2,
          top: 20,
          bottom: 120,
          width: 20,
          child: LetterRail(
            letters: letters,
            onPick: (l) {
              final gk = letterKeyOf(l);
              if (gk.currentContext != null) {
                Scrollable.ensureVisible(gk.currentContext!,
                    duration: const Duration(milliseconds: 220));
              }
            },
          ),
        ),
      ],
    );
  }


}

/* ── 专辑网格 ─────────────────────────────────────────────────────── */

class _AlbumsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumsProvider).value ?? const <AlbumGroup>[];
    final edge = edgeInsets(context);
    if (albums.isEmpty) {
      return const EmptyState(title: '还没有专辑', subtitle: '扫描音乐目录后出现在这里');
    }
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.m, edge.right, 140),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 18,
          childAspectRatio: 0.76),
      itemCount: albums.length,
      itemBuilder: (_, i) => AlbumTile(
        album: albums[i],
        onTap: () => Navigator.of(context).push(zuneRoute<void>(
            builder: (_) => DetailPage(
                type: DetailType.album, id: albumKey(albums[i].album)))),
      ),
    );
  }
}

/* ── 歌曲列表 ─────────────────────────────────────────────────────── */

class _SongsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tracksProvider(TrackSort.title)).value ?? const <Track>[];
    final playingId = ref.watch(playbackProvider.select((s) => s.current?.id));
    final edge = edgeInsets(context);
    if (tracks.isEmpty) {
      return const EmptyState(title: '还没有歌曲', subtitle: '扫描音乐目录后出现在这里');
    }
    final favs = ref.watch(favoritesSetProvider).value ?? const <int>{};
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.m, edge.right, 140),
      itemCount: tracks.length,
      itemBuilder: (_, i) {
        final t = tracks[i];
        return SongRow(
          track: t,
          leading: CoverArt(track: t, size: IaSpacing.coverSmall),
          isPlaying: playingId == t.id,
          isLiked: favs.contains(t.id),
          missing: t.missing,
          onTap: () =>
              ref.read(playbackProvider.notifier).playTrack(t, queue: tracks),
          onLongPress: () => showTrackMenu(context, ref, t),
        );
      },
    );
  }
}

/* ── 歌单列表 ─────────────────────────────────────────────────────── */

class _PlaylistsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pls = ref.watch(playlistListProvider).value ?? const <Playlist>[];
    final edge = edgeInsets(context);
    if (pls.isEmpty) {
      return const EmptyState(title: '还没有歌单', subtitle: '在「歌单」页新建或拉取现成歌单');
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.m, edge.right, 140),
      itemCount: pls.length,
      itemBuilder: (_, i) {
        final p = pls[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(zuneRoute<void>(
                builder: (_) => DetailPage(
                    type: DetailType.playlist, id: p.id.toString()))),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: IaSpacing.m, vertical: IaSpacing.l),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: IaColors.hairline))),
              child: Row(
                children: [
                  Text(p.name,
                      style: const TextStyle(
                          fontSize: IaType.list, color: IaColors.textHi)),
                  const Spacer(),
                  Text('${p.trackCount} 首',
                      style: const TextStyle(
                          fontSize: 12, color: IaColors.textLow)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
