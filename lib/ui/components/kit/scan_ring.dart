/// 扫描环形图（曲库统计）：上次扫描四段环（新入库/更新/缺失/复活）+
/// 扫描中的实时进度环。kit 层纯展示件——数据由页面下发，accent 由页面
/// 传入，其余颜色挂主题令牌（IaColors getter 随亮/暗态自动切换）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/design_tokens.dart';

/// 四段颜色口径（环与图例共用，保证同源）。
List<(Color, String)> scanSegments(Color accent) => [
      (accent, '新入库'),
      (accent.withValues(alpha: 0.55), '更新'),
      (IaColors.textMid, '缺失'),
      (IaColors.textHi.withValues(alpha: 0.8), '复活'),
    ];

class ScanRing extends StatelessWidget {
  const ScanRing({
    super.key,
    required this.ins,
    required this.upd,
    required this.miss,
    required this.rev,
    required this.accent,
    this.scanning = false,
    this.done = 0,
    this.total = 0,
    this.size = 84,
  });

  final int ins;
  final int upd;
  final int miss;
  final int rev;
  final Color accent;
  final bool scanning;
  final int done;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final counts = [ins, upd, miss, rev];
    final sum = counts.fold(0, (a, b) => a + b);
    final label = scanning
        ? (total > 0 ? '$done/$total' : '…')
        : (sum > 0 ? '$sum' : '—');

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScanRingPainter(
          scanning: scanning,
          fraction: total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0,
          counts: counts,
          accent: accent,
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: sum > 99 && !scanning ? 14 : 16.5,
                  fontWeight: IaType.regular,
                  color: IaColors.textHi)),
        ),
      ),
    );
  }
}

class _ScanRingPainter extends CustomPainter {
  const _ScanRingPainter({
    required this.scanning,
    required this.fraction,
    required this.counts,
    required this.accent,
  });

  final bool scanning;
  final double fraction;
  final List<int> counts;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - IaSpacing.s;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = IaSpacing.progressHairline + 5
      ..color = IaColors.hairlineStrong;
    canvas.drawCircle(center, radius, track);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final colors = scanSegments(accent).map((e) => e.$1).toList();

    if (scanning) {
      if (fraction <= 0) {
        return;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = IaSpacing.progressHairline + 5
        ..strokeCap = StrokeCap.butt
        ..color = accent;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, paint);
      return;
    }

    final sum = counts.fold(0, (a, b) => a + b);
    if (sum == 0) {
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] == 0) {
        continue;
      }
      final sweep = 2 * math.pi * counts[i] / sum;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = IaSpacing.progressHairline + 5
        ..strokeCap = StrokeCap.butt
        ..color = colors[i];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _ScanRingPainter old) =>
      old.scanning != scanning ||
      old.fraction != fraction ||
      old.accent != accent ||
      old.accent != accent ||
      ListEquality().equals(old.counts, counts);
}

class ListEquality {
  const ListEquality();

  bool equals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
