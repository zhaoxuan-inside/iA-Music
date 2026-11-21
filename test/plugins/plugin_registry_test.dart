/// 插件注册表测试——安装/更新/启停/卸载/凭据沙箱/市场索引（本地 HttpServer）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/plugins/plugin_manifest.dart';
import 'package:ia_music/plugins/plugin_registry.dart';

const _pluginSource = '''
/*!
{ "id": "com.example.src", "name": "示例源", "version": "1.0.0", "api": 1,
  "capabilities": ["source"] }
*/
async function search() { return []; }
''';

void main() {
  late Directory dir;
  late PluginRegistry registry;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('plugin_reg_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    registry = PluginRegistry(dir: dir.path);
  });

  test('安装 → 登记 → 读取源码 → 启停 → 卸载', () async {
    final installed = await registry.installFromSource(_pluginSource);
    expect(installed.enabled, isTrue);
    expect(installed.manifest.id, 'com.example.src');
    expect(installed.sha256,
        sha256.convert(utf8.encode(_pluginSource)).toString());
    expect(File(installed.filePath).existsSync(), isTrue);

    expect((await registry.list()).length, 1);
    expect((await registry.byId('com.example.src'))?.enabled, isTrue);
    expect(registry.loadSource(installed), contains('async function search'));

    await registry.setEnabled('com.example.src', false);
    expect((await registry.byId('com.example.src'))?.enabled, isFalse);

    // 覆盖更新：enabled 保留
    await registry.setEnabled('com.example.src', true);
    final updated = await registry.installFromSource(
        _pluginSource.replaceFirst('1.0.0', '1.1.0'));
    expect(updated.manifest.version, '1.1.0');
    expect(updated.enabled, isTrue);
    expect((await registry.list()).length, 1, reason: '同 id 覆盖而非新增');

    await registry.uninstall('com.example.src');
    expect(await registry.list(), isEmpty);
    expect(File(installed.filePath).existsSync(), isFalse,
        reason: '卸载连 KV 沙箱目录一起删除');
  });

  test('非法源码（无 manifest）→ 拒绝安装', () async {
    expect(() => registry.installFromSource('async function x(){}'),
        throwsA(isA<PluginManifestException>()));
    expect(await registry.list(), isEmpty);
  });

  test('sha256 强校验不匹配 → 拒绝', () async {
    expect(
      () => registry.installFromSource(_pluginSource,
          expectedSha256: 'deadbeef'),
      throwsA(isA<PluginInstallException>()),
    );
  });

  test('凭据沙箱：按插件 id 隔离，写读删', () async {
    await registry.installFromSource(_pluginSource);
    registry.kvSetSync('com.example.src', 'cookie', 'SESSDATA=abc');
    expect(registry.kvGetSync('com.example.src', 'cookie'), 'SESSDATA=abc');

    registry.kvSetSync('com.example.other', 'cookie', 'other-value');
    expect(registry.kvGetSync('com.example.src', 'cookie'), 'SESSDATA=abc',
        reason: '沙箱按 id 隔离');

    registry.kvSetSync('com.example.src', 'cookie', null);
    expect(registry.kvGetSync('com.example.src', 'cookie'), isNull);
    // 卸载删除沙箱文件
    registry.kvSetSync('com.example.other', 'k', 'v');
    await registry.uninstall('com.example.other');
    expect(registry.kvGetSync('com.example.other', 'k'), isNull);
  });

  test('市场：索引拉取 + 安装（sha256 校验走通）', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final base = 'http://127.0.0.1:${server.port}';
    final sha = sha256.convert(utf8.encode(_pluginSource)).toString();
    server.listen((req) async {
      final path = req.uri.path;
      if (path == '/index.json') {
        final index = jsonEncode({
          'api': 1,
          'name': '示例市场',
          'plugins': [
            {
              'id': 'com.example.src',
              'name': '示例源',
              'version': '1.0.0',
              'capabilities': ['source'],
              'file': '$base/com.example.src.plugin.js',
              'sha256': sha,
            }
          ],
        });
        req.response
          ..headers.contentType = ContentType.json
          ..add(utf8.encode(index));
        await req.response.close();
      } else if (path == '/com.example.src.plugin.js') {
        req.response.add(utf8.encode(_pluginSource));
        await req.response.close();
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });

    final (name, entries) = await registry.fetchMarket('$base/index.json');
    expect(name, '示例市场');
    expect(entries, hasLength(1));

    await registry.installFromMarket(entries.single);
    final p = await registry.byId('com.example.src');
    expect(p, isNotNull);
    expect(registry.loadSource(p!), contains('search'));

    // 市场文件被篡改 → sha 校验拒绝
    final (name2, entries2) = await registry.fetchMarket('$base/index.json');
    expect(name2, '示例市场');
    final tampered = MarketEntry(
      id: entries2.single.id,
      name: entries2.single.name,
      version: entries2.single.version,
      capabilities: entries2.single.capabilities,
      fileUrl: entries2.single.fileUrl,
      sha256: 'deadbeef',
    );
    await registry.uninstall('com.example.src');
    expect(
      () => registry.installFromMarket(tampered),
      throwsA(isA<PluginInstallException>()),
    );
  });

  test('市场索引 api 不匹配 → 诚实报错', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      req.response.add(utf8.encode(jsonEncode({'api': 99, 'plugins': []})));
      await req.response.close();
    });
    expect(
      () => registry.fetchMarket('http://127.0.0.1:${server.port}/'),
      throwsA(isA<PluginInstallException>()),
    );
  });
}
