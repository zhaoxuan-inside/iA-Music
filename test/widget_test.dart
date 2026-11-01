// 产物入口冒烟（DEC-012 Harmonoid 重构后重写）：
// 移动端=4 Tab（曲库/搜索/歌单/设置）+ TRACKS 首页；桌面=侧栏子树导航。
// 真库=内存 SQLite（同一 drift schema，真引擎）。
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/main.dart';
import 'package:ia_music/ui/shell/appearance.dart';
import 'package:ia_music/ui/shell/locale_controller.dart';

void main() {
  testWidgets('入口冒烟：资料库中心壳 + TRACKS 首页（移动端 4 Tab）',
      (WidgetTester tester) async {
    // V1 断点修复后：桌面形态阈值=720，移动 Tab 需真移动宽度。
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final gate = await tester.runAsync(() => openIaDatabaseMemory());
    final db = gate!.db;
    final hub = LibraryHub(db);
    addTearDown(() async {
      await tester.runAsync(() async {
        await hub.dispose();
        await db.close();
      });
    });

    await tester.pumpWidget(IaMusicApp(
        hub: hub,
        readOnlyGate: false,
        appearance: AppearanceController(hub.data, ThemeMode.dark),
        locale: LocaleController(hub.data, AppLanguage.zh)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 全新库 → FTUE 引导（REQ-ONB-01）；跳过后进主壳（两用例共用前置）。
    final onboard = find.byKey(const ValueKey('onboarding_page'));
    if (onboard.evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('onboarding_skip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    // 资料库中心：单曲即首页（D12-3；默认中文=zh，导航文案走 C63 本地化）。
    expect(find.text('单曲'), findsWidgets, reason: '首页=单曲大标题（桌面另有侧栏同名项）');
    // 移动 4 Tab（曲库/搜索/歌单/设置）。
    expect(find.byKey(const ValueKey('nav_library')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_search')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_playlists')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_settings')), findsOneWidget);
    // 空曲库引导（真库 0 行）。
    expect(find.byKey(const ValueKey('tracks_empty')), findsOneWidget);
    // 曲库子面分段器（移动端）。
    expect(find.byKey(const ValueKey('library_segments')), findsOneWidget);
  });

  testWidgets('桌面宽屏：侧栏 LIBRARY 子树 + 大写导航', (tester) async {
    final gate = await tester.runAsync(() => openIaDatabaseMemory());
    final db = gate!.db;
    final hub = LibraryHub(db);
    addTearDown(() async {
      await tester.runAsync(() async {
        await hub.dispose();
        await db.close();
      });
    });
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(IaMusicApp(
        hub: hub,
        readOnlyGate: false,
        appearance: AppearanceController(hub.data, ThemeMode.dark),
        locale: LocaleController(hub.data, AppLanguage.zh)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 全新库 → FTUE：跳过后进桌面壳（与 REQ-ONB-01 行为一致）。
    final onboard = find.byKey(const ValueKey('onboarding_page'));
    if (onboard.evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('onboarding_skip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    // 侧栏子树（D12-3：SEARCH / LIBRARY[TRACKS·ALBUMS·ARTISTS] / PLAYLISTS / SETTINGS）。
    expect(find.byKey(const ValueKey('nav_tracks')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_albums')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_artists')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_playlists')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_search')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_settings')), findsOneWidget);
    expect(find.text('单曲'), findsWidgets);
    // 移动 Tab 栏不在桌面形态。
    expect(find.byKey(const ValueKey('main_tabs')), findsNothing);

    // 子树跳转：ALBUMS。
    await tester.tap(find.byKey(const ValueKey('nav_albums')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('专辑'), findsWidgets, reason: '切到专辑面');
  });
}
