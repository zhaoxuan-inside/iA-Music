/// 插件页磁贴墙与配置页冒烟：磁贴渲染 / 返回钮隐藏 / 名称版本分行 / 磁贴点入配置。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/theme/app_theme.dart';
import 'package:ia_music/app/theme/design_tokens.dart';
import 'package:ia_music/plugins/plugin_manifest.dart';
import 'package:ia_music/state/plugin_providers.dart';
import 'package:ia_music/ui/plugins/plugins_page.dart';
import 'package:ia_music/ui/shared/ui_kit.dart';

InstalledPlugin _plugin({
  required String id,
  required String name,
  required String version,
  List<String> caps = const [],
  bool enabled = true,
}) =>
    InstalledPlugin(
      manifest: PluginManifest(
          id: id, name: name, version: version, api: 1, capabilities: caps),
      enabled: enabled,
      installedAt: DateTime(2024, 1, 1),
      filePath: '/p/$id/main.js',
      sha256: '',
    );

/// 假控制器：直接回放给定状态（不触真实注册表）。
class _FakePlugins extends PluginsController {
  _FakePlugins(this.initial);

  final PluginsState initial;

  @override
  PluginsState build() => initial;
}

Widget _app(PluginsState st) => ProviderScope(
      overrides: [
        pluginsProvider.overrideWith(() => _FakePlugins(st)),
        marketUrlProvider.overrideWith((ref) async => ''),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent, brightness: IaBrightness.dark),
        home: const Scaffold(body: PluginsPage()),
      ),
    );

void main() {
  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('插件页 · 磁贴墙：无返回钮，名称/版本分行，禁用压暗标注', (tester) async {
    await phone(tester);
    await tester.pumpWidget(_app(PluginsState(installed: [
      _plugin(
          id: 'src.a',
          name: '演示源',
          version: '1.2.0',
          caps: ['source']),
      _plugin(id: 'tool.b', name: '小工具', version: '0.3.1', enabled: false),
    ])));
    await tester.pump();

    // 后退按钮已删除（WP 式：靠系统返回）
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
    // 两块已装磁贴（source 用音符图标，其余扩展图标）+ 添加磁贴
    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(find.byIcon(Icons.extension), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    // 名称与版本分行显示
    expect(find.text('演示源'), findsOneWidget);
    expect(find.text('v1.2.0'), findsOneWidget);
    expect(find.text('v0.3.1 · 已禁用'), findsOneWidget);
    expect(find.text('添加插件'), findsOneWidget);
  });

  testWidgets('插件页 · 点磁贴进配置页（启停开关 + 卸载行）', (tester) async {
    await phone(tester);
    await tester.pumpWidget(_app(PluginsState(installed: [
      _plugin(
          id: 'src.a',
          name: '演示源',
          version: '1.2.0',
          caps: ['source']),
    ])));
    await tester.pump();

    await tester.tap(find.text('演示源'));
    await tester.pumpAndSettle();

    // 配置页：标题（名称）与副题（版本）分开
    expect(find.text('v1.2.0 · API 1'), findsOneWidget);
    expect(find.byType(WpSwitch), findsOneWidget);
    expect(find.text('已启用'), findsOneWidget);
    expect(find.text('卸载插件'), findsOneWidget);
  });
}
