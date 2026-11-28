/// 补全服务测试——FakeEngine 不可用（无原生指纹链），直接用假歌词端口：
/// 锁死「抛错不标记不计完成（不再原地打转卡 0/N）」与「高置信采纳写回」。
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/config/embedding_config.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/entities/track.dart';
import 'package:ia_music/domain/errors.dart';
import 'package:ia_music/domain/ports/embedding_port.dart';
import 'package:ia_music/domain/ports/fingerprint_port.dart';
import 'package:ia_music/domain/ports/lyrics_port.dart';
import 'package:ia_music/services/acoustid/acoustid_client.dart';
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
    final errors = <String>[];
    final (ok, completed) = await service.enrichPending(
        limit: 20,
        onError: (title, e, stages) =>
            errors.add('$title(${stages.join("·")}): $e'));
    // 「坏掉的歌」抛网络错（不计完成、不标记）；「好听的歌」无候选（标记）；
    // 「投名状」高置信采纳（标记）。完成数 = 2，采纳 = 1。
    expect(ok, 1);
    expect(completed, 2);
    expect(errors, hasLength(1), reason: '硬失败必须回调（诊断/日志追踪入口）');
    expect(errors.single, contains('坏掉的歌'));

    final bad = await trackByTitle('坏掉的歌');
    expect(bad.enrichedAt, isNull, reason: '未写回 → 留在待补全池');
    expect(bad.needsMeta, isTrue);

    final okCount = await db.libraryDao.countNeedsEnrichment();
    expect(okCount, 1, reason: '只剩抛错的那首');
  });

  test('高置信采纳：歌名/歌手写回 + 标记（显示列存原文大小写）', () async {
    await service.enrichPending(limit: 20);
    // 曾有 normKey 误写显示列的 bug——采纳的歌名被小写成「投名状 (live)」
    final t = await trackByTitle('投名状 (Live)');
    expect(t.title, '投名状 (Live)', reason: '显示列存原文，不折叠');
    final row = await (db.select(db.tracks)
          ..where((x) => x.title.equals('投名状 (Live)')))
        .getSingle();
    expect(row.titleNorm, '投名状 (Live)'.trim().toLowerCase(),
        reason: 'norm 列另行折叠');
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

  test('指纹链 AcoustID 400 → 软失败回退文字链，不再炸掉整曲', () async {
    // 400 服务器：曾经的黑屏级事故（JSON 请求被官方接口拒收）形态
    final server = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(server.close);
    server.listen((req) async {
      req.response.statusCode = 400;
      req.response
          .add(utf8.encode('{"error":{"message":"invalid client key"}}'));
      await req.response.close();
    });
    final svcFp = EnrichmentService(db, _FakeLyrics(),
        cacheDir: cacheDir.path,
        fingerprintPort: _FakeFpPort(),
        acoustid: AcoustidClient(
            apiKey: 'k', baseUrl: 'http://127.0.0.1:${server.port}'));

    final soft = <String>[];
    final (ok, completed) = await svcFp.enrichPending(
        limit: 20,
        onSoftError: (s, e) => soft.add('$s: $e'));

    // 指纹链 400 软失败 → 文字链接管：无候选/采纳路径照常结论
    expect(ok, 1);
    expect(completed, 2);
    expect(soft, hasLength(3), reason: '每曲一次指纹链软失败记录');
    expect(soft.first, contains('400'));
    final t = await trackByTitle('投名状 (Live)');
    expect(t.artist, '歌手', reason: '文字链接管后采纳不受指纹链影响');
  });

  test('指纹链 AuthError（key 无效）→ 会话级禁用：后续曲目不再请求 AcoustID', () async {
    var hits = 0;
    final server = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(server.close);
    server.listen((req) async {
      hits++;
      req.response.statusCode = 400;
      req.response
          .add(utf8.encode('{"error":{"code":4,"message":"invalid API key"}}'));
      await req.response.close();
    });
    final svcFp = EnrichmentService(db, _FakeLyrics(),
        cacheDir: cacheDir.path,
        fingerprintPort: _FakeFpPort(),
        acoustid: AcoustidClient(
            apiKey: 'k', baseUrl: 'http://127.0.0.1:${server.port}'));

    final soft = <String>[];
    final (ok, completed) = await svcFp.enrichPending(
        limit: 20,
        onSoftError: (s, e) => soft.add('$s: $e'));

    // 首曲即禁用指纹链：AcoustID 只被打 1 次（不再逐曲浪费指纹+HTTP，
    // 千首级全库 = 小时级纯浪费）；文字链接管照常推进与采纳。
    expect(hits, 1, reason: 'key 无效 → 会话级禁用，后续曲目直走文字链');
    expect(soft, hasLength(1), reason: '只记一次软失败，不逐曲刷屏');
    expect(soft.single, contains('key 无效'));
    expect(ok, 1);
    expect(completed, 2);
    final t = await trackByTitle('投名状 (Live)');
    expect(t.artist, '歌手', reason: '文字链接管照常采纳');
  });

  test('向量轮：池推进 + vectorAt 落账（dim/model 落库）', () async {
    final port = _FakeEmbeddingPort();
    final svc = EnrichmentService(db, _FakeLyrics(),
        cacheDir: cacheDir.path, embeddingPort: port);

    final (ok, completed) = await svc.embedPending(limit: 20);

    expect((ok, completed), (3, 3), reason: '向量池=全部存活曲目（独立于元数据结论）');
    expect(port.seen, hasLength(3));
    expect(await db.vectorDao.countWithoutVector(model: kEmbeddingModel), 0);
    final t = await trackByTitle('投名状');
    final v = await db.vectorDao.vectorOf(t.id);
    expect(v, isNotNull);
    expect(v!.model, kEmbeddingModel);
    expect(v.dim, kEmbeddingDim);
  });

  test('向量轮：曲目级失败记账留池（三败出池），不禁用端口', () async {
    final port = _FakeEmbeddingPort()..failAll = true;
    final svc = EnrichmentService(db, _FakeLyrics(),
        cacheDir: cacheDir.path, embeddingPort: port);

    for (var round = 1; round <= 3; round++) {
      final (ok, completed) = await svc.embedPending(limit: 20);
      expect((ok, completed), (0, 0), reason: '失败不计完成，原样留池');
    }
    expect(port.calls, 9, reason: '曲目级失败不禁用端口——每轮都重试');

    // 三败出池：池空，不再触端口
    final (ok2, completed2) = await svc.embedPending(limit: 20);
    expect((ok2, completed2), (0, 0));
    expect(port.calls, 9, reason: 'attempts≥3 暂出待算池');
  });

  test('向量轮：端口级 null → 会话禁用，不消耗重试计数', () async {
    final port = _FakeEmbeddingPort()..returnNull = true;
    final svc = EnrichmentService(db, _FakeLyrics(),
        cacheDir: cacheDir.path, embeddingPort: port);
    final soft = <String>[];

    final (ok, completed) =
        await svc.embedPending(limit: 20, onSoftError: (s, e) => soft.add(s));

    expect((ok, completed), (0, 0));
    expect(port.calls, 1, reason: '只碰一次端口就禁用');
    expect(soft, hasLength(1), reason: '端口级禁用只记一次软失败');
    expect(soft.single, contains('嵌入端口不可用'));

    final t = await trackByTitle('投名状');
    final row =
        await (db.select(db.tracks)..where((x) => x.id.equals(t.id)))
            .getSingle();
    expect(row.enrichAttempts, 0, reason: '端口级不可用不消耗曲目重试计数');

    // 会话级禁用：后续调用零端口触达
    final (ok2, completed2) = await svc.embedPending(limit: 20);
    expect((ok2, completed2), (0, 0));
    expect(port.calls, 1);
  });

  test('指纹链：AcoustID releases 的专辑/音轨采纳 + 五时刻打满', () async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(server.close);
    server.listen((req) async {
      req.response.headers.contentType = ContentType.json;
      req.response.add(utf8.encode(
          '{"status":"ok","results":[{"score":0.9,"recordings":['
          '{"title":"晴天","artists":[{"name":"周杰伦"}],'
          '"releases":[{"title":"叶惠美","mediums":[{"position":1,'
          '"tracks":[{"position":3,"title":"晴天"}]}]}]}]}]}'));
      await req.response.close();
    });
    final svc = EnrichmentService(db, _FakeLyrics(),
        cacheDir: cacheDir.path,
        fingerprintPort: _FakeFpPort(),
        acoustid: AcoustidClient(
            apiKey: 'k', baseUrl: 'http://127.0.0.1:${server.port}'));

    final (ok, completed) = await svc.enrichPending(limit: 20);
    expect(ok, 3, reason: '三条假指纹全部命中假 AcoustID');

    // 三条曲目全部被采纳为同一匹配（假源固定返回晴天）——按路径取行断言
    final row = await (db.select(db.tracks)
          ..where((x) => x.path.equals('/music/t2.mp3')))
        .getSingle();
    expect(row.title, '晴天');
    expect(row.album, '叶惠美', reason: 'releases 的专辑名采纳');
    expect(row.trackNo, 3, reason: 'release medium 的音轨号采纳');
    // 五时刻一次打满（结论性）
    expect(row.titleMatchedAt, isNotNull);
    expect(row.artistMatchedAt, isNotNull);
    expect(row.lyricsAt, isNotNull);
    expect(row.albumMatchedAt, isNotNull);
    expect(row.trackMatchedAt, isNotNull);
  });

  test('文字链无专辑源：专辑/音轨确认无结案（保持原值）', () async {
    await service.enrichPending(limit: 20); // setUp 默认纯文字链服务

    final t = await trackByTitle('投名状 (Live)');
    expect(t.album, '', reason: 'LRCLIB 无专辑数据——保持原值不乱填');
    expect(t.trackNo, 3, reason: '无源保持原值（夹具 trackNo 即 3）');
    final row = await (db.select(db.tracks)
          ..where((x) => x.title.equals('投名状 (Live)')))
        .getSingle();
    expect(row.albumMatchedAt, isNotNull, reason: '确认无也结案，避免无限重试');
    expect(row.trackMatchedAt, isNotNull);

    final stages = await db.libraryDao.watchEnrichStages().first;
    final album = stages.firstWhere((s) => s.label == '专辑');
    // 好听的歌/投名状：文字链确认无（灰档×2）；坏掉的歌：网络错未结案（失败桶）
    expect((album.done, album.missed, album.failed, album.total),
        (0, 2, 1, 3));
  });
}

/// 假嵌入端口：确定性向量；failAll=曲目级失败（抛错），returnNull=端口级不可用。
class _FakeEmbeddingPort implements EmbeddingPort {
  int calls = 0;
  final List<String> seen = [];
  bool failAll = false;
  bool returnNull = false;

  @override
  Future<AudioEmbedding?> embed(String path, {required int durationMs}) async {
    calls++;
    seen.add(path);
    if (returnNull) {
      return null;
    }
    if (failAll) {
      throw Exception('decode broken');
    }
    return AudioEmbedding(
        model: kEmbeddingModel,
        dim: kEmbeddingDim,
        vector: [for (var i = 0; i < kEmbeddingDim; i++) 0.1]);
  }
}

/// 会吐指纹的假指纹端口（指纹链必走 AcoustID）。
class _FakeFpPort implements FingerprintPort {
  @override
  Future<AudioFingerprint?> fingerprint(String path,
      {required int durationMs}) async {
    return AudioFingerprint(fingerprint: 'FPBASE64', durationMs: durationMs);
  }
}
