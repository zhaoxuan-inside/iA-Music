/// 诊断记录：任何来源的未捕获/链路异常 → 记录并持久化，常驻「存储」页可读。
///
/// 背景：真机上错误若只走 toast（2.6s 收回）或 debug 控制台，用户来不及读。
/// 这里把错误钉成持久数据（settings KV），UI 常驻展示 + 可复制可清除。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class DiagEntry {
  const DiagEntry({
    required this.at,
    required this.source,
    required this.detail,
  });

  final DateTime at;
  final String source;
  final String detail;

  Map<String, dynamic> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'source': source,
        'detail': detail,
      };

  static DiagEntry fromJson(Map<String, dynamic> j) => DiagEntry(
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
        source: j['source'] as String? ?? '?',
        detail: j['detail'] as String? ?? '',
      );
}

class DiagnosticsController extends Notifier<DiagEntry?> {
  @override
  DiagEntry? build() {
    _load();
    return null;
  }

  static const _key = 'diag.lastError';

  Future<void> _load() async {
    try {
      final raw = await ref.read(settingsServiceProvider).getString(_key);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final j = jsonDecode(raw) as Map<String, dynamic>;
      state = DiagEntry.fromJson(j);
    } on Object {
      // 诊断自身失败不打扰主流程
    }
  }

  /// 记录一条错误（覆盖上一条；同时持久化，跨重启可读）。
  Future<void> record(String source, Object error, [StackTrace? st]) async {
    final detail = st == null
        ? '$error'
        : '$error\n${st.toString().split('\n').take(6).join('\n')}';
    final entry = DiagEntry(at: DateTime.now(), source: source, detail: detail);
    state = entry;
    try {
      await ref
          .read(settingsServiceProvider)
          .setString(_key, jsonEncode(entry.toJson()));
    } on Object {
      // 持久化失败不阻断
    }
  }

  /// 清除（用户已读/已复制）。
  Future<void> clear() async {
    state = null;
    try {
      await ref.read(settingsServiceProvider).setString(_key, '');
    } on Object {
      // 忽略
    }
  }
}

final diagnosticsProvider =
    NotifierProvider<DiagnosticsController, DiagEntry?>(DiagnosticsController.new);

/// 日志追踪状态：开关 + 追踪期累积的错误条目（上限 200 条，持久化跨重启）。
class TraceLogState {
  const TraceLogState({this.enabled = false, this.entries = const []});

  final bool enabled;
  final List<DiagEntry> entries;

  TraceLogState copyWith({bool? enabled, List<DiagEntry>? entries}) =>
      TraceLogState(
        enabled: enabled ?? this.enabled,
        entries: entries ?? this.entries,
      );
}

/// 日志追踪控制器：开启后所有错误入册，一键复制文本导出。
class TraceLogController extends Notifier<TraceLogState> {
  static const _enabledKey = 'diag.trace.enabled';
  static const _listKey = 'diag.trace.log';
  static const _cap = 200;

  @override
  TraceLogState build() {
    _load();
    return const TraceLogState();
  }

  Future<void> _load() async {
    try {
      final s = ref.read(settingsServiceProvider);
      final enabled = await s.getBool(_enabledKey);
      final raw = await s.getString(_listKey);
      final entries = (raw == null || raw.isEmpty)
          ? const <DiagEntry>[]
          : ((jsonDecode(raw) as List)
              .whereType<Map<String, dynamic>>()
              .map(DiagEntry.fromJson)
              .toList());
      state = TraceLogState(enabled: enabled, entries: entries);
    } on Object {
      // 诊断自身失败不打扰主流程
    }
  }

  Future<void> setEnabled(bool v) async {
    state = state.copyWith(enabled: v);
    try {
      await ref.read(settingsServiceProvider).setBool(_enabledKey, v);
    } on Object {
      // 忽略
    }
  }

  /// 追踪开关开启时记录；关闭期间不采集（错误仍进最近错误诊断）。
  Future<void> record(String source, Object error, [StackTrace? st]) async {
    if (!state.enabled) {
      return;
    }
    final detail = st == null
        ? '$error'
        : '$error\n${st.toString().split('\n').take(6).join('\n')}';
    final entries = [
      ...state.entries,
      DiagEntry(at: DateTime.now(), source: source, detail: detail),
    ];
    if (entries.length > _cap) {
      entries.removeRange(0, entries.length - _cap);
    }
    state = state.copyWith(entries: entries);
    try {
      await ref
          .read(settingsServiceProvider)
          .setString(_listKey, jsonEncode([for (final e in entries) e.toJson()]));
    } on Object {
      // 持久化失败不阻断
    }
  }

  /// 一键复制文本（关于页按钮）。
  String copyText() {
    if (state.entries.isEmpty) {
      return 'iA-Music 日志追踪 · 无错误日志';
    }
    return 'iA-Music 日志追踪 · ${state.entries.length} 条\n'
        '${state.entries.map((e) => '── ${e.at} · ${e.source}\n${e.detail}').join('\n\n')}';
  }

  Future<void> clear() async {
    state = state.copyWith(entries: const []);
    try {
      await ref.read(settingsServiceProvider).setString(_listKey, '');
    } on Object {
      // 忽略
    }
  }
}

final traceLogProvider =
    NotifierProvider<TraceLogController, TraceLogState>(TraceLogController.new);

/// 全局挂钩：Flutter 框架异常 + 未捕获异步异常 → 诊断记录 + 日志追踪。
/// 在 main() 的 ProviderScope 之上调用一次。
void installDiagnostics(ProviderContainer container) {
  void rec(String s, Object e, StackTrace? st) {
    container.read(diagnosticsProvider.notifier).record(s, e, st);
    unawaited(container.read(traceLogProvider.notifier).record(s, e, st));
  }

  FlutterError.onError = (details) {
    rec('Flutter', details.exception, details.stack);
    // 保留默认控制台输出（debug 可见）
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (e, st) {
    // Riverpod 的 ProviderDisposedException = provider 在加载中被停止监听，
    // 是正常生命周期事件（riverpod 自身如此说明），不进诊断打扰用户。
    if (e.runtimeType.toString() == 'ProviderDisposedException') {
      return true;
    }
    rec('未捕获', e, st);
    return true;
  };
}
