/// 插件清单解析测试——静态解析不执行代码；api/字段/id 校验收口。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/plugins/plugin_manifest.dart';

const _valid = '''
/*!
{
  "id": "com.example.src",
  "name": "示例",
  "version": "1.0.0",
  "api": 1,
  "capabilities": ["source"],
  "author": "someone",
  "notes": "n"
}
*/
async function search() { return []; }
''';

void main() {
  test('合法清单：静态提取并校验', () {
    final m = parsePluginManifest(_valid);
    expect(m.id, 'com.example.src');
    expect(m.name, '示例');
    expect(m.version, '1.0.0');
    expect(m.api, 1);
    expect(m.capabilities, ['source']);
    expect(m.activeCapabilities, ['source']);
  });

  test('缺 manifest 块 → 拒绝', () {
    expect(() => parsePluginManifest('async function x(){}'),
        throwsA(isA<PluginManifestException>()));
  });

  test('manifest 不是 JSON 对象 → 拒绝', () {
    expect(() => parsePluginManifest('/* not json */ async function x(){}'),
        throwsA(isA<PluginManifestException>()));
  });

  test('api 版本不匹配 → 拒绝激活', () {
    const src = '''
/*!
{ "id": "com.example.src", "name": "x", "version": "1", "api": 99, "capabilities": ["source"] }
*/
''';
    expect(() => parsePluginManifest(src),
        throwsA(isA<PluginManifestException>()));
  });

  test('缺 capabilities / id 非法 → 拒绝', () {
    const noCaps = '''
/*!
{ "id": "com.example.src", "name": "x", "version": "1", "api": 1 }
*/
''';
    expect(() => parsePluginManifest(noCaps),
        throwsA(isA<PluginManifestException>()));

    const badId = '''
/*!
{ "id": "Bad ID!", "name": "x", "version": "1", "api": 1, "capabilities": ["source"] }
*/
''';
    expect(() => parsePluginManifest(badId),
        throwsA(isA<PluginManifestException>()));
  });

  test('未知能力允许安装但不激活（诚实降级）', () {
    const src = '''
/*!
{ "id": "com.example.src", "name": "x", "version": "1", "api": 1,
  "capabilities": ["source", "hologram"] }
*/
''';
    final m = parsePluginManifest(src);
    expect(m.capabilities, contains('hologram'));
    expect(m.activeCapabilities, ['source']);
  });

  test('manifest 在 4KB 之外被忽略（只读文件头）', () {
    final junk = '/* ${'x' * 5000} */\n';
    expect(() => parsePluginManifest('$junk$_valid'),
        throwsA(isA<PluginManifestException>()));
  });
}
