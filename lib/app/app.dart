/// 应用根：纯黑单主题（accent 来自设置）+ 开箱门 + edge-to-edge（曲面屏适配）。
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

class IaApp extends ConsumerStatefulWidget {
  const IaApp({super.key});

  @override
  ConsumerState<IaApp> createState() => _IaAppState();
}

class _IaAppState extends ConsumerState<IaApp> {
  @override
  void initState() {
    super.initState();
    // edge-to-edge：透明系统栏，内容铺满（曲面屏安全区由 SafeArea/edgeInsets 处理）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    // 启动续跑补全：池里有待补曲目就接着跑（进度已落库，中断重启不从头
    // ——兑现「提取与补全进度」页的承诺；空池/运行中由守卫拦住）。
    unawaited(ref.read(enrichProvider.notifier).resumeIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final locale = switch (settings.locale) {
      LocaleMode.zh => const Locale('zh'),
      LocaleMode.en => const Locale('en'),
      _ => null,
    };

    return MaterialApp(
      title: 'iA-Music',
      debugShowCheckedModeBanner: false,
      theme: buildIaTheme(accent: settings.accent),
      darkTheme: buildIaTheme(accent: settings.accent),
      themeMode: ThemeMode.dark,
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
