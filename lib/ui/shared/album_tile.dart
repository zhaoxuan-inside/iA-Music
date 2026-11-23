/// 专辑磁贴：封面 + 专辑名 + 艺人（detail 流派网格与分类页专辑格共用，
/// 原两处逐字重复的私有实现收拢于此）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import 'cover.dart';

class AlbumTile extends ConsumerWidget {
  const AlbumTile({required this.album, required this.onTap, super.key});

  final AlbumGroup album;

  /// 跳转由调用方决定（详情页路由在 ui/detail，shared 不反向依赖页面）。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 单行首曲查询取封面（原 watch 全专辑曲目流——每个磁贴一条整表流）。
    final first =
        ref.watch(albumFirstTrackProvider(albumKey(album.album))).value;
    return InkWell(
      onTap: onTap,
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
