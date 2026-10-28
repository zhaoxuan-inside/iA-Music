// DEC-010: 真库真盘真环境。本文件不触网（门禁/重复=数据库行为面）。
import 'dart:io';

import 'package:contracts/contracts.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/downloader_adapter.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/extract/extract_queue.dart';

void main() {
  test('合规门禁：未确认声明 → dequeue 被拒（状态门禁，无下载执行）', () async {
    final dir = await Directory.systemTemp.createTemp('s6_gate');
    addTearDown(() => dir.delete(recursive: true));
    final gate = await openIaDatabase('${dir.path}/ia.db');
    final dbIa = gate.db;
    final queue = ExtractQueue(db: dbIa, downloader: DownloaderAdapter());
    addTearDown(() => queue.dispose());

    final meta = const ResolvedMeta(
      sourceType: 'bilibili',
      sourceId: 'BV17x411w7KC_p1',
      url: 'https://www.bilibili.com/video/BV17x411w7KC/',
      title: 't',
      uploader: 'u',
      durationMs: 1,
      qualities: [Quality.k64],
    );

    // 门禁：未确认 → StateError（REQ-ONB-03/EXT-07；不做网络解析）
    expect(
      () => queue.enqueue(meta,
          quality: TaskQuality.k64, nowMs: 1),
      throwsStateError,
    );
    final rows = await (dbIa.select(dbIa.extractTasks)).get();
    expect(rows, isEmpty); // 门禁在库前：没有任何任务行（引导页拦截）

    // 确认后放行：acknowledged_at 设置位
    await queue.acknowledgeCompliance(at: DateTime.fromMillisecondsSinceEpoch(5));
    expect(await queue.isComplianceAcknowledged(), isTrue);
    final setting = await (DataAccess(dbIa).shell.value(
          ExtractQueue.kComplianceKey,
        ));
    expect(setting, isNotNull);
    await dbIa.close();
  });

  test('重复检测（REQ-EXT-06）：extract_tasks 同源 + tracks.source 双保险 → dup 终态', () async {
    final dir = await Directory.systemTemp.createTemp('s6_dup');
    addTearDown(() => dir.delete(recursive: true));
    final gate = await openIaDatabase('${dir.path}/ia.db');
    final dbIa = gate.db;
    final queue = ExtractQueue(db: dbIa, downloader: DownloaderAdapter());
    // 不 dispose：会话面不再下载（dup 行=终态，泵无可取任务）

    final now = DateTime.now().millisecondsSinceEpoch;
    await queue.acknowledgeCompliance(at: DateTime.fromMillisecondsSinceEpoch(now));

    const sid = 'BV17x411w7KC_p1';
    final meta = const ResolvedMeta(
      sourceType: 'bilibili',
      sourceId: sid,
      url: 'https://www.bilibili.com/video/BV17x411w7KC/',
      title: '名前のない有料施設',
      uploader: '【官方】',
      durationMs: 1,
      qualities: [Quality.k64, Quality.k128],
    );

    // 直插真实任务行（真实库状态：前次已 registered 的痕迹）
    final extractDao = DataAccess(dbIa).extract;
    await extractDao.createOrGet(
      sourceType: meta.sourceType,
      sourceId: meta.sourceId,
      url: meta.url,
      quality: TaskQuality.k64,
      nowMs: now,
    );
    await extractDao.updateTask(1, status: ExtractTaskStatus.registered);

    // ② tracks.source 双保险：库内已存在同源可见曲目 → dup
    final now2 = DateTime.now().millisecondsSinceEpoch;
    await (dbIa.into(dbIa.repositoryRoots)).insert(
        RepositoryRootsCompanion.insert(
            path: dir.path,
            mode: RepositoryMode.directory,
            addedAt: now));
    await DataAccess(dbIa).library.insertTrackCore(
          1,
          '提取/BV17x411w7KC_p1.mp3',
          mtime: now,
          fileSize: 1024,
          contentHash: 'h',
          nowMs: now,
          title: 'x',
          format: AudioFormatSpec.mp3,
          sourceType: 'bilibili',
          sourceId: sid,
        );
    final (task, isDup) = await queue.enqueue(meta,
        quality: TaskQuality.k64, nowMs: now2);
    expect(isDup, isTrue, reason: '同源曲目已在库（REQ-EXT-06 dup=复用行不重复建行）');
    expect(task.status, ExtractTaskStatus.dup);
    expect(task.errorCode, ExtractErrorCode.dup);

    // 库数量不变（dup=单行复用；§3.2 后置）
    final libCount = await (dbIa.select(dbIa.tracks)).get();
    expect(libCount.length, 1);
    final tasks = await (dbIa.select(dbIa.extractTasks)).get();
    expect(tasks.length, 1);
    await dbIa.close();
  });
}
