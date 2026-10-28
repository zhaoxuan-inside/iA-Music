// DEC-010: 真链路真环境。LRCLIB=真实 lrclib.net 正规 API（免 key）；
// lrc 落盘=真实文件系统；伪造 JSON / 回放 = 一票否决。
//
// 开发者裁决（2026-10-19 当次会话）：
//   ① 歌词来源分级=LRCLIB 优先 + 真 ASR 兜底（ASR 运行时=T10/RV-C 挂账；
//      未命中如实 failed(asr_unavailable)）；
//   ② 「歌词反查歌名歌手」正文反查引擎实证缺位（真实歌词句 LRCLIB q=0）→
//      本批次以 LRCLIB 正式 trackName/artistName/albumName 补全曲目元数据。
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/lrclib_adapter.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/lyrics/lyrics_service.dart';

void main() {
  // 纪律（S5 真网先例同款）：**不**用 TestWidgetsFlutterBinding——flutter_test
  // 绑定层会把全部 HttpClient 劫为 status 400 mock（实测 400×3 归因），真网
  // 用例一律 plain test()；无 widget 依赖。
  test('T9C 剖析：B 站多 P 分页标题真形态 → (歌名, 歌手)（纯剖析，无网络）', () {
    final (song2, artist2) = LyricsService.parseBiliPageTitle(
        '2026网络最好听100首热门歌曲，每一首都好听 🎧 p02 002. 如果可以 - 韦礼安');
    expect(song2, '如果可以');
    expect(artist2, '韦礼安');
    final (songN, artistN) =
        LyricsService.parseBiliPageTitle('p01 001. 海屿你 - 马也_Crabbit');
    expect(songN, '海屿你');
    expect(artistN, '马也_Crabbit');
    final (song1, artist1) = LyricsService.parseBiliPageTitle('【英雄联盟】K/DA官方MV');
    expect(song1, '【英雄联盟】K/DA官方MV');
    expect(artist1, isNull);
  });

  test('T9C LRCLIB 真网：条件检索 → 正规歌名/歌手 + 同步歌词 + 时长锚命中', () async {
    final port = LrclibAdapter(
        proxy:
            Platform.environment['HTTPS_PROXY'] ?? Platform.environment['https_proxy']);
    final res = await port.resolve(const LyricsQuery(
      trackId: 0,
      title: '如果可以',
      artistDisplay: '韦礼安',
      durationMs: 274840, // p02 实测 274.84s（模拟器注册时长）
    ));
    // ignore: avoid_print
    print('LRCLIB-REQ ${port.requests.length}');
    // ignore: avoid_print
    print('LRCLIB-RSP ${port.responses}');
    // ignore: avoid_print
    print('LRCLIB-FAIL ${port.failures}');
    expect(res, isNotNull, reason: '真网必须命中（如果可以-韦礼安 为词库收录曲）');
    expect(res!.source, LyricsSource.lrclib);
    expect(res.trackName, contains('如果可以'));
    expect(res.artistName, '韦礼安');
    final haveLrc = ((res.syncedLyrics ?? '').trim().isNotEmpty) ||
        ((res.plainLyrics ?? '').trim().isNotEmpty);
    expect(haveLrc, isTrue, reason: '歌词正文必须真实返回');
    expect(res.durationSec, greaterThan(0));
  });

  test('T9C LRCLIB 真网：artist 尾巴杂质 → 仅曲名+时长锚兜底命中（孤勇者实证）', () async {
    // B 站单 P 标题剖析实证（BV1ifUDBREF3）：song=孤勇者，
    // artist=「陈奕迅【Hi-Res无损音质】」尾巴杂质——/api/get 与条件 search
    // 均 404/空，末兜底 /api/search?track_name+时长锚 ±2s 命中正主。
    final port = LrclibAdapter(
        proxy:
            Platform.environment['HTTPS_PROXY'] ?? Platform.environment['https_proxy']);
    final res = await port.resolve(const LyricsQuery(
      trackId: 0,
      title: '孤勇者',
      artistDisplay: '陈奕迅【Hi-Res无损音质】',
      durationMs: 256031,
    ));
    // ignore: avoid_print
    print('LRCLIB-REQ ${port.requests.length}');
    // ignore: avoid_print
    print('LRCLIB-FAIL ${port.failures}');
    expect(res, isNotNull, reason: '仅曲名+时长锚兜底必须命中真网收录曲');
    expect(res!.trackName, contains('孤勇者'));
    expect(res.artistName, '陈奕迅');
  });

  test('T9C LRCLIB 真网：编造曲名 → 未命中 null（不伪造）', () async {
    final port = LrclibAdapter(
        proxy: Platform.environment['HTTPS_PROXY'] ?? Platform.environment['https_proxy']);
    final res = await port.resolve(const LyricsQuery(
      trackId: 0,
      title: '绝无可能有这样一首测试曲名 XyZ9Q7',
      artistDisplay: '绝不存在的歌手 Qw8R',
      durationMs: 123456,
    ));
    expect(res, isNull);
  });

  test('T9C 未命中链：真 DB 行 + 词库无此曲 → asrUnavailable（如实，不伪装）', () async {
    final dir = await Directory.systemTemp
        .createTemp('s7_t9c_m_${DateTime.now().millisecondsSinceEpoch}');
    final gate = await openIaDatabase('${dir.path}/ia.db');
    final db = gate.db;
    addTearDown(gate.db.close);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.repositoryRoots).insert(RepositoryRootsCompanion.insert(
          path: dir.path,
          mode: RepositoryMode.directory,
          addedAt: now,
        ));
    final dao = LibraryDao(db);
    final trackId = await dao.insertTrackCore(
      1,
      'x.mp3',
      mtime: now,
      fileSize: 8,
      contentHash: 't9c-miss',
      nowMs: now,
      title: '绝无可能有这样一首测试曲名 XyZ9Q7 - 绝不存在的歌手 Qw8R',
      durationMs: 123456,
    );
    final svc = LyricsService(db, DataAccess(db).lyrics);
    final out = await svc.runForTrack(trackId);
    expect(out.kind, LyricsOutcomeKind.asrUnavailable);
    expect(out.errorCode, 'asr_unavailable');
    final meta = await DataAccess(db).lyrics.metaFor(trackId);
    expect(meta, isNull, reason: '未命中不写歌词位，不伪造占位');
  });
}
