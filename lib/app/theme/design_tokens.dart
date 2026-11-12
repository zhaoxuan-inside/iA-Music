/// 设计 token——全站换肤唯一入口（品牌绿基板，沿用 v1 设计宪章色板）。
library;

import 'package:flutter/material.dart';

/// 深色：画布 #0F1013 → 表面 #1A1B20 → 抬升 #23242B。
/// 浅色：画布 #F5F6F8 / 表面 #FFFFFF / 抬升 #ECEEF1。
/// 红心 #FF5C7A 仅收藏语义，不随封面取色漂移。
@immutable
final class IaPalette extends ThemeExtension<IaPalette> {
  const IaPalette({
    required this.canvas,
    required this.surface,
    required this.lifted,
    required this.mainText,
    required this.secondaryText,
    required this.separator,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
    required this.onAccent,
    required this.heart,
    required this.error,
    required this.isDark,
  });

  final Color canvas;
  final Color surface;
  final Color lifted;
  final Color mainText;
  final Color secondaryText;
  final Color separator;
  final Color accent;
  final Color accentHover;
  final Color accentPressed;
  final Color onAccent;
  final Color heart;
  final Color error;
  final bool isDark;

  static const dark = IaPalette(
    canvas: Color(0xFF0F1013),
    surface: Color(0xFF1A1B20),
    lifted: Color(0xFF23242B),
    mainText: Color(0xFFF4F5F7),
    secondaryText: Color(0xFF9A9CA6),
    separator: Color(0x12FFFFFF),
    accent: Color(0xFF4BE0A3),
    accentHover: Color(0xFF63E8B4),
    accentPressed: Color(0xFF33C48D),
    onAccent: Color(0xFF0F1013),
    heart: Color(0xFFFF5C7A),
    error: Color(0xFFFF6B6B),
    isDark: true,
  );

  static const light = IaPalette(
    canvas: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    lifted: Color(0xFFECEEF1),
    mainText: Color(0xFF17191C),
    secondaryText: Color(0xFF6E747C),
    separator: Color(0x14000000),
    accent: Color(0xFF17A566),
    accentHover: Color(0xFF1EB877),
    accentPressed: Color(0xFF128A52),
    onAccent: Color(0xFFFFFFFF),
    heart: Color(0xFFFF5C7A),
    error: Color(0xFFE05555),
    isDark: false,
  );

  /// 封面动态取色：只覆盖 accent 族，基板色固定。
  factory IaPalette.seeded(Brightness brightness, Color seed) {
    final base = brightness == Brightness.dark ? IaPalette.dark : IaPalette.light;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final hsl = HSLColor.fromColor(scheme.primary);
    Color shift(double delta) => hsl
        .withLightness((hsl.lightness + delta).clamp(0.0, 1.0))
        .toColor();
    return base.copyWith(
      accent: scheme.primary,
      accentHover: shift(brightness == Brightness.dark ? 0.05 : -0.03),
      accentPressed: shift(brightness == Brightness.dark ? -0.05 : 0.03),
      onAccent: scheme.onPrimary,
    );
  }

  @override
  IaPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? lifted,
    Color? mainText,
    Color? secondaryText,
    Color? separator,
    Color? accent,
    Color? accentHover,
    Color? accentPressed,
    Color? onAccent,
    Color? heart,
    Color? error,
    bool? isDark,
  }) =>
      IaPalette(
        canvas: canvas ?? this.canvas,
        surface: surface ?? this.surface,
        lifted: lifted ?? this.lifted,
        mainText: mainText ?? this.mainText,
        secondaryText: secondaryText ?? this.secondaryText,
        separator: separator ?? this.separator,
        accent: accent ?? this.accent,
        accentHover: accentHover ?? this.accentHover,
        accentPressed: accentPressed ?? this.accentPressed,
        onAccent: onAccent ?? this.onAccent,
        heart: heart ?? this.heart,
        error: error ?? this.error,
        isDark: isDark ?? this.isDark,
      );

  @override
  IaPalette lerp(IaPalette? other, double t) {
    if (other == null || t <= 0.02) {
      return this;
    }
    if (t >= 0.98) {
      return other;
    }
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return IaPalette(
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      lifted: c(lifted, other.lifted),
      mainText: c(mainText, other.mainText),
      secondaryText: c(secondaryText, other.secondaryText),
      separator: c(separator, other.separator),
      accent: c(accent, other.accent),
      accentHover: c(accentHover, other.accentHover),
      accentPressed: c(accentPressed, other.accentPressed),
      onAccent: c(onAccent, other.onAccent),
      heart: c(heart, other.heart),
      error: c(error, other.error),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// 间距/圆角/字级 token（UI 禁止裸数字，除布局特例）。
abstract final class IaSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double coverSmall = 48;
  static const double coverGrid = 160;
  static const double radiusS = 6;
  static const double radiusM = 10;
  static const double radiusL = 14;
}

/// context.ia 快捷取色。
extension IaPaletteContext on BuildContext {
  IaPalette get ia =>
      Theme.of(this).extension<IaPalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? IaPalette.dark
          : IaPalette.light);
}
