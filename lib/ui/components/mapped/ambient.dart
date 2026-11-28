/// 黑胶倒影 / Zune 细线进度。
///
/// 背景永远是纯黑画布，不随歌曲/封面变化——封面只作为内容出现。
library;

import 'package:flutter/material.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../domain/entities/track.dart';
import 'cover.dart';

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

