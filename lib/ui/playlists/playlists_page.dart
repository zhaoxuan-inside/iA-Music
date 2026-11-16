/// 歌单屏（Hub 屏6）：计数行 + 两列歌单卡（GitHub 拉取 pending 态）+ 拉取入口。
library;

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
import 'github/github_page.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pls = ref.watch(playlistListProvider).value ?? const <Playlist>[];
    final pending = pls.fold<int>(0, (s, p) => s + p.pendingCount);
    final total = pls.fold<int>(0, (s, p) => s + p.trackCount);
    final pad = hubPadding(context);

    return ListView(
      padding: pad,
      children: [
        const SizedBox(height: IaSpacing.xl),
        PageHeader(
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
        const SizedBox(height: IaSpacing.xl),
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
              return InkWell(
                onTap: () => Navigator.of(context).push(zuneRoute<void>(
                    builder: (_) => DetailPage(
                        type: DetailType.playlist, id: p.id.toString()))),
                onLongPress: () => _playlistMenu(context, ref, p),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                                color: pend > 0
                                    ? Theme.of(context)
                                        .extension<IaPalette>()!
                                        .accent
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
                                p.name.isEmpty ? '♪' : p.name[0],
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
                                  Text(p.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 19,
                                          height: 1.25,
                                          fontWeight: IaType.light,
                                          color: IaColors.textHi)),
                                  const SizedBox(height: IaSpacing.s),
                                  Text(
                                      pend > 0
                                          ? '$pend 首待提取'
                                          : '${p.trackCount} 首',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: IaColors.textLow)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
    ]);
  }
}
