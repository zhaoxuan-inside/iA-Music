/// EnrichController 状态测试：resumeIfNeeded 的空池守卫与有池续跑。
///
/// 空池直接 runOnce 会跑出假的「补全中断 0/0」——启动续跑 / 收集队列触发
/// 全靠 resumeIfNeeded 的守卫，锁死这两条行为。向量轮（嵌入端口）的
/// 接棒驱动与端口缺失跳过同页锁死。
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/config/embedding_config.dart';
import 'package:ia_music/app/providers.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/ports/embedding_port.dart';
import 'package:ia_music/domain/ports/lyrics_port.dart';
import 'package:ia_music/services/enrich/enrichment_service.dart';
import 'package:ia_music/state/diagnostics.dart';
import 'package:ia_music/state/enrich_controller.dart';

/// 捕获型诊断控制器：同步记录（真 record 有 async 间隙，测试断言会与
/// unawaited 记录竞态；也避免在测试里触平台目录 IO）。
final diagRecords = <String>[];

class _CapturingDiag extends DiagnosticsController {
  @override
  DiagEntry? build() => null;

  @override
  Future<void> record(String source, Object error, [StackTrace? st]) async {
    diagRecords.add('$source: $error');
  }

  @override
  Future<void> clear() async {}
}

/// 全程无候选：补全走「无匹配 → 标记 enrichedAt」路径。
class _NoMatchLyrics implements LyricTextSearchPort {
  @override
  Future<LyricHit?> getByFields(
          {required String title, required String artist, int? durationMs}) =>
      Future.value(null);

  @override
  Future<List<LrcMatch>> searchMatches(String query) async => const [];
}

/// 确定性向量假端口（向量轮接棒测试用）。
class _FakeEmbeddingPort implements EmbeddingPort {
  @override
  Future<AudioEmbedding?> embed(String path, {required int durationMs}) async =>
      AudioEmbedding(
          model: kEmbeddingModel,
          dim: kEmbeddingDim,
          vector: [for (var i = 0; i < kEmbeddingDim; i++) 0.1]);
}

void main() {
  late IaDatabase db;
  late ProviderContainer container;
  late Directory cacheDir;

  ProviderContainer buildContainer({EmbeddingPort? embeddingPort}) {
    return ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
      // 覆盖组合根的补全服务：不触指纹/网络，纯文字链在内存库上跑
      enrichmentServiceProvider.overrideWith((ref) async => EnrichmentService(
          db, _NoMatchLyrics(),
          cacheDir: cacheDir.path, embeddingPort: embeddingPort)),
      // 诊断同步捕获：断言与 unawaited 记录无竞态
      diagnosticsProvider.overrideWith(_CapturingDiag.new),
    ]);
  }

  setUp(() async {
    diagRecords.clear();
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    cacheDir = await Directory.systemTemp.createTemp('enrich_ctl_test');
    container = buildContainer();
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

  test('补全完成：轮次汇总进诊断记录（与「补全中断」对称）', () async {
    final rootId = await db.libraryDao.addRoot('/music');
    await db.libraryDao.upsertScannedBatch([
      TrackUpsert(
        rootId: rootId,
        relPath: 't2.mp3',
        path: '/music/t2.mp3',
        title: '汇总歌',
        artist: '',
        album: '',
        genre: '',
        needsMeta: true,
        trackNo: 2,
        durationMs: 60000,
        sizeBytes: 10,
        contentHash: 'h2',
        audioFormat: 'mp3',
      ),
    ]);

    await container.read(enrichProvider.notifier).resumeIfNeeded();

    final summaryLines =
        diagRecords.where((r) => r.startsWith('补全:')).toList();
    expect(summaryLines, hasLength(1), reason: '完成轮次汇总一条');
    expect(summaryLines.single, contains('采纳 0 / 1'));
  });

  test('向量轮：元数据清完后由嵌入端口接棒（有端口才跑）', () async {
    container.dispose();
    container = buildContainer(embeddingPort: _FakeEmbeddingPort());
    final rootId = await db.libraryDao.addRoot('/music');
    await db.libraryDao.upsertScannedBatch([
      TrackUpsert(
        rootId: rootId,
        relPath: 't3.mp3',
        path: '/music/t3.mp3',
        title: '向量歌',
        artist: '',
        album: '',
        genre: '',
        needsMeta: true,
        trackNo: 3,
        durationMs: 60000,
        sizeBytes: 10,
        contentHash: 'h3',
        audioFormat: 'mp3',
      ),
    ]);

    await container.read(enrichProvider.notifier).resumeIfNeeded();

    final st = container.read(enrichProvider);
    expect(st.running, isFalse);
    expect(st.lastSummary, contains('向量 1/1'),
        reason: '元数据轮后向量轮接棒，汇总带向量计数');
    expect(
        await db.vectorDao.countWithoutVector(model: kEmbeddingModel), 0,
        reason: '向量已落账');
  });

  test('向量轮：端口缺失时整段跳过（不出假「向量中断」）', () async {
    final rootId = await db.libraryDao.addRoot('/music');
    await db.libraryDao.upsertScannedBatch([
      TrackUpsert(
        rootId: rootId,
        relPath: 't4.mp3',
        path: '/music/t4.mp3',
        title: '无端口歌',
        artist: '',
        album: '',
        genre: '',
        needsMeta: true,
        trackNo: 4,
        durationMs: 60000,
        sizeBytes: 10,
        contentHash: 'h4',
        audioFormat: 'mp3',
      ),
    ]);

    await container.read(enrichProvider.notifier).resumeIfNeeded();

    final st = container.read(enrichProvider);
    expect(st.lastSummary, contains('补全完成'),
        reason: '端口缺失（测试宿主等）→ 向量段静默跳过，不出假中断');
    expect(st.lastSummary, isNot(contains('向量中断')));
    expect(
        diagRecords.where((r) => r.startsWith('补全向量中断')), isEmpty);
  });
}
