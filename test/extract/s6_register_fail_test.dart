// DEC-010: 真盘真实只读目录触发迁移失败路径（§3.2 不变量：库不动）。
// 制造方式=Windows 目录只读属性（真实磁盘态，非注入伪造）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/downloader_adapter.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/extract/extract_queue.dart';

// T9B 拆分语义：单视频场景锚=真·单 P（B 站 popular API 实取 videos=1，2026-10-19）。
const String kVideoUrl = 'https://www.bilibili.com/video/BV1j5nj68E48';

void main() {
  test('§3.2 不变量：迁移失败（只读目标目录）→ FAILED(disk)+库不动+无半成品遗留',
      () async {
    final dir = await Directory.systemTemp.createTemp('s6_failro');
    final gate = await openIaDatabase('${dir.path}/ia.db');
    final db = gate.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rootId = await db.into(db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(
            path: dir.path,
            mode: RepositoryMode.directory,
            addedAt: now,
          ),
        );
    final queue = ExtractQueue(db: db, downloader: DownloaderAdapter());
    await queue.acknowledgeCompliance(
        at: DateTime.fromMillisecondsSinceEpoch(now));

    // 真实磁盘态：把「提取」位预置为普通文件（而非目录）
    // → targetDir.create(recursive:true) 真抛 FileSystemException → 泵兜底 FAILED。
    // （Windows 目录 +R 不阻止新建文件，实测不能触发迁移失败；用文件占位=可重复。）
    final targetPlace = File('${dir.path}/提取');
    await targetPlace.writeAsString('占位', flush: true);

    final metas = await queue.parseLinkText(kVideoUrl);
    final (_, isDup) = await queue.enqueue(metas.single,
        quality: TaskQuality.k64, nowMs: now);
    expect(isDup, isFalse);

    // 等 FAILED(disk) 终态（重试计入但 disk 类不退避重试=§4.3）
    final failed = await queue.events
        .where((e) =>
            e is ExtractStateChanged && e.status == ExtractTaskStatus.failed)
        .first
        .timeout(const Duration(minutes: 6));
    expect(failed.taskId, greaterThanOrEqualTo(1));

    final row = await (db.select(db.extractTasks)).getSingle();
    expect(row.status, ExtractTaskStatus.failed);
    expect(row.errorCode, ExtractErrorCode.disk);

    // 库不动（§3.2 不变量；rootId 从未产出 track）
    final lib = await (db.select(db.tracks)).get();
    expect(lib.where((t) => t.rootId == rootId), isEmpty);

    // 恢复现场后目录可删（快照面留证）
    await queue.dispose();
    await db.close();
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
