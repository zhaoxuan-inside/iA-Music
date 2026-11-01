// S2 红绿测试（IMPL-01：先红后绿）——fixture=真实 ffmpeg 编码产物（DEC-010）
//
// DoD1: 12 音频（1 损坏+1 零字节）→ total=10 / skipped=2 / track 行=10（§6.2 样例 1）
import 'dart:async';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/metadata_adapter.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/scan/scan_service.dart';

void main() {
  // fixture 为仓库内真实文件（tool/fixtures/gen_library_fixture.py 生成）
  final fixtureRoot = Directory('test/fixtures/library_smoke').absolute;

  late IaDatabase db;
  late MetadataAdapter metadata;
  late ScanService scanService;
  late int rootId;

  setUp(() async {
    final gate = await openIaDatabaseMemory();
    db = gate.db;
    metadata = MetadataAdapter();
    scanService = ScanService(db: db);
    final now = DateTime.now().millisecondsSinceEpoch;
    rootId = await db.into(db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(
            path: fixtureRoot.path,
            mode: RepositoryMode.directory,
            addedAt: now,
          ),
        );
  });

  tearDown(() => db.close());

  group('MetadataPort 真解析（audio_metadata_reader 1.8.1）', () {
    test('mp3/ogg/flac/m4a 真 tag → ParsedMeta 字段全真', () async {
      // mp3 标签时长本包为 null（Xing 头无时长；库中可空、播放期引擎补齐——REQ 口径）
      final cases = {
        '探曲01.mp3': ('探曲01', '测试歌手A', '测试专辑壹', AudioFormat.mp3, false),
        '探曲07.ogg': ('探曲07', '测试歌手A', '测试专辑壹', AudioFormat.ogg, true),
        '探曲09.flac': ('探曲09', '测试歌手A', '测试专辑贰', AudioFormat.flac, true),
        '探曲04.m4a': ('探曲04', '测试歌手A', '测试专辑贰', AudioFormat.m4a, true),
      };
      for (final entry in cases.entries) {
        final p = await metadata.read('${fixtureRoot.path}\\${entry.key}');
        final (title, artist, album, format, hasDuration) = entry.value;
        expect(p.title, title, reason: entry.key);
        expect(p.artistDisplay, artist, reason: entry.key);
        expect(p.albumDisplay, album, reason: entry.key);
        expect(p.durationMs, greaterThanOrEqualTo(0), reason: entry.key);
        if (hasDuration) {
          expect(p.durationMs, greaterThan(0), reason: entry.key);
        }
        expect(p.format, format, reason: entry.key);
        expect(p.fileSizeBytes, greaterThan(0), reason: entry.key);
        expect(p.mtimeMs, greaterThan(0), reason: entry.key);
      }
    });

    test('无 tag wav → 解析器裸值（空串），兜底责任在扫描层（tables.dart 注释口径）', () async {
      final p = await metadata.read('${fixtureRoot.path}\\探曲06.wav');
      expect(p.title, isEmpty);
      expect(p.artistDisplay, isEmpty);
      expect(p.albumDisplay, isEmpty);
      expect(p.durationMs, greaterThan(0));
    });

    test('损坏文件（真实乱码事故类）→ FormatException（契约口径）', () async {
      await expectLater(
        metadata.read('${fixtureRoot.path}\\10_broken_probe.mp3'),
        throwsFormatException,
      );
    });

    test('零字节 → FormatException', () async {
      await expectLater(
        metadata.read('${fixtureRoot.path}\\11_empty_probe.flac'),
        throwsFormatException,
      );
    });
  });

  group('S2 DoD1 真实计数（§6.2 样例 1）', () {
    test('12 音频（1 损坏+1 零字节）→ total=10 / skipped=2 / track 行=10', () async {
      final events = await scanService.scan(rootId: rootId, mode: ScanMode.full).toList();
      final done = events.last;
      expect(done, isA<ScanDone>());
      final report = (done as ScanDone).report;

      expect(report.total, 10); // 真实计数红线：入库=有效音频
      expect(report.skipped, 2); // 损坏 + 零字节
      expect(report.added, 10);
      expect(report.skippedPaths, contains('10_broken_probe.mp3'));

      // DB 双口径核对
      final trackRows = await db
          .customSelect('SELECT count(*) c FROM tracks WHERE root_id=? AND deleted_at IS NULL',
              variables: [Variable.withInt(rootId)])
          .getSingle();
      expect(trackRows.read<int>('c'), 10);
      final fts = await db.customSelect('SELECT count(*) c FROM tracks_fts').getSingle();
      expect(fts.read<int>('c'), 10);

      // 文件名兜底（wav 无 tag）
      final wavTitle = await db
          .customSelect("SELECT title FROM tracks WHERE rel_path LIKE '%探曲06.wav'")
          .getSingle();
      expect(wavTitle.read<String>('title'), startsWith('探曲06'));

      // 字典 upsert（两歌手/两专辑）
      expect(await db.select(db.artists).get(), hasLength(2));
      expect(await db.select(db.albums).get(), hasLength(2));

      // 新增轨 id 清单（识别修正入队消费）：首扫=全部入库 id；未变重扫=空
      expect(report.addedTrackIds, hasLength(10));
      final second = (await scanService.scan(rootId: rootId, mode: ScanMode.full).toList()).last
          as ScanDone;
      expect(second.report.added, 0);
      expect(second.report.addedTrackIds, isEmpty);
    });

    test('同 root 并发扫描 → 程序级拒绝（§3.1 任务锁）', () async {
      final first = scanService.scan(rootId: rootId, mode: ScanMode.full);
      final completer = StreamIterator<ScanEvent>(first);
      // 首个事件（进度）抵达后生成器挂起——锁持有期确定化
      await completer.moveNext();
      await expectLater(
        scanService.scan(rootId: rootId, mode: ScanMode.full).toList(),
        throwsStateError,
      );
      await completer.cancel();
    });
  });
}
