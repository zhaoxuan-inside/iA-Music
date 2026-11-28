/// 编辑歌曲信息页冒烟：五字段+歌词预填、空歌名禁保存（不落库）、
/// 保存信息全链路（内存 SQLite：行更新 + needsMeta 清位 + FTS 重建）、
/// 歌词保存经 LyricsActions 替身捕获。
///
/// 遵守 UI 冒烟纪律（同 layout_smoke_test）：页面本身不开 drift watch 流，
/// 断言一律纯查询；toast 定时器在收尾 pump 清掉。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/providers.dart';
import 'package:ia_music/app/theme/app_theme.dart';
import 'package:ia_music/app/theme/design_tokens.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/entities/track.dart';
import 'package:ia_music/state/media_providers.dart';
import 'package:ia_music/ui/library/track_edit_page.dart';
import 'package:ia_music/ui/shared/ui_kit.dart';

Track _track({String title = '晴天', bool needsMeta = false}) => Track(
      id: 1,
      rootId: 1,
      relPath: 'a.mp3',
      path: '/music/a.mp3',
      title: title,
      artist: '周杰伦',
      album: '叶惠美',
      genre: '',
      durationMs: 1000,
      sizeBytes: 1,
      contentHash: 'h',
      audioFormat: 'mp3',
      trackNo: 0,
      coverPath: null,
      addedAt: DateTime(2024, 1, 1),
      needsMeta: needsMeta,
    );

/// 歌词动作替身：预填与保存都只是捕获，不碰服务、磁盘与网络。
class _CapturingLyricsActions extends LyricsActions {
  _CapturingLyricsActions(super.ref);

  String? prefill;
  String? savedText;

  @override
  Future<String?> loadRawLyrics(int trackId) async => prefill;

  @override
  Future<void> savePasted(int trackId, String text) async {
    savedText = text;
  }
}

