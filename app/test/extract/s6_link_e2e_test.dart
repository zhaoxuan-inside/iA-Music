// DEC-010: 真链路真环境。解析/下载/转码/注册 —— 真实 yt-dlp+ffmpeg 进程、
// 真实 bilibili 公开样例（EXP-001 同源锚点 BV17x411w7KC）、真 SQLite、真盘。
// 伪造 JSON / 回放 = 一票否决。
import 'dart:io';

import 'package:contracts/contracts.dart';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/cover_fetch_adapter.dart';
import 'package:ia_music/adapters/downloader_adapter.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/extract/extract_queue.dart';
import 'package:ia_music/library/cover_chain.dart';

/// RE2 Ere 公开镇站样例（EXP-001 已锚定；匿名 64k 可下载）。
const String kPrimaryVideoUrl =
    'https://www.bilibili.com/video/BV17x411w7KC/';

/// 真实 SenseVoice 模型位（EXP-002 产物；present 状态对应真实文件 + 真实 sha）。
const String kRealModelPath = 'C:/Users/hardstone/tools/r3/sensevoice';
const String kRealModelFile = '$kRealModelPath/model.int8.onnx';

TaskQuality _qualityOf(Quality q) {
  switch (q) {
    case Quality.k64:
      return TaskQuality.k64;
    case Quality.k128:
      return TaskQuality.k128;
    case Quality.k192:
      return TaskQuality.k192;
    case Quality.hires:
      return TaskQuality.hires;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('REQ-EXT-01/03 主 Aha 路径 + EXT-04 串行 + EXT-08 联动（真链路全真）',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('s6_e2e_${DateTime.now().millisecondsSinceEpoch}');
    final gate = await openIaDatabase('${dir.path}/ia.db');
    final dbIa = gate.db;
    final data = DataAccess(dbIa);
    final now = DateTime.now().millisecondsSinceEpoch;
    await dbIa.into(dbIa.repositoryRoots).insert(RepositoryRootsCompanion.insert(
          path: dir.path,
          mode: RepositoryMode.directory,
          addedAt: now,
        ));

    final queue =
        ExtractQueue(db: dbIa, downloader: DownloaderAdapter());
    final watched = <String>[];
    final sub = queue.events.listen((ev) {
      watched.add(switch (ev) {
        ExtractStateChanged() => '${ev.taskId}:${ev.status.name}',
        ExtractRegistered() => 'reg:${ev.taskId}:${ev.trackId}',
        ExtractProgress() => 'p:${ev.taskId}',
      });
    });

    // ✅ 合规门禁前置：确认声明（真实应用态=settings 行 put）
    await queue.acknowledgeCompliance(
        at: DateTime.fromMillisecondsSinceEpoch(now));

    // ── REQ-EXT-01：真 B 站链接解析 ≤5s ───────────────────────
    // T9B 拆分语义（2026-10-19）：单视频场景锚改用真·单 P 视频
    // （BV1j5nj68E48，B 站 popular API 实取 videos=1；本意=单视频单任务不变）。
    final sw = Stopwatch()..start();
    final metas = await queue.parseLinkText(
        '【英雄联盟】K/DA官方MV https://www.bilibili.com/video/BV1j5nj68E48');
    sw.stop();
    expect(metas, hasLength(1));
    final resolved = metas.single;
    expect(resolved.sourceType, 'bilibili');
    expect(resolved.sourceId, 'BV1j5nj68E48');
    expect(resolved.uploader, isNotEmpty);
    expect(resolved.durationMs, greaterThan(50000)); // 单 P 全量面=真实时长
    expect(resolved.qualities, isNotEmpty);
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)), // ≤5s 承诺
        reason: 'resolve elapsed=${sw.elapsed}');
    // resolve 解析=元数据展示域（封面 URL 展示为解析卡可选内容）
    //（IE1/IE2: 元数据级即可；封面文件=提取产物阶段经 APIC）

    // ── EXT-08 预置：真实模型 present 状态（真实文件+real SHA-256）───
    final modelBytes = await File(kRealModelFile).readAsBytes();
    final modelSha =
        crypto.sha256.convert(modelBytes).toString();
    await data.shell.upsertModel('sensevoice-small-int8-zh',
        sizeBytes: modelBytes.length,
        sha256: modelSha,
        status: ModelStatus.present,
        localPath: kRealModelPath,
        downloadedAt: now);

    // ── REQ-EXT-03/04：一键提取 → 串行队列 → 自动入库 ──────────
    final (task, isDup) = await queue.enqueue(resolved,
        quality: _qualityOf(resolved.qualities.first), // 默认最高可用（EXP-001 匿名=64k）
        withLyrics: true,
        nowMs: DateTime.now().millisecondsSinceEpoch);
    expect(task.title, resolved.title); // 解析卡标题入库任务行（显示用）
    expect(task.status, anyOf(
        ExtractTaskStatus.resolved, ExtractTaskStatus.downloading));
    expect(isDup, isFalse);

    // 串行泵在下载（等待 REGISTERED 终态事件=6 分钟上限；EXP-001 1 分钟量级）
    final registered = await queue.events
        .where((e) => e is ExtractRegistered).cast<ExtractRegistered>()
        .first
        .timeout(const Duration(minutes: 6));
    expect(registered.taskId, task.id);

    final trackId = registered.trackId;
    final track = await (dbIa.select(dbIa.tracks)
          ..where((t) => t.id.equals(trackId)))
        .getSingle();
    // 自动入库断言（REQ-EXT-03；元数据=嵌入标签）
    expect(track.sourceType, 'bilibili');
    expect(track.sourceId, resolved.sourceId);
    expect(track.title, isNotEmpty); // 标签嵌入+净化前缀=提取面（真值非空）
    expect(track.artistDisplay, isNotEmpty);
    expect(track.contentHash.length, 64); // 真实整文件 sha256
    expect(track.rootId, greaterThan(0));

    // 产物=仓库/提取/ 子目录（PRD §3 保存位置默认），staging 已清
    final moveTo = '${dir.path}/提取';
    expect(Directory(moveTo).existsSync(), isTrue,
        reason: '产物迁入仓库提取子目录');
    final repoFiles = await Directory(moveTo).list().toList();
    expect(repoFiles.whereType<File>().length, greaterThanOrEqualTo(1));
    final staging =
        Directory('${Directory.systemTemp.path}/ia_extract/${resolved.sourceId}');
    if (staging.existsSync()) {
      // 终态清空（§4.3 终态即清理）
      expect(await staging.list().toList(), isEmpty,
          reason: '产物已迁出，分片清理无半成品');
    }

    // ── EXT-08：歌词自动排队（真实模型 present）─────────────────
    final jobs = await (dbIa.select(dbIa.lyricsGenJobs)).get();
    expect(jobs, hasLength(1), reason: '勾选「同时生成歌词」→注册后 queued');
    expect(jobs.single.status, LyricsJobStatus.queued);
    expect(jobs.single.trackId, trackId);

    // ── REQ-EXT-06：dup 双保险（同链接再 enqueue）───────────────
    final (dupTask, isDup2) = await queue.enqueue(resolved,
        quality: _qualityOf(resolved.qualities.first),
        withLyrics: false,
        nowMs: DateTime.now().millisecondsSinceEpoch);
    expect(isDup2, isTrue);
    expect(dupTask.status, ExtractTaskStatus.dup);
    expect(dupTask.errorCode, ExtractErrorCode.dup);

    // 库只有一曲目（dup=复用行；不重复插入，DEC-002 语义）
    final libRows = await (dbIa.select(dbIa.tracks)).get();
    expect(libRows.length, 1);

    // ── 封面链确认（S5 注册路径可协作：字体清理 tag 类=内嵌封面）──
    // 提取产物 embed-thumbnail（APIC）→ CoverChain embedded 即可装饰
    // ── 封面链确认（S5 注册路径可协作：embed-thumbnail → APIC → embedded）──
    final cover =
        await CoverChain(data, CoverFetchAdapter()).decide(trackId);
    // 匿名样例缩略图=bilibili 真缩略图；embedded/sibling/fetched 皆真链路
    expect(cover.kind,
        isIn([CoverKind.embedded, CoverKind.sibling, CoverKind.fetched]),
        reason: '封面=真链路（嵌入缩略图或目录同级/在线补缺）');

    // 事件序列（状态机锚）：
    expect(watched, contains('1:downloading'));
    expect(watched, contains('1:transcoding'));
    expect(watched, contains('1:registered'));

    await sub.cancel();
    await queue.dispose();
    await dbIa.close();
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

