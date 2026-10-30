// EnrichService 单元测试（2026-10-30 本地扫描识别修正）。
//
// 形态：真内存库 + 真临时目录旁车落盘 + 端口缝注入 fake（contracts
// LyricsPort / SongSearchPort）。网络适配器的真网验收归 lrclib/netease
// 既有真网用例（lyrics_t9c_test 等）——本文件只验管线编排与回写面。
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/netease_lyric_search.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/enrich_service.dart';

final class FakeLrclib implements LyricsPort {
  FakeLrclib(this.resolution);

  LyricsResolution? resolution;
  final List<LyricsQuery> queries = [];

  @override
  Future<LyricsResolution?> resolve(LyricsQuery q) async {
    queries.add(q);
    return resolution;
  }
}

final class FakeSongSearch implements SongSearchPort {
  FakeSongSearch({this.identity, this.synced, this.cover});

  LyricsIdentity? identity;
  String? synced;
  ({String url, List<int> bytes})? cover;
  int searchCalls = 0;
  int lyricCalls = 0;
  int coverCalls = 0;

  @override
  Future<LyricsIdentity?> searchByName({
    required String title,
    String? artist,
    int? durationMs,
  }) async {
    searchCalls++;
    return identity;
  }

  @override
  Future<String?> fetchSyncedLyrics(int songId) async {
    lyricCalls++;
    return synced;
  }

  @override
  Future<({String url, List<int> bytes})?> fetchCover(int songId) async {
    coverCalls++;
    return cover;
  }
}

