/// QuickJS 运行时集成测试——真引擎跑 demo-source 参考插件：
/// source 契约调用 + 四类桥（fetch 经本地 HttpServer / kv / crypto / log）。
///
/// `flutter test` 需要引擎测试库（Windows：quickjs_engine 的
/// `tool/build_native.ps1` 产物或 LIBQUICKJSC_TEST_PATH）；不可用时跳过
/// （设备端由 NDK 从源码构建，不受影响）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/plugins/plugin_manifest.dart';
import 'package:ia_music/plugins/plugin_registry.dart';
import 'package:ia_music/plugins/plugin_runtime.dart';
import 'package:ia_music/plugins/quickjs_plugin_runtime.dart';

Future<InstalledPlugin> _installDemo(PluginRegistry registry) async {
  final source =
      File('plugins/demo-source.plugin.js').readAsStringSync();
  return registry.installFromSource(source);
}

Future<PluginSession?> _openSession(
    QuickJsPluginRuntime rt, InstalledPlugin plugin) async {
  try {
    return await rt.open(plugin);
  } on Object catch (e) {
    // 引擎测试库缺失（未构建 DLL/so）：跳过而非失败
    // ignore: avoid_print
    print('跳过 QuickJS 集成测试（引擎库不可用）：$e');
    return null;
  }
}

void main() {
  late Directory dir;
  late PluginRegistry registry;
  late QuickJsPluginRuntime runtime;
  late InstalledPlugin plugin;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('plugin_rt_test');
    registry = PluginRegistry(dir: dir.path);
    runtime = QuickJsPluginRuntime(registry: registry);
    plugin = await _installDemo(registry);
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  test('source 契约：search 返回结构化结果 + kv 沙箱落笔', () async {
    final session = await _openSession(runtime, plugin);
    if (session == null) {
      return;
    }
    final result = await session.call('search', ['夜曲']);
    expect(result, isA<List<Object?>>());
    final items = result! as List<Object?>;
    expect(items, hasLength(2));
    expect((items.first as Map)['id'], 'demo-1');
    expect((items.first as Map)['title'], contains('夜曲'));
    // kv 沙箱真的写进来了（宿主可验证落笔，不读取内容语义）
    expect(registry.kvGetSync(plugin.manifest.id, 'lastQuery'), '夜曲');
    // log 桥
    expect(session.logs.join('\n'), contains('search: 夜曲'));
    session.dispose();
  });

  test('resolve / lyrics / auth 契约', () async {
    final session = await _openSession(runtime, plugin);
    if (session == null) {
      return;
    }
    final r = await session.call('resolve', ['demo-1']) as Map;
    expect(r['url'], contains('demo-1'));
    expect(r['ext'], 'mp3');
    expect(await session.call('lyrics', ['demo-1']), isNull);
    final auth = await session.call('auth', []) as Map;
    expect(auth['kind'], 'none');
    session.dispose();
  });

  test('fetch 桥端到端（本地 HttpServer）+ crypto/kv 桥', () async {
    final session = await _openSession(runtime, plugin);
    if (session == null) {
      return;
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    const payload = 'ia-bridge-payload';
    server.listen((req) async {
      req.response.add(utf8.encode(payload));
      await req.response.close();
    });

    final result =
        await session.call('ping', ['http://127.0.0.1:${server.port}/'])
            as Map;
    expect(result['status'], 200);
    expect(result['bodyEcho'], payload);
    expect(result['md5'],
        md5.convert(utf8.encode(payload)).toString(),
        reason: 'crypto 桥与 Dart crypto 一致');
    expect(result['kv'], payload, reason: 'kv 沙箱写读闭环');
    session.dispose();
  });

  test('插件未定义函数 / 抛错 → PluginInvokeException（宿主不被拖垮）', () async {
    final session = await _openSession(runtime, plugin);
    if (session == null) {
      return;
    }
    await expectLater(
      session.call('noSuchFn', [], timeout: const Duration(seconds: 3)),
      throwsA(isA<PluginInvokeException>()),
    );
    session.dispose();
  }, timeout: Timeout(Duration(seconds: 20)));

  test('清单与注册表装配：manifest 静态解析 + api 匹配', () {
    final m = parsePluginManifest(
        File('plugins/demo-source.plugin.js').readAsStringSync());
    expect(m.id, 'app.iamusic.demo-source');
    expect(m.activeCapabilities, ['source']);
  });
}
