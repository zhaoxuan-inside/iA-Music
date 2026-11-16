/// 音乐页（分类菜单）：浏览入口一览 + 流派 chips（真实标签聚合）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/playlist_providers.dart';
import '../detail/detail_page.dart';
import '../search/search_page.dart';
import '../shared/search_action.dart';
import '../shared/ui_kit.dart';
import 'collection_page.dart';

class MusicMenuPage extends ConsumerWidget {
  const MusicMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genres = ref.watch(genresProvider).value ?? const <GenreGroup>[];
    final artists = ref.watch(artistsProvider).value ?? const <ArtistGroup>[];
    final albums = ref.watch(albumsProvider).value ?? const <AlbumGroup>[];
    final songs = ref.watch(trackCountProvider).value ?? 0;
    final playlists = ref.watch(playlistListProvider).value ?? const [];
    final pad = hubPadding(context);

    return ListView(
      padding: pad,
      children: [
        const SizedBox(height: IaSpacing.xl),
        const PageHeader(
          kicker: '分类浏览',
          title: '音乐',
          subtitle: '艺人 / 专辑 / 歌曲 / 歌单 · 搜索在下方',
          trailing: SearchAction(),
        ),
        const SizedBox(height: IaSpacing.xl),
        BigRow(
          title: '艺人',
          subtitle: '${artists.length} 位',
          onTap: () => _openList(context, 'artists'),
        ),
        BigRow(
          title: '专辑',
          subtitle: '${albums.length} 张',
          onTap: () => _openList(context, 'albums'),
        ),
        BigRow(
          title: '歌曲',
          subtitle: '$songs 首',
          onTap: () => _openList(context, 'songs'),
        ),
        BigRow(
          title: '歌单',
          subtitle: '${playlists.length} 个',
          onTap: () => _openList(context, 'playlists'),
        ),
        if (genres.isNotEmpty) ...[
          const SizedBox(height: IaSpacing.xl),
          SectionHead(label: '流派', meta: '${genres.length} 种'),
          const SizedBox(height: IaSpacing.m),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: genres.length,
              separatorBuilder: (_, _) => const SizedBox(width: IaSpacing.s),
              itemBuilder: (_, i) => ZuneChip(
                label: genres[i].genre,
                onTap: () => _openGenre(context, genres[i].genre),
              ),
            ),
          ),
        ],
        const SizedBox(height: IaSpacing.xl),
        BigRow(
          title: '搜索',
          subtitle: '拼音全拼 · 首字母',
          onTap: () => Navigator.of(context).push(
              zuneRoute<void>(builder: (_) => const MusicSearchPage())),
        ),
      ],
    );
  }

  void _openList(BuildContext context, String tab) {
    Navigator.of(context).push(zuneRoute<void>(
        builder: (_) => CollectionPage(initialTab: tab)));
  }

  void _openGenre(BuildContext context, String genre) {
    Navigator.of(context).push(zuneRoute<void>(
        builder: (_) => DetailPage(type: DetailType.genre, id: genre)));
  }
}
