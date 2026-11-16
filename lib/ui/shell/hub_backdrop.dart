/// Hub 全景环境：当前封面 → 整窗失焦色雾（Zune 软件的灵魂）。
///
/// 与列表页的纯黑不同，Hub 允许封面颜色占据整个背景：换歌即换房间。
/// 上面再压一层黑纱，保证文字与细线仍然清楚。
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/library_providers.dart';
import '../../state/listen_providers.dart';
import '../../state/media_providers.dart';
import '../../state/playback_controller.dart';

class HubBackdrop extends ConsumerWidget {
  const HubBackdrop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final current = ref.watch(playbackProvider.select((s) => s.current));
    final recent =
        ref.watch(recentAddedAlbumsProvider).value ?? const <AlbumGroup>[];

    // 没有在播曲目时，拿最近入库的第一张专辑当环境；再没有就退回 accent 渐变。
    Track? hero = current;
    if (hero == null && recent.isNotEmpty) {
      hero = ref
          .watch(albumTracksProvider(albumKey(recent.first.album)))
          .value
          ?.firstOrNull;
    }

    File? file;
    if (hero != null) {
      final f = ref.watch(coverProvider((hero.id, hero.coverPath))).value;
      if (f != null && f.existsSync()) {
        file = f;
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: IaColors.canvas),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 760),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: file == null
              ? SizedBox.expand(
                  key: const ValueKey('hub-accent'),
                  child: _DefaultWash(accent: p.accent),
                )
              : SizedBox.expand(
                  key: ValueKey('hub-${file.path}'),
                  child: RepaintBoundary(
                    child: Opacity(
                      opacity: 0.58,
                      child: Transform.scale(
                        scale: 1.32,
                        child: ImageFiltered(
                          imageFilter:
                              ui.ImageFilter.blur(sigmaX: 58, sigmaY: 58),
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                            cacheWidth: 800,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: IaColors.canvas),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        // 黑纱：上浅下深；色雾只做环境，不做信息层。
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.34, 0.66, 1],
              colors: [
                Color(0x73000000),
                Color(0x8C000000),
                Color(0xC2000000),
                Color(0xF2000000),
              ],
            ),
          ),
        ),
        // 暗角：四周回到黑，中间保留封面颜色。
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.15),
              radius: 1.2,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.62),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DefaultWash extends StatelessWidget {
  const _DefaultWash({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.45, 1],
          colors: [
            accent.withValues(alpha: 0.78),
            accent.withValues(alpha: 0.22),
            const Color(0xFF08060A),
          ],
        ),
      ),
    );
  }
}
