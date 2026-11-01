// S4 歌单域服务测试（REQ-PL-01/02/03/04/06 数据面 + 我的页计数卡）。
//
// DEC-010 全真：真 drift 内存库 + 真行；无引擎（数据域纯 IO，普通 test() 异步）。
// 纪律：红心=system_favorite 唯一格；重复添加=DB UNIQUE 拦截（服务层 false）；
//       歌单删除=软删（listAll 排除）；历史淘汰只在 playback 域（此处只读计数）。
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/playlists/playlist_service.dart';

void main() {
  late IaDatabase db;
  late DataAccess data;
  late PlaylistService svc;
  var clock = 1000;
  int now() => clock++;

  setUp(() async {
    final gate = await openIaDatabaseMemory();
    db = gate.db;
    data = DataAccess(db);
    svc = PlaylistService(data);
    clock = 1000;
  });

  tearDown(() async {
    await db.close();
  });

  Future<(int, List<int>)> seedTracks(int n) async {
    final t = now();
    final rootId = await db.into(db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(
            path: 'E:/s4',
            mode: RepositoryMode.directory,
            addedAt: t,
          ),
        );
    final ids = <int>[];
    for (var i = 0; i < n; i++) {
      ids.add(await data.library.insertTrackWithIndex(
        rootId,
        'A/曲$i.flac',
        mtime: t,
        fileSize: 100 + i,
        contentHash: 'hash-s4-$i',
        nowMs: now(),
        title: '曲$i',
        artistDisplay: '歌手$i',
        albumDisplay: '专辑',
        format: AudioFormatSpec.flac,
      ));
    }
    return (rootId, ids);
  }

  test('REQ-PL-01：红心切换=system_favorite 唯一格 + 计数随加/出同步', () async {
    final (_, ids) = await seedTracks(2);

    expect(await svc.isFavorite(ids[0]), isFalse);
    expect(await svc.favoriteCount(), 0);

    expect(await svc.toggleFavorite(ids[0], nowMs: now()), isTrue, reason: '点上=加入');
    expect(await svc.isFavorite(ids[0]), isTrue);
    expect(await svc.favoriteCount(), 1, reason: '计数 +1（REQ-PL-01 计数同步）');

    expect(await svc.toggleFavorite(ids[0], nowMs: now()), isFalse, reason: '再点=移出');
    expect(await svc.isFavorite(ids[0]), isFalse);
    expect(await svc.favoriteCount(), 0, reason: '计数 -1（同步变化）');

    // 幂等：反复取收藏格不重复建行（DB 级部分唯一索引兜底）
    await svc.toggleFavorite(ids[1], nowMs: now());
    await svc.toggleFavorite(ids[0], nowMs: now());
    final favs = (await svc.listAll())
        .where((d) => d.playlist.kind == PlaylistKind.system_favorite)
        .toList();
    expect(favs.length, 1, reason: 'system_favorite 恰一行');
    expect(favs.first.trackCount, 2);
  });

  test('REQ-PL-02：新建歌单真行 + 软删后 listAll 不再列出', () async {
    final pl = await svc.create('深夜', nowMs: now());
    expect(pl.id, greaterThan(0));
    expect(pl.kind, PlaylistKind.user);

    var all = await svc.listAll();
    expect(all.map((d) => d.playlist.name), ['深夜']);

    await svc.delete(pl.id, nowMs: now());
    all = await svc.listAll();
    expect(all, isEmpty, reason: '删除=软删（REQ-PL-02），列表不再列出');

    // 软删行仍在库里（墓碑由 SyncEngine 补写；此处只证数据未物删）
    final raw = await (db.select(db.playlists)..where((p) => p.id.equals(pl.id)))
        .getSingle();
    expect(raw.deletedAt, isNotNull);
  });

  test('REQ-PL-03：重复添加被拦截（UNIQUE）+ 顺序保持 + 移出', () async {
    final (_, ids) = await seedTracks(3);
    final pl = await svc.create('深夜', nowMs: now());

    expect(await svc.addTo(pl.id, ids[0], nowMs: now()), isTrue);
    expect(await svc.addTo(pl.id, ids[2], nowMs: now()), isTrue);
    expect(await svc.addTo(pl.id, ids[0], nowMs: now()), isFalse,
        reason: 'DB UNIQUE(playlist_id, track_id) 拦截——服务层 false（UI 原话面）');
    expect(await data.playlists.contains(pl.id, ids[0]), isTrue);

    var rows = await svc.rows(pl.id);
    expect(rows.map((r) => r.id).toList(), [ids[0], ids[2]],
        reason: 'idx_pt_pos 顺序（REQ-PL-06 播放全部顺序）');

    await svc.removeFrom(pl.id, ids[0]);
    rows = await svc.rows(pl.id);
    expect(rows.map((r) => r.id).toList(), [ids[2]]);
  });

  test('我的页计数卡（REQ-NAV-05 从属面）：曲库活行 + 播放历史总数', () async {
    final (_, ids) = await seedTracks(3);
    expect(await svc.libraryCount(), 3);

    await data.history.recordBatch([
      (trackId: ids[0], completed: true, playedAtMs: now(), deviceId: 'test'),
      (trackId: ids[1], completed: false, playedAtMs: now(), deviceId: 'test'),
    ]);
    expect(await svc.historyCount(), 2);

    // 曲库卡口径与列表同构：软删行不计（缺失行计入=列表仍展示）
    await data.library.softDeleteTrack(ids[2], now());
    expect(await svc.libraryCount(), 2);
  });

  test('歌单计数随加入/移出同步（我的页红心卡口径）', () async {
    final (_, ids) = await seedTracks(2);
    final pl = await svc.create('跑步', nowMs: now());
    await svc.addTo(pl.id, ids[0], nowMs: now());
    await svc.addTo(pl.id, ids[1], nowMs: now());

    var digests = await svc.listAll();
    expect(digests.single.trackCount, 2);

    await svc.removeFrom(pl.id, ids[0]);
    digests = await svc.listAll();
    expect(digests.single.trackCount, 1);
  });
}
