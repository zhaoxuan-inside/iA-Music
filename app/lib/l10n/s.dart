/// C63 i18n 语言包访问面（DEC-005 D5-2：中文默认/English/跟随系统）。
///
/// * UI 层：`sOf(context)`（等价 `AppLocalizations.of(context)`，未挂载时
///   兜底全局实例，直接 pump 子页面的测试不炸）。
/// * 服务层：`PlaybackNotice`/`ExtractStateChanged` 等消息在无 BuildContext
///   的服务里拼装，用全局 [msg]（命名避让 drift 查询惯用的 `(t) =>` lambda）；
///   由 `LocaleController` 启动与切换语言时同步，切语言后新消息即用新语言
///   （存量横幅保持原文，可接受）。
///
/// 应用名与曲目/歌手/专辑/歌单/歌词等内容资产不译（DEC-005 D5-3）。
library;

import 'package:flutter/widgets.dart';

import 'package:ia_music/l10n/app_localizations.dart';
import 'package:ia_music/l10n/app_localizations_zh.dart';

/// 全局当前语言包实例（服务层消息用；初始=中文默认）。
AppLocalizations msg = AppLocalizationsZh();

/// UI 层短别名：取当前上下文语言包，未挂载 Localizations 时兜底全局实例。
AppLocalizations sOf(BuildContext context) =>
    AppLocalizations.of(context) ?? msg;
