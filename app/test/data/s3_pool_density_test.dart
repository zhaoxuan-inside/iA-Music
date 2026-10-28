// S3 DoD1 密度面：500 级 fixture 的随机池 SQL 粗筛 + 内存采样断言（D9-2）。
// 真库+真行（DEC-010：行=真实 DB 实体；断言取样性能与正确性，不造 stub 引擎）。
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';

void main() {
  test(
    '500 行曲库随机池：取样 3 正确（有界子集）+ 调用毫秒级（内存采样口径）',
    timeout: Timeout(Duration(minutes: 3)),
    () async {
      final gate = await openIaDatabaseMemory();
      final db = gate.db;
      addTearDown(() => db.close());
      final data = DataAccess(db);

      final rootId = await (db.into(db.repositoryRoots).insert(
            RepositoryRootsCompanion.insert(
              path: 'E:/music',
              mode: RepositoryMode.directory,
              addedAt: 1,
            ),
          ));
      final now = 700000;
      for (var i = 1; i <= 500; i++) {
        await data.library.insertTrackWithIndex(
          rootId,
          'A/密度曲$i.flac',
          mtime: now,
          fileSize: 128,
          contentHash: 'hash-$i',
          nowMs: now,
          title: '密度曲$i',
          artistDisplay: '密度歌手${i % 20}',
          albumDisplay: '密度专辑${i % 7}',
          durationMs: 100000 + i,
        );
      }

      // 软删/缺失/少播排他面（500 库中植入三类排除样本）
      final excludedRows = (await data.library.browse(pageSize: 500));
      final softDelId = excludedRows.first.id;
      await data.library.softDeleteTrack(softDelId, now);
      final missingId = excludedRows.elementAt(1).id;
      await data.library.markMissing(missingId, now);
      final fewId = excludedRows.elementAt(2).id;
      await data.history.addFewWatch(fewId, now);

      // 三类排除面自检（哪个漏，哪个先炸——不再猜）
      final delCnt = await db
          .customSelect('SELECT count(*) c FROM tracks WHERE deleted_at IS NOT NULL')
          .getSingle();
      expect(delCnt.read<int>('c'), 1, reason: '软删=1');
      final missCnt = await db
          .customSelect('SELECT count(*) c FROM tracks WHERE missing_at IS NOT NULL')
          .getSingle();
      expect(missCnt.read<int>('c'), 1, reason: '缺失=1');
      final fewCnt =
          await db.customSelect('SELECT count(*) c FROM few_watch_list').getSingle();
      expect(fewCnt.read<int>('c'), 1, reason: '少播=1');
      final trackCnt =
          await db.customSelect('SELECT count(*) c FROM tracks').getSingle();
      expect(trackCnt.read<int>('c'), 500, reason: '总入行=500');

      final sw = Stopwatch()..start();
      final pool = await data.library.randomPool(sampleSize: 5000);
      sw.stop();

      final cand = (await db
              .customSelect(
                'SELECT count(*) c FROM tracks WHERE deleted_at IS NULL AND '
                'missing_at IS NULL AND id NOT IN (SELECT track_id FROM few_watch_list)',
              )
              .getSingle())
          .read<int>('c');
      expect(pool.length, 497,
          reason: '500−软删−缺失−少播=497 池容量（SQL 直算候选=$cand）');
      for (final nono in [softDelId, missingId, fewId]) {
        expect(pool.map((t) => t.id), isNot(contains(nono)),
            reason: '排除面：双 NULL+NOT IN few_watch');
      }

      // 取样本（sample 3）：子集断言 + 不重复内蕴（DAO 采样=逐额内嵌去重后洗牌）
      final part = await data.library.randomPool(sampleSize: 3);
      final poolIds = pool.map((t) => t.id).toSet();
      expect(part.length, 3);
      expect(part.every((t) => poolIds.contains(t.id)), isTrue);
      expect(part.map((t) => t.id).toSet().length, 3, reason: '单轮不重复');

      // 性能口径：池计算（SQL 粗筛+洗牌）毫秒级（Windows 真测上界 200ms 宽裕）
      // 诚实注记：机器差异允许宽裕；回归退化战机=秒级（错序/全表载行才致死）
      expect(sw.elapsedMilliseconds, lessThan(200),
          reason: 'D9-2 内存采样=毫秒级（实测 ${sw.elapsedMilliseconds}ms）');

      // 池不足 10 → includeFewWatch 补满口径（少播回场不改双 NULL 排他）
      for (final t in pool.sublist(0, 495)) {
        await data.history.addFewWatch(t.id, now);
      }
      final strict = await data.library.randomPool(sampleSize: 100);
      expect(strict.length, 2, reason: '少播 495+缺失1+软删1=严格池 2');
      final filled = await data.library.randomPool(
        sampleSize: 5000,
        includeFewWatch: true,
      );
      expect(filled.length, 498, reason: '全库补满=少播回场（500−软删−缺失=498）');
      expect(filled.map((t) => t.id), contains(fewId));
    },
  );
}
