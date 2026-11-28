/// 设计令牌 v3「黑胶金时代」——基板 + WP 经典色板 + 字阶，双态（黑/白）。
///
/// 三分离：本文件是设计配置层；UI 只引用令牌，禁止硬编码色值与字号。
/// 亮/暗两态由 [IaColors.apply] 切换（app 根随外观设置驱动）；
/// accent 用户可自选（WP 色板），持久化于设置。
library;

import 'package:flutter/material.dart';

/// WP 经典色板（配置；首项为默认 accent：Zune 洋红）。
const List<AccentOption> kWpPalette = [
  AccentOption(name: 'Zune 洋红', value: Color(0xFFF1006E)),
  AccentOption(name: '洋红', value: Color(0xFFD80073)),
  AccentOption(name: '经典蓝', value: Color(0xFF1BA1E2)),
  AccentOption(name: '青绿', value: Color(0xFF00ABA9)),
  AccentOption(name: '柠绿', value: Color(0xFFA4C400)),
  AccentOption(name: '绿', value: Color(0xFF008A00)),
  AccentOption(name: '橙', value: Color(0xFFF09609)),
  AccentOption(name: '粉', value: Color(0xFFF472D0)),
  AccentOption(name: '紫', value: Color(0xFFA200FF)),
  AccentOption(name: '红', value: Color(0xFFE51400)),
  AccentOption(name: '棕', value: Color(0xFFA05000)),
];

/// 默认 accent（经典 Zune 软件洋红）。
const Color kDefaultAccent = Color(0xFFF1006E);

class AccentOption {
  const AccentOption({required this.name, required this.value});

  final String name;
  final Color value;
}

/// 外观模式（设置项持久化值）。
abstract final class IaAppearance {
  static const system = 'system';
  static const light = 'light';
  static const dark = 'dark';
}

/// 一组完整基板/文字色值（暗态与亮态各一份）。
class _IaPaletteSet {
  const _IaPaletteSet({
    required this.canvas,
    required this.textHi,
    required this.textMid,
    required this.textLow,
    required this.hairline,
    required this.hairlineStrong,
    required this.onAccent,
    required this.error,
    required this.lyricIdle,
    required this.watermark,
  });

  final Color canvas;
  final Color textHi;
  final Color textMid;
  final Color textLow;
  final Color hairline;
  final Color hairlineStrong;
  final Color onAccent;
  final Color error;
  final Color lyricIdle;
  final Color watermark;
}

/// 暗态（黑胶金时代原初形态）：纯黑基板 + 白字阶。
const _IaPaletteSet _darkSet = _IaPaletteSet(
  canvas: Color(0xFF000000),
  textHi: Color(0xEBFFFFFF),
  textMid: Color(0x8CFFFFFF),
  textLow: Color(0x59FFFFFF),
  hairline: Color(0x0FFFFFFF),
  hairlineStrong: Color(0x24FFFFFF),
  onAccent: Color(0xFFFFFFFF),
  error: Color(0xFFE51400),
  lyricIdle: Color(0x66FFFFFF),
  watermark: Color(0x0BFFFFFF),
);

/// 亮态（WP 白）：纯白基板 + 黑字阶（accent 不变）。
const _IaPaletteSet _lightSet = _IaPaletteSet(
  canvas: Color(0xFFFFFFFF),
  textHi: Color(0xE6000000),
  textMid: Color(0x8C000000),
  textLow: Color(0x59000000),
  hairline: Color(0x1A000000),
  hairlineStrong: Color(0x33000000),
  onAccent: Color(0xFFFFFFFF),
  error: Color(0xFFC80000),
  lyricIdle: Color(0x66000000),
  watermark: Color(0x08000000),
);

/// 基板与文字色阶——当前态的取色出口。
/// 值随 [apply] 切换；调用点语法不变（getter 取代 const 值）。
abstract final class IaColors {
  static IaBrightness _mode = IaBrightness.dark;

  /// 切换亮/暗态（app 根在外观变化与系统亮度变化时调用；调用后需整树重建）。
  static void apply(IaBrightness mode) => _mode = mode;

  static IaBrightness get mode => _mode;

  static _IaPaletteSet get _p => _mode == IaBrightness.light ? _lightSet : _darkSet;

  static Color get canvas => _p.canvas;

  /// 主文字（暗态白 92% / 亮态黑 90%）。
  static Color get textHi => _p.textHi;

  /// 次文字（55%）。
  static Color get textMid => _p.textMid;

  /// 弱文字（35%，只用于可弃信息）。
  static Color get textLow => _p.textLow;

  /// 发丝分隔线。
  static Color get hairline => _p.hairline;

  /// 强分隔（面板描边）。
  static Color get hairlineStrong => _p.hairlineStrong;

  static Color get onAccent => _p.onAccent;
  static Color get error => _p.error;

  /// 歌词非当前行（40%）。
  static Color get lyricIdle => _p.lyricIdle;

  /// 全景背景水印（只作空气感，不参与信息层级）。
  static Color get watermark => _p.watermark;
}

/// 亮度态（独立于 ColorScheme.brightness，供令牌层切换用）。
enum IaBrightness { dark, light }

/// 主题扩展：随 accent 变化的运行时调色板。
@immutable
final class IaPalette extends ThemeExtension<IaPalette> {
  const IaPalette({required this.accent});

  final Color accent;

