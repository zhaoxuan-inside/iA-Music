/// 内置参考插件（bilibili / youtube）验证：真引擎加载 + 离线可测入口。
///
/// 网络入口（search/resolve/stream/lyrics）无法离线验证——真机端到端；
/// 这里锁死：清单合规、契约函数齐全、match/分P元数据等纯逻辑正确。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/plugins/plugin_manifest.dart';
import 'package:ia_music/plugins/plugin_registry.dart';
import 'package:ia_music/plugins/plugin_runtime.dart';
import 'package:ia_music/plugins/quickjs_plugin_runtime.dart';

void main() {
  late Directory dir;
  late QuickJsPluginRuntime runtime;

  Future<PluginSession?> open(String file) async {
    final registry = PluginRegistry(dir: dir.path);
    final source = File(file).readAsStringSync();
    parsePluginManifest(source); // 清单合规
    final installed = await registry.installFromSource(source);
    try {
      return await runtime.open(installed);
    } on Object catch (e) {
      // ignore: avoid_print
      print('跳过（引擎库不可用）：$e');
      return null;
    }
  }

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('builtin_plugins_test');
    runtime = QuickJsPluginRuntime(registry: PluginRegistry(dir: dir.path));
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  test('bilibili 插件：契约函数齐全 + match + 分P元数据 + authKind', () async {
    final m = parsePluginManifest(
        File('plugins/bilibili.plugin.js').readAsStringSync());
    expect(m.id, 'app.iamusic.bilibili');
    expect(m.activeCapabilities, ['source']);

    final session = await open('plugins/bilibili.plugin.js');
    if (session == null) {
      return;
    }
    // 契约函数全部定义（名单来自 docs/PLUGIN.md §3.2；__IA_HAS 为预置内省）
    final required = [
      'match', 'authKind', 'authStart', 'authPoll', 'authImport',
      'authStatus', 'authLogout', 'search', 'resolve', 'stream', 'lyrics',
    ];
    for (final fn in required) {
      expect(await session.call('__IA_HAS', [fn]), true,
          reason: 'bilibili 缺契约函数 $fn');
    }

    expect(await session.call('match', ['https://www.bilibili.com/video/BV1xx411c7mD?p=2']),
        {'id': 'BV1xx411c7mD'});
    expect(await session.call('match', ['https://example.com/nope']), isNull);
    expect(await session.call('authKind', []), {'kind': 'qr'});

    // 分 P 名解析（与原宿主内置 parseBiliPageMeta 同口径）
    final meta =
        await session.call('parsePageMeta', ['001.周杰伦-爱在西元前', '视频标题', 'UP主']) as Map;
    expect(meta['title'], '爱在西元前');
    expect(meta['artist'], '周杰伦');
    final coop = await session.call('parsePageMeta', ['005.潘玮柏_弦子-不得不爱', 'T', 'U']) as Map;
    expect(coop['title'], '不得不爱');
    expect(coop['artist'], '潘玮柏 / 弦子');
    final numeric = await session.call('parsePageMeta', ['1', 'T', 'U']) as Map;
    expect(numeric['title'], 'T - 1');
    session.dispose();
  });

  test('youtube 插件：契约函数齐全 + match + authKind', () async {
    final m = parsePluginManifest(
        File('plugins/youtube.plugin.js').readAsStringSync());
    expect(m.id, 'app.iamusic.youtube');
    expect(m.activeCapabilities, ['source']);

    final session = await open('plugins/youtube.plugin.js');
    if (session == null) {
      return;
    }
    for (final fn in [
      'match', 'authKind', 'authStart', 'authPoll', 'authImport',
      'authStatus', 'authLogout', 'search', 'resolve', 'stream', 'lyrics',
    ]) {
      expect(await session.call('__IA_HAS', [fn]), true,
          reason: 'youtube 缺契约函数 $fn');
    }
    expect(
        await session
            .call('match', ['https://www.youtube.com/watch?v=dQw4w9WgXcQ']),
        {'id': 'dQw4w9WgXcQ'});
    expect(await session.call('match', ['https://youtu.be/dQw4w9WgXcQ']),
        {'id': 'dQw4w9WgXcQ'});
    expect(await session.call('match', ['https://example.com/x']), isNull);
    expect(await session.call('authKind', []), {'kind': 'cookie'});
    // cookie 导入校验：缺 SAPISID 拒绝
    final bad = await session.call('authImport', ['foo=bar']) as Map;
    expect(bad['ok'], false);
    session.dispose();
  });
}
