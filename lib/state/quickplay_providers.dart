/// Quickplay 状态：固定项持久化在 KV 设置里，UI 只读 state。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/entities/quickplay.dart';
import '../services/settings/settings_service.dart';

class QuickplayState {
  const QuickplayState({this.pins = const [], this.loaded = false});

  final List<QuickplayPin> pins;
  final bool loaded;

  bool isPinned(QuickplayKind kind, String key) =>
      pins.any((p) => p.kind == kind && p.key == key);
}

class QuickplayController extends Notifier<QuickplayState> {
  bool _mutated = false;

  @override
  QuickplayState build() {
    unawaited(_load());
    return const QuickplayState();
  }

  SettingsService get _settings => ref.watch(settingsServiceProvider);

  Future<void> _load() async {
    final raw = await _settings.getJsonObject(SettingKeys.quickplay);
    final list = raw?['pins'];
    final pins = <QuickplayPin>[];
    if (list is List) {
      for (final item in list) {
        Map<String, dynamic>? map;
        if (item is Map<String, dynamic>) {
          map = item;
        } else if (item is Map) {
          map = Map<String, dynamic>.from(item);
        }
        if (map == null) {
          continue;
        }
        final pin = QuickplayPin.fromJson(map);
        if (pin != null) {
          pins.add(pin);
        }
      }
    }
    // 加载期间用户已经钉过：以用户刚钉的为准，避免旧数据覆盖。
    if (!_mutated) {
      state = QuickplayState(pins: pins, loaded: true);
    }
  }

  Future<void> pin(QuickplayPin item) async {
    if (state.isPinned(item.kind, item.key)) {
      return;
    }
    _mutated = true;
    state = QuickplayState(pins: [...state.pins, item], loaded: true);
    await _persist();
  }

  Future<void> unpin(QuickplayKind kind, String key) async {
    _mutated = true;
    state = QuickplayState(
      pins: state.pins
          .where((p) => !(p.kind == kind && p.key == key))
          .toList(),
      loaded: true,
    );
    await _persist();
  }

  Future<void> toggle(QuickplayPin item) async {
    if (state.isPinned(item.kind, item.key)) {
      await unpin(item.kind, item.key);
    } else {
      await pin(item);
    }
  }

  Future<void> _persist() async {
    await _settings.setJsonObject(SettingKeys.quickplay, {
      'pins': state.pins.map((p) => p.toJson()).toList(),
    });
  }
}

final quickplayProvider =
    NotifierProvider<QuickplayController, QuickplayState>(
        QuickplayController.new);
