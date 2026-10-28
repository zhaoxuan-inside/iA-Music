// DEC-010: 真进程真清理。取消=树杀+分片清理（§4.3 资源释放；无半成品遗留）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/downloader_adapter.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/extract/extract_queue.dart';

// T9B 拆分语义：单视频场景锚=真·单 P（B 站 popular API 实取 videos=1，2026-10-19）。
const String kVideoUrl = 'https://www.bilibili.com/video/BV1j5nj68E48';

void main() {
  test('REQ-EXT-04 取消：进行中任务 → kill + staging 无半成品 + 行删除', () async {
    final dir =
        await Directory.systemTemp.createTemp('s6_cancel');
    final gate = await openIaDatabase('${dir.path}/ia.db');
    final dbIa = gate.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await dbIa.into(dbIa.repositoryRoots).insert(RepositoryRootsCompanion.insert(
          path: dir.path,
          mode: RepositoryMode.directory,
          addedAt: now,
        ));

    final adapter = DownloaderAdapter();
    final queue = ExtractQueue(db: dbIa, downloader: adapter);
    await queue.acknowledgeCompliance(at: DateTime.fromMillisecondsSinceEpoch(now));

    // 真解析（元数据仅探测=模拟预期）
    final metas = await queue.parseLinkText(kVideoUrl);
    expect(metas, hasLength(1));
    final resolved = metas.single;

    final (task, isDup) = await queue.enqueue(resolved,
        quality: TaskQuality.k64, nowMs: now);
    expect(isDup, isFalse);

    // 进行中取消：等真实进度 >0（真链路进入下载段）或 6s 兜底，再取消
    var sawProgress = false;
    final sub = queue.events
        .where((e) => e is ExtractProgress)
        .cast<ExtractProgress>()
        .listen((p) {
      if (p.percent > 0) {
        sawProgress = true;
      }
    });
    for (var i = 0; i < 60 && !sawProgress; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(sawProgress, isTrue, reason: '取消时机=真实下载进行中（进度>0）');
    await queue.cancelTask(task.id);

    // 行删除 = 用户取消（PRD §3 5：任务可取消）
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final rowsAfter = await (dbIa.select(dbIa.extractTasks)).get();
    expect(rowsAfter.where((r) => r.id == task.id), isEmpty,
        reason: '取消=行删除（历史可清）');

    final staging =
        Directory('${Directory.systemTemp.path}/ia_extract/${resolved.sourceId}');
    if (staging.existsSync()) {
      final leftovers = await staging.list().toList();
      final parts = leftovers
          .whereType<File>()
          .where((f) => f.path.endsWith('.part') || f.path.endsWith('.ytdl'));
      expect(parts, isEmpty, reason: '取消=无半成品遗留（§4.3）');
    }
    // 库不受影响（取消曲目未入曲库）
    final lib = await (dbIa.select(dbIa.tracks)).get();
    expect(lib, isEmpty, reason: '取消=不入库');

    await sub.cancel();
    await queue.dispose();
    await dbIa.close();
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 6)));
}
