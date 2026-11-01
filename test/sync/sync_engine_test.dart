/// 同步域 E2E（WS6/DEC-010 全真：MiniWebDavServer=真实协议 fixture）。
/// * Gherkin 锚：REQ-SYNC-02/03 跨端闭环；REQ-SYNC-05 墓碑不毁云端资产；
///   REQ-SYNC-06 断网恢复（通道错误=TestResult 人话，状态机面单测锚）。
/// * 双实例=同机双内存库 + 双临时仓库目录。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/playlists/playlist_service.dart';
import 'package:contracts/contracts.dart';
import 'package:ia_music/sync/sync_service.dart';
import 'webdav_fixture_server.dart';

/// 测试内存认据面（SecureStorePort 测试缝；协议/传输仍全真）。
class _MemSecure implements SecureStorePort {
  final _map = <String, String>{};
  @override
  Future<bool> containsKey(String key) async => _map.containsKey(key);
  @override
  Future<void> delete(String key) async => _map.remove(key);
  @override
  Future<String?> read(String key) async => _map[key];
  @override
  Future<void> write(String key, String value) async => _map[key] = value;
}

void main() {

  late MiniWebDavServer server;
  late Uri baseUri;
  late Directory rootA;
  late Directory rootB;

  setUpAll(() async {
    server = MiniWebDavServer();
    baseUri = await server.start(username: 'ia-test', password: 'pw'); // 真协议
  });

  tearDownAll(() async {
    await server.stop();
  });

  setUp(() async {
    rootA = await Directory.systemTemp.createTemp('ia_sync_a');
    rootB = await Directory.systemTemp.createTemp('ia_sync_b');
  });

  tearDown(() async {
    await rootA.delete(recursive: true);
    await rootB.delete(recursive: true);
  });

  /// 实例工厂：内存库 + hub + 一个仓库根（含 1 首 1KB 假音频=真实字节文件）。
  Future<(LibraryHub, IaDatabase, File)> makeInstance(String name, Directory root) async {
    final gate = await openIaDatabaseMemory();
    final db = gate.db;
    final hub = LibraryHub(db);
    final rootId = await db.into(db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(
            path: root.path,
            mode: RepositoryMode.directory,
            addedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    final audio = File('${root.path}/song.mp3');
    await audio.writeAsBytes(List.generate(1024, (i) => i % 256));
    final dao = DataAccess(db).library;
    await dao.insertTrackBatch([
      ScannedTrackInput(
        rootId: rootId,
        relPath: 'song.mp3',
        mtime: DateTime.now().millisecondsSinceEpoch,
        fileSize: 1024,
        contentHash: 'hash-$name-1',
        nowMs: DateTime.now().millisecondsSinceEpoch,
        title: '测试曲',
        artistDisplay: '测试歌手',
      ),
    ]);
    return (hub, db, audio);
  }

  /// 通道装配（applyChannel 走真实 testConnection→fixture）。
  Future<void> attachChannel(SyncService svc, String password) async {
    final err = await svc.applyChannel(
      type: SyncChannelType.webdav,
      baseUrl: baseUri.toString(),
      credentialsValue: password,
      username: 'ia-test',
    );
    expect(err, isNull, reason: '通道连接测试应通过（REQ-SYNC-01）');
  }

  test('REQ-SYNC-02/03 跨端闭环：A 曲目+红心 → 30s 内远端可见 → B 拉取可播放',
      timeout: const Timeout(Duration(seconds: 60)), () async {
    final (hubA, dbA, audioA) = await makeInstance('a', rootA);
    addTearDown(() async {
      await hubA.dispose();
      await dbA.close();
    });
    final svcA = SyncService(db: dbA, secure: _MemSecure());
    await attachChannel(svcA, 'pw');

    // A：建歌单并收录（轻数据变更喂点 → 引擎 30s 防抖；此处手动同步）
    final playlist = await hubA.data.playlists
        .create('深夜', nowMs: DateTime.now().millisecondsSinceEpoch);
    final track = (await hubA.data.library.liveTracksOnce(LibSort.recent)).first;
    // ignore: unused_local_variable
    await hubA.data.playlists.addTrack(
      playlist.id,
      track.id,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );

    final summary = await svcA.syncNow();
    expect(summary, isNotNull);
    expect(summary!.applied, isNull, reason: '完整跑完无中断');
    expect(summary.uploaded, greaterThanOrEqualTo(1), reason: '音频本体上传');

    // 远端资产断言（fixture=权威真相）
    expect(server.exists('iA-Music/library.json'), isTrue);
    expect(server.exists('iA-Music/manifest.json'), isTrue);
    expect(server.exists('iA-Music/tombstones.json'), isTrue);
    expect(server.exists('iA-Music/audio/${rootA.path.replaceAll("\\", "/").split("/").last}/song.mp3'), isTrue,
        reason: 'relKey=rootBase/relPath');

    // ── B 端拉取 ──
    final (hubB, dbB, audioB) = await makeInstance('b', rootB);
    addTearDown(() async {
      await hubB.dispose();
      await dbB.close();
    });
    final svcB = SyncService(db: dbB, secure: _MemSecure());
    final errB = await svcB.applyChannel(
      type: SyncChannelType.webdav,
      baseUrl: baseUri.toString(),
      credentialsValue: 'pw',
      username: 'ia-test',
    );
    if (errB != null) {
      // fail fast with reason
      fail('B 通道装配失败: $errB');
    }

    final summaryB = await svcB.syncNow();
    expect(summaryB, isNotNull);
    expect(summaryB!.downloaded, greaterThanOrEqualTo(1), reason: '音频下载');
    // B 本地文件落盘（REQ-SYNC-03：下载后可直接播放=文件在根内）
    final pulled = File('${rootB.path}/song.mp3');
    expect(pulled.existsSync(), isTrue);
    expect(pulled.lengthSync(), audioA.lengthSync());
    expect(audioB.existsSync(), isTrue);

    // 轻数据：B 拉到 A 的歌单（uuid 键控）
    final bPlaylists = await PlaylistService(hubB.data).listAll();
    expect(
      bPlaylists.any((d) => d.playlist.name == '深夜'),
      isTrue,
      reason: 'REQ-SYNC-02：歌单跨端出现',
    );
  });

  test('REQ-SYNC-05 墓碑：A 移除曲目 → B 记录消失，云端音频保留',
      timeout: const Timeout(Duration(seconds: 60)), () async {
    final (hubA, dbA, _) = await makeInstance('a', rootA);
    addTearDown(() async {
      await hubA.dispose();
      await dbA.close();
    });
    final svcA = SyncService(db: dbA, secure: _MemSecure());
    await attachChannel(svcA, 'pw');
    await svcA.syncNow();

    final (hubB, dbB, _) = await makeInstance('b', rootB);
    addTearDown(() async {
      await hubB.dispose();
      await dbB.close();
    });
    final svcB = SyncService(db: dbB, secure: _MemSecure());
    await attachChannel(svcB, 'pw');
    await svcB.syncNow();

    // A 移除（LibraryService 内部登记墓碑——WS6 接线）
    final trackA =
        (await hubA.data.library.liveTracksOnce(LibSort.recent)).first;
    await hubA.library
        .removeTrack(trackA.id, nowMs: DateTime.now().millisecondsSinceEpoch);
    await svcA.syncNow();

    // B 拉取 → 曲目消失（墓碑下行应用）
    await svcB.syncNow();
    final bTracks = await hubB.data.library.liveTracksOnce(LibSort.recent);
    expect(bTracks, isEmpty, reason: 'REQ-SYNC-05：B 端记录随墓碑移除');

    // 云端音频仍在（Guardrail：远端文件永不因子端删除被删）
    expect(server.exists('iA-Music/audio/${rootA.path.replaceAll("\\", "/").split("/").last}/song.mp3'), isTrue,
        reason: '墓碑只传播记录，云端 .mp3 可手动找回');
  });

  test('REQ-SYNC-01 连接测试：错误凭据 → 人话 reason（不可保存）', timeout: const Timeout(Duration(seconds: 30)),
      () async {
    final (hubA, dbA, _) = await makeInstance('a', rootA);
    addTearDown(() async {
      await hubA.dispose();
      await dbA.close();
    });
    final err = await SyncService(db: dbA, secure: _MemSecure()).applyChannel(
      type: SyncChannelType.webdav,
      baseUrl: baseUri.toString(),
      credentialsValue: 'wrong-password',
      username: 'ia-test',
    );
    expect(err, isNotNull, reason: '错误凭据必须给具体人话原因');
    final channel = await hubA.data.sync.currentChannel();
    expect(channel, isNull, reason: '测试不通过=不落账（REQ-SYNC-01 门禁）');
  });
}
