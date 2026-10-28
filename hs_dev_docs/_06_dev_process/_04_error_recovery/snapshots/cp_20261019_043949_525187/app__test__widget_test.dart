// 产物入口冒烟（真库真壳：2026-10-19 装配修复后重写；计数器 Demo 已废）。
//
// 断言面=产品首拍：三 Tab 壳（NAV-01）+ 音乐空间 AppBar + 空库文案；
// 真库=内存 SQLite（openIaDatabaseMemory=同一 drift schema，真引擎）。
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/main.dart';

void main() {
  testWidgets('产品入口冒烟：三 Tab 壳 + 音乐空间首拍（真库真壳）',
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

    await tester.pumpWidget(IaMusicApp(hub: hub, readOnlyGate: false));
    await tester.pump();

    expect(find.byKey(const ValueKey('extract_entry')), findsOneWidget,
        reason: 'S6 提取入口在音乐空间 AppBar（真装配）');
    expect(find.byIcon(Icons.shuffle), findsOneWidget, reason: '随机入口（NAV-02）');
    expect(find.text('音乐空间'), findsWidgets);
    expect(find.text('曲库为空'), findsOneWidget, reason: '空态引导（真库 0 行）');
    await tester.pump();
  });
}
