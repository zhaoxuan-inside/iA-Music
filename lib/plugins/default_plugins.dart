/// 默认插件：随包分发的 `.plugin.js` 资产，启动时自动安装进注册表。
///
/// 语义（docs/PLUGIN.md §4）：
/// * 未安装 → 安装；随包版本更高 → 覆盖升级（启用态与凭据沙箱保留）；
/// * 用户卸载过的默认插件记入墓碑（settings），不再自动回装——
///   卸载是用户决定，升级不打扰。
/// * 平台知识仍在插件文件里（数据而非编译代码），可整文件替换升级。
library;

import 'package:flutter/services.dart' show rootBundle;

import 'plugin_manifest.dart';
import 'plugin_registry.dart';

/// 随包分发的默认插件资产路径（pubspec `flutter.assets` 同步声明）。
const List<String> defaultPluginAssets = [
  'plugins/bilibili.plugin.js',
  'plugins/youtube.plugin.js',
  'plugins/jamendo.plugin.js',
  'plugins/internetarchive.plugin.js',
  'plugins/audius.plugin.js',
  'plugins/librivox.plugin.js',
  'plugins/podcast.plugin.js',
  'plugins/subsonic.plugin.js',
];

/// 设置键：用户卸载过的默认插件 id（JSON 数组）。
const String defaultUninstalledKey = 'plugins.default.uninstalled';

/// 确保默认插件就位（幂等；失败单插件隔离——一个坏资产不拖垮其余）。
///
/// [uninstalledIds] 为墓碑（用户卸载过的默认插件 id，跳过不回装）。
/// 返回本次实际安装/升级的插件 id。
Future<List<String>> ensureDefaultPlugins(
    PluginRegistry registry, Set<String> uninstalledIds) async {
  final changed = <String>[];
  for (final asset in defaultPluginAssets) {
    try {
      final source = await rootBundle.loadString(asset);
      final manifest = parsePluginManifest(source);
      if (uninstalledIds.contains(manifest.id)) {
        continue;
      }
      final existing = await registry.byId(manifest.id);
      if (existing == null ||
          compareVersions(manifest.version, existing.manifest.version) > 0) {
        await registry.installFromSource(source);
        changed.add(manifest.id);
      }
    } on Object {
      // 单个默认资产缺失/损坏不阻断启动；其余插件照常安装
    }
  }
  return changed;
}

/// 默认插件 id 清单（从资产 manifest 读取；损坏资产跳过）。
Future<Set<String>> defaultPluginIds() async {
  final ids = <String>{};
  for (final asset in defaultPluginAssets) {
    try {
      ids.add(parsePluginManifest(await rootBundle.loadString(asset)).id);
    } on Object {
      // 资产缺失/损坏：不参与墓碑判定
    }
  }
  return ids;
}

/// semver 三段比较：a>b → 1，a<b → -1，相等 → 0（缺段按 0）。
int compareVersions(String a, String b) {
  final as = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final bs = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final av = i < as.length ? as[i] : 0;
    final bv = i < bs.length ? bs[i] : 0;
    if (av != bv) {
      return av > bv ? 1 : -1;
    }
  }
  return 0;
}
