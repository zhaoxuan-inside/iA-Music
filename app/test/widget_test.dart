// 产物入口冒烟（DEC-012 Harmonoid 重构后重写）：
// 移动端=4 Tab（曲库/搜索/歌单/设置）+ TRACKS 首页；桌面=侧栏子树导航。
// 真库=内存 SQLite（同一 drift schema，真引擎）。
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/main.dart';
import 'package:ia_music/ui/shell/appearance.dart';

void main() {
  testWidgets('入口冒烟：资料库中心壳 + TRACKS 首页（移动端 4 Tab）',
      (WidgetTester tester) async {
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
        appearance: AppearanceController(hub.data, ThemeMode.dark)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 资料库中心：TRACKS 即首页（D12-3）。
    expect(find.text('TRACKS'), findsWidgets, reason: '首页=TRACKS 大写标题（桌面另有侧栏同名项）');
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
        appearance: AppearanceController(hub.data, ThemeMode.dark)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 侧栏子树（D12-3：SEARCH / LIBRARY[TRACKS·ALBUMS·ARTISTS] / PLAYLISTS / SETTINGS）。
    expect(find.byKey(const ValueKey('nav_tracks')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_albums')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_artists')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_playlists')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_search')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_settings')), findsOneWidget);
    expect(find.text('TRACKS'), findsWidgets);
    // 移动 Tab 栏不在桌面形态。
    expect(find.byKey(const ValueKey('main_tabs')), findsNothing);

    // 子树跳转：ALBUMS。
    await tester.tap(find.byKey(const ValueKey('nav_albums')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('ALBUMS'), findsWidgets, reason: '切到专辑面');
  });
}
