/// 详情页（专辑 / 艺人 / 歌单 / 流派 四型同壳）：
/// 磁贴头 + 曲目列表 + 底部应用栏（播放/随机/喜欢）；左缘右滑返回。
///
/// 头部使用「封面 + 倒影 + 环境光」，把详情页从一张列表变成一张唱片内页。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/quickplay.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../../state/playlist_providers.dart';
import '../../state/providers.dart';
import '../../state/quickplay_providers.dart';
import '../playlists/playlist_edit.dart';
import '../search/search_page.dart';
import '../shared/actions.dart';
import '../shared/ambient.dart';
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
    var typeLabel = '专辑';
    String? plCover;

    switch (type) {
      case DetailType.album:
        final groups = ref.watch(albumsProvider).value ?? const <AlbumGroup>[];
        final g = groups.where((a) => albumKey(a.album) == id).firstOrNull;
        tracksAsync = ref.watch(albumTracksProvider(id));
        title = g?.album ?? id;
        subtitle = '${g?.artist ?? ''} · ${g?.trackCount ?? 0} 首';
        likeTarget = 'album:$id';
        typeLabel = '专辑';
        break;
      case DetailType.artist:
        final groups = ref.watch(artistsProvider).value ?? const <ArtistGroup>[];
        final g = groups.where((a) => artistKey(a.artist) == id).firstOrNull;
        tracksAsync = ref.watch(artistTracksProvider(id));
        title = g?.artist ?? id;
        subtitle = '${g?.trackCount ?? 0} 首';
        likeTarget = 'artist:$id';
        typeLabel = '艺人';
        break;
      case DetailType.playlist:
        final pl = ref.watch(playlistListProvider).value
            ?.where((x) => x.id == int.tryParse(id))
            .firstOrNull;
        tracksAsync = ref.watch(playlistTracksProvider(int.tryParse(id) ?? 0));
        title = pl?.name ?? '歌单';
        subtitle = '${pl?.trackCount ?? 0} 首';
        likeTarget = 'playlist:$id';
        typeLabel = '歌单';
        plCover = pl?.coverPath;
        break;
      case DetailType.genre:
        final albums = ref.watch(genreAlbumsProvider(id)).value ?? const <AlbumGroup>[];
        final count = albums.fold<int>(0, (s, a) => s + a.trackCount);
        title = id;
        subtitle = '${albums.length} 张专辑 · $count 首';
        tracksAsync = const AsyncValue.data(<Track>[]);
        typeLabel = '流派';
        extra = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: IaSpacing.l),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.76),
              itemCount: albums.length,
              itemBuilder: (_, i) => _AlbumTile(album: albums[i]),
            ),
          ],
        );
        break;
    }

    final tracks = tracksAsync.value ?? const <Track>[];
    final first = tracks.firstOrNull;
    final totalMs =
        tracks.fold<int>(0, (sum, t) => sum + t.durationMs);
    final total = _fmtTotal(totalMs);

    final qp = ref.watch(quickplayProvider);
    final qpKind = switch (type) {
      DetailType.album => QuickplayKind.album,
      DetailType.artist => QuickplayKind.artist,
      DetailType.playlist => QuickplayKind.playlist,
      DetailType.genre => null,
    };
    final pinned = qpKind != null && qp.isPinned(qpKind, id);
    final accent = Theme.of(context).extension<IaPalette>()!.accent;

    return Scaffold(
      backgroundColor: IaColors.canvas,
      body: AmbientBackdrop(
        track: first,
        strength: 0.7,
        opacity: 0.46,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: false,
              backgroundColor: Colors.transparent,
              foregroundColor: IaColors.textHi,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              toolbarHeight: 48,
              leading: IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              actions: [
                if (type == DetailType.playlist)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '编辑歌单',
                    icon: const Icon(Icons.edit_outlined, size: 19,
                        color: IaColors.textHi),
                    onPressed: () {
                      final pl = ref.watch(playlistListProvider).value
                          ?.where((x) => x.id == int.tryParse(id))
                          .firstOrNull;
                      if (pl != null) {
                        showPlaylistEditMenu(context, ref, pl);
                      }
                    },
                  ),
                if (qpKind != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: pinned ? '解除快速播放固定' : '固定到快速播放',
                    icon: Icon(
                      pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 19,
                      color: pinned ? accent : IaColors.textHi,
                    ),
                    onPressed: () async {
                      final notifier =
                          ref.read(quickplayProvider.notifier);
                      if (pinned) {
                        await notifier.unpin(qpKind, id);
                      } else {
                        await notifier.pin(QuickplayPin(
                          kind: qpKind,
                          key: id,
                          title: title,
                          subtitle: subtitle,
                        ));
                      }
                    },
                  ),
                if (type != DetailType.playlist)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.search, size: 19),
                    onPressed: () => Navigator.of(context).push(
                        zuneRoute<void>(
                            builder: (_) => const MusicSearchPage())),
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Hero(
                      typeLabel: typeLabel,
                      title: title,
                      subtitle: subtitle,
                      trackCount: tracks.length,
                      total: total,
                      track: first,
                      coverPath: plCover,
                    ),
                    const SizedBox(height: IaSpacing.xl),
                    if (extra != null)
                      extra
                    else ...[
                      SectionHead(
                        label: '曲目',
                        meta: tracks.isEmpty
                            ? '暂无曲目'
                            : '${tracks.length} 首 · $total',
                      ),
                      const SizedBox(height: IaSpacing.xs),
                      for (var i = 0; i < tracks.length; i++)
                        _TrackLine(
                          track: tracks[i],
                          index: i + 1,
                          showCover: type == DetailType.playlist,
                          isPlaying: ref.watch(playbackProvider
                              .select((s) => s.current?.id == tracks[i].id)),
                          isLiked:
                              ref.watch(favoriteProvider(tracks[i].id)).value ??
                                  false,
                          onTap: () => ref
                              .read(playbackProvider.notifier)
                              .playTracks(tracks, startIndex: i),
                          onLongPress: () => type == DetailType.playlist
                              ? _playlistTrackMenu(
                                  context, ref, int.tryParse(id) ?? 0, tracks[i])
                              : showTrackMenu(context, ref, tracks[i]),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      bottomNavigationBar: tracks.isEmpty
          ? null
          : _DetailAppBar(
              onPlay: () => ref
                  .read(playbackProvider.notifier)
                  .playTracks(tracks),
              onShuffle: () => ref.read(playbackProvider.notifier).playTracks(
                  tracks,
                  startIndex: 0,
                  shuffle: true),
              onLike: likeTarget.isEmpty
                  ? null
                  : () => _toggleLike(context, ref, likeTarget),
            ),
    );
  }

  Future<void> _toggleLike(
      BuildContext context, WidgetRef ref, String target) async {
    showWpToast(context, title: '喜欢', message: '专辑级收藏在歌单「我喜欢的音乐」中按曲生效');
  }

  /// 歌单条目长按菜单：移出歌单 / 插播 / 查看专辑。
  void _playlistTrackMenu(
      BuildContext context, WidgetRef ref, int playlistId, Track track) {
    showWpMenu(context, title: track.title, items: [
      (
        '移出歌单',
        () async {
          await ref
              .read(dbProvider)
              .playlistDao
              .removeTrack(playlistId, track.id);
          if (context.mounted) {
            showWpToast(context,
                title: '歌单', message: '已移出「${track.title}」');
          }
        },
      ),
      (
        '插播：下一首播放',
        () => ref.read(dbActionsProvider).playNext(track),
      ),
      (
        '查看专辑',
        () => Navigator.of(context).push(zuneRoute<void>(
              builder: (_) => DetailPage(
                  type: DetailType.album, id: albumKey(track.album)),
            )),
      ),
    ]);
  }

  String _fmtTotal(int ms) {
    final min = (ms / 60000).round();
    if (min < 60) {
      return '$min 分钟';
    }
    return '${min ~/ 60} 小时 ${min % 60} 分';
  }
}