void main() {
  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
  }

  /// 内存库 + 种子行（真实入库，供全链路断言）。
  Future<IaDatabase> seedDb() async {
    final db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get(); // 触发 onCreate（FTS 建表）
    final rootId = await db.libraryDao.addRoot('/music');
    await db.libraryDao.upsertScannedBatch([
      TrackUpsert(
        rootId: rootId,
        relPath: 'a.mp3',
        path: '/music/a.mp3',
        title: '晴天',
        artist: '周杰伦',
        album: '叶惠美',
        genre: '',
        needsMeta: true,
        trackNo: 0,
        durationMs: 1000,
        sizeBytes: 1,
        contentHash: 'h',
        audioFormat: 'mp3',
      ),
    ]);
    return db;
  }

  testWidgets('五字段+歌词预填；空歌名禁保存不落库', (tester) async {
    await phone(tester);
    final db = await seedDb();
    addTearDown(db.close);
    _CapturingLyricsActions? actions;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWith((ref) => db),
        lyricsActionsProvider.overrideWith((ref) {
          final a = _CapturingLyricsActions(ref)
            ..prefill = '[00:12.00]夜曲';
          actions = a;
          return a;
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent, brightness: IaBrightness.dark),
        home: Scaffold(body: TrackEditPage(track: _track())),
      ),
    ));
    await tester.pump();
    await tester.pump(); // 预填 microtask + setState 帧

    // 六个输入框：歌名/歌手/专辑/流派/音轨号/歌词
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(6));
    expect(tester.widget<TextField>(fields.at(0)).controller!.text, '晴天');
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, '周杰伦');
    expect(tester.widget<TextField>(fields.at(2)).controller!.text, '叶惠美');
    expect(tester.widget<TextField>(fields.at(3)).controller!.text, '');
    expect(tester.widget<TextField>(fields.at(4)).controller!.text, '');
    expect(
        tester.widget<TextField>(fields.at(5)).controller!.text, '[00:12.00]夜曲');

    // 清空歌名 → 保存信息禁用，点按不落库
    await tester.enterText(fields.at(0), '');
    await tester.pump();
    final saveBtn = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '保存信息'));
    expect(saveBtn.onPressed, isNull);
    await tester.tap(find.text('保存信息'));
    await tester.pump();
    final rows = await db.select(db.tracks).get();
    expect(rows.single.title, '晴天', reason: '空歌名禁保存，行未被改写');
    expect(actions, isNotNull);
    await tester.pump(const Duration(seconds: 3)); // 到点收回定时器
    await tester.pumpAndSettle(); // 收回动画跑完（控制器正常 dispose）
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存信息 · 全链路：行更新 + needsMeta 清位 + FTS 重建', (tester) async {
    await phone(tester);
    final db = await seedDb();
    addTearDown(db.close);
    final seeded = (await db.libraryDao.availableTracks()).single;

    // 经路由 push 进入：保存成功后页内 pop 回到打开方
    await tester.pumpWidget(ProviderScope(
      overrides: [dbProvider.overrideWith((ref) => db)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent, brightness: IaBrightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(ctx).push(zuneRoute<void>(
                    builder: (_) => TrackEditPage(track: seeded))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '爱在西元前');
    await tester.enterText(fields.at(1), 'Jay');
    await tester.enterText(fields.at(2), 'Fantasy');
    await tester.enterText(fields.at(3), 'Mandopop');
    await tester.enterText(fields.at(4), '3');
    await tester.pump();
    await tester.tap(find.text('保存信息'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 写库 + toast + pop

    final row = await db.libraryDao.trackById(seeded.id);
    expect(row!.title, '爱在西元前');
    expect(row.artist, 'Jay');
    expect(row.album, 'Fantasy');
    expect(row.genre, 'Mandopop');
    expect(row.trackNo, 3);
    expect(row.needsMeta, isFalse, reason: '用户编辑即结论，补全池不再回收');
    expect(row.enrichedAt, isNotNull);

    // FTS 整行重建（纯查询断言）：旧拼音灭、新拼音活
    final oldHits = await db
        .customSelect("SELECT track_id FROM track_index WHERE track_index MATCH '\"qingtian\"*'")
        .get();
    expect(oldHits, isEmpty);
    final newHits = await db
        .customSelect("SELECT track_id FROM track_index WHERE track_index MATCH '\"aizai\"*'")
        .get();
    expect(newHits.map((r) => r.read<int>('track_id')), [seeded.id]);

    await tester.pump(const Duration(seconds: 3)); // 到点收回定时器
    await tester.pumpAndSettle(); // 收回动画跑完（控制器正常 dispose）
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存歌词 · 经 LyricsActions 替身捕获（不动磁盘）', (tester) async {
    await phone(tester);
    final db = await seedDb();
    addTearDown(db.close);
    _CapturingLyricsActions? actions;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWith((ref) => db),
        lyricsActionsProvider.overrideWith((ref) {
          actions = _CapturingLyricsActions(ref);
          return actions!;
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIaTheme(accent: kDefaultAccent, brightness: IaBrightness.dark),
        home: Scaffold(body: TrackEditPage(track: _track())),
      ),
    ));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(5), '[00:12.00]新歌词');
    await tester.pump();
    // 字阶上调后按钮在 390×844 视口落到了惰性 ListView 视口外，滚动露出再点
    await tester.dragUntilVisible(
        find.text('保存歌词'), find.byType(ListView), const Offset(0, -160));
    await tester.pump();
    await tester.tap(find.text('保存歌词'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 保存 + toast

    expect(actions!.savedText, '[00:12.00]新歌词');
    expect(find.text('歌词已保存'), findsOneWidget); // toast 反馈
    await tester.pump(const Duration(seconds: 3)); // 到点收回定时器
    await tester.pumpAndSettle(); // 收回动画跑完（控制器正常 dispose）
    expect(tester.takeException(), isNull);
  });
}
