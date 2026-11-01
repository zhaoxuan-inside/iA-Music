/// UI 视觉审查黄金图（--update-goldens 生成真实渲染 PNG，逐页人工审计）。
/// 数据=内存库 + 合成种子；字体=真微软雅黑 + MaterialSymbols。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/main.dart';
import 'package:ia_music/ui/extract/extract_page.dart';
import 'package:ia_music/ui/settings/model_manager_page.dart';
import 'package:ia_music/ui/settings/sync_center_page.dart';
import 'package:ia_music/ui/shell/app_shell.dart';
import 'package:ia_music/ui/shell/appearance.dart';
import 'package:ia_music/ui/shell/locale_controller.dart';
import 'package:ia_music/ui/shell/onboarding_page.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';
Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) {
      loader
          .addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    }
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFont('Microsoft YaHei UI', [
      'C:/Windows/Fonts/msyh.ttc',
      'C:/Windows/Fonts/msyhbd.ttc',
    ]);
    await _loadFont('MaterialSymbolsRounded', [
      'E:/HardStone.Flutter/pub-cache/hosted/pub.flutter-io.cn/'
          'material_symbols_icons-4.2960.0/lib/fonts/MaterialSymbolsRounded.ttf',
    ]);
  });

  Future<(LibraryHub, IaDatabase)> seededHub() async {
    final gate = await openIaDatabaseMemory();
    final db = gate.db;
    final hub = LibraryHub(db);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final fixtureRoot = Directory('test/fixtures/library_smoke').absolute.path;
    final rootId = await db.into(db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(
            path: fixtureRoot,
            mode: RepositoryMode.directory,
            addedAt: nowMs,
          ),
        );
    final dao = DataAccess(db).library;
    final files = [
      ('探曲01.mp3', '晴天', '周杰伦', '叶惠美', 269000),
      ('探曲02.mp3', '夜曲', '周杰伦', '十一月的萧邦', 226000),
      ('探曲03.mp3', '稻香', '周杰伦', '魔杰座', 223000),
      ('探曲04.m4a', '孤勇者', '陈奕迅', '孤勇者', 278000),
      ('探曲05.m4a', '十年', '陈奕迅', '黑白灰', 200000),
      ('探曲06.wav', '后来', '刘若英', '我等你', 260000),
      ('探曲07.ogg', '富士山下', '陈奕迅', 'Beautiful Day', 250000),
      ('探曲09.flac', '七里香', '周杰伦', '七里香', 280000),
    ];
    var i = 0;
    for (final (rel, title, artist, album, dur) in files) {
      final f = File('$fixtureRoot/$rel');
      if (!f.existsSync()) {
        continue;
      }
      i++;
      await dao.insertTrackBatch([
        ScannedTrackInput(
          rootId: rootId,
          relPath: rel,
          mtime: nowMs - i * 3600000,
          fileSize: f.lengthSync(),
          contentHash: 'seed-hash-$i',
          nowMs: nowMs - i * 3600000,
          title: title,
          artistDisplay: artist,
          albumDisplay: album,
          durationMs: dur,
        ),
      ]);
    }
    await hub.data.shell.put(kOnboardingDoneKey, 'true', nowMs: nowMs);
    final pl = await DataAccess(db).playlists.create('深夜电台', nowMs: nowMs);
    final tracks = await dao.liveTracksOnce(LibSort.recent);
    for (final t in tracks.take(3)) {
      await DataAccess(db).playlists.addTrack(pl.id, t.id, nowMs: nowMs);
    }
    return (hub, db);
  }

  Widget host(LibraryHub hub, {Size size = const Size(1280, 800)}) =>
      MediaQuery(
        data: MediaQueryData(size: size),
        child: IaMusicApp(
          hub: hub,
          readOnlyGate: false,
          // golden 环境关闭 debug 横幅（右上角红带）
          appearance: AppearanceController(hub.data, ThemeMode.dark),
          locale: LocaleController(hub.data, AppLanguage.zh),
        ),
      );

  ThemeData darkTheme() => buildIaTheme(Brightness.dark, seed: null);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('AUDIT 首启引导（移动形态）', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final gate = await openIaDatabaseMemory();
    final hub = LibraryHub(gate.db);
    addTearDown(() async {
      await hub.dispose();
      await gate.db.close();
    });
    await tester.pumpWidget(host(hub, size: const Size(412, 915)));
    await settle(tester);
    await shot(tester, '01_onboarding_mobile');
  });

  testWidgets('AUDIT 曲库首页（桌面 populated）', (tester) async {
    final (hub, db) = await seededHub();
    addTearDown(() async {
      await hub.dispose();
      await db.close();
    });
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(hub));
    await settle(tester);
    await shot(tester, '02_tracks_desktop');
  });

  testWidgets('AUDIT 专辑/歌手', (tester) async {
    final (hub, db) = await seededHub();
    addTearDown(() async {
      await hub.dispose();
      await db.close();
    });
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(hub));
    await settle(tester);
    final state = tester.state<AppShellState>(find.byType(AppShell));
    state.jumpTo(ShellSection.albums);
    await settle(tester);
    await shot(tester, '03_albums_desktop');
    state.jumpTo(ShellSection.artists);
    await settle(tester);
    await shot(tester, '04_artists_desktop');
  });

  testWidgets('AUDIT 歌单+搜索+设置', (tester) async {
    final (hub, db) = await seededHub();
    addTearDown(() async {
      await hub.dispose();
      await db.close();
    });
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(hub));
    await settle(tester);
    final state = tester.state<AppShellState>(find.byType(AppShell));
    state.jumpTo(ShellSection.playlists);
    await settle(tester);
    await shot(tester, '05_playlists_desktop');
    state.jumpTo(ShellSection.search);
    await settle(tester);
    await shot(tester, '06_search_desktop');
    state.jumpTo(ShellSection.settings);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, '07_settings_desktop');
  });

  testWidgets('AUDIT 提取页', (tester) async {
    final (hub, db) = await seededHub();
    addTearDown(() async {
      await hub.dispose();
      await db.close();
    });
    await tester.pumpWidget(MaterialApp(
      theme: darkTheme(),
      home: ExtractPage(hub: hub),
    ));
    await settle(tester);
    await shot(tester, '08_extract_desktop');
  });

  testWidgets('AUDIT 模型管理/同步中心', (tester) async {
    final (hub, db) = await seededHub();
    addTearDown(() async {
      await hub.dispose();
      await db.close();
    });
    await tester.pumpWidget(MaterialApp(
      theme: darkTheme(),
      home: ModelManagerPage(hub: hub),
    ));
    await settle(tester);
    await shot(tester, '09_model_manager');
    await tester.pumpWidget(MaterialApp(
      theme: darkTheme(),
      home: SyncCenterPage(hub: hub),
    ));
    await settle(tester);
    await shot(tester, '10_sync_center');
  });
}
