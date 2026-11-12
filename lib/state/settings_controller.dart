/// 设置域状态：外观 / 语言 / onboarding（变更即持久化）。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings/settings_service.dart';
import 'providers.dart';

abstract final class AppearanceMode {
  static const system = 'system';
  static const light = 'light';
  static const dark = 'dark';
}

abstract final class LocaleMode {
  static const system = 'system';
  static const zh = 'zh';
  static const en = 'en';
}

class SettingsState {
  const SettingsState({
    this.appearance = AppearanceMode.system,
    this.locale = LocaleMode.system,
    this.onboardingDone = false,
    this.loaded = false,
  });

  final String appearance;
  final String locale;
  final bool onboardingDone;
  final bool loaded;

  SettingsState copyWith({
    String? appearance,
    String? locale,
    bool? onboardingDone,
    bool? loaded,
  }) =>
      SettingsState(
        appearance: appearance ?? this.appearance,
        locale: locale ?? this.locale,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        loaded: loaded ?? this.loaded,
      );
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    unawaited(_load());
    return const SettingsState();
  }

  SettingsService get _settings => ref.watch(settingsServiceProvider);

  Future<void> _load() async {
    final appearance =
        await _settings.getString(SettingKeys.appearance) ?? AppearanceMode.system;
    final locale = await _settings.getString(SettingKeys.locale) ?? LocaleMode.system;
    final done = await _settings.getBool(SettingKeys.onboardingDone);
    state = state.copyWith(
      appearance: appearance,
      locale: locale,
      onboardingDone: done,
      loaded: true,
    );
  }

  Future<void> setAppearance(String mode) async {
    state = state.copyWith(appearance: mode);
    await _settings.setString(SettingKeys.appearance, mode);
  }

  Future<void> setLocale(String mode) async {
    state = state.copyWith(locale: mode);
    await _settings.setString(SettingKeys.locale, mode);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingDone: true);
    await _settings.setBool(SettingKeys.onboardingDone, true);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
