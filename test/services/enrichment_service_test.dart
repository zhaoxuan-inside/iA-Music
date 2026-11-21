/// 补全服务测试——FakeEngine 不可用（无原生指纹链），直接用假歌词端口：
/// 锁死「抛错不标记不计完成（不再原地打转卡 0/N）」与「高置信采纳写回」。
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/entities/track.dart';
import 'package:ia_music/domain/errors.dart';
import 'package:ia_music/domain/ports/lyrics_port.dart';
import 'package:ia_music/services/enrich/enrichment_service.dart';

/// 按查询内容路由：含「坏」→ 抛网络错；含「投名状」→ 3 条同键高置信候选；
/// 其余 → 无候选。
class _FakeLyrics implements LyricTextSearchPort {
  static const _hit = LrcMatch(
      trackName: '投名状 (Live)',
      artistName: '歌手',
      durationMs: 60000,
      syncedLrc: '[00:01.00]测试',
      plainLrc: '测试');

  @override
  Future<LyricHit?> getByFields(
      {required String title, required String artist, int? durationMs}) async {
    return null;
  }

  @override
  Future<LyricHit?> search(String query) async => null;

  @override
  Future<List<LrcMatch>> searchMatches(String query) async {
    if (query.contains('坏')) {
      throw const NetworkError(detail: 'offline');
    }
    if (query.contains('投名状')) {
      return const [_hit, _hit, _hit];
    }
    return const [];
  }
}

void main() {
  late IaDatabase db;
  late Directory cacheDir;
  late EnrichmentService service;

  setUp(() async {
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    cacheDir = await Directory.systemTemp.createTemp('enrich_test');
    addTearDown(() => cacheDir.delete(recursive: true));
    addTearDown(db.close);
    final rootId = await db.libraryDao.addRoot('/music');
    await db.libraryDao.upsertScannedBatch([
      for (final (i, title) in ['坏掉的歌', '好听的歌', '投名状'].indexed)
        TrackUpsert(
          rootId: rootId,
          relPath: 't$i.mp3',
          path: '/music/t$i.mp3',
          title: title,
          artist: '',
          album: '',
          genre: '',
          needsMeta: true,
          trackNo: i + 1,
          durationMs: 60000,
          sizeBytes: 10,
          contentHash: 'h$i',
          audioFormat: 'mp3',
        ),
    ]);
    service = EnrichmentService(db, _FakeLyrics(), cacheDir: cacheDir.path);
  });

  Future<Track> trackByTitle(String title) async {
    final row = await (db.select(db.tracks)
          ..where((t) => t.title.equals(title)))
        .getSingle();
    return (await db.libraryDao.trackById(row.id))!;
  }

  test('抛错曲目不标记不计完成——留在池中，进度不再卡死打转', () async {
    final (ok, completed) = await service.enrichPending(limit: 20);
    // 「坏掉的歌」抛网络错（不计完成、不标记）；「好听的歌」无候选（标记）；
    // 「投名状」高置信采纳（标记）。完成数 = 2，采纳 = 1。
    expect(ok, 1);
    expect(completed, 2);

    final bad = await trackByTitle('坏掉的歌');
    expect(bad.enrichedAt, isNull, reason: '未写回 → 留在待补全池');
    expect(bad.needsMeta, isTrue);

    final okCount = await db.libraryDao.countNeedsEnrichment();
    expect(okCount, 1, reason: '只剩抛错的那首');
  });

  test('高置信采纳：歌名/歌手写回 + 标记', () async {
    await service.enrichPending(limit: 20);
    final t = await trackByTitle('投名状 (live)');
    expect(t.artist, '歌手');
    expect(t.enrichedAt, isNotNull);
    expect(t.needsMeta, isFalse);
  });

  test('无候选也标记已尝试（enrichedAt），不再无限重试', () async {
    await service.enrichPending(limit: 20);
    final t = await trackByTitle('好听的歌');
    expect(t.enrichedAt, isNotNull);
    expect(t.needsMeta, isFalse);
  });
}
