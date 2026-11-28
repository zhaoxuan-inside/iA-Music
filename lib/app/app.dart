/// 应用根：黑/白双态主题（accent 与外观来自设置）+ 开箱门 +
/// edge-to-edge（曲面屏适配）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/enrich_controller.dart';
import '../state/settings_controller.dart';
import '../ui/onboarding/onboarding_page.dart';
import '../ui/shell/hub_shell.dart';
import 'theme/app_theme.dart';
import 'theme/design_tokens.dart';

class IaApp extends ConsumerStatefulWidget {
  const IaApp({super.key});

  @override
  ConsumerState<IaApp> createState() => _IaAppState();
}

class _IaAppState extends ConsumerState<IaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // edge-to-edge：透明系统栏，内容铺满（曲面屏安全区由 SafeArea/edgeInsets 处理）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 启动续跑补全：池里有待补曲目就接着跑（进度已落库，中断重启不从头
    // ——兑现「歌曲处理」页的承诺；空池/运行中由守卫拦住）。
    unawaited(ref.read(enrichProvider.notifier).resumeIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 系统亮度变化（外观=跟随系统时）→ 令牌态切换 + 整树重建。
  @override
  void didChangePlatformBrightness() {
    setState(_applyEffectiveTokens);
  }

  /// 依据外观设置与系统亮度，把令牌态切到当前值（build 前调用——
  /// 所有组件的 build 都在本次帧里读到同一态）。
  void _applyEffectiveTokens() {
    final appearance = ref.read(settingsProvider).appearance;
    final systemDark = WidgetsBinding
            .instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final light = appearance == AppearanceMode.light ||
        (appearance == AppearanceMode.system && !systemDark);
    IaColors.apply(
        light ? IaBrightness.light : IaBrightness.dark);
    // 系统栏图标随态：暗态用亮图标，亮态用暗图标。
    final icon = light ? Brightness.dark : Brightness.light;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: icon,
      systemNavigationBarIconBrightness: icon,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    _applyEffectiveTokens();
    final locale = switch (settings.locale) {
      LocaleMode.zh => const Locale('zh'),
      LocaleMode.en => const Locale('en'),
      _ => null,
    };
    final themeMode = switch (settings.appearance) {
      AppearanceMode.light => ThemeMode.light,
      AppearanceMode.dark => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp(
      title: 'iA-Music',
      debugShowCheckedModeBanner: false,
      theme: buildIaTheme(
          accent: settings.accent, brightness: IaBrightness.light),
      darkTheme: buildIaTheme(
          accent: settings.accent, brightness: IaBrightness.dark),
      themeMode: themeMode,
      scrollBehavior: const ZuneScrollBehavior(),
      locale: locale,
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: !settings.loaded
          ? const SizedBox.shrink()
          : settings.onboardingDone
              ? const HubShell()
              : const OnboardingPage(),
    );
  }
}
