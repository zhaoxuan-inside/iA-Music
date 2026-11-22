/// EnrichController 状态测试：resumeIfNeeded 的空池守卫与有池续跑。
///
/// 空池直接 runOnce 会跑出假的「补全中断 0/0」——启动续跑 / 收集队列触发
/// 全靠 resumeIfNeeded 的守卫，锁死这两条行为。
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/ports/lyrics_port.dart';
import 'package:ia_music/services/enrich/enrichment_service.dart';
import 'package:ia_music/state/enrich_controller.dart';
import 'package:ia_music/state/providers.dart';

/// 全程无候选：补全走「无匹配 → 标记 enrichedAt」路径。
class _NoMatchLyrics implements LyricTextSearchPort {
  @override
  Future<LyricHit?> getByFields(
          {required String title, required String artist, int? durationMs}) =>
      Future.value(null);

  @override
  Future<LyricHit?> search(String query) => Future.value(null);

  @override
  Future<List<LrcMatch>> searchMatches(String query) async => const [];
}

void main() {
  late IaDatabase db;
  late ProviderContainer container;
  late Directory cacheDir;

  setUp(() async {
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    cacheDir = await Directory.systemTemp.createTemp('enrich_ctl_test');
    container = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
      // 覆盖组合根的补全服务：不触指纹/网络，纯文字链在内存库上跑
      enrichmentServiceProvider.overrideWith((ref) async =>
          EnrichmentService(db, _NoMatchLyrics(), cacheDir: cacheDir.path)),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
      await cacheDir.delete(recursive: true);
    });
  });

  test('空池 resumeIfNeeded：no-op，不出假「补全中断」', () async {
    await container.read(enrichProvider.notifier).resumeIfNeeded();

    final st = container.read(enrichProvider);
    expect(st.running, isFalse);
    expect(st.lastSummary, isEmpty, reason: '空池绝不能跑出「补全中断 0/0」');
  });

  test('有待补曲目：resumeIfNeeded 续跑并标记（无候选也落 enrichedAt）', () async {
    final rootId = await db.libraryDao.addRoot('/music');
    await db.libraryDao.upsertScannedBatch([
      TrackUpsert(
        rootId: rootId,
        relPath: 't1.mp3',
        path: '/music/t1.mp3',
        title: '待补的歌',
        artist: '',
        album: '',
        genre: '',
        needsMeta: true,
        trackNo: 1,
        durationMs: 60000,
        sizeBytes: 10,
        contentHash: 'h1',
        audioFormat: 'mp3',
      ),
    ]);

    await container.read(enrichProvider.notifier).resumeIfNeeded();

    final st = container.read(enrichProvider);
    expect(st.running, isFalse);
    expect(st.lastSummary, contains('补全完成'));
    final row = await (db.select(db.tracks)
          ..where((t) => t.title.equals('待补的歌')))
        .getSingle();
    final track = (await db.libraryDao.trackById(row.id))!;
    expect(track.enrichedAt, isNotNull, reason: '无候选也标记已尝试');
    expect(track.needsMeta, isFalse);
  });
}
