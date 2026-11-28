/// Zune 页面路由：WP「turnstile」翻入转场（demo .scr.enter）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Zune 页面路由：WP「turnstile」翻入转场（demo .scr.enter）。
///
/// 进入：rotateX 62°→0 · scale .96→1 · 透明度 .25→1，0.36s，origin 50% 62%；
/// 返回：同动画倒放（= demo flipOut 0.28s）。黑底画布下底层页不可见也无妨。
PageRouteBuilder<T> zuneRoute<T>({required WidgetBuilder builder}) =>
    PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, _) => builder(context),
      transitionsBuilder: (_, anim, secondary, child) {
        final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return AnimatedBuilder(
          animation: t,
          builder: (_, _) {
            final v = t.value;
            final angle = (1 - v) * 62 * math.pi / 180; // 62° → 0
            final scale = 0.96 + 0.04 * v; // .96 → 1
            return Opacity(
              opacity: 0.25 + 0.75 * v,
              child: Transform(
                alignment: const Alignment(0, 0.24), // origin 50% 62%
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0018) // 透视（轻微近大远小）
                  ..rotateX(angle)
                  ..scaleByDouble(scale, scale, scale, 1),
                child: child,
              ),
            );
          },
        );
      },
    );
