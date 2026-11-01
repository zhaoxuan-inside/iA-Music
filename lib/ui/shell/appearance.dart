/// 外观控制器（DEC-005 主题三选；重写版）。
/// `appearance.theme` = JSON 字符串 dark|light|system；缺省深色。
library;

import 'package:flutter/material.dart';

import 'package:ia_music/data/daos.dart';

const String kAppearanceThemeKey = 'appearance.theme';

ThemeMode _modeOf(String? raw) {
  switch (raw) {
    case '"light"':
      return ThemeMode.light;
    case '"system"':
      return ThemeMode.system;
    default:
      return ThemeMode.dark;
  }
}

final class AppearanceController extends ValueNotifier<ThemeMode> {
  AppearanceController(this._data, ThemeMode initial) : super(initial);

  final DataAccess _data;

  static Future<AppearanceController> load(DataAccess data) async {
    final raw = await data.shell.value(kAppearanceThemeKey);
    return AppearanceController(data, _modeOf(raw));
  }

  /// 三选切换（即时生效 → 持久化；失败不回滚=下次启动以库为准）。
  Future<void> set(ThemeMode mode) async {
    if (value == mode) return;
    value = mode;
    await _data.shell.put(
      kAppearanceThemeKey,
      '"${mode.name}"',
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
