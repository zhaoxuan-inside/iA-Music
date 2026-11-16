/// CollectRunner 提取管道测试：假平台客户端 + 真下载落盘 + 真扫描入库。
///
/// 覆盖：直链下载、B 站单 P/多 P 拆分/指定 P、YouTube 提取、失败路径、归歌单。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/entities/track.dart';
import 'package:ia_music/services/collect/bilibili_client.dart';
import 'package:ia_music/services/collect/collect_ports.dart';
import 'package:ia_music/services/collect/collect_service.dart';
import 'package:ia_music/services/collect/youtube_client.dart';
import 'package:ia_music/services/scan/scan_service.dart';

/// 夹具音频字节（探曲01.mp3，带真实 tag）——下载落盘后由真扫描链路解析。
final Uint8List _fixture =
    File('test/fixtures/library_smoke/探曲01.mp3').readAsBytesSync();

class FakeBili implements BiliCollectApi {
  FakeBili(
      {List<({int cid, String part})> pages = const [], bool failInfo = false})
      : pages = List.of(pages),
        failInfo = failInfo;

  List<({int cid, String part})> pages;
  bool failInfo;

  @override
  Future<BiliVideoInfo> videoInfo(String bvid) async {
    if (failInfo) {
      throw Exception('视频不存在');
    }
    return BiliVideoInfo(
        bvid: bvid,
        title: '测试视频',
        owner: '测试UP',
        cid: pages.isEmpty ? 7 : pages.first.cid,
        pages: pages,
        durationSec: 180,
        aid: '999');
  }

  @override
  Future<BiliAudioStream> audioStream(
          String bvid, String aid, int cid) async =>
      BiliAudioStream(
          url: 'http://127.0.0.1:9/audio',
          sizeBytes: _fixture.length,
          ext: 'mp3',
          qualityId: 30232);

  @override
  Future<String> downloadAudio(BiliAudioStream stream, String filePath,
      {void Function(int received, int total)? onProgress}) async {
    await File(filePath).writeAsBytes(_fixture, flush: true);
    onProgress?.call(_fixture.length, _fixture.length);
    return filePath;
  }

  @override
  Future<List<BiliSubtitle>> subtitles(String? aid, int cid) async => const [];

  @override
  Future<String?> subtitleLrc(String subtitleUrl) async => null;
}

class FakeYt implements YtCollectApi {
  @override
  Future<(Map<String, dynamic>, YtAudioStream)> resolveAudio(
          String videoId) async =>
      (
        {'title': 'YT Song', 'author': 'YT Artist'},
        YtAudioStream(
            url: 'http://127.0.0.1:9/a', ext: 'mp3', bitrate: 128000),
      );

  @override
  Future<String> downloadAudio(YtAudioStream stream, String filePath,
      {void Function(int received, int total)? onProgress}) async {
    await File(filePath).writeAsBytes(_fixture, flush: true);
    return filePath;
  }
}

void main() {
  late IaDatabase db;
  late Directory rootDir;
  late FakeBili bili;
  late FakeYt yt;
  late CollectRunner runner;

  setUp(() async {
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    rootDir = Directory.systemTemp.createTempSync('ia_collect');
    bili = FakeBili();
    yt = FakeYt();
    runner = CollectRunner(db, ScanService(db),
        cacheDir: rootDir.path, bilibili: bili, youtube: yt);
    await db.libraryDao.addRoot(rootDir.path);
  });

  tearDown(() async {
    await db.close();
    rootDir.deleteSync(recursive: true);
  });

  Future<List<CollectTaskRow>> tasks() => db.collectDao.watchAll().first;
  Future<List<Track>> tracks() =>
      db.libraryDao.watchTracks(sort: TrackSort.title).first;

  test('直链：HTTP 下载 → 重扫入库 → done', () async {
    final fileServer = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(fileServer.close);
    fileServer.listen((req) async {
      req.response.add(_fixture);
      await req.response.close();
    });
    await db.collectDao.enqueue(
        'direct', 'http://127.0.0.1:${fileServer.port}/song.mp3',
        title: '直链歌', artist: '');

    await runner.runOnce();

    final all = await tasks();
    expect(all.single.status, CollectStatusCol.done);
    expect(all.single.filePath, isNotNull);
    expect(await tracks(), hasLength(1));
  });

  test('B 站单 P：提取 → 入库 → 归歌单', () async {
    bili.pages = const [(cid: 1, part: 'P1')];
    final playlistId = await db.playlistDao.createPlaylist('提取单');
    await db.collectDao.enqueue(
        'bilibili', 'https://www.bilibili.com/video/BV1TEST12345',
        playlistId: playlistId);

    await runner.runOnce();

    final all = await tasks();
    expect(all.single.status, CollectStatusCol.done);
    final pts = await db.playlistDao.watchPlaylistTracks(playlistId).first;
    expect(pts, hasLength(1));
    expect(await tracks(), hasLength(1));
  });

  test('B 站多 P：自动拆分（P1 重定向 + P2 入队）→ 全部 done', () async {
    bili.pages = const [
      (cid: 1, part: '001.周杰伦-爱在西元前'),
      (cid: 2, part: '002.周杰伦-安静'),
    ];
    await db.collectDao
        .enqueue('bilibili', 'https://www.bilibili.com/video/BV1TEST12345');

    await runner.runOnce();

    final all = await tasks();
    expect(all, hasLength(2), reason: 'P2 应被拆分入队');
    expect(all.map((t) => t.status), everyElement(CollectStatusCol.done));
    expect(
        all.map((t) => Uri.parse(t.url).queryParameters['p']),
        unorderedEquals(['1', '2']));
    expect(await tracks(), hasLength(2));
  });

  test('B 站带 p 参数：只提取指定 P，不拆分', () async {
    bili.pages = const [
      (cid: 1, part: 'P1'),
      (cid: 2, part: 'P2'),
    ];
    await db.collectDao.enqueue('bilibili',
        'https://www.bilibili.com/video/BV1TEST12345?p=2');

    await runner.runOnce();

    final all = await tasks();
    expect(all, hasLength(1));
    expect(all.single.status, CollectStatusCol.done);
    expect(await tracks(), hasLength(1));
  });

  test('YouTube：解析 → 下载 → 入库 → done', () async {
    await db.collectDao
        .enqueue('youtube', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');

    await runner.runOnce();

    final all = await tasks();
    expect(all.single.status, CollectStatusCol.done);
    expect(all.single.filePath, contains('YT Artist - YT Song.mp3'));
    expect(await tracks(), hasLength(1));
  });

  test('视频信息失败：任务标记 failed，不中断后续轮次', () async {
    bili.failInfo = true;
    await db.collectDao
        .enqueue('bilibili', 'https://www.bilibili.com/video/BV1TEST12345');

    await runner.runOnce();

    final all = await tasks();
    expect(all.single.status, CollectStatusCol.failed);
    expect(await tracks(), isEmpty);
  });

  test('僵尸 running 任务（App 中途死亡）：开轮自动回收重跑', () async {
    final id = await db.collectDao
        .enqueue('bilibili', 'https://www.bilibili.com/video/BV1TEST12345');
    // 模拟死亡现场：任务停在 running/85%，文件没落盘
    await db.collectDao.setStatus(id, CollectStatusCol.running);
    await db.collectDao.setProgress(id, 85);

    await runner.runOnce();

    final all = await tasks();
    expect(all.single.status, CollectStatusCol.done);
    expect(await tracks(), hasLength(1));
  });
}
