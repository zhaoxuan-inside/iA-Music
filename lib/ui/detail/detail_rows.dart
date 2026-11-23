/// 详情页行组件：编号曲目行 + 底部应用栏（播放/随机/喜欢）。
library;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../shared/cover.dart';
import '../shared/format.dart';

/// 编号曲目行（序号 + 可选封面 + 标题/歌手 + 时长）。
class DetailTrackLine extends StatelessWidget {
  const DetailTrackLine({
    required this.track,
    required this.index,
    required this.isPlaying,
    required this.isLiked,
    required this.onTap,
    required this.onLongPress,
    this.showCover = false,
    super.key,
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
              Text(formatDuration(track.durationMs),
                  style: const TextStyle(fontSize: 11.5, color: IaColors.textLow)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 详情页底部应用栏：播放（accent 圆环）/ 随机 / 喜欢。
class DetailAppBar extends StatelessWidget {
  const DetailAppBar({
    required this.onPlay,
    required this.onShuffle,
    this.onLike,
    super.key,
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
