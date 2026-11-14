/// 详情页（专辑 / 艺人 / 歌单 / 流派 四型同壳）：
/// 磁贴头 + 列表 + 底部应用栏（播放/随机/喜欢）；左缘右滑返回。
library;

import 'package:flutter/material.dart';
import '../../state/listen_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/playlist_providers.dart';
import '../../state/playback_controller.dart';
import '../shared/actions.dart';
import '../shared/cover.dart';
import '../shared/ui_kit.dart';

enum DetailType { album, artist, playlist, genre }

class DetailPage extends ConsumerWidget {
  const DetailPage({required this.type, required this.id, super.key});

  final DetailType type;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edge = edgeInsets(context);

    // 各型取标题/副题/曲目与磁贴头
    final AsyncValue<List<Track>> tracksAsync;
    String title = '';
    String subtitle = '';
    Widget? extra;
    var likeTarget = '';

    switch (type) {
      case DetailType.album:
        final groups = ref.watch(albumsProvider).value ?? const <AlbumGroup>[];
        final g = groups.where((a) => albumKey(a.album) == id).firstOrNull;
        tracksAsync = ref.watch(albumTracksProvider(id));
        title = g?.album ?? id;
        subtitle = '${g?.artist ?? ''} · ${g?.trackCount ?? 0} 首';
        likeTarget = 'album:$id';
        break;
      case DetailType.artist:
        final groups = ref.watch(artistsProvider).value ?? const <ArtistGroup>[];
        final g = groups.where((a) => artistKey(a.artist) == id).firstOrNull;
        tracksAsync = ref.watch(artistTracksProvider(id));
        title = g?.artist ?? id;
        subtitle = '${g?.trackCount ?? 0} 首';
        likeTarget = 'artist:$id';
        break;
      case DetailType.playlist:
        final pl = ref.watch(playlistListProvider).value
                ?.where((x) => x.id == int.tryParse(id))
                .firstOrNull;
        tracksAsync = ref.watch(playlistTracksProvider(int.tryParse(id) ?? 0));
        title = pl?.name ?? '歌单';
        subtitle = '歌单 · ${pl?.trackCount ?? 0} 首';
        likeTarget = 'playlist:$id';
        break;
      case DetailType.genre:
        final albums = ref.watch(genreAlbumsProvider(id)).value ?? const <AlbumGroup>[];
        final count = albums.fold<int>(0, (s, a) => s + a.trackCount);
        title = id;
        subtitle = '流派 · ${albums.length} 张专辑 · $count 首';
        tracksAsync = const AsyncValue.data(<Track>[]);
        extra = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: IaSpacing.l),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14),
              itemCount: albums.length,
              itemBuilder: (_, i) => _AlbumTile(album: albums[i]),
            ),
          ],
        );
        break;
    }

    final tracks = tracksAsync.value ?? const <Track>[];

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            foregroundColor: IaColors.textHi,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(subtitle,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: IaType.regular,
                    color: IaColors.textMid)),
            actions: [
              if (type != DetailType.playlist)
                IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => _SearchStub())),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.l, edge.right, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: IaType.page,
                          fontWeight: IaType.light,
                          color: IaColors.textHi)),
                  const SizedBox(height: IaSpacing.m),
                  extra ??
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final t in tracks)
                            _TrackLine(
                                track: t,
                                isPlaying: ref.watch(playbackProvider
                                        .select((s) => s.current?.id == t.id)),
                                isLiked:
                                    ref.watch(favoriteProvider(t.id)).value ?? false,
                                onTap: () => ref
                                    .read(playbackProvider.notifier)
                                    .playTracks(tracks,
                                        startIndex: tracks.indexOf(t)),
                                onLongPress: () =>
                                    showTrackMenu(context, ref, t)),
                        ],
                      ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: type == DetailType.playlist
          ? null
          : _DetailAppBar(
              onPlay: () => ref
                  .read(playbackProvider.notifier)
                  .playTracks(tracks.isEmpty ? <Track>[] : tracks),
              onShuffle: () => ref.read(playbackProvider.notifier).playTracks(
                  tracks.isEmpty ? <Track>[] : tracks,
                  startIndex: 0,
                  shuffle: true),
              onLike: likeTarget.isEmpty
                  ? null
                  : () => _toggleLike(context, ref, likeTarget),
            ),
    );
  }

  Future<void> _toggleLike(BuildContext context, WidgetRef ref, String target) async {
    showWpToast(context, title: '喜欢', message: '专辑级收藏在歌单「我喜欢的音乐」中按曲生效');
  }
}

class _AlbumTile extends ConsumerWidget {
  const _AlbumTile({required this.album});

  final AlbumGroup album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(albumTracksProvider(albumKey(album.album))).value ?? const <Track>[];
    final first = tracks.firstOrNull;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => DetailPage(type: DetailType.album, id: albumKey(album.album)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: first == null
                ? Container(color: IaColors.hairline)
                : CoverArt(track: first, size: double.infinity),
          ),
          const SizedBox(height: IaSpacing.s),
          Text(album.album,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: IaColors.textHi)),
          Text(album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: IaColors.textLow)),
        ],
      ),
    );
  }
}

class _TrackLine extends StatelessWidget {
  const _TrackLine({
    required this.track,
    required this.isPlaying,
    required this.isLiked,
    required this.onTap,
    required this.onLongPress,
  });

  final Track track;
  final bool isPlaying;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final sec = (track.durationMs / 1000).round();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: IaSpacing.m),
          decoration:
              const BoxDecoration(border: Border(bottom: BorderSide(color: IaColors.hairline))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: IaType.list,
                                color: isPlaying ? p.accent : IaColors.textHi,
                                fontWeight: isPlaying
                                    ? IaType.semibold
                                    : IaType.regular)),
                      ),
                      if (isLiked)
                        Padding(
                          padding: const EdgeInsets.only(left: IaSpacing.s),
                          child: Text('♥', style: TextStyle(fontSize: 12, color: p.accent)),
                        ),
                    ]),
                    const SizedBox(height: IaSpacing.xs),
                    Text(track.artistDisplay,
                        style:
                            const TextStyle(fontSize: 12, color: IaColors.textLow)),
                  ],
                ),
              ),
              Text('${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailAppBar extends StatelessWidget {
  const _DetailAppBar({
    required this.onPlay,
    required this.onShuffle,
    this.onLike,
  });

  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final safe = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: IaColors.hairline))),
      padding: EdgeInsets.only(
          left: IaSpacing.gutter,
          right: IaSpacing.gutter,
          top: IaSpacing.m,
          bottom: IaSpacing.m + (safe > 6 ? safe : 0)),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.play_arrow, size: 26), onPressed: onPlay),
          IconButton(icon: const Icon(Icons.shuffle, size: 22), onPressed: onShuffle),
          if (onLike != null)
            IconButton(
                icon: const Icon(Icons.favorite_outline, size: 22),
                color: p.textMid,
                onPressed: onLike),
        ],
      ),
    );
  }
}

/// 占位：搜索页接通前禁用详情页搜索入口。
class _SearchStub extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: IaColors.canvas, body: Container());
  }
}
