/// 音乐页（分类菜单）：浏览入口一览 + 流派 chips（真实标签聚合）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../domain/entities/track.dart';
import '../../state/playlist_providers.dart';
import '../detail/detail_page.dart';
import '../search/search_page.dart';
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
    final edge = edgeInsets(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 140),
      children: [
        const SizedBox(height: IaSpacing.xl),
        const SectionLabel('分类浏览'),
        const SizedBox(height: IaSpacing.m),
        BigRow(
          title: '艺人',
          subtitle: '${artists.length}',
          onTap: () => _openList(context, 'artists'),
        ),
        BigRow(
          title: '专辑',
          subtitle: '${albums.length}',
          onTap: () => _openList(context, 'albums'),
        ),
        BigRow(
          title: '歌曲',
          subtitle: '$songs',
          onTap: () => _openList(context, 'songs'),
        ),
        BigRow(
          title: '歌单',
          subtitle: '${playlists.length}',
          onTap: () => _openList(context, 'playlists'),
        ),
        if (genres.isNotEmpty) ...[
          const SizedBox(height: IaSpacing.xl),
          const SectionLabel('流派'),
          const SizedBox(height: IaSpacing.m),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: genres.length,
              separatorBuilder: (_, _) => const SizedBox(width: IaSpacing.m),
              itemBuilder: (_, i) => ActionChip(
                label: Text(genres[i].genre),
                onPressed: () => _openGenre(context, genres[i].genre),
              ),
            ),
          ),
        ],
        const SizedBox(height: IaSpacing.xl),
        BigRow(
          title: '搜索',
          subtitle: '拼音 · 首字母',
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MusicSearchPage())),
        ),
      ],
    );
  }

  void _openList(BuildContext context, String tab) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CollectionPage(initialTab: tab)));
  }

  void _openGenre(BuildContext context, String genre) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => DetailPage(type: DetailType.genre, id: genre)));
  }
}
