// 语言三选（DEC-005 D5-2）测试：持久化往返 + 切语言即时换文案。
// 真库=内存 SQLite（同一 drift schema）；UI=真 IaMusicApp（MaterialApp 委托齐备）。
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/l10n/app_localizations.dart';
import 'package:ia_music/main.dart';
import 'package:ia_music/ui/shell/appearance.dart';
import 'package:ia_music/ui/shell/locale_controller.dart';

void main() {
  testWidgets('语言设置持久化往返：set(en) → 库 → load 回读 en', (tester) async {
    final gate = await tester.runAsync(() => openIaDatabaseMemory());
    final db = gate!.db;
    final hub = LibraryHub(db);
    addTearDown(() async {
      await tester.runAsync(() async {
        await hub.dispose();
        await db.close();
      });
    });

    final ctl = LocaleController(hub.data, AppLanguage.zh);
    await ctl.set(AppLanguage.en);
    // KV 落账（appearance.locale 键族，JSON 字符串）。
    expect(await hub.data.shell.value(kAppearanceLocaleKey), '"en"');
    // 回读：新实例以库为准。
    final reloaded = await tester.runAsync(() => LocaleController.load(hub.data));
    expect(reloaded!.value, AppLanguage.en);
    expect(reloaded.resolvedLocale, const Locale('en'));
    // 缺省=中文（D5-2 默认）：全新空库回读。
    final gate2 = await tester.runAsync(() => openIaDatabaseMemory());
    final db2 = gate2!.db;
    final hub2 = LibraryHub(db2);
    addTearDown(() async {
      await tester.runAsync(() async {
        await hub2.dispose();
        await db2.close();
      });
    });
    final fresh = await tester.runAsync(() => LocaleController.load(hub2.data));
    expect(fresh!.value, AppLanguage.zh);
  });

  testWidgets('切语言即时换文案：设置页 中文→English', (tester) async {
    final gate = await tester.runAsync(() => openIaDatabaseMemory());
    final db = gate!.db;
    final hub = LibraryHub(db);
    addTearDown(() async {
      await tester.runAsync(() async {
        await hub.dispose();
        await db.close();
      });
    });

    final appearance = AppearanceController(hub.data, ThemeMode.dark);
    final locale = LocaleController(hub.data, AppLanguage.zh);
    await tester.pumpWidget(IaMusicApp(
        hub: hub,
        readOnlyGate: false,
        appearance: appearance,
        locale: locale));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 全新库 → FTUE 引导：跳过进主壳（REQ-ONB-01 行为本身即被引导页测试覆盖）。
    final onboard = find.byKey(const ValueKey('onboarding_page'));
    if (onboard.evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('onboarding_skip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    // 中文默认：侧栏/Tab 文案为中文（桌面侧栏 SETTINGS 项；宽屏断言）。
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pump();
    expect(find.text('设置'), findsWidgets, reason: '中文侧栏设置项');

    // 切 English：MaterialApp locale 重建 → 同一文案位变 SETTINGS。
    await locale.set(AppLanguage.en);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('SETTINGS'), findsWidgets, reason: '英文侧栏设置项');
    expect(find.text('设置'), findsNothing);
    // 进设置页（IndexedStack 未选中子面 offstage，需真实导航后断言）。
    await tester.tap(find.byKey(const ValueKey('nav_settings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Language'), findsOneWidget, reason: '英文语言条目标题');
    expect(find.text('English'), findsOneWidget, reason: '副标题=当前选中项自称');
    // 支持的语言集（zh 居首=回落默认中文）。
    expect(AppLocalizations.supportedLocales.first, const Locale('zh'));
  });
}
