/// 封面组件：文件命中用真图；未决议用确定性色块（按曲目 id 取色）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../domain/entities/track.dart';
import '../../state/media_providers.dart';

class CoverArt extends ConsumerWidget {
  const CoverArt({required this.track, this.size = IaSpacing.coverSmall, super.key});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file =
        ref.watch(coverProvider((track.id, track.coverPath))).value;
    if (file != null && file.existsSync()) {
      return Image.file(file,
          width: size.isFinite ? size : null,
          height: size.isFinite ? size : null,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _fallback(context, track.id, size));
    }
    return _fallback(context, track.id, size);
  }

  /// 确定性色块：色相按 id 哈希，Metro 方块（无圆角无描边）。
  Widget _fallback(BuildContext context, int id, double size) {
    final h = (id * 47) % 360;
    return Container(
      width: size.isFinite ? size : null,
      height: size.isFinite ? size : null,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, h.toDouble(), 0.38, 0.24).toColor(),
            HSLColor.fromAHSL(1, ((h + 40) % 360).toDouble(), 0.50, 0.08).toColor(),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        (track.title.isNotEmpty ? track.title[0] : '?'),
        style: TextStyle(
          fontSize: size.isFinite ? size * 0.36 : 28,
          fontWeight: IaType.light,
          color: IaColors.textHi.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
