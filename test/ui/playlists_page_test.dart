/// 歌单屏：页头瘦身（无拉取/搜索/计数副题）、新建磁贴建单全链路
/// （内存 SQLite）、无封面磁贴不装轮换；FlipTile 周期翻面两态与封顶。
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/providers.dart';
import 'package:ia_music/app/theme/app_theme.dart';
import 'package:ia_music/app/theme/design_tokens.dart';
import 'package:ia_music/domain/entities/playlist.dart';
import 'package:ia_music/state/playlist_providers.dart';
import 'package:ia_music/ui/motion/wp_motion.dart';
import 'package:ia_music/ui/playlists/playlists_page.dart';

Playlist _pl({int id = 1, String name = '夜航', String? coverPath}) => Playlist(
      id: id,
      name: name,
      kind: PlaylistKind.user,
      trackCount: 3,
      createdAt: DateTime(2024, 1, 1),
      coverPath: coverPath,
    );

void main() {
  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> pump390(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent, brightness: IaBrightness.dark),
        home: Scaffold(body: child),
      ),
    ));
  }

  testWidgets('页头瘦身：无拉取入口/无搜索钮/无计数副题，新建磁贴在位', (tester) async {
    await phone(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        playlistListProvider.overrideWith((ref) => Stream.value([_pl()])),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent, brightness: IaBrightness.dark),
        home: const Scaffold(body: PlaylistsPage()),
      ),
    ));
    await tester.pump();

    expect(find.text('拉取歌单'), findsNothing);
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.textContaining('个歌单'), findsNothing); // 计数副题移除
    expect(find.text('新建歌单'), findsOneWidget);
    expect(find.text('夜航'), findsNWidgets(2)); // 字块磁贴内 + 磁贴下歌名
    // 无封面磁贴本就是详情面，不装轮换
    expect(find.byType(FlipTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新建歌单 · 磁贴点按 → 对话框 → 入库（内存 SQLite 全链路）', (tester) async {
    await phone(tester);
    final db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get(); // 触发 onCreate（FTS 建表）
    // 页面歌单流走手动 controller：fake async 区里开 drift watch，provider
    // 销毁时的流取消会挂清理 Timer（测试末尾判失败）——入库断言用纯查询。
    final pls = StreamController<List<Playlist>>();
    addTearDown(pls.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWith((ref) => db),
        playlistListProvider.overrideWith((ref) => pls.stream),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent, brightness: IaBrightness.dark),
        home: const Scaffold(body: PlaylistsPage()),
      ),
    ));
    pls.add(const <Playlist>[]);
    await tester.pump();

    // 空态与新建磁贴共存
    expect(find.text('还没有歌单'), findsOneWidget);
    expect(find.text('新建歌单'), findsOneWidget);

    await tester.tap(find.text('新建歌单'));
    await tester.pump(const Duration(milliseconds: 400)); // 对话框入场
    await tester.enterText(find.byType(TextField), '夜航');
    await tester.pump();
    await tester.tap(find.text('创建'));
    await tester.pump(const Duration(milliseconds: 400)); // 关对话框 + toast 入场

    // 已入库（纯查询，不开 watch）
    final rows = await db.select(db.playlists).get();
    expect(rows.map((r) => r.name), contains('夜航'));

    // 流回灌 → 新磁贴出现
    pls.add([
      Playlist(
          id: 99,
          name: '夜航',
          kind: PlaylistKind.user,
          trackCount: 0,
          createdAt: DateTime(2024, 1, 1)),
    ]);
    await tester.pump();
    expect(find.text('夜航'), findsWidgets);

    await tester.pump(const Duration(seconds: 3)); // 清掉 toast 定时器再收尾
    await db.close();
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlipTile · 周期翻面 正面→背面→正面', (tester) async {
    await pump390(
        tester,
        SizedBox(
          width: 200,
          height: 200,
          child: FlipTile(
              index: 0, back: const Text('B'), child: const Text('F')),
        ));
    await tester.pump(); // 首帧：进页停顿段（正面）
    expect(find.text('F'), findsOneWidget);

    // 越过「进页停顿 + 翻出」窗口 → 背面停留
    await tester.pump(IaMotion.tileFlipLead +
        IaMotion.tileFlip +
        const Duration(milliseconds: 30));
    expect(find.text('B'), findsOneWidget);

    // 越过「背面停留 + 翻回」→ 回到正面
    await tester.pump(IaMotion.tileFlipHold +
        IaMotion.tileFlip +
        const Duration(milliseconds: 30));
    expect(find.text('F'), findsOneWidget);

    // 再滚一整周期仍在正面（翻回后余量为正面停留）
    await tester.pump(IaMotion.tileFlipCycle);
    expect(find.text('F'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FlipTile · 超出参与上限的磁贴恒为正面', (tester) async {
    await pump390(
        tester,
        SizedBox(
          width: 200,
          height: 200,
          child: FlipTile(
              index: IaMotion.tileFlipMaxItems,
              back: const Text('B'),
              child: const Text('F')),
        ));
    await tester.pump(IaMotion.tileFlipCycle);
    expect(find.text('F'), findsOneWidget);
    expect(find.text('B'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
