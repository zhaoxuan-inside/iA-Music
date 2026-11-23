/// 详情页头部：大封面（歌单可用自定义封面）+ 倒影 + 类型 kicker + 细体大标题。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../shared/ambient.dart';

/// 详情页头部（专辑/艺人/歌单/流派四型同壳）。
class DetailHero extends StatelessWidget {
  const DetailHero({
    required this.typeLabel,
    required this.title,
    required this.subtitle,
    required this.trackCount,
    required this.total,
    required this.track,
    this.coverPath,
    super.key,
  });

  final String typeLabel;
  final String title;
  final String subtitle;
  final int trackCount;
  final String total;
  final Track? track;
  final String? coverPath;

  /// 封面图失效兜底：发丝色块。
  Widget _fallbackArt(BuildContext context) =>
      Container(width: 148, height: 148, color: IaColors.hairline);

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final hasCover =
        coverPath != null && coverPath!.isNotEmpty && File(coverPath!).existsSync();
    final art = hasCover
        ? ClipRect(
            child: Image.file(File(coverPath!),
                width: 148,
                height: 148,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _fallbackArt(context)))
        : track == null
            ? null
            : AlbumArt(
                track: track!, size: 148, reflection: true);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (art != null) ...[
          art,
          const SizedBox(width: IaSpacing.l),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                typeLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: IaType.semibold,
                  letterSpacing: IaType.kickerTracking,
                  color: p.accent,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: IaType.light,
                  letterSpacing: IaType.titleTracking,
                  color: IaColors.textHi,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: IaColors.textMid,
                ),
              ),
              if (trackCount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '$trackCount 首 · $total',
                  style:
                      const TextStyle(fontSize: 11, color: IaColors.textLow),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
