/// 设置域状态：主题色 / 语言 / onboarding（变更即持久化）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/design_tokens.dart';
import '../services/settings/settings_service.dart';
import 'providers.dart';

abstract final class LocaleMode {
  static const system = 'system';
  static const zh = 'zh';
  static const en = 'en';
}

class SettingsState {
  const SettingsState({
    this.accent = kDefaultAccent,
    this.locale = LocaleMode.system,
    this.onboardingDone = false,
    this.loaded = false,
  });

  /// 用户选定的 accent（WP 色板色值）。
  final Color accent;
  final String locale;
  final bool onboardingDone;
  final bool loaded;

  SettingsState copyWith({
    Color? accent,
    String? locale,
    bool? onboardingDone,
    bool? loaded,
  }) =>
      SettingsState(
        accent: accent ?? this.accent,
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
    final accentHex = await _settings.getString(SettingKeys.accent);
    final locale = await _settings.getString(SettingKeys.locale) ?? LocaleMode.system;
    final done = await _settings.getBool(SettingKeys.onboardingDone);
    final accent = _parseAccent(accentHex);
    state = state.copyWith(
      accent: accent,
      locale: locale,
      onboardingDone: done,
      loaded: true,
    );
  }

  /// hex 字符串 → Color；非法回默认 Zune 洋红。
  Color _parseAccent(String? hex) {
    if (hex == null || hex.length < 7) {
      return kDefaultAccent;
    }
    final v = int.tryParse(hex.substring(1), radix: 16);
    return v == null ? kDefaultAccent : Color(0xFF000000 | v);
  }

  Future<void> setAccent(Color color) async {
    state = state.copyWith(accent: color);
    await _settings.setString(SettingKeys.accent, '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}');
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

/// 运行时 accent（主题与全部 accent 色面由此驱动）。
final accentColorProvider =
    Provider<Color>((ref) => ref.watch(settingsProvider).accent);
