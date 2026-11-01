// 搜索页复现测试（「不能搜索」缺陷排查，2026-10-25）：
// 本地模式输入 → 防抖后出结果；B站模式切换 → 触发搜索不抛。

// ignore: unnecessary_import
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/l10n/app_localizations.dart';
import 'package:ia_music/ui/shell/appearance.dart';
import 'package:ia_music/ui/shell/app_shell.dart';
import 'package:ia_music/ui/shell/locale_controller.dart';

void main() {
  late IaDatabase db;
  late LibraryHub hub;

  setUp(() async {
    final gate = await openIaDatabaseMemory();
    db = gate.db;
    hub = LibraryHub(db);
    final rootId = await db.into(db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(
            path: 'C:/tmp/lib',
            mode: RepositoryMode.directory,
            addedAt: 1,
          ),
        );
    await hub.data.library.insertTrackWithIndex(
      rootId,
      '夜黑雾.mp3',
      mtime: 1,
      fileSize: 1,
      contentHash: 'h1',
      nowMs: 1,
      title: '夜黑雾',
      artistDisplay: '测试歌手',
      durationMs: 200000,
    );
  });

  tearDown(() async {
    try {
      await hub.dispose();
    } catch (_) {}
    try {
      await db.close();
    } catch (_) {}
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: AppShell(
        hub: hub,
        appearance: AppearanceController(hub.data, ThemeMode.dark),
        locale: LocaleController(hub.data, AppLanguage.zh),
      ),
    ));
    await tester.pump();
  }

  testWidgets('本地搜索：输入关键词防抖后命中「夜黑雾」', (tester) async {
    await pumpShell(tester);
    // 移动端默认 800x600 → 切到搜索 Tab。
    await tester.tap(find.byKey(const ValueKey('nav_search')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final input = find.byKey(const ValueKey('search_input'));
    expect(input, findsOneWidget, reason: '搜索框存在');
    await tester.enterText(input, '夜黑雾');
    await tester.pump(const Duration(milliseconds: 400)); // 防抖 300ms

    final rows =
        await tester.runAsync(() => hub.data.library.search('夜黑雾'));
    expect(rows!.length, 1, reason: 'DAO 直查命中（排除 DAO 嫌疑）');
    expect(find.byKey(const ValueKey('search_local_row_0')), findsOneWidget,
        reason: '页面渲染命中行');
  });

  testWidgets('B站模式：切换不抛异常、结果区可达', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byKey(const ValueKey('nav_search')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
        find.byKey(const ValueKey('search_input')), '晴天');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('search_mode')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull, reason: 'B站搜索路径不抛异常');
    expect(find.byKey(const ValueKey('search_bili_error')), findsOneWidget,
        reason: '测试环境无网=错误面可见');
    expect(find.byKey(const ValueKey('search_bili_login')), findsNothing,
        reason: '网络错误不得误导为登录引导（缺陷修复断言）');
    expect(find.byKey(const ValueKey('search_bili_retry')), findsOneWidget,
        reason: '网络错误给重试入口');
  });
}
