// 拆分真链路 E2E（2026-10-25 需求验证）：真实合集视频（开发者实报
// BV1LTn2zoEeh，粤语精选歌单、标题含 10 首《》歌单）→ 下载 → 静音分析
// → 拆分 → 多曲注册（标题按歌单匹配）。伪造回放=一票否决（DEC-010）。
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/downloader_adapter.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/extract/extract_queue.dart';

const String kCollectionUrl =
    'https://www.bilibili.com/video/BV1LTn2zoEeh';

// ignore_for_file: avoid_print

void main() {
  test('REQ-EXT 拆分面：歌曲合集视频 → 多曲注册（真下载+真 ffmpeg 分析）',
      timeout: const Timeout(Duration(minutes: 15)), () async {
    final dir = await Directory.systemTemp
        .createTemp('ia_split_${DateTime.now().millisecondsSinceEpoch}');
    final gate = await openIaDatabase('${dir.path}/ia.db');
    final db = gate.db;
    addTearDown(() async {
      try {
        await db.close();
      } catch (_) {}
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    await db.into(db.repositoryRoots).insert(RepositoryRootsCompanion.insert(
          path: dir.path,
          mode: RepositoryMode.directory,
          addedAt: 1,
        ));

    final queue = ExtractQueue(db: db, downloader: DownloaderAdapter());
    await queue.acknowledgeCompliance(at: DateTime.now());
    final messages = <String>[];
    final sub = queue.events.listen((ev) {
      if (ev is ExtractStateChanged) {
        messages.add('${ev.status.name}:${ev.message ?? ''}');
      }
    });

    final metas = await queue.parseLinkText(kCollectionUrl);
    expect(metas, isNotEmpty);
    print('SPLIT-E2E resolve: dur=${metas.first.durationMs}ms '
        'title=${metas.first.title}');
    expect(metas.first.durationMs, greaterThan(5 * 60 * 1000),
        reason: '测试样本必须是 >5 分钟的合集视频');

    final (task, _) = await queue.enqueue(metas.first,
        quality: TaskQuality.k192,
        withLyrics: true,
        withText: false,
        withVideo: false,
        nowMs: DateTime.now().millisecondsSinceEpoch);

    final done = await queue.events
        .where((e) =>
            e is ExtractStateChanged &&
            e.taskId == task.id &&
            (e.status == ExtractTaskStatus.registered ||
                e.status == ExtractTaskStatus.failed))
        .cast<ExtractStateChanged>()
        .first
        .timeout(const Duration(minutes: 12));
    expect(done.status, ExtractTaskStatus.registered,
        reason: '失败消息=${done.message}');

    final tracks = await (db.select(db.tracks)
          ..where((t) => t.sourceId.like('%${metas.first.sourceId}#p%')))
        .get();
    print('SPLIT-E2E registered tracks=${tracks.length}');
    for (final t in tracks) {
      print('SPLIT-E2E track: ${t.sourceId} "${t.title}" '
          'dur=${t.durationMs}ms');
    }
    expect(tracks.length, greaterThanOrEqualTo(2),
        reason: '合集应拆出多曲（失败消息=${done.message}）');
    // 标题歌单匹配：段数=歌单数时按《》命名
    final withKnownTitle =
        tracks.where((t) => t.title!.contains('吴哥窟')).length;
    print('SPLIT-E2E tracks matched to song list: $withKnownTitle');
    // 每段时长 ≥45s（规划红线）
    for (final t in tracks) {
      expect(t.durationMs, greaterThan(45 * 1000));
    }
    await sub.cancel();
    await queue.dispose();
  });
}
