/// iA Music 主题面（DESIGN.md alpha.3「Harmonoid 参照」代码化，DEC-012）。
///
/// 从零重写（D12-2）；全站换肤唯一入口，禁绕过 scheme 的硬编码。
///
/// * 深色（默认）：画布 #0F1013 → 表面 #1A1B20 → 抬升 #23242B。
/// * 浅色：画布 #F5F6F8 / 表面 #FFFFFF / 抬升 #ECEEF1。
/// * 动态取色（D12-6 延续 DEC-011 D11-3）：accent 族由当前播放封面主色
///   seed 经 `ColorScheme.fromSeed` 派生；无 seed=品牌绿基板。
/// * 红心 #FF5C7A 仅收藏语义，不随 seed 漂移。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 色板 token（ThemeExtension 载体；`context.ia` 快捷取用）。
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

  /// 封面 seed 派生（D12-6）：只覆盖 accent 族；基板色固定。
  factory IaPalette.seeded(Brightness brightness, Color seed) {
    final base =
        brightness == Brightness.dark ? IaPalette.dark : IaPalette.light;
    final scheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final hsl = HSLColor.fromColor(scheme.primary);
    final hover = hsl
        .withLightness(
            (hsl.lightness + (brightness == Brightness.dark ? 0.05 : -0.03))
                .clamp(0.0, 1.0))
        .toColor();
    final pressed = hsl
        .withLightness(
            (hsl.lightness + (brightness == Brightness.dark ? -0.05 : 0.03))
                .clamp(0.0, 1.0))
        .toColor();
    return base.copyWith(
      accent: scheme.primary,
      accentHover: hover,
      accentPressed: pressed,
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
    if (other == null) return this;
    if (t < 0.02) return this;
    if (t > 0.98) return other;
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

/// 圆角 token（DESIGN.md alpha.3 Shapes）。
abstract final class IaRadius {
  static const double cover = 16; // 网格卡/播放页大封面
  static const double coverSm = 8; // 列表缩略
  static const double card = 12;
  static const double button = 10;
  static const double input = 12;
  static const double sheet = 20;
  static const double pill = 999;
}

/// 间距步进（4/8/12/16/24/32）。
abstract final class IaSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// 字体族栈。
const List<String> kIaFontFallback = [
  'PingFang SC',
  'HarmonyOS Sans',
  'Microsoft YaHei UI',
  'Noto Sans CJK SC',
];

/// 数字等宽（时间/进度不跳动）。
const List<FontFeature> kIaNumericFeatures = [FontFeature.tabularFigures()];

/// 构建主题（[seed]=封面主色；null=品牌绿基板）。
ThemeData buildIaTheme(Brightness brightness, {Color? seed}) {
  final p = seed == null
      ? (brightness == Brightness.dark ? IaPalette.dark : IaPalette.light)
      : IaPalette.seeded(brightness, seed);
  final isDark = brightness == Brightness.dark;
  final m3 = seed == null
      ? null
      : ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

  TextStyle body(double size, double weight, {Color? color, double? height}) =>
      TextStyle(
        fontSize: size,
        fontWeight: _w(weight),
        color: color ?? p.mainText,
        height: height,
        fontFamilyFallback: kIaFontFallback,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: m3?.primaryContainer ??
          (isDark ? const Color(0xFF123527) : const Color(0xFFD9F4E6)),
      onPrimaryContainer: m3?.onPrimaryContainer ??
          (isDark ? const Color(0xFF4BE0A3) : const Color(0xFF0E3D26)),
      secondary: p.secondaryText,
      onSecondary: p.onAccent,
      secondaryContainer: p.lifted,
      onSecondaryContainer: p.mainText,
      tertiary: p.heart,
      onTertiary: const Color(0xFF0F1013),
      error: p.error,
      onError: isDark ? const Color(0xFF0F1013) : Colors.white,
      surface: p.surface,
      onSurface: p.mainText,
      onSurfaceVariant: p.secondaryText,
      outline: p.separator,
      outlineVariant: p.separator,
      surfaceContainerHighest: p.lifted,
      surfaceContainerHigh: p.lifted,
      surfaceContainer: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainerLowest: p.canvas,
      surfaceTint: Colors.transparent,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xE60F1013),
      inverseSurface: p.lifted,
      onInverseSurface: p.mainText,
      inversePrimary: p.accent,
    ),
    scaffoldBackgroundColor: p.canvas,
    canvasColor: p.canvas,
    dividerColor: p.separator,
    splashFactory: InkSparkle.splashFactory,
    extensions: <ThemeExtension<dynamic>>{p},
    textTheme: TextTheme(
      displaySmall: body(24, 800), // SectionCaps（大写大标题）
      headlineMedium: body(24, 700), // PlayerTitle
      titleMedium: body(15, 600), // SectionTitle
      bodyMedium: body(14, 400, height: 1.5),
      bodySmall: body(12, 400, color: p.secondaryText),
      labelLarge: body(14, 600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: p.mainText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: body(17, 650),
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.canvas,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(IaRadius.card)),
        side: BorderSide(color: p.separator),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        textStyle: body(14, 600),
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        shape: const StadiumBorder(),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) => states
                .contains(WidgetState.pressed)
            ? p.accentPressed
            : p.accentHover),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.mainText,
        textStyle: body(14, 500),
        side: BorderSide(color: p.separator),
        minimumSize: const Size(64, 44),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(IaRadius.button)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        textStyle: body(14, 600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.lifted,
      hintStyle: body(14, 400, color: p.secondaryText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(IaRadius.input)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(IaRadius.input)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(IaRadius.input)),
        borderSide: BorderSide(color: p.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(IaRadius.input)),
        borderSide: BorderSide(color: p.error),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? p.accent : Colors.transparent),
      side: BorderSide(color: p.secondaryText, width: 1.5),
      checkColor: WidgetStateProperty.all(p.onAccent),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.lifted,
      selectedColor: p.accent,
      checkmarkColor: p.onAccent,
      labelStyle: body(13, 500, color: p.mainText),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    progressIndicatorTheme:
        ProgressIndicatorThemeData(color: p.accent, linearTrackColor: p.lifted),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.separator,
      thumbColor: p.mainText,
      overlayColor: const Color(0x1FFFFFFF),
      trackHeight: 3,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.secondaryText,
      textColor: p.mainText,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(IaRadius.card)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.lifted,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(IaRadius.sheet)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.lifted,
      contentTextStyle: body(13, 500),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(IaRadius.card)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.lifted,
      modalBackgroundColor: p.lifted,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(IaRadius.sheet)),
      ),
      showDragHandle: true,
      dragHandleColor: p.secondaryText,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.lifted,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: body(12, 400),
    ),
  );
}

FontWeight _w(double weight) {
  if (weight <= 400) return FontWeight.w400;
  if (weight <= 500) return FontWeight.w500;
  if (weight <= 600) return FontWeight.w600;
  if (weight <= 650) return FontWeight.w600;
  return FontWeight.w700;
}

/// token 快捷取用（`context.ia.accent`）。
extension IaPaletteX on BuildContext {
  IaPalette get ia =>
      Theme.of(this).extension<IaPalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? IaPalette.dark
          : IaPalette.light);
}