/// 头部：大封面（歌单可用自定义封面）+ 倒影 + 类型 kicker + 细体大标题。
class _Hero extends StatelessWidget {
  const _Hero({
    required this.typeLabel,
    required this.title,
    required this.subtitle,
    required this.trackCount,
    required this.total,
    required this.track,
    this.coverPath,
  });

  final String typeLabel;
  final String title;
  final String subtitle;
  final int trackCount;
  final String total;
  final Track? track;
  final String? coverPath;

  /// 封面图失效兜底：发丝色块。
  Widget _fallbackArt(BuildContext context) =>
      Container(width: 148, height: 148, color: IaColors.hairline);

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final hasCover =
        coverPath != null && coverPath!.isNotEmpty && File(coverPath!).existsSync();
    final art = hasCover
        ? ClipRect(
            child: Image.file(File(coverPath!),
                width: 148,
                height: 148,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _fallbackArt(context)))
        : track == null
            ? null
            : AlbumArt(
                track: track!, size: 148, reflection: true);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (art != null) ...[
          art,
          const SizedBox(width: IaSpacing.l),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                typeLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: IaType.semibold,
                  letterSpacing: IaType.kickerTracking,
                  color: p.accent,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: IaType.light,
                  letterSpacing: IaType.titleTracking,
                  color: IaColors.textHi,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: IaColors.textMid,
                ),
              ),
              if (trackCount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '$trackCount 首 · $total',
                  style:
                      const TextStyle(fontSize: 11, color: IaColors.textLow),
                ),
              ],
            ],
          ),
        ),
      ],
    );
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
      onTap: () => Navigator.of(context).push(zuneRoute<void>(
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
    required this.index,
    required this.isPlaying,
    required this.isLiked,
    required this.onTap,
    required this.onLongPress,
    this.showCover = false,
  });

  final Track track;
  final int index;
  final bool isPlaying;
  final bool isLiked;
  final bool showCover;
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
              SizedBox(
                width: 28,
                child: Text(
                  '$index'.padLeft(2, '0'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    color: isPlaying ? p.accent : IaColors.textLow,
                  ),
                ),
              ),
              const SizedBox(width: IaSpacing.m),
              if (showCover) ...[
                CoverArt(track: track, size: 36),
                const SizedBox(width: IaSpacing.m),
              ],
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
                          child: Text('♥',
                              style: TextStyle(fontSize: 12, color: p.accent)),
                        ),
                    ]),
                    const SizedBox(height: IaSpacing.xs),
                    Text(track.artistDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 12, color: IaColors.textLow)),
                  ],
                ),
              ),
              const SizedBox(width: IaSpacing.m),
              Text('${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11.5, color: IaColors.textLow)),
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
    final safe = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.92),
        border: const Border(top: BorderSide(color: IaColors.hairline)),
      ),
      padding: EdgeInsets.only(
          left: IaSpacing.gutter,
          right: IaSpacing.gutter,
          top: IaSpacing.m,
          bottom: IaSpacing.m + (safe > 6 ? safe : 0)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AppBarButton(
            icon: Icons.play_arrow,
            accent: true,
            size: 48,
            onPressed: onPlay,
          ),
          const SizedBox(width: 18),
          _AppBarButton(icon: Icons.shuffle, onPressed: onShuffle),
          if (onLike != null) ...[
            const SizedBox(width: 18),
            _AppBarButton(icon: Icons.favorite_outline, onPressed: onLike!),
          ],
        ],
      ),
    );
  }
}

class _AppBarButton extends StatelessWidget {
  const _AppBarButton({
    required this.icon,
    required this.onPressed,
    this.accent = false,
    this.size = 42,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: accent ? p.accent : IaColors.hairlineStrong),
        ),
        child: Icon(icon,
            size: size * 0.46,
            color: accent ? p.accent : IaColors.textHi),
      ),
    );
  }
}
