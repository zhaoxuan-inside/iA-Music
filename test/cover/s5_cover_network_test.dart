// DEC-010: live services only. Never substitute HTTP or replay responses.
import 'dart:io';

import 'package:contracts/contracts.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/cover_fetch_adapter.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/cover_chain.dart';

void main() {
  test('CAA 主源真实命中：1200 JPEG、逐跳限流、不调用 iTunes', () async {
    final fetch = CoverFetchAdapter();
    addTearDown(fetch.close);
    final result = await fetch.fetchTrackCover(
      const CoverQuery(
        trackId: 1,
        title: 'Come Together',
        artistDisplay: 'The Beatles',
      ),
    );
    // ignore: avoid_print
    print('CAA primary real responses: ${fetch.responses.map((r) => '${r.uri.host}:${r.statusCode}').join(',')}');
    expect(
      result?.source,
      CoverSource.caa,
      reason: '需要可访问 archive.org 的真实网络；可通过 HTTPS_PROXY 配置现有代理',
    );
    final file = File(result!.localPath);
    addTearDown(() async {
      await file.delete();
      await file.parent.delete();
    });
    expect(await file.length(), greaterThan(1000));
    expect((await file.readAsBytes()).take(3), [255, 216, 255]);
    expect(fetch.requests.any((r) => r.uri.path.endsWith('-1200.jpg')), isTrue);
    expect(
      fetch.requests.any((r) => r.uri.host == 'itunes.apple.com'),
      isFalse,
    );
    expect(
      fetch.responses.where((r) => r.statusCode == 200).length,
      greaterThanOrEqualTo(3),
    );
    for (var i = 1; i < fetch.requests.length; i++) {
      expect(
        fetch.requests[i].startedAt
            .difference(fetch.requests[i - 1].startedAt)
            .inMilliseconds,
        greaterThanOrEqualTo(1000),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
  test('容量一令牌桶：三个并发真实计时请求许可间隔 ≥1秒', () async {
    final limiter = CoverRequestLimiter();
    final clock = Stopwatch()..start();
    final starts = <int>[];
    await Future.wait(
      List.generate(3, (_) async {
        await limiter.acquire();
        starts.add(clock.elapsedMicroseconds);
      }),
    );
    for (var i = 1; i < starts.length; i++) {
      expect(starts[i] - starts[i - 1], greaterThanOrEqualTo(1000000));
    }
  });

  test('REQ-LIB-08 真 CAA/iTunes → 同目录 JPEG → 注册，音频不变，再浏览零新增请求', () async {
    final dir = await Directory.systemTemp.createTemp('ia_s5_online_');
    final db = (await openIaDatabaseMemory()).db;
    final fetch = CoverFetchAdapter();
    addTearDown(() async {
      fetch.close();
      await db.close();
      await dir.delete(recursive: true);
    });
    final data = DataAccess(db);
    final chain = CoverChain(data, fetch);
    final audio = await File('test/fixtures/library_smoke/探曲03.mp3')
        .copy('${dir.path}/Imagine.mp3');
    final bytes = await audio.readAsBytes();
    final root = await db
        .into(db.repositoryRoots)
        .insert(
          RepositoryRootsCompanion.insert(
            path: dir.path,
            mode: RepositoryMode.directory,
            addedAt: 1,
          ),
        );
    final id = await data.library.insertTrackWithIndex(
      root,
      'Imagine.mp3',
      mtime: 1,
      fileSize: bytes.length,
      contentHash: 'real-audio',
      nowMs: 1,
      title: 'Imagine',
      artistDisplay: 'John Lennon',
    );
    final result = await chain.decide(id);
    // ignore: avoid_print
    print(
      'Real network: kind=${result.kind}; requests=${fetch.requests.map((r) => r.uri.host).join(',')}; responses=${fetch.responses.map((r) => '${r.uri.host}:${r.statusCode}').join(',')}',
    );
    expect(
      result.kind,
      CoverKind.fetched,
      reason:
          'Live cover services must return a real cover; outage is not PASS',
    );
    expect(File(result.localPath!).uri, File('${audio.path}.cover.jpg').uri);
    expect(await File(result.localPath!).length(), greaterThan(100));
    expect((await File(result.localPath!).readAsBytes()).take(3), [
      255,
      216,
      255,
    ]);
    final count = fetch.requestCount;
    expect((await chain.decide(id)).kind, CoverKind.fetched);
    expect(fetch.requestCount, count);
    expect(
      (await data.library.rowById(id))!.coverRelPath,
      'Imagine.mp3.cover.jpg',
    );
    expect(await audio.readAsBytes(), bytes);
    for (var i = 1; i < fetch.requests.length; i++) {
      expect(
        fetch.requests[i].startedAt
            .difference(fetch.requests[i - 1].startedAt)
            .inMilliseconds,
        greaterThanOrEqualTo(990),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('真实不存在曲名：无匹配→色块，无封面文件、无元数据改写', () async {
    final dir = await Directory.systemTemp.createTemp('ia_s5_miss_');
    final db = (await openIaDatabaseMemory()).db;
    final fetch = CoverFetchAdapter();
    addTearDown(() async {
      fetch.close();
      await db.close();
      await dir.delete(recursive: true);
    });
    final data = DataAccess(db);
    await File('test/fixtures/library_smoke/探曲03.mp3')
        .copy('${dir.path}/miss.mp3');
    final root = await db
        .into(db.repositoryRoots)
        .insert(
          RepositoryRootsCompanion.insert(
            path: dir.path,
            mode: RepositoryMode.directory,
            addedAt: 1,
          ),
        );
    final id = await data.library.insertTrackWithIndex(
      root,
      'miss.mp3',
      mtime: 1,
      fileSize: 1,
      contentHash: 'real-audio',
      nowMs: 1,
      title: 'ia_music_nonexistent_${DateTime.now().microsecondsSinceEpoch}',
    );
    final result = await CoverChain(data, fetch).decide(id);
    expect(result.kind, CoverKind.none);
    expect(fetch.requestCount, greaterThanOrEqualTo(2));
    // ignore: avoid_print
    print(
      'No-match real responses: ${fetch.responses.map((r) => '${r.uri.host}:${r.statusCode}').join(',')}',
    );
    expect(
      fetch.responses
          .where(
            (r) =>
                r.statusCode == 200 &&
                (r.uri.host == 'musicbrainz.org' ||
                    r.uri.host == 'itunes.apple.com'),
          )
          .length,
      2,
      reason: '无匹配必须有两源成功响应，不能用服务故障冒充无结果',
    );
    expect(await File('${dir.path}/miss.mp3.cover.jpg').exists(), isFalse);
    final row = (await data.library.rowById(id))!;
    expect(row.coverKind, CoverKind.none);
    expect(row.updatedAt, 1);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
