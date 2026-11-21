/// CollectRunner 提取管道测试：FakeRuntime 驱动的 source 插件 + 真下载落盘 + 真扫描入库。
///
/// 覆盖：直链下载、插件单曲目/多曲目拆分/指定子曲目、歌词随带、失败路径、
/// 僵尸回收、归歌单。平台知识在 FakeSession 的契约应答里（形态 = docs/PLUGIN.md §3.2）。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/entities/track.dart';
import 'package:ia_music/plugins/plugin_registry.dart';
import 'package:ia_music/plugins/plugin_runtime.dart';
import 'package:ia_music/services/collect/collect_service.dart';
import 'package:ia_music/services/collect/source_plugins.dart';
import 'package:ia_music/services/scan/scan_service.dart';

/// 夹具音频字节（探曲01.mp3，带真实 tag）——下载落盘后由真扫描链路解析。
final Uint8List _fixture =
    File('test/fixtures/library_smoke/探曲01.mp3').readAsBytesSync();

const _fakePluginSource = '''
/*!
{ "id": "test.fake-source", "name": "假音频源", "version": "1.0.0", "api": 1,
  "capabilities": ["source"] }
*/
async function match(url) { return url.indexOf('fake.test') >= 0 ? { id: url } : null; }
async function search() { return { items: [] }; }
async function resolve() { return {}; }
async function stream() { return {}; }
async function lyrics() { return null; }
async function authKind() { return { kind: 'none' }; }
async function authStatus() { return { loggedIn: true, account: 'fake' }; }
async function authStart() { return {}; }
async function authPoll() { return {}; }
async function authImport() { return {}; }
async function authLogout() { return {}; }
''';

/// 契约应答可编程的假会话：行为由 [resolvePages]/[failResolve]/[lyricsText] 决定。
class FakeSession implements PluginSession {
  int serverPort = 0;

  /// 子曲目列表（id/title/artist）——resolve 应答的 tracks。
  List<Map<String, Object?>> resolvePages = const [];

  String? lyricsText;
  bool failResolve = false;
  int _resolveCalls = 0;
  final List<String> _logs = <String>[];

  int get resolveCalls => _resolveCalls;

  @override
  Future<Object?> call(String fn, List<Object?> args, {Duration? timeout}) async {
    switch (fn) {
      case 'match':
        final url = '${args[0]}';
        return url.contains('fake.test') ? {'id': url} : null;
      case 'resolve':
        _resolveCalls++;
        if (failResolve) {
          throw Exception('插件解析失败');
        }
        return {
          'title': '测试视频',
          'artist': '测试UP',
          'durationSec': 180,
          'tracks': resolvePages,
        };
      case 'stream':
        final id = '${args[0]}';
        return {
          'url': 'http://127.0.0.1:$serverPort/audio/$id',
          'ext': 'mp3',
          'headers': <String, Object?>{},
        };
      case 'lyrics':
        return lyricsText == null ? null : {'synced': lyricsText};
      default:
        return null;
    }
  }

  @override
  List<String> get logs => _logs;
  @override
  void dispose() {}
}

class FakeRuntime implements PluginRuntimePort {
  final FakeSession session = FakeSession();

  @override
  Future<PluginSession> open(InstalledPlugin plugin) async => session;
}

