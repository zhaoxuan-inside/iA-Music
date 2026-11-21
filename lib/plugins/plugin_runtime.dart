/// 插件运行时端口：宿主对沙箱的唯一依赖面。
///
/// 一个会话 = 一个插件实例（独立引擎实例，互不可见）。调用 = 触发插件
/// 全局 async 函数并等待其 Promise 落定（docs/PLUGIN.md §2/§3）。
library;

import 'plugin_registry.dart';

class PluginInvokeException implements Exception {
  const PluginInvokeException(this.message);

  final String message;

  @override
  String toString() => '插件调用失败：$message';
}

/// 已打开的插件会话。
abstract class PluginSession {
  /// 调用插件全局函数 [fn]（参数 JSON 化），等待 Promise 落定并返回结果。
  /// 插件抛错 / 超时 / 返回不可序列化值 → [PluginInvokeException]。
  Future<Object?> call(String fn, List<Object?> args, {Duration? timeout});

  /// 本次会话内插件经 IA.log 输出的日志（诊断用）。
  List<String> get logs;

  void dispose();
}

/// 运行时工厂。宿主只依赖这个端口；QuickJS 实现可替换。
abstract class PluginRuntimePort {
  Future<PluginSession> open(InstalledPlugin plugin);
}
