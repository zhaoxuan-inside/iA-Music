// DEC-010: 真链路真环境。flat 枚举=真实 yt-dlp 进程对真实 B 站多 P 视频的
// 真网络解析；伪造 JSON / 回放 = 一票否决。
//
// 开发裁决（2026-10-19 开发者原话「很多 B 站上面的分享链接是歌曲合计，
// 需要进行拆分，成多个单独的歌曲。」）：
//   resolveAll（flat-playlist 枚举）→ 一条链接拆成逐分页独立条目
//   （url 带 ?p=N，sourceId=BVID_pN）；条目详情由下载任务二次 resolve 补全。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/downloader_adapter.dart';
import 'package:ia_music/extract/extract_queue.dart';
import 'package:ia_music/data/ia_database.dart';

/// 100 首多 P 合计（验证锚点；x86_64 模拟器全链同源）。
const String kMultiPageUrl =
    'https://www.bilibili.com/video/BV1ANQqBTEVU';

/// 单视频回归锚点（EXP-001 同源 BV17x411w7KC）。
const String kSingleVideoUrl =
    'https://www.bilibili.com/video/BV17x411w7KC/';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('EXT-拆分：多 P 合计 → 100 条独立条目（真网 flat 枚举，≤5s 量级）', () async {
    final dir =
        await Directory.systemTemp.createTemp('s6_split_${DateTime.now().millisecondsSinceEpoch}');
    final gate = await openIaDatabase('${dir.path}/ia.db');
    addTearDown(gate.db.close);
    final queue = ExtractQueue(db: gate.db, downloader: DownloaderAdapter());

    final sw = Stopwatch()..start();    final metas = await queue.parseLinkText(
        '100首热门歌曲合集 https://www.bilibili.com/video/BV1ANQqBTEVU');
    sw.stop();

    expect(metas, hasLength(100), reason: '多 P 合计须拆成逐分页条目');
    expect(sw.elapsed, lessThan(const Duration(seconds: 15)),
        reason: 'flat 枚举不逐页取详情，elapsed=${sw.elapsed}');

    // sourceId=BVID_pN，p1..p100 全序唯一（dup 门禁以此做 UNIQUE）。
    final ids = metas.map((m) => m.sourceId).toList();
    expect(ids.first, 'BV1ANQqBTEVU_p1');
    expect(ids.last, 'BV1ANQqBTEVU_p100');
    expect(ids.toSet().length, 100);

    // 条目 url 自带 ?p=N（下载任务用它二次 resolve 补全条目详情）。
    expect(metas.first.url, contains('BV1ANQqBTEVU?p=1'));
    expect(metas[9].url, contains('BV1ANQqBTEVU?p=10'));

    // flat 面保真断言：标题可展示（回退派生），时长不伪造。
    expect(metas.first.title, isNotEmpty);
    expect(metas.first.durationMs, 0);
    expect(metas.first.sourceType, 'bilibili');
    expect(metas.first.qualities, isNotEmpty);
  });

  test('EXT-拆分回归：多 P 锚点（10 分 P）→ 10 条同源条目（真网 flat 枚举）', () async {
    final dir =
        await Directory.systemTemp
            .createTemp('s6_split2_${DateTime.now().millisecondsSinceEpoch}');
    final gate = await openIaDatabase('${dir.path}/ia.db');
    addTearDown(gate.db.close);
    final queue = ExtractQueue(db: gate.db, downloader: DownloaderAdapter());

    // 实测（2026-10-19 真网）：BV17x411w7KC 为 10 分 P 视频（旧 resolve 语义聚焦
    // 首页 p1；拆分语义=枚举该视频自身分 P 域——flat 条目 url 全部同 BV 实证）。
    final metas = await queue.parseLinkText(kSingleVideoUrl);
    expect(metas, hasLength(10), reason: '该锚点视频实测 10 分 P');
    final ids = metas.map((m) => m.sourceId).toList();
    expect(ids.toSet().length, 10);
    expect(ids.first, 'BV17x411w7KC_p1');
    expect(metas.first.url, contains('video/BV17x411w7KC?p=1'));
    for (final m in metas) {
      expect(m.url.contains('/video/BV17x411w7KC'), isTrue, reason: '条目必须同源该视频');
      expect(m.durationMs, 0); // flat 面不伪造时长
    }
  });

  test('EXT-拆分回归：真单 P 视频 → 恰 1 条全量元数据（真网）', () async {
    final dir =
        await Directory.systemTemp
            .createTemp('s6_split3_${DateTime.now().millisecondsSinceEpoch}');
    final gate = await openIaDatabase('${dir.path}/ia.db');
    addTearDown(gate.db.close);
    final queue = ExtractQueue(db: gate.db, downloader: DownloaderAdapter());

    // 真单 P 锚（2026-10-19 经 B 站 popular API 实取，videos=1）。
    final metas = await queue.parseLinkText(
        'https://www.bilibili.com/video/BV1j5nj68E48');
    expect(metas, hasLength(1));
    final m = metas.single;
    // 真·单 P：yt-dlp id 语义=无 _p 后缀（与旧 resolve 全量面一致）。
    expect(m.sourceId, 'BV1j5nj68E48');
    expect(m.uploader, isNotEmpty);
    expect(m.durationMs, greaterThan(60000)); // 全量面=真实时长（K/DA MV）
    expect(m.qualities, isNotEmpty);
  });
}