void main() {
  late IaDatabase db;
  late Directory rootDir;
  late Directory pluginDir;
  late FakeRuntime runtime;
  late PluginRegistry registry;
  late SourcePlugins sources;
  late CollectRunner runner;
  late HttpServer fileServer;

  FakeSession fake() => runtime.session;

  setUp(() async {
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    rootDir = Directory.systemTemp.createTempSync('ia_collect');
    pluginDir = Directory.systemTemp.createTempSync('ia_plugin_reg');
    registry = PluginRegistry(dir: pluginDir.path);
    runtime = FakeRuntime();
    sources = SourcePlugins(registry, runtime);
    runner = CollectRunner(db, ScanService(db),
        cacheDir: rootDir.path, sources: sources);
    await db.libraryDao.addRoot(rootDir.path);
    await registry
        .installFromSource(_fakePluginSource)
        .then((_) => sources.reset());

    fileServer = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(fileServer.close);
    fileServer.listen((req) async {
      req.response.add(_fixture);
      await req.response.close();
    });
    fake().serverPort = fileServer.port;
    addTearDown(() => pluginDir.deleteSync(recursive: true));
  });

  tearDown(() async {
    await db.close();
    rootDir.deleteSync(recursive: true);
  });

  Future<List<CollectTaskRow>> tasks() => db.collectDao.watchAll().first;
  Future<List<Track>> tracks() =>
      db.libraryDao.watchTracks(sort: TrackSort.title).first;

  Map<String, Object?> track(int i, String title, String artist) =>
      {'id': 'track-$i', 'title': title, 'artist': artist};

  test('直链：HTTP 下载 → 重扫入库 → done', () async {
    await db.collectDao.enqueue(
        'direct', 'http://127.0.0.1:${fileServer.port}/song.mp3',
        title: '直链歌', artist: '');

    await runner.runOnce();

    final all = await tasks();
    expect(all.single.status, CollectStatusCol.done);
    expect(all.single.filePath, isNotNull);
    expect(await tracks(), hasLength(1));
  });

  test('插件单曲目：resolve → stream → 宿主下载 → 入库 → 归歌单', () async {
    fake().resolvePages = [track(1, 'P1', '测试UP')];
    final playlistId = await db.playlistDao.createPlaylist('提取单');
    await db.collectDao.enqueue(
        'test.fake-source', 'https://fake.test/video/BV1TEST12345',
        playlistId: playlistId);

    await runner.runOnce();

    final all = await tasks();
    expect(all.single.status, CollectStatusCol.done);
    final pts = await db.playlistDao.watchPlaylistTracks(playlistId).first;
    expect(pts, hasLength(1));
    expect(await tracks(), hasLength(1));
  });

  test('插件多曲目：自动拆分（首曲重定向 + 其余入队）→ 全部 done，解析只一次', () async {
    fake().resolvePages = [
      track(1, '001.周杰伦-爱在西元前', '测试UP'),
      track(2, '002.周杰伦-安静', '测试UP'),
    ];
    await db.collectDao
        .enqueue('test.fake-source', 'https://fake.test/video/BV1TEST12345');

    await runner.runOnce();

    final all = await tasks();
    expect(all, hasLength(2), reason: '第二曲应被拆分入队');
    expect(all.map((t) => t.status), everyElement(CollectStatusCol.done));
    expect(
        all.map((t) => t.url),
        unorderedEquals([
          'https://fake.test/video/BV1TEST12345#ia-track=1',
          'https://fake.test/video/BV1TEST12345#ia-track=2',
        ]));
    expect(await tracks(), hasLength(2));
    expect(fake().resolveCalls, 1, reason: '同一链接的元数据缓存：两个任务只 resolve 一次');
  });

  test('插件带 #ia-track 片段：只提取指定子曲目，不拆分', () async {
    fake().resolvePages = [
      track(1, 'P1', '测试UP'),
      track(2, 'P2', '测试UP'),
    ];
    await db.collectDao.enqueue('test.fake-source',
        'https://fake.test/video/BV1TEST12345#ia-track=2');

    await runner.runOnce();

    final all = await tasks();
    expect(all, hasLength(1));
    expect(all.single.status, CollectStatusCol.done);
    expect(await tracks(), hasLength(1));
  });

  test('插件随带歌词：LRC 落盘并挂到曲目', () async {
    fake().resolvePages = [track(1, '歌词歌', '测试UP')];
    fake().lyricsText = '[00:01.00]测试歌词\n';
    await db.collectDao
        .enqueue('test.fake-source', 'https://fake.test/video/BV1TEST12345');

    await runner.runOnce();

    final all = await tasks();
    expect(all.single.status, CollectStatusCol.done);
    final filePath = all.single.filePath!;
    final dot = filePath.lastIndexOf('.');
    final lrcTarget = dot > 0
        ? '${filePath.substring(0, dot)}.lrc'
        : '$filePath.lrc';
    expect(File(lrcTarget).readAsStringSync(), contains('测试歌词'));
    final ts = await tracks();
    expect(ts, hasLength(1));
    final meta = await db.lyricsDao.metaOf(ts.single.id);
    expect(meta?.lrcPath, lrcTarget, reason: '歌词表挂接到 LRC 文件');
  });

  test('插件解析失败：任务标记 failed，不中断后续轮次', () async {
    fake().failResolve = true;
    await db.collectDao
        .enqueue('test.fake-source', 'https://fake.test/video/BV1TEST12345');

    await runner.runOnce();

    final all = await tasks();
    expect(all.single.status, CollectStatusCol.failed);
    expect(await tracks(), isEmpty);
  });

  test('未安装的来源插件：任务 failed', () async {
    await db.collectDao
        .enqueue('test.not-installed', 'https://fake.test/video/BV1TEST12345');

    await runner.runOnce();

    expect((await tasks()).single.status, CollectStatusCol.failed);
  });

  test('僵尸 running 任务（App 中途死亡）：开轮自动回收重跑', () async {
    fake().resolvePages = [track(1, 'P1', '测试UP')];
    final id = await db.collectDao
        .enqueue('test.fake-source', 'https://fake.test/video/BV1TEST12345');
    // 模拟死亡现场：任务停在 running/85%，文件没落盘
    await db.collectDao.setStatus(id, CollectStatusCol.running);
    await db.collectDao.setProgress(id, 85);

    await runner.runOnce();

    final all = await tasks();
    expect(all.single.status, CollectStatusCol.done);
    expect(await tracks(), hasLength(1));
  });
}
