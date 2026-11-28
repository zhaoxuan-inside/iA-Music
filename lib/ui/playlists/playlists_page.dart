/// 歌单屏（Hub 屏4）：新建磁贴 + 两列歌单磁贴（封面/详情自动轮换）。
///
/// 建单走首位「新建歌单」磁贴；有封面的磁贴按活磁贴节奏自动翻面
/// （正面封面 / 背面歌名与首数，wp_motion FlipTile），无封面磁贴常显
/// 字块（本就是详情面，不翻）。页头不再计数（n 个歌单 · x 首），
/// 拉取入口与搜索按钮已移除——找歌走曲库屏搜索。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playlist.dart';
import '../../state/playlist_providers.dart';
import '../detail/detail_page.dart';
import '../motion/wp_motion.dart';
import '../shared/ui_kit.dart';
import 'playlist_edit.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pls = ref.watch(playlistListProvider).value ?? const <Playlist>[];
    final edge = edgeInsets(context);

    return HubSliverPage(
      header: const PageHeader(kicker: '亲手整理的', title: '歌单'),
      slivers: [
        // SliverGrid：磁贴按可视区构建（原 shrinkWrap 网格全量 eager build）。
        SliverPadding(
          padding: EdgeInsets.fromLTRB(edge.left, IaSpacing.xl, edge.right, 140),
          sliver: SliverMainAxisGroup(
            slivers: [
              // 槽 0 = 新建磁贴，其后为歌单磁贴。
              SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 18,
                        childAspectRatio: 0.76),
                delegate: SliverChildBuilderDelegate(
                  childCount: pls.length + 1,
                  (context, i) {
                    if (i == 0) {
                      return FeatherIn(
                        index: 0,
                        child: _NewTile(
                            onTap: () => createPlaylistDialog(context, ref)),
                      );
                    }
                    final p = pls[i - 1];
                    return FeatherIn(
                      index: i,
                      child: _PlaylistTile(
                        playlist: p,
                        index: i,
                        onTap: () => Navigator.of(context).push(
                            zuneRoute<void>(
                                builder: (_) => DetailPage(
                                    type: DetailType.playlist,
                                    id: p.id.toString()))),
                        onLongPress: () => _playlistMenu(context, ref, p),
                      ),
                    );
                  },
                ),
              ),
              if (pls.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                      title: '还没有歌单',
                      subtitle: '点「新建歌单」磁贴创建，或长按歌曲选「加到歌单」'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _playlistMenu(BuildContext context, WidgetRef ref, Playlist p) {
    showWpMenu(context, title: p.name, items: [
      (
        '打开歌单',
        () => Navigator.of(context).push(zuneRoute<void>(
            builder: (_) => DetailPage(
                type: DetailType.playlist, id: p.id.toString()))),
      ),
      if (!p.isSystem)
        (
          '重命名歌单',
          () => renamePlaylistDialog(context, ref, p),
        ),
      (
        '设置歌单封面',
        () => pickPlaylistCover(context, ref, p),
      ),
    ]);
  }
}

/// 歌单磁贴：有封面 = FlipTile 轮换（正面封面 / 背面字块详情），无封面 =
/// 常显字块（本就是详情面，不翻）。磁贴下方歌名/状态随行。
class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  final Playlist playlist;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = playlist;
    final pend = p.pendingCount;
    final hasCover = p.coverPath != null && File(p.coverPath!).existsSync();

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: hasCover
                ? FlipTile(
                    index: index,
                    back: _LetterTile(
                        name: p.name, count: p.trackCount, pend: pend),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: IaColors.hairline),
                      ),
                      child: Image.file(
                        File(p.coverPath!),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => _LetterTile(
                            name: p.name, count: p.trackCount, pend: pend),
                      ),
                    ),
                  )
                : _LetterTile(name: p.name, count: p.trackCount, pend: pend),
          ),
          const SizedBox(height: IaSpacing.s),
          Text(p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: IaColors.textHi)),
          Text(pend > 0 ? '提取中' : '歌单',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: IaColors.textLow)),
        ],
      ),
    );
  }
}

/// 新建歌单磁贴：细线描边空磁贴 + accent「+」，点按输入名字即建。
class _NewTile extends StatelessWidget {
  const _NewTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).extension<IaPalette>()!.accent;
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                  border: Border.all(color: IaColors.hairlineStrong)),
              alignment: Alignment.center,
              child: Icon(Icons.add, size: 34, color: accent),
            ),
          ),
          const SizedBox(height: IaSpacing.s),
          Text('新建歌单',
              style: TextStyle(fontSize: 14, color: IaColors.textHi)),
        ],
      ),
    );
  }
}

/// 无自定义封面时的字块磁贴（首字水印 + 底部歌名/计数）；也是封面磁贴
/// 翻面后的详情背面（歌单名称 + 歌曲数量）。
class _LetterTile extends StatelessWidget {
  const _LetterTile({required this.name, required this.count, required this.pend});

  final String name;
  final int count;
  final int pend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: pend > 0
                  ? Theme.of(context).extension<IaPalette>()!.accent
                  : IaColors.hairlineStrong,
              width: pend > 0 ? 2 : 1),
          top: BorderSide(color: IaColors.hairline),
          right: BorderSide(color: IaColors.hairline),
          bottom: BorderSide(color: IaColors.hairline),
        ),
      ),
      padding: const EdgeInsets.all(IaSpacing.l),
      child: Stack(
        children: [
          Positioned(
            right: -2,
            top: -14,
            child: Text(
              name.isEmpty ? '♪' : name[0],
              style: TextStyle(
                fontSize: 64,
                height: 1,
                fontWeight: IaType.light,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 21,
                        height: 1.25,
                        fontWeight: IaType.light,
                        color: IaColors.textHi)),
                const SizedBox(height: IaSpacing.s),
                Text(pend > 0 ? '$pend 首待提取' : '$count 首',
                    style: TextStyle(
                        fontSize: 12.5, color: IaColors.textLow)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
