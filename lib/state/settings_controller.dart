/// 设置域状态：主题色 / 语言 / onboarding（变更即持久化）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/theme/design_tokens.dart';
import '../services/settings/settings_service.dart';

abstract final class LocaleMode {
  static const system = 'system';
  static const zh = 'zh';
  static const en = 'en';
}

/// 外观模式值（与 IaAppearance 对齐；独立声明避免 state→theme 反向依赖）。
abstract final class AppearanceMode {
  static const system = 'system';
  static const light = 'light';
  static const dark = 'dark';
}

class SettingsState {
  const SettingsState({
    this.accent = kDefaultAccent,
    this.locale = LocaleMode.system,
    this.appearance = AppearanceMode.system,
    this.onboardingDone = false,
    this.loaded = false,
  });

  /// 用户选定的 accent（WP 色板色值）。
  final Color accent;
  final String locale;

  /// 外观模式（system 跟随系统 / light 白天 / dark 黑夜）。
  final String appearance;
  final bool onboardingDone;
  final bool loaded;

  SettingsState copyWith({
    Color? accent,
    String? locale,
    String? appearance,
    bool? onboardingDone,
    bool? loaded,
  }) =>
      SettingsState(
        accent: accent ?? this.accent,
        locale: locale ?? this.locale,
        appearance: appearance ?? this.appearance,
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
    final appearance =
        await _settings.getString(SettingKeys.appearance) ?? AppearanceMode.system;
    final done = await _settings.getBool(SettingKeys.onboardingDone);
    final accent = _parseAccent(accentHex);
    state = state.copyWith(
      accent: accent,
      locale: locale,
      appearance: appearance,
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
    await _settings.setString(SettingKeys.accent, '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}');
  }

  /// 取色拖动中的即时预览：只改内存态不落盘（松手由 [setAccent] 持久化）。
  void previewAccent(Color color) {
    state = state.copyWith(accent: color);
  }

  Future<void> setLocale(String mode) async {
    state = state.copyWith(locale: mode);
    await _settings.setString(SettingKeys.locale, mode);
  }

  Future<void> setAppearance(String mode) async {
    state = state.copyWith(appearance: mode);
    await _settings.setString(SettingKeys.appearance, mode);
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
