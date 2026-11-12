/// 应用根：主题（品牌绿 + 封面动态取色）、语言、onboarding 门。
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/media_providers.dart';
import '../state/settings_controller.dart';
import '../ui/onboarding/onboarding_page.dart';
import '../ui/shell/app_shell.dart';
import 'theme/app_theme.dart';

class IaApp extends ConsumerWidget {
  const IaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final current = ref.watch(currentTrackProvider);
    final seed = ref.watch(accentSeedProvider(current?.coverPath)).value;

    final locale = switch (settings.locale) {
      LocaleMode.zh => const Locale('zh'),
      LocaleMode.en => const Locale('en'),
      _ => null,
    };

    return MaterialApp(
      title: 'iA Music',
      debugShowCheckedModeBanner: false,
      theme: buildIaTheme(Brightness.light, accentSeed: seed?.withBrightness(false)),
      darkTheme: buildIaTheme(Brightness.dark, accentSeed: seed?.withBrightness(true)),
      themeMode: switch (settings.appearance) {
        AppearanceMode.light => ThemeMode.light,
        AppearanceMode.dark => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: locale,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: settings.onboardingDone ? const AppShell() : const OnboardingPage(),
    );
  }
}

/// 封面主色 seed（饱和度加权采样；无封面/解码失败 → null=品牌绿基板）。
final class AccentSeed {
  const AccentSeed(this.color);

  final Color color;

  /// seed 派生的 accent 在深浅色下观感一致：亮度按端微调由 fromSeed 处理，
  /// 这里只透传色相。
  Color withBrightness(bool dark) => color;
}

final accentSeedProvider = FutureProvider.autoDispose
    .family<AccentSeed?, String?>((ref, coverPath) async {
  if (coverPath == null || coverPath.isEmpty || !File(coverPath).existsSync()) {
    return null;
  }
  try {
    final bytes = await File(coverPath).readAsBytes();
    final codec =
        await ui.instantiateImageCodec(bytes, targetWidth: 24, targetHeight: 24);
    final frame = await codec.getNextFrame();
    final bd = await frame.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    frame.image.dispose();
    codec.dispose();
    if (bd == null) {
      return null;
    }
    final px = bd.buffer.asUint32List();
    double bestScore = -1;
    var r = 0, g = 0, b = 0;
    for (final p in px) {
      final pr = (p >> 16) & 0xFF;
      final pg = (p >> 8) & 0xFF;
      final pb = p & 0xFF;
      final max = [pr, pg, pb].reduce((a, c) => a > c ? a : c);
      final min = [pr, pg, pb].reduce((a, c) => a < c ? a : c);
      final sat = max == 0 ? 0.0 : (max - min) / max;
      final lum = (pr * 0.3 + pg * 0.59 + pb * 0.11) / 255;
      final score = sat * (1 - (lum - 0.55).abs() * 1.6);
      if (score > bestScore) {
        bestScore = score;
        r = pr;
        g = pg;
        b = pb;
      }
    }
    if (bestScore <= 0.12) {
      return null; // 近灰图不抢色
    }
    return AccentSeed(Color.fromARGB(255, r, g, b));
  } on Object {
    return null;
  }
});
