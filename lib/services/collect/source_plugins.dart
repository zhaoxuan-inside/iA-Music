/// 音频源插件门面：宿主对 source 能力插件的唯一依赖面。
///
/// 枚举已启用且带 source 能力的插件；每个插件懒开一个沙箱会话，
/// 契约入口（docs/PLUGIN.md §3.2）封装成类型化方法。平台知识 100% 在
/// 插件里，本门面只做「会话管理 + JSON 形状对齐」。
library;

import 'dart:async';

import 'package:ia_music/plugins/plugin_registry.dart';
import 'package:ia_music/plugins/plugin_runtime.dart';

class SourcePluginHandle {
  SourcePluginHandle(this._runtime, this.plugin);

  final PluginRuntimePort _runtime;
  final InstalledPlugin plugin;

  Future<PluginSession>? _sessionFuture;

  String get id => plugin.manifest.id;
  String get name => plugin.manifest.name;

  /// 会话懒开（失败清空可重试；插件文件被删/引擎缺失 → 调用报错）。
  Future<PluginSession> _ensureSession() async {
    _sessionFuture ??= _runtime.open(plugin);
    try {
      return await _sessionFuture!;
    } on Object {
      _sessionFuture = null;
      rethrow;
    }
  }

  Future<Object?> _call(String fn, List<Object?> args, {Duration? timeout}) async {
    final session = await _ensureSession();
    return session.call(fn, args, timeout: timeout);
  }

  Future<Map<String, Object?>?> _callMap(String fn, List<Object?> args,
      {Duration? timeout}) async {
    final r = await _call(fn, args, timeout: timeout);
    return r is Map<String, Object?> ? r : (r as Map<Object?, Object?>?)?.cast<String, Object?>();
  }

  /// URL 归属判定：插件认领 → 返回其 id；不认领/失败 → null。
  Future<String?> match(String url) async {
    final r = await _callMap('match', [url], timeout: const Duration(seconds: 12));
    final id = r?['id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// 元数据 + 全部子曲目（docs/PLUGIN.md §3.2）。
  Future<Map<String, Object?>?> resolve(String url) =>
      _callMap('resolve', [url], timeout: const Duration(seconds: 25));

  /// 音频直链 + 下载所需请求头。
  Future<Map<String, Object?>?> stream(String trackId) =>
      _callMap('stream', [trackId], timeout: const Duration(seconds: 25));

  /// 歌词（{ synced?, plain? }）或 null。
  Future<Map<String, Object?>?> lyrics(String trackId) =>
      _callMap('lyrics', [trackId], timeout: const Duration(seconds: 20));

  Future<List<Map<String, Object?>>> search(String q) async {
    final r = await _callMap('search', [q], timeout: const Duration(seconds: 20));
    final items = r?['items'];
    if (items is! List) {
      return const [];
    }
    return items
        .whereType<Map>()
        .map((m) => m.cast<String, Object?>())
        .toList(growable: false);
  }

  Future<String?> authKind() async {
    final r = await _callMap('authKind', const [], timeout: const Duration(seconds: 8));
    return r?['kind'] as String?;
  }

  Future<Map<String, Object?>?> authStart() =>
      _callMap('authStart', const [], timeout: const Duration(seconds: 15));

  Future<Map<String, Object?>?> authPoll() =>
      _callMap('authPoll', const [], timeout: const Duration(seconds: 15));

  Future<Map<String, Object?>?> authImport(String header) =>
      _callMap('authImport', [header], timeout: const Duration(seconds: 8));

  Future<({bool loggedIn, String account})> authStatus() async {
    final r = await _callMap('authStatus', const [], timeout: const Duration(seconds: 8));
    return (
      loggedIn: r?['loggedIn'] == true,
      account: (r?['account'] as String?) ?? '',
    );
  }

  Future<void> authLogout() async {
    await _call('authLogout', const [], timeout: const Duration(seconds: 8));
  }

  void dispose() {
    final f = _sessionFuture;
    if (f != null) {
      unawaited(f.then((s) => s.dispose()).catchError((Object _) {}));
    }
    _sessionFuture = null;
  }
}

/// 已启用音频源插件的枚举与路由。
class SourcePlugins {
  SourcePlugins(this._registry, this._runtime);

  final PluginRegistry _registry;
  final PluginRuntimePort _runtime;

  final List<SourcePluginHandle> _handles = [];

  /// 枚举已启用且带 source 能力的插件（结果缓存；宿主变更插件后调 [reset]）。
  Future<List<SourcePluginHandle>> enabled() async {
    if (_handles.isEmpty) {
      final all = await _registry.list();
      for (final p in all) {
        if (p.enabled && p.manifest.activeCapabilities.contains('source')) {
          _handles.add(SourcePluginHandle(_runtime, p));
        }
      }
    }
    return List.unmodifiable(_handles);
  }

  /// 插件安装/启停/卸载后调用：下一次枚举重扫注册表。
  void reset() {
    for (final h in _handles) {
      h.dispose();
    }
    _handles.clear();
  }

  Future<SourcePluginHandle?> byId(String id) async {
    for (final h in await enabled()) {
      if (h.id == id) {
        return h;
      }
    }
    return null;
  }

  /// URL → 插件 id 路由：按启用顺序问 match()，第一个认领的胜出。
  Future<String?> routeUrl(String url) async {
    for (final h in await enabled()) {
      try {
        if (await h.match(url) != null) {
          return h.id;
        }
      } on Object {
        // 单插件路由失败不影响其余插件
      }
    }
    return null;
  }
}
