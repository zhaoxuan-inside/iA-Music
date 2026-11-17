/// 歌单屏（Hub 屏6）：计数行 + 两列歌单卡（自定义封面 / GitHub 拉取 pending 态）+ 拉取入口。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/quickplay.dart';
import '../../state/playlist_providers.dart';
import '../../state/quickplay_providers.dart';
import '../detail/detail_page.dart';
import '../shared/search_action.dart';
import '../shared/ui_kit.dart';
import '../shared/wp_motion.dart';
import 'github/github_page.dart';
import 'playlist_edit.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pls = ref.watch(playlistListProvider).value ?? const <Playlist>[];
    final pending = pls.fold<int>(0, (s, p) => s + p.pendingCount);
    final total = pls.fold<int>(0, (s, p) => s + p.trackCount);

    return HubPage(
      header: PageHeader(
        kicker: '亲手整理的',
        title: '歌单',
        subtitle:
            '${pls.length} 个歌单 · $total 首${pending > 0 ? ' · $pending 首待提取' : ''}',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => Navigator.of(context).push(
                  zuneRoute<void>(builder: (_) => const GithubPage())),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('⇣ 拉取歌单',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(context).extension<IaPalette>()!.accent)),
              ),
            ),
            const SearchAction(),
          ],
        ),
      ),
      children: [
        if (pls.isEmpty)
          const EmptyState(
              title: '还没有歌单',
              subtitle: '长按歌曲「加到歌单」新建，或从 GitHub 拉取现成歌单')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
                childAspectRatio: 0.76),
            itemCount: pls.length,
            itemBuilder: (_, i) {
              final p = pls[i];
              final pend = p.pendingCount;
              final hasCover = p.coverPath != null && File(p.coverPath!).existsSync();
              return FeatherIn(
                index: i,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(zuneRoute<void>(
                      builder: (_) => DetailPage(
                          type: DetailType.playlist, id: p.id.toString()))),
                  onLongPress: () => _playlistMenu(context, ref, p),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: hasCover
                            ? Container(
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
                              )
                            : _LetterTile(name: p.name, count: p.trackCount, pend: pend),
                      ),
                      const SizedBox(height: IaSpacing.s),
                      Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: IaColors.textHi)),
                      Text(pend > 0 ? 'GitHub · 提取中' : '歌单',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 11, color: IaColors.textLow)),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _playlistMenu(BuildContext context, WidgetRef ref, Playlist p) {
    final pin = QuickplayPin(
      kind: QuickplayKind.playlist,
      key: p.id.toString(),
      title: p.name,
      subtitle: '${p.trackCount} 首',
    );
    final pinned = ref
        .read(quickplayProvider)
        .isPinned(QuickplayKind.playlist, pin.key);
    showWpMenu(context, title: p.name, items: [
      (
        pinned ? '解除快速播放固定' : '固定到快速播放',
        () async {
          await ref.read(quickplayProvider.notifier).toggle(pin);
        },
      ),
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

/// 无自定义封面时的字块磁贴（首字水印 + 底部歌名/计数）。
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
          top: const BorderSide(color: IaColors.hairline),
          right: const BorderSide(color: IaColors.hairline),
          bottom: const BorderSide(color: IaColors.hairline),
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
                        fontSize: 19,
                        height: 1.25,
                        fontWeight: IaType.light,
                        color: IaColors.textHi)),
                const SizedBox(height: IaSpacing.s),
                Text(pend > 0 ? '$pend 首待提取' : '$count 首',
                    style: const TextStyle(
                        fontSize: 11, color: IaColors.textLow)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
