/// 详情页（专辑 / 艺人 / 歌单 / 流派 四型同壳）：
/// 磁贴头 + 曲目列表 + 底部应用栏（播放/随机/喜欢）；左缘右滑返回。
///
/// 头部使用「封面 + 倒影」，把详情页从一张列表变成一张唱片内页。
/// 头部与行组件拆在同目录（detail_hero / detail_rows），专辑磁贴在
/// shared/album_tile（与分类页共用）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/design_tokens.dart';
import '../../domain/entities/quickplay.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../../state/playlist_providers.dart';
import '../../state/quickplay_providers.dart';
import '../playlists/playlist_edit.dart';
import '../search/search_page.dart';
import '../shared/actions.dart';
import '../shared/album_tile.dart';
import '../shared/ui_kit.dart';
import 'detail_hero.dart';
import 'detail_rows.dart';

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
              itemBuilder: (_, i) => AlbumTile(
                album: albums[i],
                onTap: () => Navigator.of(context).push(zuneRoute<void>(
                    builder: (_) =>
                        DetailPage(type: DetailType.album, id: albumKey(albums[i].album)))),
              ),
            ),
          ],
        );
        break;
    }

    final tracks = tracksAsync.value ?? const <Track>[];
    final favs = ref.watch(favoritesSetProvider).value ?? const <int>{};
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
      body: CustomScrollView(
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
                    DetailHero(
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
                        DetailTrackLine(
                          track: tracks[i],
                          index: i + 1,
                          showCover: type == DetailType.playlist,
                          isPlaying: ref.watch(playbackProvider
                              .select((s) => s.current?.id == tracks[i].id)),
                          isLiked: favs.contains(tracks[i].id),
                          onTap: () => ref
                              .read(playbackProvider.notifier)
                              .playTrack(tracks[i], queue: tracks),
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
      bottomNavigationBar: tracks.isEmpty
          ? null
          : DetailAppBar(
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