void main() {
  late IaDatabase db;
  late LibraryDao lib;
  late LyricsDao lyricsDao;
  late Directory tmp;
  late int rootId;

  setUp(() async {
    final gate = await openIaDatabaseMemory();
    db = gate.db;
    lib = DataAccess(db).library;
    lyricsDao = DataAccess(db).lyrics;
    tmp = await Directory.systemTemp.createTemp('enrich_svc_');
    addTearDown(() async {
      await tmp.delete(recursive: true);
      await db.close();
    });
    rootId = await db.into(db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(
            path: tmp.path,
            mode: RepositoryMode.directory,
            addedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  });

  /// 直插一条扫描形态的轨（走 insertTrackBatch：字典 + FTS 同事务同真链）。
  /// 音频实体无需在盘——管线只写旁车文件，不读音频。
  Future<int> insertTrack({
    String rel = '01. 晴天.mp3',
    String title = '01. 晴天',
    String? artist,
    String? album,
    int? durationMs = 269000,
  }) async {
    final ids = await lib.insertTrackBatch([
      ScannedTrackInput(
        rootId: rootId,
        relPath: rel,
        mtime: 111,
        fileSize: 222,
        contentHash: 'hash-$rel',
        nowMs: DateTime.now().millisecondsSinceEpoch,
        title: title,
        artistDisplay: artist,
        albumDisplay: album,
        durationMs: durationMs,
      ),
    ]);
    return ids.single;
  }

  EnrichService buildService({
    required FakeLrclib lrclib,
    required FakeSongSearch search,
    Future<void> Function(int trackId)? asr,
    void Function(int trackId)? onEnriched,
  }) {
    return EnrichService(
      db: db,
      lrclib: lrclib,
      songSearch: search,
      asrFallback: asr ?? (_) async {},
      onTrackEnriched: onEnriched,
    );
  }

  Future<Track> trackRow(int id) async => (await lib.rowById(id))!;

  group('tier1 LRCLIB', () {
    test('锚定命中 → 正名回写（字典+FTS 同事务）+ 同步歌词旁车落盘', () async {
      final id = await insertTrack();
      final lrclib = FakeLrclib(const LyricsResolution(
        source: LyricsSource.lrclib,
        trackName: '晴天',
        artistName: '周杰伦',
        albumName: '叶惠美',
        syncedLyrics: '[00:12.34]故事的小黄花\n[00:18.00]从出生那年就飘着',
        durationSec: 269,
      ));
      final search = FakeSongSearch();
      var enriched = 0;
      final svc = buildService(
          lrclib: lrclib, search: search, onEnriched: (_) => enriched++);

      final out = await svc.runForTrack(id);

      expect(out.identityWritten, isTrue);
      expect(out.lyricsWritten, isTrue);
      expect(out.asrDelegated, isFalse);
      final row = await trackRow(id);
      expect(row.title, '晴天');
      expect(row.artistDisplay, '周杰伦');
      expect(row.albumDisplay, '叶惠美');
      expect(row.artistId, isNotNull,
          reason: '字典 upsert → artistId 落账（专辑页分组）');
      // FTS 同事务：新正名可检索（软删/缺失排除口径同曲库搜索）。
      final hits = await lib.search('晴天');
      expect(hits.any((t) => t.id == id), isTrue, reason: 'FTS 翻新到正名');
      // 旁车歌词 + lyrics_meta 落账。
      final lrc = File('${tmp.path}${Platform.pathSeparator}01. 晴天.lrc');
      expect(lrc.existsSync(), isTrue);
      expect(lrc.readAsStringSync(), contains('故事的小黄花'));
      final meta = await lyricsDao.metaFor(id);
      expect(meta!.type, LyricsSourceType.lrc);
      expect(meta.lrcPath, '01. 晴天.lrc');
      // tier1 已给歌词 → tier2 不推进；修正回调恰好一次。
      expect(search.searchCalls, 0);
      expect(enriched, 1);
    });

    test('仅纯文本（无时间轴）不落盘（_completeFromIdentity 同纪律）', () async {
      final id = await insertTrack();
      final lrclib = FakeLrclib(const LyricsResolution(
        source: LyricsSource.lrclib,
        trackName: '晴天',
        artistName: '周杰伦',
        plainLyrics: '纯文本无时间轴',
      ));
      final svc = buildService(lrclib: lrclib, search: FakeSongSearch());

      final out = await svc.runForTrack(id);

      expect(out.identityWritten, isTrue);
      expect(out.lyricsWritten, isFalse);
      expect(
          File('${tmp.path}${Platform.pathSeparator}01. 晴天.lrc').existsSync(),
          isFalse);
    });
  });

  group('tier2 网易', () {
    test('tier1 无同步歌词 → 现名搜索补身份+歌词+封面旁车', () async {
      final id = await insertTrack();
      final lrclib = FakeLrclib(const LyricsResolution(
        source: LyricsSource.lrclib,
        trackName: '',
        artistName: '',
        plainLyrics: '只有正文没有正名',
      ));
      final search = FakeSongSearch(
        identity: const LyricsIdentity(
          songId: 42,
          title: '晴天',
          artist: '周杰伦',
          album: '叶惠美',
          durationMs: 269000,
        ),
        synced: '[00:01.00]刮风这天 我试过握着你手',
        cover: (url: 'https://x/42.jpg', bytes: [1, 2, 3]),
      );
      final svc = buildService(lrclib: lrclib, search: search);

      final out = await svc.runForTrack(id);

      expect(out.identityWritten, isTrue);
      expect(out.lyricsWritten, isTrue);
      expect(out.coverWritten, isTrue);
      expect(search.searchCalls, 1);
      expect(search.lyricCalls, 1);
      expect(search.coverCalls, 1);
      final row = await trackRow(id);
      expect(row.title, '晴天');
      expect(row.artistDisplay, '周杰伦');
      final cover = File('${tmp.path}${Platform.pathSeparator}01. 晴天.cover.jpg');
      expect(cover.existsSync(), isTrue);
      expect(cover.readAsBytesSync(), [1, 2, 3]);
    });

    test('tier1 已回写身份 → tier2 不重复改写（仅补歌词/封面）', () async {
      final id = await insertTrack(title: '晴天', artist: '旧歌手');
      final lrclib = FakeLrclib(const LyricsResolution(
        source: LyricsSource.lrclib,
        trackName: '晴天',
        artistName: '周杰伦',
        plainLyrics: '正文',
      ));
      final search = FakeSongSearch(
        identity: const LyricsIdentity(
            songId: 7, title: '别首', artist: '别家', durationMs: 100),
        synced: '[00:01.00]网易版歌词',
      );
      final svc = buildService(lrclib: lrclib, search: search);

      await svc.runForTrack(id);

      final row = await trackRow(id);
      expect(row.title, '晴天', reason: 'tier1 正名保留');
      expect(row.artistDisplay, '周杰伦');
      final lrc = File('${tmp.path}${Platform.pathSeparator}01. 晴天.lrc');
      expect(lrc.existsSync(), isTrue);
      expect(lrc.readAsStringSync(), contains('网易版歌词'));
    });
  });

  group('tier3 ASR 兜底', () {
    test('两级未命中 → 委托 B 站链路一次；自身不触发 onTrackEnriched', () async {
      final id = await insertTrack();
      final asrCalls = <int>[];
      var enriched = 0;
      final svc = buildService(
        lrclib: FakeLrclib(null),
        search: FakeSongSearch(),
        asr: (tid) async => asrCalls.add(tid),
        onEnriched: (_) => enriched++,
      );

      final out = await svc.runForTrack(id);

      expect(out.asrDelegated, isTrue);
      expect(asrCalls, [id]);
      expect(enriched, 0, reason: 'tier3 的回调由被委托链路自持，不重复触发');
    });
  });

  group('守卫与队列', () {
    test('lyrics_meta.edited=true → 歌词不落盘；身份回写照常；tier2/3 不推进', () async {
      final id = await insertTrack();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await lyricsDao.upsertMeta(
        trackId: id,
        type: LyricsSourceType.paste,
        sourceText: '用户手改歌词',
        edited: true,
        nowMs: nowMs,
      );
      final lrclib = FakeLrclib(const LyricsResolution(
        source: LyricsSource.lrclib,
        trackName: '晴天',
        artistName: '周杰伦',
        syncedLyrics: '[00:12.00]不许覆盖手改',
      ));
      final search = FakeSongSearch();
      final asrCalls = <int>[];
      final svc = buildService(
          lrclib: lrclib,
          search: search,
          asr: (tid) async => asrCalls.add(tid));

      final out = await svc.runForTrack(id);

      expect(out.identityWritten, isTrue);
      expect(out.lyricsWritten, isFalse);
      final row = await trackRow(id);
      expect(row.title, '晴天');
      expect(
          File('${tmp.path}${Platform.pathSeparator}01. 晴天.lrc').existsSync(),
          isFalse,
          reason: '用户手改歌词 → 不落任何歌词文件');
      final meta = await lyricsDao.metaFor(id);
      expect(meta!.edited, isTrue, reason: '手改标记保留');
      expect(search.searchCalls, 0);
      expect(asrCalls, isEmpty);
    });

    test('入队去重 + 串行消化：同 id 多次入队只跑一次', () async {
      final a = await insertTrack(rel: 'a.mp3', title: 'a', durationMs: 1);
      final b = await insertTrack(rel: 'b.mp3', title: 'b', durationMs: 2);
      final asrCalls = <int>[];
      final svc = buildService(
        lrclib: FakeLrclib(null),
        search: FakeSongSearch(),
        asr: (tid) async => asrCalls.add(tid),
      );

      svc.enqueue(a);
      svc.enqueue(a);
      svc.enqueue(a);
      svc.enqueueAll([a, b, a]);

      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (asrCalls.length < 2 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(asrCalls.toSet().length, asrCalls.length,
          reason: '同曲不重复跑');
      expect(asrCalls, containsAll([a, b]));
      expect(asrCalls.length, 2, reason: 'a 入队 6 次/b 1 次 → 恰各消化一次');
      svc.dispose();
    });
  });
}
