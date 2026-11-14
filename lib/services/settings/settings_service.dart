/// 壳层 KV 设置（JSON 值，类型化 accessor；解析只在这里）。
library;

import 'dart:convert';

import '../../data/daos/settings_dao.dart';

/// 设置键（集中定义，防散落字符串）。
abstract final class SettingKeys {
  static const appearance = 'appearance'; // system | light | dark
  static const locale = 'locale'; // system | zh | en
  static const onboardingDone = 'onboarding.done';
  static const volume = 'playback.volume';
  static const shuffle = 'playback.shuffle';
  static const repeat = 'playback.repeat'; // off | all | one
  static const session = 'playback.session'; // 会话恢复快照
  static const accent = 'appearance.accent'; // WP 色板色值字符串
}

class SettingsService {
  SettingsService(this._dao);

  final SettingsDao _dao;

  Future<String?> getString(String key) => _dao.valueOf(key);

  Future<void> setString(String key, String value) => _dao.setValue(key, value);

  Future<bool> getBool(String key, {bool fallback = false}) async {
    final raw = await _dao.valueOf(key);
    if (raw == null || raw.isEmpty) {
      return fallback;
    }
    final v = jsonDecode(raw);
    return v is bool ? v : fallback;
  }

  Future<void> setBool(String key, bool value) =>
      _dao.setValue(key, jsonEncode(value));

  Future<double> getDouble(String key, {double fallback = 0}) async {
    final raw = await _dao.valueOf(key);
    if (raw == null || raw.isEmpty) {
      return fallback;
    }
    final v = jsonDecode(raw);
    return v is num ? v.toDouble() : fallback;
  }

  Future<void> setDouble(String key, double value) =>
      _dao.setValue(key, jsonEncode(value));

  Future<Map<String, dynamic>?> getJsonObject(String key) async {
    final raw = await _dao.valueOf(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } on Object {
      return null;
    }
  }

  Future<void> setJsonObject(String key, Map<String, dynamic> value) =>
      _dao.setValue(key, jsonEncode(value));

  Future<void> remove(String key) => _dao.setValue(key, '');
}
