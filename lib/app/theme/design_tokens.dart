/// 设计令牌 v3「黑胶金时代」——纯黑基板 + WP 经典色板 + 字阶。
///
/// 三分离：本文件是设计配置层；UI 只引用令牌，禁止硬编码色值与字号。
/// 纯黑单主题（不做浅色）；accent 用户可自选（WP 色板），持久化于设置。
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

/// 基板与文字色阶（恒定常量，不随 accent 变化）。
abstract final class IaColors {
  static const Color canvas = Color(0xFF000000);

  /// 主文字：白 92%。
  static const Color textHi = Color(0xEBFFFFFF);

  /// 次文字：白 55%。
  static const Color textMid = Color(0x8CFFFFFF);

  /// 弱文字：白 35%（只用于可弃信息）。
  static const Color textLow = Color(0x59FFFFFF);

  /// 发丝分隔线：白 6%。
  static const Color hairline = Color(0x0FFFFFFF);

  /// 强分隔（暗态面板描边）：白 14%。
  static const Color hairlineStrong = Color(0x24FFFFFF);

  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFE51400);

  /// 歌词非当前行：白 40%。
  static const Color lyricIdle = Color(0x66FFFFFF);
}

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
  Color get accentDim => accent.withValues(alpha: 0.16);

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
abstract final class IaType {
  static const double hero = 44; // Hub 主标题
  static const double page = 28; // 页面大标题
  static const double pivotCur = 24; // pivot 当前项
  static const double pivotIdle = 16; // pivot 非当前项
  static const double list = 15; // 列表主文字
  static const double lyricCur = 20; // 歌词当前行
  static const double menu = 18; // 长按菜单项

  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight semibold = FontWeight.w600;
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
  static const double coverDetail = 120;
  static const double coverNp = 280;

  /// 内容水平安全边距（曲面屏：与左右安全区取大者）。
  static const double gutter = 24;

  /// 迷你条高度 / 进度线厚度 / 分隔厚度。
  static const double miniHeight = 56;
  static const double progressHairline = 2;
  static const double hairline = 1;

  static const double radiusS = 2;
  static const double railLetter = 9.5;
}
