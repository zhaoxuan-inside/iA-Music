/// SourcePluginHandle.search 测试：关键词默认「分p」后缀 + 结果形状对齐。
///
/// FakeSession 记录发往插件的实参——验证后缀只落在出站关键词上，
/// 且用户已自带「分p」（不分大小写）时不重复追加。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/plugins/plugin_manifest.dart';
import 'package:ia_music/plugins/plugin_registry.dart';
import 'package:ia_music/plugins/plugin_runtime.dart';
import 'package:ia_music/services/collect/source_plugins.dart';

class _RecordingSession implements PluginSession {
  final List<String> searchKeywords = <String>[];
  final List<String> _logs = <String>[];

  @override
  Future<Object?> call(String fn, List<Object?> args, {Duration? timeout}) async {
    if (fn == 'search') {
      searchKeywords.add('${args[0]}');
      return {
        'items': [
          {
            'url': 'https://fake.test/video/BV1',
            'title': '夜曲 分P合集',
            'artist': '测试UP',
            'durationSec': 210,
          },
        ],
      };
    }
    return null;
  }

  @override
  List<String> get logs => _logs;

  @override
  void dispose() {}
}

class _RecordingRuntime implements PluginRuntimePort {
  final _RecordingSession session = _RecordingSession();

  @override
  Future<PluginSession> open(InstalledPlugin plugin) async => session;
}

SourcePluginHandle _handle(PluginRuntimePort runtime) {
  const manifest = PluginManifest(
      id: 'test.rec', name: '记录源', version: '1.0.0', api: 1,
      capabilities: ['source']);
  final plugin = InstalledPlugin(
      manifest: manifest,
      enabled: true,
      installedAt: DateTime(2026),
      filePath: '/tmp/test.rec.plugin.js',
      sha256: 'test');
  return SourcePluginHandle(runtime, plugin);
}

void main() {
  test('search 默认在关键词后追加「分p」发给插件，结果形状照常对齐', () async {
    final runtime = _RecordingRuntime();
    final h = _handle(runtime);

    final items = await h.search('夜曲');

    expect(runtime.session.searchKeywords, ['夜曲分p']);
    expect(items.single['title'], '夜曲 分P合集');
    expect(items.single['durationSec'], 210);
  });

  test('关键词已以「分p」结尾（不分大小写）时原样透传', () async {
    final runtime = _RecordingRuntime();
    final h = _handle(runtime);

    await h.search('夜曲 分P');
    await h.search('夜曲分p');

    expect(runtime.session.searchKeywords, ['夜曲 分P', '夜曲分p']);
  });
}