  Color get canvas => IaColors.canvas;
  Color get textHi => IaColors.textHi;
  Color get textMid => IaColors.textMid;
  Color get textLow => IaColors.textLow;
  Color get hairline => IaColors.hairline;
  Color get hairlineStrong => IaColors.hairlineStrong;
  Color get onAccent => IaColors.onAccent;
  Color get error => IaColors.error;

  /// accent 的暗衬底（长按菜单遮罩、选中底色用透明度而非新色值）。

  @override
  IaPalette copyWith({Color? accent}) => IaPalette(accent: accent ?? this.accent);

  @override
  IaPalette lerp(IaPalette? other, double t) {
    if (other == null || t <= 0.02) {
      return this;
    }
    if (t >= 0.98) {
      return other;
    }
    return IaPalette(accent: Color.lerp(accent, other.accent, t)!);
  }
}

/// 上下文快捷取色。
extension IaPaletteContext on BuildContext {
  IaPalette get ia =>
      Theme.of(this).extension<IaPalette>() ??
      IaPalette(accent: Theme.of(this).colorScheme.primary);
}

/// 字阶（细体大标题是 Metro 的灵魂；尺寸配 IaType.w300/w400/w600 使用）。
///
/// 中小字档对位 WP7 Segoe 字阶按占屏宽折算 412dp 的值
/// （Normal ≈17 / MediumLarge ≈21.7 / Large ≈27.5；大标题档 hub=36 压
/// ExtraLarge 折算值 36.6，hero/display 保持 Metro 灵魂区不动）。
abstract final class IaType {
  static const double display = 56; // 水印 / 仪式页
  static const double hero = 44; // Hub 主标题
  static const double hub = 36; // Hub 页大标题
  static const double page = 30; // 页面大标题
  static const double pivotCur = 26; // pivot 当前项 / 歌词当前行
  static const double pivotIdle = 18; // pivot 非当前项
  static const double list = 16.5; // 列表主文字 / 歌词其他行
  static const double menu = 20; // 长按菜单项

  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight semibold = FontWeight.w600;

  /// 大标题字距：略微收紧，避免细体大字松散。
  static const double titleTracking = -0.4;

  /// 小标题字距：全大写拉丁/kicker 的呼吸感。
  static const double kickerTracking = 2.0;
}

/// 间距与尺寸。
abstract final class IaSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const double coverSmall = 48;

  /// 在播大封面：随屏宽收缩，但不超过 340。
  static const double coverHeroMax = 340;

  /// 封面倒影高度比例（黑胶时代的「桌面倒影」）。
  static const double reflectionRatio = 0.30;

  /// 内容水平安全边距（曲面屏：与左右安全区取大者）。
  static const double gutter = 24;

  /// 迷你条高度 / 进度线厚度 / 分隔厚度。
  static const double progressHairline = 2;
  static const double hairline = 1;

  static const double railLetter = 10.5;
}

/// 动效令牌——Windows Phone 8 默认音乐播放器（Music+Videos Hub / Xbox Music）
/// 的三个招牌动效（调研见 docs/DESIGN.md 动效表）：
///
/// 1. **Turnstile Feather**：pivot 页列表条目绕纵轴依次翻入（Silverlight
///    Toolkit `TurnstileFeatherEffect`：`RotationY` + 每条递增 BeginTime）；
/// 2. **走马灯**：长标题匀速横滚（WP 音乐播放页/迷你条的 ticker）；
/// 3. **Tilt**：按压轻微缩放反馈（黑底无水波纹的等位手感）。
abstract final class IaMotion {
  // ── Turnstile Feather ──
  /// 单条翻入时长。
  static const Duration feather = Duration(milliseconds: 420);

  /// 条目间错峰步长。
  static const Duration featherStep = Duration(milliseconds: 45);

  /// 参与错峰的条目上限（此后并为一拍，长列表滚动不重播）。
  static const int featherMaxItems = 11;

  /// 绕纵轴（Y）起始角（度）。
  static const double featherAngle = 84;

  // ── 走马灯 ──
  /// 横滚速度（px/s）。
  static const double marqueeSpeed = 62;

  /// 起始停顿（看清当前文本再开始滚）。
  static const Duration marqueeLead = Duration(milliseconds: 900);

  /// 尾部停顿（回到起点前喘口气）。
  static const Duration marqueeHold = Duration(milliseconds: 1500);

  // ── Tilt ──
  /// 按压缩放时长。
  static const Duration tilt = Duration(milliseconds: 140);

  /// 按下时的缩放。
  static const double tiltScale = 0.972;

  // ── 切歌文字过渡 ──
  /// 标题/歌手随切歌上滑淡入淡出。
  static const Duration trackSlide = Duration(milliseconds: 220);

  // ── 磁贴翻转（live tile）──
  /// 进页后到首翻的停顿（先看清封面，且晚于 Turnstile Feather 落定）。
  static const Duration tileFlipLead = Duration(milliseconds: 1200);

  /// 单次翻出/翻回时长。
  static const Duration tileFlip = Duration(milliseconds: 620);

  /// 背面停留时长（读完次数/歌名/歌手再翻回）。
  static const Duration tileFlipHold = Duration(milliseconds: 2200);

  /// 翻转周期（每片每周期翻一次，窗口按 [tileFlipStagger] 错峰）。
  static const Duration tileFlipCycle = Duration(seconds: 10);

  /// 相邻磁贴的翻转错峰步长（避免整屏齐翻，WP8 磁贴的错落感）。
  static const Duration tileFlipStagger = Duration(milliseconds: 420);

  /// 参与翻转的磁贴上限（常驻动画成本封顶，超出者恒为正面）。
  static const int tileFlipMaxItems = 12;
}
