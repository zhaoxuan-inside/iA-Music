/// 插件注册表：文件式存储（docs/PLUGIN.md §5），无数据库迁移负担。
///
/// 布局：
/// ```
/// <dir>/registry.json        # 已装清单（manifest + enabled + installedAt + file）
/// <dir>/<id>/main.js         # 插件代码
/// <dir>/<id>/kv.json         # 凭据沙箱（宿主只代存，不读取不展示）
/// ```
/// 安装来源：本地文件 / 源码串 / URL / 市场索引。安装一律**静态校验**
/// manifest（不执行代码），sha256 可选强校验。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'plugin_manifest.dart';

class InstalledPlugin {
  const InstalledPlugin({
    required this.manifest,
    required this.enabled,
    required this.installedAt,
    required this.filePath,
    required this.sha256,
  });

  final PluginManifest manifest;
  final bool enabled;
  final DateTime installedAt;

  /// main.js 绝对路径。
  final String filePath;

  /// 安装时源码哈希（市场更新比对用）。
  final String sha256;

  Map<String, Object?> toJson() => {
        ...manifest.toJson(),
        'enabled': enabled,
        'installedAt': installedAt.toIso8601String(),
        'file': filePath,
        'sha256': sha256,
      };

  static InstalledPlugin fromJson(Map<String, Object?> json) {
    final m = PluginManifest.fromJson(json);
    return InstalledPlugin(
      manifest: m,
      enabled: json['enabled'] as bool? ?? true,
      installedAt:
          DateTime.tryParse(json['installedAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      filePath: json['file'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
    );
  }
}

/// 市场索引条目（docs/PLUGIN.md §4）。
class MarketEntry {
  const MarketEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.capabilities,
    required this.fileUrl,
    this.sha256 = '',
    this.homepage = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final String version;
  final List<String> capabilities;
  final String fileUrl;
  final String sha256;
  final String homepage;
  final String notes;

  static MarketEntry fromJson(Map<String, Object?> json) => MarketEntry(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        version: json['version'] as String? ?? '',
        capabilities: (json['capabilities'] as List<Object?>? ?? const [])
            .whereType<String>()
            .toList(),
        fileUrl: json['file'] as String? ?? '',
        sha256: json['sha256'] as String? ?? '',
        homepage: json['homepage'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}

class PluginInstallException implements Exception {
  const PluginInstallException(this.message);

  final String message;

  @override
  String toString() => '插件安装失败：$message';
}

class PluginRegistry {
  PluginRegistry({required this.dir});

  /// 插件根目录（`<applicationSupport>`/plugins）。
  final String dir;

  File get _registryFile =>
      File('$dir${Platform.pathSeparator}registry.json');

  Future<List<InstalledPlugin>> list() async {
    if (!_registryFile.existsSync()) {
      return const [];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(_registryFile.readAsStringSync());
    } on FormatException {
      return const [];
    }
    final plugins = (decoded as Map<String, Object?>?)?['plugins'];
    if (plugins is! List<Object?>) {
      return const [];
    }
    return plugins
        .whereType<Map<String, Object?>>()
        .map(InstalledPlugin.fromJson)
        .toList(growable: false);
  }

  Future<InstalledPlugin?> byId(String id) async =>
      (await list()).where((p) => p.manifest.id == id).firstOrNull;

  /// 从源码串安装（本地文件导入与市场下载的公共收口）。
  ///
  /// [expectedSha256] 非空时强校验（市场索引提供）。同 id 覆盖更新，
  /// 更新要求清单 id 一致（安全：文件内容决定装到哪，不靠请求方声称）。
  Future<InstalledPlugin> installFromSource(String source,
      {String? expectedSha256}) async {
    final manifest = parsePluginManifest(source);
    final sha = sha256.convert(utf8.encode(source)).toString();
    if (expectedSha256 != null &&
        expectedSha256.isNotEmpty &&
        expectedSha256 != sha) {
      throw const PluginInstallException('sha256 校验不匹配（市场索引 vs 实际文件）');
    }

    final pluginDir = Directory(
        '$dir${Platform.pathSeparator}${manifest.id}');
    pluginDir.createSync(recursive: true);
    final file = File(
        '${pluginDir.path}${Platform.pathSeparator}main.js');
    file.writeAsStringSync(source, flush: true);

    final existing = await byId(manifest.id);
    final entry = InstalledPlugin(
      manifest: manifest,
      enabled: existing?.enabled ?? true,
      installedAt: existing?.installedAt ?? DateTime.now(),
      filePath: file.path,
      sha256: sha,
    );
    await _upsert(entry);
    return entry;
  }

  Future<InstalledPlugin> installFromFile(String path) {
    final f = File(path);
    if (!f.existsSync()) {
      throw PluginInstallException('文件不存在：$path');
    }
    return installFromSource(f.readAsStringSync());
  }

  Future<InstalledPlugin> installFromUrl(String url) async {
    final source = await _httpGet(url);
    return installFromSource(source);
  }

  /// 市场安装收口：按条目下载 → sha256 强校验 → 登记。
  Future<InstalledPlugin> installFromMarket(MarketEntry entry) async {
    final source = await _httpGet(entry.fileUrl);
    return installFromSource(source, expectedSha256: entry.sha256);
  }

  /// 拉取市场索引（api 版本必须匹配宿主）。
  Future<(String, List<MarketEntry>)> fetchMarket(String url) async {
    final body = await _httpGet(url);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const PluginInstallException('市场索引不是合法 JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const PluginInstallException('市场索引顶层不是 JSON 对象');
    }
    if (decoded['api'] != pluginApiVersion) {
      throw PluginInstallException(
          '市场索引 api=${decoded['api']} 与宿主 $pluginApiVersion 不匹配');
    }
    final plugins = (decoded['plugins'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(MarketEntry.fromJson)
        .where((e) => e.id.isNotEmpty && e.fileUrl.isNotEmpty)
        .toList(growable: false);
    // 缓存原始索引（市场页展示用）
    File('$dir${Platform.pathSeparator}market.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(body, flush: true);
    return (decoded['name'] as String? ?? '', plugins);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final p = await byId(id);
    if (p == null) {
      throw PluginInstallException('未安装：$id');
    }
    await _upsert(InstalledPlugin(
      manifest: p.manifest,
      enabled: enabled,
      installedAt: p.installedAt,
      filePath: p.filePath,
      sha256: p.sha256,
    ));
  }

  /// 卸载：删除插件目录（代码 + KV 沙箱）并注销。
  Future<void> uninstall(String id) async {
    final pluginDir = Directory('$dir${Platform.pathSeparator}$id');
    if (pluginDir.existsSync()) {
      pluginDir.deleteSync(recursive: true);
    }
    final rest = (await list())
        .where((p) => p.manifest.id != id)
        .map((p) => p.toJson())
        .toList();
    _writeRegistry(rest);
  }

  /// 读插件源码（运行时加载入口）。
  String loadSource(InstalledPlugin p) {
    final f = File(p.filePath);
    if (!f.existsSync()) {
      throw PluginInstallException('插件文件缺失：${p.manifest.id}');
    }
    return f.readAsStringSync();
  }

  // ── 凭据沙箱（每插件独立 KV；宿主只代存不解析） ──────────────────────
  // 同步 API：插件运行时的消息通道回调是同步的，KV 读写必须即刻返回。

  File _kvFile(String id) => File(
      '$dir${Platform.pathSeparator}$id${Platform.pathSeparator}kv.json');

  String? kvGetSync(String id, String key) {
    final f = _kvFile(id);
    if (!f.existsSync()) {
      return null;
    }
    final map = jsonDecode(f.readAsStringSync()) as Map<String, Object?>?;
    return map?[key] as String?;
  }

  void kvSetSync(String id, String key, String? value) {
    final f = _kvFile(id);
    f.parent.createSync(recursive: true);
    final map = f.existsSync()
        ? (jsonDecode(f.readAsStringSync()) as Map<String, Object?>?)
        : null;
    final kv = <String, Object?>{...?map};
    if (value == null) {
      kv.remove(key);
    } else {
      kv[key] = value;
    }
    f.writeAsStringSync(jsonEncode(kv), flush: true);
  }

  // ── 内部 ──────────────────────────────────────────────────────────

  Future<void> _upsert(InstalledPlugin entry) async {
    final rest = (await list())
        .where((p) => p.manifest.id != entry.manifest.id)
        .map((p) => p.toJson())
        .toList();
    rest.add(entry.toJson());
    _writeRegistry(rest);
  }

  void _writeRegistry(List<Map<String, Object?>> plugins) {
    _registryFile.parent.createSync(recursive: true);
    _registryFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({'plugins': plugins}),
        flush: true);
  }

  Future<String> _httpGet(String url) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close().timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) {
        throw PluginInstallException('下载失败 HTTP ${resp.statusCode}：$url');
      }
      return await resp.transform(utf8.decoder).join();
    } on TimeoutException {
      throw PluginInstallException('下载超时：$url');
    } on SocketException catch (e) {
      throw PluginInstallException('网络不可达：${e.message}');
    } finally {
      client.close();
    }
  }
}
