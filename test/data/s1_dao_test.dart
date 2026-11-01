// S1 DAO 门面行为测试（DEC-010：真 sqlite3 引擎；行为断言优于内部断言）
//
// 覆盖九组查询的行为层 + D9-2/D9-3 + 域写路径（见 IMPL-S1）。
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';

void main() {
  late IaDatabase db;
  late DataAccess dao;

  setUp(() async {
    final gate = await openIaDatabaseMemory();
    db = gate.db;
    dao = DataAccess(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 建一个根 + n 首真曲目（含 FTS 同事务），返回 (rootId, ids)。
  Future<(int, List<int>)> seedTracks(List<(String, String?)> titleArtists) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rootId = await db
        .into(db.repositoryRoots)
        .insert(RepositoryRootsCompanion.insert(
          path: 'E:/music',
          mode: RepositoryMode.directory,
          addedAt: now,
        ));
    final ids = <int>[];
    for (final (title, artist) in titleArtists) {
      final id = await dao.library.insertTrackWithIndex(
        rootId,
        'A/$title.flac',
        mtime: now,
        fileSize: title.hashCode & 0xFF,
        contentHash: 'hash-$title',
        nowMs: now,
        title: title,
        artistDisplay: artist,
        albumDisplay: '专辑',
        format: AudioFormatSpec.flac,
      );
      ids.add(id);
    }
    return (rootId, ids);
  }

  group('① 全局搜索（REQ-NAV-04）', () {
    test('汉字前缀 + 拼音首字母 + 空格拼音三路（真 FTS 同事务）', () async {
      final (root, _) = await seedTracks([
        ('夜黑雾', '声无哀乐'),
        ('猫步', '假面骑士'),
      ]);
      expect(root, 1);

      expect((await dao.library.search('夜黑')).map((t) => t.title), ['夜黑雾']);
      expect((await dao.library.search('yhw')).map((t) => t.title), ['夜黑雾']);
      expect(
        (await dao.library.search('ye hei')).map((t) => t.title),
        ['夜黑雾'],
      );
      // 艺术家检索：乐为多音字，拼音包取 yue → initials=sway（前缀 swa 对多音字稳健）
      expect((await dao.library.search('swa')).map((t) => t.title), ['夜黑雾']);
    });

    test('软删曲不出现在搜索（红规断言在行为层）', () async {
      final (root, ids) = await seedTracks([
        ('夜色', 'a'),
        ('夜雨', 'b'),
      ]);
      await (db.update(db.tracks)
            ..where((t) => t.id.equals(ids[0])))
          .write(TracksCompanion(deletedAt: Value(123456)));
      final found = await dao.library.search('夜');
      expect(found.map((t) => t.id), contains(ids[1]));
      expect(found.map((t) => t.id), isNot(contains(ids[0])));
    });
  });

  group('② 曲库浏览（REQ-LIB-02/06）', () {
    test('title 排序 + addedAt 排序 + 分页', () async {
      final (root, ids) = await seedTracks([
        ('charlie', 'a'),
        ('alpha', 'b'),
        ('bravo', 'c'),
      ]);
      expect(root, 1);
      final byTitle = (await dao.library.browse(sort: LibrarySort.title))
          .map((t) => t.title)
          .toList();
      expect(byTitle, ['alpha', 'bravo', 'charlie']);

      // addedAt DESC：同 now（测试种子同毫秒）→ 由 id 序托底稳定（rows 主键序）
      final byAdded = await dao.library.browse(sort: LibrarySort.addedAt);
      expect(byAdded.map((t) => t.id), hasLength(3));

      final page = await dao.library.browse(sort: LibrarySort.title, page: 1, pageSize: 2);
      expect(page.map((t) => t.title), ['charlie']);
    });

    test('软删不进浏览（缺唤醒保留供「缺失徽章」）', () async {
      final (root, ids) = await seedTracks([
        ('a', 'x'),
        ('b', 'y'),
      ]);
      await dao.library.softDeleteTrack(ids[0], 999);
      final rows = await dao.library.browse();
      expect(rows.map((t) => t.id), [ids[1]]);
    });
  });

  group('③ 随机池（REQ-NAV-02/PLAY-03，D9-2）', () {
    test('SQL 粗筛：claude 排除少播/软删；内存采样命中，样品大小正确', () async {
      final (root, ids) = await seedTracks([
        for (var i = 1; i <= 12; i++) ('歌-$i', null),
      ]);
      // 少播 3 首
      await dao.history.addFewWatch(ids[0], 1);
      await dao.history.addFewWatch(ids[11], 2);
      // 软删 1 首
      await dao.library.softDeleteTrack(ids[8], 3);

      final eligible = ids.toSet()
        ..remove(ids[0])
        ..remove(ids[11])
        ..remove(ids[8]);

      final pool = await dao.library.randomPool(sampleSize: 50);
      expect(pool.every((t) => eligible.contains(t.id)), isTrue);
      expect(pool.map((t) => t.id).toSet(), eligible);

      final sample = await dao.library.randomPool(sampleSize: 3);
      expect(sample.map((t) => t.id).every(eligible.contains), isTrue);
      expect(sample.length, 3);
    });

    test('空库采样=空', () async {
      expect(await dao.library.randomPool(), isEmpty);
    });
  });

  group('⑦ 扫描 diff（REQ-LIB-02）', () {
    test('新曲→created；变化→touch 写 mtime/size/hash；未变化→no-op；缺→出库+回库', () async {
      final (root, ids) = await seedTracks([('基', null)]);
      final id = ids.single;
      final before = await dao.library.findByRelPath(root, 'A/基.flac');
      expect(before, isNotNull);

      // 未变化
      await dao.library.touchTrackOnRescan(
        id,
        changed: false,
        mtime: before!.mtime,
        fileSize: before.fileSize,
        contentHash: before.contentHash,
        nowMs: 7777777,
      );
      expect((await dao.library.findByRelPath(root, 'A/基.flac'))!.updatedAt,
          before.updatedAt);

      // 变化 → touch
      await dao.library.touchTrackOnRescan(
        id,
        changed: true,
        mtime: 999,
        fileSize: 123,
        contentHash: 'hash-2',
        nowMs: 7777777,
      );
      final after = await dao.library.findByRelPath(root, 'A/基.flac');
      expect(after!.mtime, 999);
      expect(after.fileSize, 123);
      expect(after.contentHash, 'hash-2');

      // 缺失 → 回归
      await dao.library.markMissing(id, 8888);
      expect((await dao.library.findByRelPath(root, 'A/基.flac'))!.missingAt, 8888);
      await dao.library.markPresent(id, 8899);
      expect((await dao.library.findByRelPath(root, 'A/基.flac'))!.missingAt, isNull);
    });
  });

  group('⑥ dup 检测（REQ-EXT-06）', () {
    test('同 source 复用行；大小写可含 null source_id', () async {
      final (root, ids) = await seedTracks([('提取曲', null)]);
      // 手工登记源
      await (db.update(db.tracks)..where((t) => t.id.equals(ids.single))).write(
        TracksCompanion(
          sourceType: const Value('bilibili'),
          sourceId: const Value('BV123'),
        ),
      );
      final dup = await dao.library.findBySource('bilibili', 'BV123');
      expect(dup!.id, ids.single);
      expect(await dao.library.findBySource('bilibili', 'OTHER'), isNull);
    });
  });

  group('⑤ 历史（REQ-PL-05，D9-3）', () {
    test('DESC 分组页 + 500 淘汰（批次事务）', () async {
      final (root, ids) = await seedTracks([('被播放', null)]);
      final id = ids.single;
      for (var i = 0; i < 530; i++) {
        await dao.history.record(
          trackId: id,
          completed: true,
          deviceId: 'dev-test',
          nowMs: 1000000 + i,
        );
      }
      // DESC 首页
      final page = await dao.history.historyPage(pageSize: 5);
      expect(page.length, 5);
      expect(page.map((h) => h.$1.playedAt),
          [1000529, 1000528, 1000527, 1000526, 1000525]);

      final removed = await dao.history.pruneToCap();
      expect(removed, 30);
      final cnt =
          await db.customSelect('SELECT count(*) c FROM play_history').getSingle();
      expect(cnt.read<int>('c'), 500);
      // 最老的一批（1000000..1000029）被删：现存最老 played_at=1000030
      final minAt =
          await db.customSelect('SELECT MIN(played_at) m FROM play_history').getSingle();
      expect(minAt.read<int>('m'), 1000030);
    });

    test('少播放名单清空（墓碑由 SyncEngine 补——本层仅物理化）', () async {
      final (root, ids) = await seedTracks([
        ('f1', null),
        ('f2', null),
      ]);
      await dao.history.addFewWatch(ids[0], 1);
      await dao.history.addFewWatch(ids[1], 2);
      expect(await dao.history.clearFewWatch(), 2);
      final c =
          await db.customSelect('SELECT count(*) c FROM few_watch_list').getSingle();
      expect(c.read<int>('c'), 0);
    });
  });

  group('④ 歌单（REQ-PL-01..06）', () {
    test('system_favorite 单行兜底 + 新建 + 添加去重 + 排序 + 移除 + 软删', () async {
      final fav = await dao.playlists.ensureFavorite(nowMs: 1);
      final fav2 = await dao.playlists.ensureFavorite(nowMs: 2);
      expect(fav2.id, fav.id); // 不重复建行

      final pl = await dao.playlists.create('晚间电台', nowMs: 3);

      final (root, ids) = await seedTracks([('s1', null), ('s2', null)]);
      expect(root, 1);

      expect(await dao.playlists.addTrack(pl.id, ids[0], nowMs: 4), isTrue);
      expect(await dao.playlists.addTrack(pl.id, ids[1], nowMs: 5), isTrue);
      expect(await dao.playlists.addTrack(pl.id, ids[0], nowMs: 6), isFalse);

      var rows = await dao.playlists.browse(pl.id);
      expect(rows.map((r) => r.$2.id), [ids[0], ids[1]]);
      expect(rows.map((r) => r.$1.position), [0, 1]);

      await dao.playlists.reorder(pl.id, orderedTrackIds: [ids[1], ids[0]], nowMs: 7);
      rows = await dao.playlists.browse(pl.id);
      expect(rows.map((r) => r.$2.id), [ids[1], ids[0]]);

      await dao.playlists.removeTrack(pl.id, ids[1]);
      rows = await dao.playlists.browse(pl.id);
      expect(rows.map((r) => r.$2.id), [ids[0]]);

      await dao.playlists.softDeletePlaylist(pl.id, 7);
      final only = await (db.select(db.playlists)..where((p) => p.id.equals(pl.id)))
          .getSingle();
      expect(only.deletedAt, 7);
      // 歌单条目仍在（不物理删）
      expect(await dao.playlists.browse(pl.id), hasLength(1));
    });
  });

  group('⑧ 墓碑（REQ-SYNC-04/05）', () {
    test('登记→待处理序→远清标记；代码级无删除语义仅记录', () async {
      final (root, ids) = await seedTracks([('墓曲', null)]);
      expect(root, 1);
      await dao.sync.recordTombstone(TombstoneKind.track,
          localId: ids[0], deletedByDevice: 'dev-A', nowMs: 1000);
      await dao.sync.recordTombstone(TombstoneKind.playlist,
          localId: 1, deletedByDevice: 'dev-A', nowMs: 1001);
      await dao.sync.recordTombstone(TombstoneKind.playlist,
          localId: 2, deletedByDevice: 'dev-A', nowMs: 1002);

      final pending = await dao.sync.pendingTombstones();
      expect(pending.map((t) => t.entityKind), [
        TombstoneKind.playlist,
        TombstoneKind.playlist,
        TombstoneKind.track,
      ]);
      expect(
        pending
            .where((t) => t.entityKind == TombstoneKind.playlist)
            .map((t) => t.deletedAt),
        [1002, 1001],
      );

      await dao.sync
          .markTombstoneRemoteCleared(pending.map((t) => t.id).toList(), 2000);
      expect(await dao.sync.pendingTombstones(), isEmpty);
    });
  });

  group('同步通道（C44 单通道）', () {
    test('applyChannel：换通道自动停用旧通道；currentChannel 单行；凭据仅 ref', () async {
      await dao.sync.applyChannel(
        SyncChannelType.webdav,
        'https://dav.example.com',
        credentialsRef: 'webdav.creds',
        username: 'u1',
      );
      expect((await dao.sync.currentChannel())!.type, SyncChannelType.webdav);
      expect((await dao.sync.currentChannel())!.baseUrl, 'https://dav.example.com');

      await dao.sync.applyChannel(
        SyncChannelType.github,
        'https://api.github.com',
        credentialsRef: 'gh.token',
      );
      final cur = await dao.sync.currentChannel();
      expect(cur!.type, SyncChannelType.github);
      // 通道共两行，active 仅一行
      final rows = await db.select(db.syncChannel).get();
      expect(rows, hasLength(2));
      expect(rows.where((c) => c.isActive), hasLength(1));
      // 凭据本体不入 DB：字段只存 ref
      expect(cur.credentialsRef, 'gh.token');
    });

    test('lastSync upsert（REQ-SYNC-07）', () async {
      await dao.sync.applyChannel(
        SyncChannelType.webdav,
        'https://dav.example.com',
        credentialsRef: 'c',
      );
      final ch = await dao.sync.currentChannel();
      await dao.sync.upsertLastSync(
        channelId: ch!.id,
        pendingUp: 3,
        pendingDown: 0,
        summaryJson: '{"ok":3,"fail":0}',
        nowMs: 123456,
      );
      await dao.sync.upsertLastSync(
        channelId: ch.id,
        pendingUp: 4,
        pendingDown: 1,
        summaryJson: '{"ok":3,"fail":1}',
        nowMs: 999999,
      );
      final state = await (db.select(db.lastSyncState)).get();
      expect(state, hasLength(1));
      expect(state.single.summaryJson, '{"ok":3,"fail":1}');
    });
  });

  group('提取任务（REQ-EXT-06 dup 复用行）', () {
    test('createOrGet 建行/复用行；状态机推进；溯源负到底', () async {
      final (task, isNew) = await dao.extract.createOrGet(
        sourceType: 'bilibili',
        sourceId: 'BV1xx',
        url: 'https://b23.tv/BV1xx',
        quality: TaskQuality.k64,
        nowMs: 1,
      );
      expect(isNew, isTrue);

      final (again, isNew2) = await dao.extract.createOrGet(
        sourceType: 'bilibili',
        sourceId: 'BV1xx',
        url: 'https://b23.tv/BV1xx',
        quality: TaskQuality.k64,
        nowMs: 2,
      );
      expect(isNew2, isFalse);
      expect(again.id, task.id);

      await dao.extract.updateTask(
        task.id,
        status: ExtractTaskStatus.downloading,
        progressPct: 42.5,
        cookiesUsed: true,
      );
      final updated = await db.select(db.extractTasks).getSingle();
      expect(updated.status, ExtractTaskStatus.downloading);
      expect(updated.progressPct, closeTo(42.5, 0.0001));
      expect(updated.cookiesUsed, isTrue);
    });
  });

  group('歌词 ASR 任务（REQ-LYRAI-03 串行）', () {
    test('schedule→claim（串行队首）→progress→finish；重派=重置终态', () async {
      final (root, ids) = await seedTracks([('asr曲', null)]);
      final id = ids.single;
      expect(root, 1);
      // 模型注册先行（jobs.model_id FK→model_registry；REQ-LYRAI-01 前置）
      await dao.shell.upsertModel(
        'sensevoice-int8-20240717',
        sizeBytes: 123,
        sha256: 'abc',
        status: ModelStatus.present,
        localPath: '/models/m.onnx',
        downloadedAt: 5,
      );

      final j1 = await dao.lyrics.schedule(id, modelId: 'sensevoice-int8-20240717', nowMs: 1);
      expect(j1!.status, LyricsJobStatus.queued);

      final claimed = await dao.lyrics.claimNext(nowMs: 2);
      expect(claimed!.id, j1.id);
      expect(claimed.status, LyricsJobStatus.running);

      await dao.lyrics.setProgress(j1.id, 50, nowMs: 3);
      expect(
        (await db.select(db.lyricsGenJobs).getSingle()).progress,
        closeTo(50, 0.0001),
      );

      // 同曲未终态 → no-op（UNIQUE(track_id) 行为）
      expect(await dao.lyrics.schedule(id, modelId: 'm', nowMs: 4), isNull);

      await dao.lyrics.finish(j1.id,
          terminal: LyricsJobStatus.failed, errorCode: 'no_voice', nowMs: 5);
      expect(
        (await db.select(db.lyricsGenJobs).getSingle()).finishedAt,
        5,
      );

      // 终态后可重派：同样行（ICE=track_id 唯一）被重置
      final j2 = await dao.lyrics
          .schedule(id, modelId: 'sensevoice-int8-20240717', nowMs: 6);
      expect(j2!.id, j1.id);
      expect(j2.status, LyricsJobStatus.queued);
    });

    test('no_voice 终态 + meta upsert（REQ-LYRAI-05 空文件不落盘）', () async {
      final (root, ids) = await seedTracks([('纯音乐', null)]);
      final id = ids.single;
      expect(root, 1);
      // 模型注册先行（FK）
      await dao.shell.upsertModel(
        'm',
        sizeBytes: null,
        sha256: null,
        status: ModelStatus.present,
        localPath: null,
        downloadedAt: null,
      );

      final j = await dao.lyrics.schedule(id, modelId: 'm', nowMs: 1);
      final claimed = await dao.lyrics.claimNext(nowMs: 2);
      expect(claimed!.id, j!.id);
      await dao.lyrics.finish(j.id, terminal: LyricsJobStatus.no_voice, nowMs: 3);

      expect((await db.select(db.lyricsGenJobs).getSingle()).status,
          LyricsJobStatus.no_voice);

      await dao.lyrics.upsertMeta(
        trackId: id,
        type: LyricsSourceType.none,
        nowMs: 4,
      );
      final meta = await dao.lyrics.metaFor(id);
      expect(meta!.type, LyricsSourceType.none);
      expect(meta.lrcPath, isNull); // 纯音乐绝不留空文件（REQ-LYRAI-05）
    });
  });

  group('壳层设置/模型注册', () {
    test('settings put/get；model_registry upsert', () async {
      await dao.shell.put('appearance.theme', '"dark"', nowMs: 1);
      expect(await dao.shell.value('appearance.theme'), '"dark"');
      await dao.shell.put('appearance.theme', '"light"', nowMs: 2);
      expect(await dao.shell.value('appearance.theme'), '"light"');
      expect(await dao.shell.value('absent.key'), isNull);

      await dao.shell.upsertModel(
        'sensevoice-int8-20240717',
        sizeBytes: 123,
        sha256: 'abc',
        status: ModelStatus.present,
        localPath: '/models/m.onnx',
        downloadedAt: 5,
      );
      await dao.shell.upsertModel(
        'sensevoice-int8-20240717',
        sizeBytes: 999,
        sha256: 'def',
        status: ModelStatus.paused,
        localPath: null,
        downloadedAt: null,
      );
      final model = await (db.select(db.modelRegistry).getSingle());
      expect(model.sizeBytes, 999);
      expect(model.status, ModelStatus.paused);
    });
  });
}
