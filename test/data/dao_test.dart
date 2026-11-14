/// 曲库/歌单/历史 DAO 测试——内存真 SQLite + FTS 全链路。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/entities/playlist.dart';

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

  TrackUpsert upsert(int rootId, String rel, {String title = 'T', String artist = 'A', String album = 'L'}) =>
      TrackUpsert(
        rootId: rootId,
        relPath: rel,
        path: '$pathRoot/$rel',
        title: title,
        artist: artist,
        album: album,
        genre: '',
        needsMeta: false,
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

      expect(await dao.watchFavorite(track.id).first, isTrue);
      await dao.setFavorite(track.id, false);
      expect(await dao.watchFavorite(track.id).first, isFalse);
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
  });

  group('历史与歌词元数据', () {
    test('record + watchRecent + clear', () async {
      final r = await root('/music');
      await db.libraryDao.upsertScannedBatch([upsert(r, 'h.mp3')]);
      final t = (await db.libraryDao.availableTracks()).single;

      await db.historyDao.record(t.id, completed: true);
      final items = await db.historyDao.watchRecent().first;
      expect(items.single.track.id, t.id);
      expect(items.single.completed, isTrue);

      await db.historyDao.clearAll();
      expect(await db.historyDao.watchRecent().first, isEmpty);
    });
  });
}
