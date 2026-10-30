// S2 DoD2/3/4 红绿测试（IMPL-01：先红后绿）——全真：真文件、真事件、真扫描、真库。
//
// DoD2: 目录真事件 → 新文件 ≤15s 增量入库；mtime 变更 → updated_at 刷新（REQ-LIB-02）
// DoD3: 编辑标题 → 列表/播放页即时更新；**mtime/size/hash/文件字节不变**（REQ-LIB-03）
// DoD4: 移除 → 记录消失 + 物理文件保留；文件放回 → 恢复（REQ-LIB-05/07）
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/library_service.dart';
import 'package:ia_music/scan/scan_service.dart';
import 'package:ia_music/scan/root_watcher.dart';
import 'package:drift/drift.dart' show Variable;

void main() {
  final fixtureRoot = Directory('test/fixtures/library_smoke').absolute;

  late IaDatabase db;
  late ScanService scanService;
  late LibraryService libraryService;

  setUp(() async {
    final gate = await openIaDatabaseMemory();
    db = gate.db;
    scanService = ScanService(db: db);
    libraryService = LibraryService(db: db);
  });

  tearDown(() => db.close());

  /// 真 fixture 复制（直接字节复制；返回临时根路径）。
  Future<Directory> copyFixtureToTemp(String tag) async {
    final tmp = await Directory.systemTemp.createTemp('s2_${tag}_');
    await for (final ent in fixtureRoot.list()) {
      if (ent is File) {
        final name = ent.path.split(Platform.pathSeparator).last;
        await ent.copy('${tmp.path}\\$name');
      }
    }
    return tmp;
  }

  Future<int> addRoot(Directory dir) {
    return db.into(db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(
            path: dir.path,
            mode: RepositoryMode.directory,
            addedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  group('DoD2 增量扫描（真目录事件 REQ-LIB-02）', () {
    test('新文件落盘 → 防抖触发增量 → ≤15s 入库；改写件 → updated touch', () async {
      final tmp = await copyFixtureToTemp('dod2');
      addTearDown(() async => tmp.delete(recursive: true));
      final rootId = await addRoot(tmp);

      // 基线全量：12 件 → 10 入架
      final base = (await scanService.scan(rootId: rootId).toList()).last as ScanDone;
      expect(base.report.added, 10);

      final watcher = RootWatcher(
        db: db,
        scanService: scanService,
        rootId: rootId,
        rootPath: tmp.path,
        debounceMs: 600,
      );
      await watcher.start();

      // ① 新文件：真字节复制改名（rel_path 全新 → INSERT）
      final sw = Stopwatch()..start();
      await File('${fixtureRoot.path}\\探曲04.m4a').copy('${tmp.path}\\新声01.m4a');
      final reportNew =
          await watcher.reports.first.timeout(const Duration(seconds: 15));
      sw.stop();
      expect(reportNew.added, 1, reason: '新文件增量入库');
      expect(sw.elapsed, lessThan(const Duration(seconds: 15)), reason: 'REQ-LIB-02 ≤15s');
      final rows = await db
          .customSelect(
              'SELECT count(*) c FROM tracks WHERE root_id=? AND deleted_at IS NULL',
              variables: [Variable.withInt(rootId)])
          .getSingle();
      expect(rows.read<int>('c'), 11);

      // ② 改写：另一真实文件字节整写覆盖（size/mtime/hash 全变 → touch updated=1）
      final before = (await db
          .customSelect(
              "SELECT id, content_hash FROM tracks WHERE rel_path LIKE '%探曲02.mp3'")
          .getSingle())
          .data;
      await File('${fixtureRoot.path}\\探曲05.m4a')
          .copy('${tmp.path}\\探曲02.mp3');
      final reportUpd =
          await watcher.reports.first.timeout(const Duration(seconds: 15));
      expect(reportUpd.updated, 1, reason: 'mtime/size/hash 变更 → updated_at 刷新');
      final after = (await db
          .customSelect(
              "SELECT id, content_hash FROM tracks WHERE rel_path LIKE '%探曲02.mp3'")
          .getSingle())
          .data;
      expect(after['id'], before['id']);
      expect(after['content_hash'], isNot(before['content_hash']));

      await watcher.stop();
    });
  });

  group('DoD3 编辑标题（REQ-LIB-03 编辑不写原文件）', () {
    test('rename → FTS 同事务翻新 + 文件字节/mtime/size/hash 纹丝不动', () async {
      final rootId = await addRoot(fixtureRoot); // 直接扫真 fixture（只读域）
      final scan = (await scanService.scan(rootId: rootId).toList()).last as ScanDone;
      expect(scan.report.total, 10);

      // 选文件名兜底行（wav 无 tag → 扫描填充）
      final wavId = (await db
          .customSelect(
              "SELECT id FROM tracks WHERE rel_path LIKE '%探曲06.wav'")
          .getSingle())
          .data['id'] as int;
      final fsBefore = File('${fixtureRoot.path}\\探曲06.wav');
      final bytesBefore = await fsBefore.readAsBytes();

      const newTitle = '探曲06改名件';
      final now = DateTime.now().millisecondsSinceEpoch;
      await libraryService.editTrackTitle(wavId, newTitle, nowMs: now);

      final d = (await db
          .customSelect(
              'SELECT title, mtime, file_size, content_hash FROM tracks WHERE id=?',
              variables: [Variable.withInt(wavId)])
          .getSingle())
          .data;
      expect(d['title'], newTitle);

      // 文件零写入（红线：REQ-LIB-03）
      final bytesAfter = await fsBefore.readAsBytes();
      expect(bytesAfter, bytesBefore, reason: '原文件字节不变');
      expect(d['mtime'], greaterThan(0), reason: 'mtime 原值保留（非清写）');

      // FTS 同事务：锚定行 title 翻新 + 拼音列含新词
      final anchor = (await db
          .customSelect('SELECT title, pinyin_full FROM track_index WHERE id=?',
              variables: [Variable.withInt(wavId)])
          .getSingle())
          .data;
      expect(anchor['title'], newTitle);
      expect(anchor['pinyin_full'], contains('gai')); // 改名件 → gaimingjian
    });
  });

  group('DoD4 移除与恢复（REQ-LIB-07 / REQ-LIB-05）', () {
    test('移除：记录消失 + 物理文件保留；放回：恢复（软删行复活）', () async {
      final tmp = await copyFixtureToTemp('dod4');
      addTearDown(() async => tmp.delete(recursive: true));
      final rootId = await addRoot(tmp);
      final scan = (await scanService.scan(rootId: rootId).toList()).last as ScanDone;
      expect(scan.report.added, 10);

      // ① 软删：列表消失 + 文件在盘
      final goneId = (await db
          .customSelect(
              "SELECT id FROM tracks WHERE rel_path LIKE '%探曲07.ogg'")
          .getSingle())
          .data['id'] as int;
      final movedFile = File('${tmp.path}\\探曲07.ogg');
      final now = DateTime.now().millisecondsSinceEpoch;
      await libraryService.removeTrack(goneId, nowMs: now);
      final removed = (await db
          .customSelect('SELECT deleted_at FROM tracks WHERE id=?',
              variables: [Variable.withInt(goneId)])
          .getSingle())
          .data;
      expect(removed['deleted_at'], greaterThan(0));
      final aliveRows = await db
          .customSelect(
              'SELECT count(*) c FROM tracks WHERE root_id=? AND deleted_at IS NULL',
              variables: [Variable.withInt(rootId)])
          .getSingle();
      expect(aliveRows.read<int>('c'), 9, reason: '列表/随机池不再见');
      expect(await movedFile.exists(), isTrue, reason: '物理文件保留');

      // ② 活行文件物理移出根（根外暂存，根内不留新生名）→ 全量再扫 → missing
      final stash = await Directory.systemTemp.createTemp('s2_stash_');
      addTearDown(() async => stash.delete(recursive: true));
      await movedFile.rename('${stash.path}\\探曲07.ogg');
      final aliveFile = File('${tmp.path}\\探曲08.ogg');
      await aliveFile.rename('${stash.path}\\探曲08.ogg');
      final scanMiss =
          (await scanService.scan(rootId: rootId).toList()).last as ScanDone;
      expect(scanMiss.report.missing, 1, reason: '活行缺失（07 已软删不计）');
      final missRow = (await db
          .customSelect(
              'SELECT missing_at FROM tracks WHERE rel_path LIKE \'%探曲08.ogg\'')
          .getSingle())
          .data;
      expect(missRow['missing_at'], greaterThan(0), reason: 'REQ-LIB-05 missing_at');

      // ③ 两件放回 → 再扫：软删 07 复活（added=1）+ 缺行 08 恢复（missing_at 清零）
      await File('${stash.path}\\探曲07.ogg').rename(movedFile.path);
      await File('${stash.path}\\探曲08.ogg').rename(aliveFile.path);
      final scanBack =
          (await scanService.scan(rootId: rootId).toList()).last as ScanDone;
      expect(scanBack.report.added, 1, reason: '07 复活计为重入架');
      expect(scanBack.report.addedTrackIds, [goneId],
          reason: '复活轨 id 上报（识别修正入队消费）');
      final revived = (await db
          .customSelect(
              'SELECT deleted_at, missing_at, file_size FROM tracks WHERE id=?',
              variables: [Variable.withInt(goneId)])
          .getSingle())
          .data;
      expect(revived['deleted_at'], isNull, reason: '软删清零');
      expect(revived['missing_at'], isNull);
      expect(revived['file_size'], greaterThan(0));
      final back08 = (await db
          .customSelect(
              "SELECT missing_at, file_size FROM tracks WHERE rel_path LIKE '%探曲08.ogg'")
          .getSingle())
          .data;
      expect(back08['missing_at'], isNull, reason: '活行缺失恢复');
      expect(back08['file_size'], greaterThan(0));
    });
  });
}
