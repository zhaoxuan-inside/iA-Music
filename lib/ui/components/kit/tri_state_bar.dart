/// 进度线组件：2px 单值发丝线 + 6px 三态条（原 5 处手写 Stack 收拢）。
library;

import 'package:flutter/material.dart';

import '../../../app/theme/design_tokens.dart';

/// 单值发丝进度线（2px：底灰轨 + 前景填充），MiniPlayer/扫描/任务行共用。
class HairlineProgress extends StatelessWidget {
  const HairlineProgress({
    required this.fraction,
    this.color,
    this.height = 2,
    super.key,
  });

  /// 0..1（越界自动夹取）。
  final double fraction;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(height: height, color: IaColors.hairlineStrong),
      FractionallySizedBox(
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(height: height, color: color ?? IaColors.hairlineStrong),
      ),
    ]);
  }
}

/// 三态进度条（8px）：底灰=待处理；成功绿从左往右；失败红从右往左；
/// 段宽变化 250ms 缓动（进度是持续推进的，跳变读不出方向感）；
/// 成功段前沿一枚 2px 白刻度标记当前位置（0<成功<1 时）。
/// 补全四阶段与提取聚合条共用。
class TriStateBar extends StatelessWidget {
  const TriStateBar({
    required this.successFraction,
    required this.failedFraction,
    super.key,
  });

  final double successFraction;
  final double failedFraction;

  @override
  Widget build(BuildContext context) {
    const okGreen = Color(0xFF60A917);
    const barHeight = 8.0;
    final success = successFraction.clamp(0.0, 1.0);
    final failed = failedFraction.clamp(0.0, 1.0);
    return SizedBox(
      height: barHeight,
      child: Stack(children: [
        Container(height: barHeight, color: IaColors.hairlineStrong),
        Align(
          alignment: Alignment.centerRight,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: failed),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(height: barHeight, color: IaColors.error),
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(end: success),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => FractionallySizedBox(
            widthFactor: v,
            child: Container(height: barHeight, color: okGreen),
          ),
        ),
        // 成功段前沿刻度：当前位置一眼可读（走满或空盘时不画）
        if (success > 0 && success < 1)
          Align(
            alignment: Alignment(success * 2 - 1, 0),
            child: Container(
              width: 2,
              height: barHeight,
              color: IaColors.textHi,
            ),
          ),
      ]),
    );
  }
}
