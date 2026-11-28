/// MaterialApp 主题装配（唯一入口；黑/白双态，accent 来自设置）。
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

/// 构建主题。[accent] 为用户选定的 WP 色板色值；[brightness] 定亮/暗态
/// （design_tokens 的 IaColors.apply 由 app 根先行调用——本函数与全部
/// 组件读到的都是同一态）。
ThemeData buildIaTheme(
    {required Color accent, required IaBrightness brightness}) {
  final p = IaPalette(accent: accent);
  final isDark = brightness == IaBrightness.dark;
  final schemeBrightness =
      isDark ? Brightness.dark : Brightness.light;

  final colorScheme = ColorScheme(
    brightness: schemeBrightness,
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
    brightness: schemeBrightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: p.canvas,
    canvasColor: p.canvas,
    extensions: [p],
    // Zune 没有 Material 水波纹：点按只让 accent 微微透出，保持画面安静。
    splashFactory: NoSplash.splashFactory,
    highlightColor: p.accent.withValues(alpha: 0.06),
    hoverColor: p.accent.withValues(alpha: 0.05),
    focusColor: p.accent.withValues(alpha: 0.08),
    iconTheme: IconThemeData(color: p.textMid, size: 22),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: p.textHi,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.canvas,
      modalBackgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
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
      hintStyle: TextStyle(
          color: p.textLow,
          fontWeight: IaType.light),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: p.hairlineStrong),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: p.accent),
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: IaSpacing.s, vertical: IaSpacing.m),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.hairlineStrong,
      thumbColor: p.accent,
      trackHeight: 2,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
    ),
    dividerTheme: DividerThemeData(
        color: p.hairline, thickness: IaSpacing.hairline, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: p.textMid,
      titleTextStyle: TextStyle(
          fontSize: IaType.list, color: p.textHi, fontWeight: IaType.regular),
      subtitleTextStyle: TextStyle(
          fontSize: 14, color: p.textMid, fontWeight: IaType.regular),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.accent),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.textHi,
        side: BorderSide(color: p.hairlineStrong),
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
      side: BorderSide(color: p.hairlineStrong),
      labelStyle: TextStyle(fontSize: 14, color: p.textHi),
      shape: const RoundedRectangleBorder(),
    ),
    progressIndicatorTheme:
        ProgressIndicatorThemeData(color: p.accent),
  );
}
