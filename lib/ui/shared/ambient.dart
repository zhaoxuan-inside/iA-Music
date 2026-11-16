/// 氛围层：封面环境光 / 黑胶倒影 / Zune 细线进度。
///
/// Zune 的核心不是「黑底 + 洋红」，而是**音乐本身成为环境**：
/// 当前封面在页面上方化成一层被压暗、失焦的色雾，页面仍是纯黑，
/// 但每换一首歌，房间的光就换一次。所有氛围都限制在低透明度内，
/// 信息层级仍由排版与 accent 承担。
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/media_providers.dart';
import 'cover.dart';

/// 封面环境光：纯黑基板上铺一层失焦封面 + 黑色面纱 + 暗角。
///
/// [track] 为空时退化为 accent 的极淡径向光。只用于沉浸页
/// （Now Playing / 详情 / Hub 在播），列表页保持纯黑。
class AmbientBackdrop extends ConsumerWidget {
  const AmbientBackdrop({
    required this.track,
    required this.child,
    this.strength = 1,
    this.opacity = 0.34,
    super.key,
  });

  final Track? track;
  final Widget child;

  /// 0..1：环境光强度。详情页可用 0.7，Now Playing 用 1。
  final double strength;

  /// 色雾不透明度（Zune 软件里可以更高；列表页不透明）。
  final double opacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = Theme.of(context).extension<IaPalette>()!;
    File? file;
    final t = track;
    if (t != null) {
      final f = ref.watch(coverProvider((t.id, t.coverPath))).value;
      if (f != null && f.existsSync()) {
        file = f;
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: IaColors.canvas),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 620),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: file == null
              ? SizedBox.expand(
                  key: const ValueKey('accent-wash'),
                  child: _AccentWash(accent: p.accent, strength: strength),
                )
              : SizedBox.expand(
                  key: ValueKey(file.path),
                  child: RepaintBoundary(
                    child: Opacity(
                      opacity: opacity * strength,
                      child: Transform.scale(
                        scale: 1.24,
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(sigmaX: 42, sigmaY: 42),
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                            cacheWidth: 640,
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
        // 黑色面纱：上浅下深，保证内容永远压得住。
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.42, 1],
              colors: [
                Color(0x4D000000),
                Color(0xB8000000),
                Color(0xF2000000),
              ],
            ),
          ),
        ),
        // 暗角：让四角回到纯黑。
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.25),
              radius: 1.15,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AccentWash extends StatelessWidget {
  const _AccentWash({required this.accent, required this.strength});

  final Color accent;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.55),
          radius: 1.2,
          colors: [
            accent.withValues(alpha: 0.14 * strength),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// 封面 + 可选的黑胶倒影。倒影不是装饰：它把方形封面「放」在黑底上，
/// 而不是浮在页面里——这是 Zune 桌面端最容易被记住的一笔。
class AlbumArt extends StatelessWidget {
  const AlbumArt({
    required this.track,
    required this.size,
    this.reflection = false,
    super.key,
  });

  final Track track;
  final double size;
  final bool reflection;

  @override
  Widget build(BuildContext context) {
    final art = SizedBox(
      width: size,
      height: size,
      child: CoverArt(track: track, size: size),
    );
    if (!reflection) {
      return art;
    }
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          art,
          SizedBox(
            width: size,
            height: size * IaSpacing.reflectionRatio,
            child: ClipRect(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x73FFFFFF), Color(0x00FFFFFF)],
                ).createShader(bounds),
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: IaSpacing.reflectionRatio,
                  child: Transform.flip(flipY: true, child: art),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zune 细线进度条：2px 轨道 + accent 已播线 + 小圆点。
///
/// 不用 Material Slider 的胖轨道与涟漪，保证进度条只是「一条线」。
class ZuneSeekBar extends StatefulWidget {
  const ZuneSeekBar({
    required this.value,
    this.onSeek,
    this.onSeekEnd,
    this.height = 30,
    super.key,
  });

  final double value;
  final ValueChanged<double>? onSeek;
  final ValueChanged<double>? onSeekEnd;
  final double height;

  @override
  State<ZuneSeekBar> createState() => _ZuneSeekBarState();
}

class _ZuneSeekBarState extends State<ZuneSeekBar> {
  double? _last;
  double _width = 0;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<IaPalette>()!;
    final v = widget.value.clamp(0.0, 1.0);

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, box) {
          _width = box.maxWidth;
          final w = box.maxWidth;
          final dotLeft = (w * v - 5).clamp(0.0, w - 10);

          double valueAt(Offset local) {
            return _width <= 0 ? 0 : local.dx.clamp(0.0, _width) / _width;
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final nv = valueAt(d.localPosition);
              widget.onSeek?.call(nv);
              widget.onSeekEnd?.call(nv);
            },
            onHorizontalDragStart: (d) {
              _last = valueAt(d.localPosition);
              widget.onSeek?.call(_last!);
            },
            onHorizontalDragUpdate: (d) {
              _last = valueAt(d.localPosition);
              widget.onSeek?.call(_last!);
            },
            onHorizontalDragEnd: (_) {
              if (_last != null) {
                widget.onSeekEnd?.call(_last!);
                _last = null;
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: widget.height / 2 - 1,
                  child: Container(height: 2, color: IaColors.hairlineStrong),
                ),
                Positioned(
                  left: 0,
                  width: w * v,
                  top: widget.height / 2 - 1,
                  child: Container(height: 2, color: p.accent),
                ),
                Positioned(
                  left: dotLeft,
                  top: widget.height / 2 - 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.accent,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

