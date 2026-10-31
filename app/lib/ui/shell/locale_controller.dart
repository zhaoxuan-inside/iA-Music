/// 语言控制器（DEC-005 D5-2 语言三选：中文默认/English/跟随系统）。
/// `appearance.locale` = JSON 字符串 zh|en|system；缺省中文。
/// 切换时同步全局语言包实例（`s.dart` t，服务层消息面用）。
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/l10n/app_localizations.dart';
import 'package:ia_music/l10n/app_localizations_en.dart';
import 'package:ia_music/l10n/app_localizations_zh.dart';
import 'package:ia_music/l10n/s.dart';

const String kAppearanceLocaleKey = 'appearance.locale';

/// 语言三选（D5-2）；名字即持久化值（JSON 字符串）。
enum AppLanguage { system, zh, en }

AppLanguage _langOf(String? raw) {
  switch (raw) {
    case '"en"':
      return AppLanguage.en;
    case '"system"':
      return AppLanguage.system;
    default:
      return AppLanguage.zh; // D5-2：缺省中文
  }
}

/// 跟随系统时的解析：平台语言 en→英文，其余回落中文（D5-2 默认中文）。
bool _platformIsEnglish() =>
    PlatformDispatcher.instance.locale.languageCode == 'en';

AppLocalizations _bundleOf(AppLanguage lang) => switch (lang) {
  AppLanguage.en => AppLocalizationsEn(),
  AppLanguage.system when _platformIsEnglish() => AppLocalizationsEn(),
  _ => AppLocalizationsZh(), // zh 及 system 未匹配 en 的回落
};

final class LocaleController extends ValueNotifier<AppLanguage> {
  LocaleController(this._data, AppLanguage initial) : super(initial) {
    _syncGlobal();
  }

  final DataAccess _data;

  static Future<LocaleController> load(DataAccess data) async {
    final raw = await data.shell.value(kAppearanceLocaleKey);
    return LocaleController(data, _langOf(raw));
  }

  /// 三选切换（即时生效 → 持久化；失败不回滚=下次启动以库为准）。
  Future<void> set(AppLanguage lang) async {
    if (value == lang) return;
    value = lang;
    _syncGlobal();
    await _data.shell.put(
      kAppearanceLocaleKey,
      '"${lang.name}"',
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// MaterialApp locale：system→null 交由平台解析（supportedLocales 内
  /// zh 居首=未匹配时回落中文）；zh/en→显式锁定。
  Locale? get resolvedLocale => switch (value) {
    AppLanguage.system => null,
    AppLanguage.zh => const Locale('zh'),
    AppLanguage.en => const Locale('en'),
  };

  /// 全局语言包同步（服务层 `msg`）。
  void _syncGlobal() {
    msg = _bundleOf(value);
  }
}
