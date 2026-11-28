/// 列表行组件：chip / 大字行 / 歌曲行（点播与列表的标准行）。
library;

import 'package:flutter/material.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../domain/entities/track.dart';
import '../../motion/wp_motion.dart';
import 'format.dart';

/// WP 直角 chip：细线描边，选中时 accent 描边 + accent 字。
///
/// 替代 Material 的圆角 tonal chip，避免破坏纯黑画布。
class ZuneChip extends StatelessWidget {
  const ZuneChip({
    required this.label,
    this.onTap,
    this.active = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: IaSpacing.m,
          vertical: IaSpacing.s,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: active ? p.accent : IaColors.hairlineStrong,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: active ? p.accent : IaColors.textMid,
            fontWeight: active ? IaType.semibold : IaType.regular,
          ),
        ),
      ),
    );
  }
}

/// 大字行（细体标题 + 副题 + 箭头），分类菜单与页内跳转的标准行。
class BigRow extends StatelessWidget {
  const BigRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: TiltOnPress(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: IaColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.15,
                          fontWeight: IaType.light,
                          color: IaColors.textHi,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: IaColors.textLow,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: IaSpacing.m),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: IaColors.textLow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 歌曲行（封面 + 歌名 + 歌手·专辑 + 时长；点击开播，长按 WP 菜单）。
class SongRow extends StatelessWidget {
  const SongRow({
    required this.track,
    required this.onTap,
    required this.onLongPress,
    this.leading,
    this.isPlaying = false,
    this.isLiked = false,
    this.missing = false,
    super.key,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget? leading;
  final bool isPlaying;
  final bool isLiked;

  /// 文件缺失/已删除：诚实灰显（点击仍可播，播放器会跳过）。
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final dur = formatDuration(track.durationMs);
    return Material(
      color: Colors.transparent,
      child: TiltOnPress(
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: IaSpacing.m,
              vertical: IaSpacing.m,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: IaColors.hairline)),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: IaSpacing.m),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: IaType.list,
                                color: missing
                                    ? IaColors.textLow
                                    : isPlaying
                                        ? p.accent
                                        : IaColors.textHi,
                                fontWeight: isPlaying
                                    ? IaType.semibold
                                    : IaType.regular,
                              ),
                            ),
                          ),
                          if (isLiked)
                            Padding(
                              padding: const EdgeInsets.only(left: IaSpacing.s),
                              child: Text(
                                '♥',
                                style: TextStyle(fontSize: 13.5, color: p.accent),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: IaSpacing.xs),
                      Text(
                        '${track.artistDisplay} · ${track.albumDisplay}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: IaColors.textLow,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: IaSpacing.m),
                Text(
                  dur,
                  style: TextStyle(fontSize: 13.5, color: IaColors.textLow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
