/// MaterialApp 主题装配（唯一入口；纯黑单主题，accent 来自设置）。
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// 构建黑胶金时代主题。[accent] 为用户选定的 WP 色板色值。
ThemeData buildIaTheme({required Color accent}) {
  final p = IaPalette(accent: accent);

  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: p.accent,
    onPrimary: p.onAccent,
    secondary: p.accent,
    onSecondary: p.onAccent,
    surface: p.canvas,
    onSurface: p.textHi,
    surfaceContainerHighest: p.canvas,
    onSurfaceVariant: p.textMid,
    outline: p.hairlineStrong,
    error: p.error,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: p.canvas,
    extensions: [p],
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: IaColors.textHi,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      hintStyle: const TextStyle(color: IaColors.textLow, fontWeight: IaType.light),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: IaColors.hairlineStrong),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: p.accent),
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: IaSpacing.s, vertical: IaSpacing.m),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: IaColors.hairlineStrong,
      thumbColor: p.accent,
      trackHeight: 2,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
    ),
    dividerTheme: DividerThemeData(
        color: IaColors.hairline, thickness: IaSpacing.hairline, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: p.textMid,
      titleTextStyle: TextStyle(
          fontSize: IaType.list, color: IaColors.textHi, fontWeight: IaType.regular),
      subtitleTextStyle: TextStyle(
          fontSize: 12.5, color: IaColors.textMid, fontWeight: IaType.regular),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.accent),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: IaColors.textHi,
        side: const BorderSide(color: IaColors.hairlineStrong),
        shape: const RoundedRectangleBorder(),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        shape: const RoundedRectangleBorder(),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      side: const BorderSide(color: IaColors.hairlineStrong),
      labelStyle: TextStyle(fontSize: 12.5, color: IaColors.textHi),
      shape: const RoundedRectangleBorder(),
    ),
    progressIndicatorTheme:
        ProgressIndicatorThemeData(color: p.accent),
  );
}
