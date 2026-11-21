/// 插件清单：从 `.plugin.js` 头部注释块**静态解析**（不执行代码）。
///
/// 规范见 docs/PLUGIN.md §1：manifest 必须出现在文件前 4KB 内的
/// `/*! { … } */` 块中；api 版本不匹配则拒绝激活。
library;

import 'dart:convert';

/// 当前宿主支持的桥协议版本（docs/PLUGIN.md）。
const int pluginApiVersion = 1;

/// v1 已知能力；未知能力允许安装但不激活（诚实降级）。
const Set<String> knownCapabilities = {'source'};

class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.api,
    required this.capabilities,
    this.author = '',
    this.homepage = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final String version;

  /// 桥协议版本；宿主只激活 api == [pluginApiVersion] 的插件。
  final int api;
  final List<String> capabilities;
  final String author;
  final String homepage;
  final String notes;

  /// 声明的能力中宿主可激活的部分。
  List<String> get activeCapabilities =>
      capabilities.where(knownCapabilities.contains).toList();

  factory PluginManifest.fromJson(Map<String, Object?> json) {
    final caps = (json['capabilities'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList();
    return PluginManifest(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      version: (json['version'] as String?)?.trim() ?? '',
      api: (json['api'] as num?)?.toInt() ?? 0,
      capabilities: caps,
      author: (json['author'] as String?) ?? '',
      homepage: (json['homepage'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'api': pluginApiVersion,
        'capabilities': capabilities,
        if (author.isNotEmpty) 'author': author,
        if (homepage.isNotEmpty) 'homepage': homepage,
        if (notes.isNotEmpty) 'notes': notes,
      };

  @override
  String toString() => 'PluginManifest($id@$version)';
}

/// 清单解析失败（缺字段 / api 不匹配 / 无 manifest 块）。
class PluginManifestException implements Exception {
  const PluginManifestException(this.message);

  final String message;

  @override
  String toString() => '插件清单无效：$message';
}

/// 从插件源码静态提取 manifest。
///
/// 只读前 4KB，找到第一个 `/*` … `*/` 块并按 JSON 解析——**绝不执行代码**。
/// 失败抛 [PluginManifestException]。
PluginManifest parsePluginManifest(String source) {
  final head = source.length > 4096 ? source.substring(0, 4096) : source;
  final start = head.indexOf('/*');
  if (start < 0) {
    throw const PluginManifestException('缺少 manifest 注释块');
  }
  final end = head.indexOf('*/', start);
  if (end < 0) {
    throw const PluginManifestException('manifest 注释块未闭合');
  }
  var body = head.substring(start + 2, end).trim();
  // 横幅注释惯例 /*! … */ 与普通块注释 /* … */ 都支持
  body = body.replaceFirst(RegExp(r'^[!*]+'), '').trim();
  if (!body.startsWith('{')) {
    throw const PluginManifestException('manifest 注释块不是 JSON 对象');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw PluginManifestException('manifest JSON 解析失败：${e.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw const PluginManifestException('manifest 顶层不是 JSON 对象');
  }
  final m = PluginManifest.fromJson(decoded);
  if (m.id.isEmpty || m.name.isEmpty || m.version.isEmpty) {
    throw const PluginManifestException('id / name / version 必填');
  }
  if (m.api != pluginApiVersion) {
    throw PluginManifestException(
        'api=${m.api} 与宿主 $pluginApiVersion 不匹配（更新插件或宿主）');
  }
  if (!RegExp(r'^[a-z][a-z0-9_.-]*$').hasMatch(m.id)) {
    throw const PluginManifestException(
        'id 必须是反向域名风格（小写字母/数字/点/下划线/连字符）');
  }
  if (m.capabilities.isEmpty) {
    throw const PluginManifestException('capabilities 不能为空');
  }
  return m;
}
