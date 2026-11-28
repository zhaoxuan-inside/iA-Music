/// 曲库/歌单/历史 DAO 测试——内存真 SQLite + FTS 全链路。
library;

import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/config/embedding_config.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/entities/playlist.dart';
import 'package:ia_music/domain/entities/track.dart' show EnrichStage;
import 'package:ia_music/state/listen_providers.dart';

void main() {
  late IaDatabase db;
  const pathRoot = '/music';

  setUp(() async {
    db = IaDatabase.connect(NativeDatabase.memory());
    // 触发 onCreate（FTS 建表）
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() async => db.close());

  Future<int> root(String path) => db.libraryDao.addRoot(path);

  TrackUpsert upsert(int rootId, String rel,
          {String title = 'T',
          String artist = 'A',
          String album = 'L',
          bool needsMeta = false}) =>
      TrackUpsert(
        rootId: rootId,
        relPath: rel,
        path: '$pathRoot/$rel',
        title: title,
        artist: artist,
        album: album,
        genre: '',
        needsMeta: needsMeta,
        trackNo: 0,
        durationMs: 1000,
        sizeBytes: 1,
        contentHash: 'h-$rel',
        audioFormat: 'mp3',
      );

  late int rootId;

  group('扫描写入与 FTS', () {
    setUp(() async {
      rootId = await root('/music');
    });

    test('upsert 幂等 + FTS 可命中', () async {
      final dao = db.libraryDao;
      await dao.upsertScannedBatch([upsert(rootId, 'a.mp3', title: '晴天', artist: '周杰伦')]);
      await dao.upsertScannedBatch([upsert(rootId, 'a.mp3', title: '晴天', artist: '周杰伦')]);

      final count = await dao.watchAvailableCount().first;
      expect(count, 1, reason: '同 path 二次 upsert 不应新增行');

      // 中文逐字命中
      final zh = await dao.watchSearchResults('晴天').first;
      expect(zh, hasLength(1));
      // 中文子串命中（逐字拆分后子串 token 前缀匹配）
      final sub = await dao.watchSearchResults('晴天'.substring(1)).first;
      expect(sub, hasLength(1));
      // 拼音命中
      final py = await dao.watchSearchResults('qingtian').first;
      expect(py, hasLength(1));
      // 拼音首字母命中
      final pyShort = await dao.watchSearchResults('qt').first;
      expect(pyShort, isNotEmpty);
      // 歌手拼音命中
      final pyArtist = await dao.watchSearchResults('zhoujielun').first;
      expect(pyArtist, hasLength(1));
    });

    test('markMissing / revive', () async {
      final dao = db.libraryDao;
      await dao.upsertScannedBatch([upsert(rootId, 'a.mp3')]);
      final track = (await dao.availableTracks()).single;
      await dao.markMissing([track.id]);
      expect((await dao.availableTracks()), isEmpty);
      await dao.revive([track.id]);
      expect(await dao.availableTracks(), hasLength(1));
    });

    test('removeRoot 级联清曲库', () async {
      final dao = db.libraryDao;
      await dao.upsertScannedBatch([upsert(rootId, 'a.mp3'), upsert(rootId, 'b.flac')]);
      await dao.removeRoot(rootId);
      expect(await dao.availableTracks(), isEmpty);
      expect(await dao.watchSearchResults('a').first, isEmpty);
      expect(await dao.allRoots(), isEmpty);
    });
  });

  group('编辑歌曲信息（editTrackMeta）', () {
    setUp(() async {
      rootId = await root('/music');
    });

    /// needsMeta 行种子（空歌名空歌手——真实扫描里待反向重建的行）。
    TrackUpsert needsMetaUpsert(int rootId, String rel) => TrackUpsert(
          rootId: rootId,
          relPath: rel,
          path: '$pathRoot/$rel',
          title: '',
          artist: '',
          album: '',
          genre: '',
          needsMeta: true,
          trackNo: 0,
          durationMs: 1000,
          sizeBytes: 1,
          contentHash: 'h-$rel',
          audioFormat: 'mp3',
        );

    test('字段与 norm 列更新 + FTS 整行重建（旧拼音灭、新标题/拼音/首字母活）', () async {
      final dao = db.libraryDao;
      await dao
          .upsertScannedBatch([upsert(rootId, 'a.mp3', title: '晴天', artist: '周杰伦', album: '叶惠美')]);
      final id = (await dao.availableTracks()).single.id;

      await dao.editTrackMeta(
        id: id,
        title: '爱在西元前',
        artist: 'Jay',
        album: 'Fantasy',
        genre: 'Mandopop',
        trackNo: 3,
      );

      final t = (await dao.trackById(id))!;
      expect(t.title, '爱在西元前');
      expect(t.artist, 'Jay');
      expect(t.album, 'Fantasy');
      expect(t.genre, 'Mandopop');
      expect(t.trackNo, 3);

      // FTS 重建：旧拼音不再命中
      expect(await dao.watchSearchResults('qingtian').first, isEmpty);
      // 新标题中文逐字命中
      final zh = await dao.watchSearchResults('爱在西元前').first;
      expect(zh.map((x) => x.id), [id]);
      // 新拼音全称 / 首字母命中
      final py = await dao.watchSearchResults('aizai').first;
      expect(py.map((x) => x.id), [id]);
      final pyShort = await dao.watchSearchResults('azxyq').first;
      expect(pyShort.map((x) => x.id), [id]);
    });

    test('needsMeta 清位：编辑后的行出补全池（用户编辑即结论）', () async {
      final dao = db.libraryDao;
      await dao.upsertScannedBatch([needsMetaUpsert(rootId, 'b.mp3')]);
      final id = (await dao.availableTracks()).single.id;
      expect(await dao.needsEnrichment(), hasLength(1));
      expect(await dao.countNeedsEnrichment(), 1);

      await dao.editTrackMeta(
        id: id,
        title: '补上的歌名',
        artist: '新歌手',
        album: '',
        genre: '',
        trackNo: 0,
      );

      expect(await dao.needsEnrichment(), isEmpty);
      expect(await dao.countNeedsEnrichment(), 0);
      final t = (await dao.trackById(id))!;
      expect(t.needsMeta, isFalse);
      expect(t.enrichedAt, isNotNull);
    });

    test('改专辑/歌手/流派后聚合面重归组', () async {
      final dao = db.libraryDao;
      await dao
          .upsertScannedBatch([upsert(rootId, 'a.mp3', title: '歌', artist: '旧歌手', album: 'Old')]);
      final id = (await dao.availableTracks()).single.id;

      await dao.editTrackMeta(
        id: id,
        title: '歌',
        artist: '新歌手',
        album: '新专辑',
        genre: 'Pop',
        trackNo: 1,
      );

      final albums = await dao.watchAlbums().first;
      expect(albums.map((a) => a.album), contains('新专辑'));
      expect(albums.map((a) => a.album), isNot(contains('Old')));
      final albumTracks = await dao.watchAlbumTracks('新专辑').first;
      expect(albumTracks.single.id, id);

      final artists = await dao.watchArtists().first;
      expect(artists.map((a) => a.artist), ['新歌手']);

      final genres = await dao.watchGenres().first;
      expect(genres.single.genre, 'Pop');
      expect(genres.single.albumCount, 1);
    });
  });

  group('歌单与喜欢', () {
    test('favorites 唯一 + addTrack 去重', () async {
      final dao = db.playlistDao;
      final fav1 = await dao.ensureFavorites();
      final fav2 = await dao.ensureFavorites();
      expect(fav1, fav2);

      final r = await root('/music');
      await db.libraryDao.upsertScannedBatch([upsert(r, 'x.mp3')]);
      final track = (await db.libraryDao.availableTracks()).single;

      expect(await dao.addTrack(fav1, track.id), isTrue);
      expect(await dao.addTrack(fav1, track.id), isFalse, reason: '重复加入被拦截');

      final lists = await dao.watchPlaylists().first;
      expect(lists.single.trackCount, 1);
      expect(lists.single.kind, PlaylistKind.favorites);

      expect(await dao.isFavorite(track.id), isTrue);
      await dao.setFavorite(track.id, false);
      expect(await dao.isFavorite(track.id), isFalse);
    });

    test('用户歌单 CRUD', () async {
      final dao = db.playlistDao;
      final id = await dao.createPlaylist('深夜驾车');
      await dao.renamePlaylist(id, '夜驾');
      final lists = await dao.watchPlaylists().first;
      expect(lists.where((p) => p.id == id).single.name, '夜驾');
      await dao.deletePlaylist(id);
      expect((await dao.watchPlaylists().first).where((p) => p.id == id), isEmpty);
    });

    test('加歌后曲目数即时刷新（playlist_tracks 变更要触发歌单流重发）', () async {
      final dao = db.playlistDao;
      final r = await root('/music');
      await db.libraryDao
          .upsertScannedBatch([upsert(r, 'a.mp3'), upsert(r, 'b.mp3')]);
      final tracks = await db.libraryDao.availableTracks();
      final id = await dao.createPlaylist('通勤');

      final counts = <int>[];
      final sub = dao.watchPlaylists().listen((ls) =>
          counts.add(ls.where((p) => p.id == id).firstOrNull?.trackCount ?? -1));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await dao.addTrack(id, tracks[0].id), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await dao.addTrack(id, tracks[1].id), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final lists = await dao.watchPlaylists().first;
      expect(lists.where((p) => p.id == id).single.trackCount, 2,
          reason: '歌单卡片显示的曲数必须是加歌后的实时值');
      await sub.cancel();
    });

    test('歌单封面路径写回', () async {
      final dao = db.playlistDao;
      final id = await dao.createPlaylist('封面');
      await dao.setPlaylistCover(id, '/data/files/pl_cover.jpg');
      final p = (await dao.watchPlaylists().first).where((x) => x.id == id).single;
      expect(p.coverPath, '/data/files/pl_cover.jpg');
      await dao.setPlaylistCover(id, null);
      expect(
          (await dao.watchPlaylists().first).where((x) => x.id == id).single.coverPath,
          isNull);
    });
  });

  group('历史与歌词元数据', () {
    test('record + watchRecent + clear', () async {
      final r = await root('/music');
      await db.libraryDao.upsertScannedBatch([upsert(r, 'h.mp3')]);
      final t = (await db.libraryDao.availableTracks()).single;

      await db.historyDao.record(t.id, completed: true);
      await db.historyDao.record(t.id, completed: false);
      final items = await db.historyDao.watchRecent().first;
      expect(items.first.track.id, t.id);
      expect(items.first.completed, isFalse);
      expect(items.first.plays, 2,
          reason: '翻面次数取 tracks.plays 物化列（与常听同口径）');
    });

    test('watchTopTracks 单曲粒度聚合播放次数', () async {
      final dao = db.libraryDao;
      final r = await root('/music');
      await dao.upsertScannedBatch([
        upsert(r, 's1.mp3', title: 'S1', album: ''),
        upsert(r, 's2.mp3', title: 'S2', album: ''),
        upsert(r, 's3.mp3', title: 'S3', album: ''),
      ]);
      final tracks = await dao.availableTracks();
      final byTitle = {for (final t in tracks) t.title: t};

      // s1 播 3 次、s2 播 1 次、s3 不播
      for (var i = 0; i < 3; i++) {
        await db.historyDao.record(byTitle['S1']!.id, completed: true);
      }
      await db.historyDao.record(byTitle['S2']!.id, completed: false);

      final top = await dao.watchTopTracks(limit: 12).first;
      expect(top, hasLength(2), reason: '未播过的歌不进常听');
      expect(top.first.track.id, byTitle['S1']!.id);
      expect(top.first.plays, 3);
      expect(top[1].plays, 1);
    });

    test('purgeTrack 清引用行 + 主行（FK 开启不炸）', () async {
      final dao = db.libraryDao;
      final r = await root('/music');
      await dao.upsertScannedBatch([upsert(r, 'p.mp3', title: 'Px')]);
      final t = (await dao.availableTracks()).single;

      final plId = await db.playlistDao.createPlaylist('清理');
      await db.playlistDao.addTrack(plId, t.id);
      await db.playlistDao.setFavorite(t.id, true);
      await db.historyDao.record(t.id, completed: true);
      await db.lyricsDao
          .upsert(t.id, LyricsMetaCompanion.insert(kind: Value('none')));

      await dao.purgeTrack(t.id);

      expect(await dao.availableTracks(), isEmpty);
      expect(await dao.watchSearchResults('Px').first, isEmpty);
      expect(await db.historyDao.watchRecent().first, isEmpty);
      final pls = await db.playlistDao.watchPlaylists().first;
      expect(pls.where((p) => p.id == plId).single.trackCount, 0);
    });
  });

  group('收集任务 DAO', () {
    test('setStatus(failed, errorText) 落库 + retryFailed 清空', () async {
      final id = await db.collectDao
          .enqueue('direct', 'http://x/a.mp3', title: '失败歌');
      await db.collectDao.setStatus(id, CollectStatusCol.failed,
          errorText: '音频流下载失败：HTTP 403');

      final row = await (db.select(db.collectTasks)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.status, CollectStatusCol.failed);
      expect(row.errorText, '音频流下载失败：HTTP 403');

      // 重试重排：状态回 pending，失败原因清空（旧原因不再误导新一轮）
      await db.collectDao.retryFailed();
      final re = await (db.select(db.collectTasks)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(re.status, CollectStatusCol.pending);
      expect(re.errorText, isNull, reason: '重排必须清空失败原因');
    });

    test('pause/resume/delete/clearFinished 往返', () async {
      final keep = await db.collectDao
          .enqueue('direct', 'http://x/keep.mp3', title: '保留歌');
      await db.collectDao.setStatus(keep, CollectStatusCol.done);
      final gone = await db.collectDao
          .enqueue('direct', 'http://x/gone.mp3', title: '清理歌');
      await db.collectDao.setStatus(gone, CollectStatusCol.failed,
          errorText: 'HTTP 403');
      final paused = await db.collectDao
          .enqueue('direct', 'http://x/paused.mp3', title: '暂停歌');

      // 暂停/恢复
      await db.collectDao.pauseTask(paused);
      var row = await db.collectDao.taskById(paused);
      expect(row!.status, CollectStatusCol.paused);
      await db.collectDao.resumeTask(paused);
      row = await db.collectDao.taskById(paused);
      expect(row!.status, CollectStatusCol.pending);

      // 清理记录：只清 done+failed（等待/暂停保留）
      final cleared = await db.collectDao.clearFinished();
      expect(cleared, 2);
      expect(await db.collectDao.taskById(keep), isNull);
      expect(await db.collectDao.taskById(gone), isNull);
      expect(await db.collectDao.taskById(paused), isNotNull);

      // 删除任务行
      await db.collectDao.deleteTask(paused);
      expect(await db.collectDao.taskById(paused), isNull);
    });
  });

  group('补全阶段口径（歌词行 有词/无词 拆分）', () {
    test('lyricsAt 已结论无词 → 无词档；落 lyrics_meta → 有词；none 孤儿行不算有词',
        () async {
      final dao = db.libraryDao;
      final r = await root('/music');
      await dao.upsertScannedBatch([
        upsert(r, 'have.mp3', title: '', artist: '', needsMeta: true),
        upsert(r, 'miss.mp3', title: '', artist: '', needsMeta: true),
      ]);
      final pending = await dao.watchNeedsEnrichment(limit: 5).first;
      final have = pending.singleWhere((t) => t.relPath == 'have.mp3');
      final miss = pending.singleWhere((t) => t.relPath == 'miss.mp3');

      EnrichStage lyricsOf(List<EnrichStage> ss) =>
          ss.singleWhere((s) => s.label == '歌词');

      // 两首都结论（确认无匹配路径同样打 lyricsAt）但都没拿到词：
      // 成功=0、无词=2——旧口径这里会虚报「成功 2」
      await dao.applyEnrichment(id: have.id, title: '甲', artist: 'A');
      await dao.applyEnrichment(id: miss.id, title: '乙', artist: 'B');
      var lyrics = lyricsOf(await dao.watchEnrichStages().first);
      expect(lyrics.done, 0);
      expect(lyrics.missed, 2);
      expect(lyrics.pending, 0, reason: '已结论的行不算等待');

      // 补全拿到词（lyrics_meta 记账）→ 转为有词
      await db.lyricsDao.upsert(
          have.id,
          LyricsMetaCompanion.insert(
            trackId: Value(have.id),
            kind: const Value('online'),
            lrcPath: const Value('/music/have.lrc'),
          ));
      lyrics = lyricsOf(await dao.watchEnrichStages().first);
      expect(lyrics.done, 1);
      expect(lyrics.missed, 1);

      // kind='none' 的偏移孤儿行（setOffset 无词时产生）不升为有词
      await db.lyricsDao.upsert(
          miss.id,
          LyricsMetaCompanion.insert(
            trackId: Value(miss.id),
            kind: const Value('none'),
          ));
      lyrics = lyricsOf(await dao.watchEnrichStages().first);
      expect(lyrics.done, 1);
      expect(lyrics.missed, 1, reason: 'none 行不算有词，已结论仍归无词');
    });
  });

  group('向量 DAO 与声学相似', () {
    setUp(() async {
      rootId = await root('/music');
    });

    Uint8List vecBytes(List<double> values) =>
        Uint8List.sublistView(Float32List.fromList(values));

    test('upsert 覆盖写 + vectorOf + allVectors 按 model 过滤', () async {
      final dao = db.vectorDao;
      await db.libraryDao.upsertScannedBatch([upsert(rootId, 'v.mp3')]);
      final t = (await db.libraryDao.getTracks()).single;

      await dao.upsertVector(
          trackId: t.id, model: 'm1', dim: 2, vec: vecBytes([1, 0]));
      final v = await dao.vectorOf(t.id);
      expect(v, isNotNull);
      expect(v!.model, 'm1');
      expect(Float32List.sublistView(v.vec).toList(), [1, 0]);

      // 换模型重算：PK=trackId 覆盖写，旧向量不残留不混用
      await dao.upsertVector(
          trackId: t.id, model: 'm2', dim: 2, vec: vecBytes([0, 1]));
      expect((await dao.vectorOf(t.id))!.model, 'm2');
      expect(await dao.allVectors('m1'), isEmpty);
      expect(await dao.allVectors('m2'), hasLength(1));
    });

    test('poolForVector 口径：排除已算/三败/缺失，换模型旧向量不算数', () async {
      final dao = db.vectorDao;
      await db.libraryDao.upsertScannedBatch([
        upsert(rootId, 'p1.mp3', title: 'P1'),
        upsert(rootId, 'p2.mp3', title: 'P2'),
        upsert(rootId, 'p3.mp3', title: 'P3'),
        upsert(rootId, 'p4.mp3', title: 'P4'),
      ]);
      final all = await db.libraryDao.getTracks();
      final by = {for (final t in all) t.title: t};

      await dao.upsertVector(
          trackId: by['P2']!.id,
          model: kEmbeddingModel,
          dim: 2,
          vec: vecBytes([1, 0]));
      for (var i = 0; i < 3; i++) {
        await db.libraryDao.bumpEnrichAttempts(by['P3']!.id);
      }
      await db.libraryDao.markMissing([by['P4']!.id]);

      final pool = await dao.poolForVector(model: kEmbeddingModel);
      expect(pool.map((t) => t.title), ['P1'], reason: '已算/三败/缺失都不进池');

      // 同曲目换模型：旧模型的向量不算数，缺口重现
      final poolOther = await dao.poolForVector(model: 'm-other');
      expect(poolOther.map((t) => t.title), containsAll(['P1', 'P2']));
      expect(await dao.countWithoutVector(model: kEmbeddingModel), 1);
      expect(await dao.countWithoutVector(model: 'm-other'), 2);
    });

    test('watchEnrichStages 向量行：done/failed/total', () async {
      final dao = db.libraryDao;
      await dao.upsertScannedBatch([
        upsert(rootId, 's1.mp3', title: 'S1'),
        upsert(rootId, 's2.mp3', title: 'S2'),
      ]);
      final all = await dao.getTracks();
      final s1 = all.firstWhere((t) => t.title == 'S1');
      final s2 = all.firstWhere((t) => t.title == 'S2');

      await db.vectorDao.upsertVector(
          trackId: s1.id,
          model: kEmbeddingModel,
          dim: 2,
          vec: vecBytes([1, 0]));

      Future<EnrichStage> row(String label) async =>
          (await dao.watchEnrichStages().first)
              .firstWhere((s) => s.label == label);
      var v = await row('向量');
      expect((v.done, v.failed, v.total), (1, 0, 2),
          reason: '向量行独立于元数据结论——全集存活曲目都要算');

      await dao.bumpEnrichAttempts(s2.id);
      v = await row('向量');
      expect((v.done, v.failed, v.total), (1, 1, 2));
    });

    test('similarTo 端到端：余弦降序 + 缺失行过滤 + 种子无向量空表', () async {
      final dao = db.libraryDao;
      await dao.upsertScannedBatch([
        upsert(rootId, 'e1.mp3', title: '种子'),
        upsert(rootId, 'e2.mp3', title: '同向'),
        upsert(rootId, 'e3.mp3', title: '反向'),
        upsert(rootId, 'e4.mp3', title: '缺失件'),
        upsert(rootId, 'e5.mp3', title: '无向量'),
      ]);
      final all = await dao.getTracks();
      final by = {for (final t in all) t.title: t};
      await dao.markMissing([by['缺失件']!.id]);
      Future<void> put(String title, List<double> v) =>
          db.vectorDao.upsertVector(
              trackId: by[title]!.id,
              model: kEmbeddingModel,
              dim: v.length,
              vec: vecBytes(v));

      final lib = ListenLibrary(db, db.playlistDao);
      // 1024 维向量（ListenLibrary 按 kEmbeddingDim 防御过滤，测试向量同维）：
      // 双分量定形 [a, b, 0...]——种子 [1,0]：同向 dot=0.9、反向 dot=-1。
      List<double> v2(double a, double b) =>
          [a, b, ...List.filled(kEmbeddingDim - 2, 0)];
      await put('种子', v2(1, 0));
      await put('同向', v2(0.9, 0.1));
      await put('反向', v2(-1, 0));
      await put('缺失件', v2(1, 0)); // 有向量但文件缺失——不该出现在取材里

      final similar = await lib.similarTo(by['种子']!.id);
      expect(similar.map((t) => t.title), ['同向', '反向'],
          reason: '余弦降序 + 自身排除 + 缺失行过滤');
      expect(
          (await lib.similarTo(by['反向']!.id, limit: 1))
              .map((t) => t.title),
          ['同向'],
          reason: '余弦如实降序——反向曲的最近邻是同向曲（dot -0.9 > -1）');
      expect(await lib.similarTo(by['无向量']!.id), isEmpty,
          reason: '种子无向量 → 空表（UI 引导先跑补全）');
    });
  });

  group('补全阶段行（专辑/音轨）', () {
    setUp(() async {
      rootId = await root('/music');
    });

    Future<EnrichStage> row(String label) async =>
        (await db.libraryDao.watchEnrichStages().first)
            .firstWhere((s) => s.label == label);

    test('专辑/音轨行：有值 done / 确认无 missed / 失败桶 / 总盘', () async {
      final dao = db.libraryDao;
      // 夹具 album/trackNo 置空——默认值有专辑（'L'）会把「确认无」污染成 done
      await dao.upsertScannedBatch([
        upsert(rootId, 'al1.mp3', title: 'A1', needsMeta: true, album: ''),
        upsert(rootId, 'al2.mp3', title: 'A2', needsMeta: true, album: ''),
        upsert(rootId, 'al3.mp3', title: 'A3', needsMeta: true, album: ''),
      ]);
      final all = await dao.getTracks();
      final by = {for (final t in all) t.title: t};

      // A1：采纳专辑+音轨（AcoustID releases 有值形态）
      await dao.applyEnrichment(
          id: by['A1']!.id, title: 'A1', artist: 'X', album: '叶惠美', trackNo: 3);
      // A2：无源结案（文字链形态——album/trackNo 传 null）
      await dao.applyEnrichment(id: by['A2']!.id, title: 'A2', artist: 'X');
      // A3：失败记账
      await dao.bumpEnrichAttempts(by['A3']!.id);

      final al = await row('专辑');
      expect((al.done, al.missed, al.failed, al.total), (1, 1, 1, 3),
          reason: 'done=有专辑；missed=确认无灰档；failed=失败桶未结论');
      final tr = await row('音轨');
      expect((tr.done, tr.missed, tr.failed, tr.total), (1, 1, 1, 3),
          reason: '口径与专辑行同构');
    });
  });
}
