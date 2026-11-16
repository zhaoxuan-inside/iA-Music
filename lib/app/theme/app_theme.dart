/// MaterialApp 主题装配（唯一入口；纯黑单主题，accent 来自设置）。
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// 去掉 Android 的拉伸光晕与回弹：Zune 的滚动是干净的、立刻停住的。
class ZuneScrollBehavior extends MaterialScrollBehavior {
  const ZuneScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

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
    canvasColor: p.canvas,
    extensions: [p],
    // Zune 没有 Material 水波纹：点按只让 accent 微微透出，保持画面安静。
    splashFactory: NoSplash.splashFactory,
    highlightColor: p.accent.withValues(alpha: 0.06),
    hoverColor: p.accent.withValues(alpha: 0.05),
    focusColor: p.accent.withValues(alpha: 0.08),
    iconTheme: const IconThemeData(color: IaColors.textMid, size: 22),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: IaColors.textHi,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.black,
      modalBackgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(0),
      thumbVisibility: const WidgetStatePropertyAll(false),
      radius: Radius.zero,
      thumbColor: WidgetStatePropertyAll(p.textLow),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.28),
      selectionHandleColor: p.accent,
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
        backgroundColor: Colors.transparent,
        foregroundColor: p.accent,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: p.accent),
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
