/// 歌单屏（Hub 屏6）：计数行 + 两列歌单卡（GitHub 拉取 pending 态）+ 拉取入口。
library;

import 'package:flutter/material.dart';
import '../../state/playlist_providers.dart';
import '../../state/library_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/playlist.dart';
import '../../state/playlist_providers.dart';
import '../detail/detail_page.dart';
import '../shared/ui_kit.dart';
import 'github/github_page.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pls = ref.watch(playlistListProvider).value ?? const <Playlist>[];
    final pending = pls.fold<int>(0, (s, p) => s + p.pendingCount);
    final total = pls.fold<int>(0, (s, p) => s + p.trackCount);
    final edge = edgeInsets(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(edge.left, 0, edge.right, 140),
      children: [
        const SectionLabel('亲手整理的'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('歌单',
                style: TextStyle(
                    fontSize: IaType.page,
                    fontWeight: IaType.light,
                    color: IaColors.textHi)),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const GithubPage())),
              child: Text('⇣ 拉取歌单',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).extension<IaPalette>()!.accent)),
            ),
          ],
        ),
        const SizedBox(height: IaSpacing.s),
        Text('${pls.length} 个歌单 · $total 首${pending > 0 ? ' · $pending 首待提取' : ''}',
            style: const TextStyle(fontSize: 12, color: IaColors.textLow)),
        const SizedBox(height: IaSpacing.l),
        if (pls.isEmpty)
          const EmptyState(
              title: '还没有歌单',
              subtitle: '长按歌曲「加到歌单」新建，或从 GitHub 拉取现成歌单')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 18),
            itemCount: pls.length,
            itemBuilder: (_, i) {
              final p = pls[i];
              final pend = p.pendingCount;
              return InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => DetailPage(
                        type: DetailType.playlist, id: p.id.toString()))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: pend > 0
                                  ? Theme.of(context)
                                      .extension<IaPalette>()!
                                      .accent
                                  : IaColors.hairlineStrong),
                        ),
                        padding: const EdgeInsets.all(IaSpacing.l),
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: IaType.light,
                                    color: IaColors.textHi)),
                            const SizedBox(height: IaSpacing.s),
                            Text(pend > 0 ? '$pend 首待提取' : '${p.trackCount} 首',
                                style: const TextStyle(
                                    fontSize: 11, color: IaColors.textLow)),
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
}
