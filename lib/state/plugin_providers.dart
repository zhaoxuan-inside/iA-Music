/// 插件域状态：注册表 / 已装列表 / 市场索引 / 启停与安装操作。
///
/// 注册表是文件式的（无流），状态由 [PluginsController] 显式驱动，
/// 操作完成后重读列表（与 EnrichController 的显式状态风格一致）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../plugins/default_plugins.dart';
import '../plugins/plugin_manifest.dart';
import '../plugins/plugin_registry.dart';
import '../plugins/plugin_runtime.dart';
import '../plugins/quickjs_plugin_runtime.dart';
import 'diagnostics.dart';
import 'providers.dart';

/// 市场索引 URL（可指向自建仓库；默认空 = 未配置市场）。
const String marketUrlKey = 'plugins.market.url';

final pluginRegistryProvider = FutureProvider<PluginRegistry>((ref) async {
  final dirs = await ref.watch(cacheDirsProvider.future);
  final registry = PluginRegistry(dir: dirs.plugins);
  // 默认插件就位（幂等；版本升级覆盖；用户卸载过的跳过）
  final skipRaw =
      await ref.watch(settingsServiceProvider).getString(defaultUninstalledKey) ??
          '[]';
  final skip = (jsonDecode(skipRaw) as List?)
          ?.whereType<String>()
          .toSet() ??
      const <String>{};
  await ensureDefaultPlugins(registry, skip);
  return registry;
});

final pluginRuntimeProvider = FutureProvider<PluginRuntimePort>((ref) async {
  return QuickJsPluginRuntime(registry: await ref.watch(pluginRegistryProvider.future));
});

final marketUrlProvider = FutureProvider<String>((ref) async {
  final settings = ref.watch(settingsServiceProvider);
  return await settings.getString(marketUrlKey) ?? '';
});

class PluginsState {
  const PluginsState({
    this.installed = const [],
    this.market = const [],
    this.marketName = '',
    this.busy = false,
    this.message = '',
  });

  final List<InstalledPlugin> installed;
  final List<MarketEntry> market;
  final String marketName;
  final bool busy;
  final String message;

  PluginsState copyWith({
    List<InstalledPlugin>? installed,
    List<MarketEntry>? market,
    String? marketName,
    bool? busy,
    String? message,
  }) =>
      PluginsState(
        installed: installed ?? this.installed,
        market: market ?? this.market,
        marketName: marketName ?? this.marketName,
        busy: busy ?? this.busy,
        message: message ?? this.message,
      );
}

class PluginsController extends Notifier<PluginsState> {
  @override
  PluginsState build() {
    Future.microtask(_reloadInstalled);
    return const PluginsState();
  }

  Future<void> _reloadInstalled() async {
    final registry = await ref.read(pluginRegistryProvider.future);
    state = state.copyWith(installed: await registry.list());
  }

  /// 操作收口：busy 翻转 + 消息即操作结果 + 异常转诚实文案。
  Future<void> _run(Future<String> Function() op) async {
    state = state.copyWith(busy: true, message: '');
    try {
      final message = await op();
      await _reloadInstalled();
      state = state.copyWith(busy: false, message: message);
    } on PluginManifestException catch (e, st) {
      // 失败进日志追踪——「详见诊断」文案从此名副其实
      unawaited(
          ref.read(diagnosticsProvider.notifier).record('插件管理', e, st));
      state = state.copyWith(busy: false, message: '$e');
    } on PluginInstallException catch (e, st) {
      unawaited(
          ref.read(diagnosticsProvider.notifier).record('插件管理', e, st));
      state = state.copyWith(busy: false, message: '$e');
    } on Object catch (e, st) {
      unawaited(
          ref.read(diagnosticsProvider.notifier).record('插件管理', e, st));
      state = state.copyWith(busy: false, message: '操作失败（详见诊断）');
    }
  }

  /// 扫描插件根目录下的 *.plugin.js 并导入未安装的文件。
  Future<void> importLocal() => _run(() async {
        final registry = await ref.read(pluginRegistryProvider.future);
        final dir = Directory(registry.dir);
        if (!dir.existsSync()) {
          throw const PluginInstallException('插件目录不存在——先把 .plugin.js 放进去');
        }
        var imported = 0;
        for (final f in dir.listSync().whereType<File>()) {
          if (!f.path.endsWith('.plugin.js')) {
            continue;
          }
          final source = f.readAsStringSync();
          final manifest = parsePluginManifest(source); // 不合法 → 整体报错
          if (await registry.byId(manifest.id) == null) {
            await registry.installFromSource(source);
            imported++;
          }
        }
        return imported == 0 ? '没有新的插件文件' : '已导入 $imported 个插件';
      });

  Future<void> installFromMarket(MarketEntry entry) => _run(() async {
        final registry = await ref.read(pluginRegistryProvider.future);
        await registry.installFromMarket(entry);
        return '已安装 ${entry.name} ${entry.version}';
      });

  Future<void> installFromUrl(String url) => _run(() async {
        final registry = await ref.read(pluginRegistryProvider.future);
        await registry.installFromUrl(url);
        return '已从 URL 安装';
      });

  Future<void> setEnabled(String id, bool enabled) => _run(() async {
        final registry = await ref.read(pluginRegistryProvider.future);
        await registry.setEnabled(id, enabled);
        return enabled ? '已启用' : '已禁用';
      });

  Future<void> uninstall(String id) => _run(() async {
        final registry = await ref.read(pluginRegistryProvider.future);
        await registry.uninstall(id);
        // 默认插件卸载记墓碑：启动不再自动回装（用户决定优先）
        if ((await defaultPluginIds()).contains(id)) {
          final settings = ref.read(settingsServiceProvider);
          final raw = await settings.getString(defaultUninstalledKey) ?? '[]';
          final list =
              ((jsonDecode(raw) as List?) ?? []).whereType<String>().toList();
          if (!list.contains(id)) {
            list.add(id);
            await settings.setString(defaultUninstalledKey, jsonEncode(list));
          }
        }
        return '已卸载';
      });

  /// 拉取市场索引并缓存；[url] 记住为默认市场。
  Future<void> refreshMarket(String url) => _run(() async {
        final trimmed = url.trim();
        if (trimmed.isEmpty) {
          throw const PluginInstallException('先配置市场索引 URL');
        }
        final registry = await ref.read(pluginRegistryProvider.future);
        await ref
            .read(settingsServiceProvider)
            .setString(marketUrlKey, trimmed);
        final (name, entries) = await registry.fetchMarket(trimmed);
        state = state.copyWith(market: entries, marketName: name);
        return '市场 ${name.isEmpty ? '' : '「$name」'}共 ${entries.length} 项';
      });
}

final pluginsProvider =
    NotifierProvider<PluginsController, PluginsState>(PluginsController.new);
