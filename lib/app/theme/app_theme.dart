/// MaterialApp 主题装配（唯一入口；全站禁止绕过 scheme 的硬编码色）。
library;

import 'package:flutter/material.dart';

import '../../state/settings_controller.dart';
import 'design_tokens.dart';

ThemeData buildIaTheme(Brightness brightness, {Color? accentSeed}) {
  final palette =
      accentSeed == null ? null : IaPalette.seeded(brightness, accentSeed);
  final base = brightness == Brightness.dark ? IaPalette.dark : IaPalette.light;
  final p = palette ?? base;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: p.lifted,
    onPrimaryContainer: p.mainText,
    secondary: p.accent,
    onSecondary: p.onAccent,
    surface: p.surface,
    onSurface: p.mainText,
    surfaceContainerHighest: p.lifted,
    onSurfaceVariant: p.secondaryText,
    outline: p.separator,
    error: p.error,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: p.canvas,
    extensions: [p],
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: p.canvas,
      foregroundColor: p.mainText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.canvas,
      indicatorColor: p.accent.withValues(alpha: 0.16),
      iconTheme: WidgetStateProperty.resolveWith((states) =>
          IconThemeData(color: states.contains(WidgetState.selected) ? p.accent : p.secondaryText)),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: p.secondaryText, fontWeight: FontWeight.w500),
      ),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IaSpacing.radiusM),
        side: BorderSide(color: p.separator),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      hintStyle: TextStyle(color: p.secondaryText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(IaSpacing.radiusM),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: IaSpacing.l, vertical: IaSpacing.m),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.lifted,
      thumbColor: p.accent,
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
    ),
    dividerTheme: DividerThemeData(color: p.separator, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.lifted,
      contentTextStyle: TextStyle(color: p.mainText),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(IaSpacing.radiusM)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.secondaryText,
      titleTextStyle: TextStyle(fontSize: 15, color: p.mainText, fontWeight: FontWeight.w500),
      subtitleTextStyle: TextStyle(fontSize: 12.5, color: p.secondaryText),
    ),
  );
}

/// 外观模式 → 亮度。
Brightness brightnessOf(String appearance, Brightness system) => switch (appearance) {
      AppearanceMode.light => Brightness.light,
      AppearanceMode.dark => Brightness.dark,
      _ => system,
    };
