// S4 播放域服务测试（REQ-PLAY-01/03/06 + REQ-PL-05 服务链）。
//
// DEC-010 全真：真 mpv 引擎 + 真 fixture + 真 drift 内存库（普通 test() 真异步，
// 沿 IMPL-S3 教训 L1–L6：非 FakeAsync；断言走「轮询快照/事件 Completer」）。
// 覆盖：行点击起播（playTrackIds）+ 模式四态行为分岔 + 插队立即生效 + 501 淘汰。
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/mpv_engine_adapter.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/playback/playback_service.dart';

void main() {
  late IaDatabase db;
  late DataAccess data;

  final fixtureDir = Directory('test/fixtures/library_smoke').absolute.path;

  setUp(() async {
    final gate = await openIaDatabaseMemory();
    db = gate.db;
    data = DataAccess(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedRoot() => db.into(db.repositoryRoots).insert(
        RepositoryRootsCompanion.insert(
          path: fixtureDir,
          mode: RepositoryMode.directory,
          addedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

  Future<int> seedTrack(String file, {String? title}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final abs = '$fixtureDir/$file';
    if (!await File(abs).exists()) {
      throw StateError('fixture 缺件 $abs');
    }
    final spec = switch (file.split('.').last) {
      'm4a' => AudioFormatSpec.m4a,
      'flac' => AudioFormatSpec.flac,
      'wav' => AudioFormatSpec.wav,
      'ogg' => AudioFormatSpec.ogg,
      _ => AudioFormatSpec.mp3,
    };
    return data.library.insertTrackWithIndex(
      1,
      file,
      mtime: now,
      fileSize: 4096,
      contentHash: 'hash-$file',
      nowMs: now,
      title: title ?? file.split('.').first,
      artistDisplay: '测试歌手',
      albumDisplay: '测试专辑',
      durationMs: 1900,
      format: spec,
    );
  }

  /// 轮询快照直到条件真（上限 [limit]）——禁流侦听（IMPL-S3 纪律）。
  Future<PlaybackSnapshot> waitSnap(
    PlaybackService svc,
    bool Function(PlaybackSnapshot s) ok, {
    Duration limit = const Duration(seconds: 40),
  }) async {
    final deadline = DateTime.now().add(limit);
    while (DateTime.now().isBefore(deadline)) {
      final s = svc.snapshot;
      if (ok(s)) {
        return s;
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    throw StateError('waitSnap 超时：${svc.snapshot.currentIndex}/${svc.snapshot.queue.length}');
  }

  test(
    'REQ-PLAY-01 行点击起播（playTrackIds）：默认列表循环 + 一轮末=同队重播',
    timeout: const Timeout(Duration(seconds: 120)),
    () async {
      await seedRoot();
      final a = await seedTrack('探曲01.mp3', title: '夜航');
      final b = await seedTrack('探曲02.mp3');

      final engine = MpvEngineAdapter();
      final service = PlaybackService(engine, data);
      await service.init();
      addTearDown(() => service.dispose());

      final ups = <int>[]; // EngineItemEnded 队列位序记录（引擎真事件）
      final sub = engine.events.listen((e) {
        if (e is EngineItemEnded) {
          ups.add(e.queueIndex);
        }
      });
      addTearDown(sub.cancel);

      await service.playTrackIds([a, b]);
      final started = await waitSnap(service, (s) => s.playing && s.queue.length == 2);
      expect(started.mode, PlaybackMode.loops, reason: 'PRD §3.1 默认列表循环');
      expect(started.currentTrack?.title, '夜航', reason: '行点击=该曲起播');
      expect(started.currentIndex, 0);

      // 一轮播完（末条 park）→ 列表循环=同队重播（不重采样：id 集不变）
      final wrapped = await waitSnap(
        service,
        (s) => s.playing && s.currentIndex == 0 && ups.contains(1),
      );
      expect(wrapped.queue.map((t) => t.id).toList(), [a, b],
          reason: '列表循环=同队重播（非随机池新轮）');
      expect(wrapped.mode, PlaybackMode.loops);
    },
  );

  test(
    'REQ-PLAY-03 顺序模式：一轮播完=自然停驻（不重播、不重采样）',
    timeout: const Timeout(Duration(seconds: 120)),
    () async {
      await seedRoot();
      final a = await seedTrack('探曲03.mp3');
      final b = await seedTrack('探曲04.m4a');

      final engine = MpvEngineAdapter();
      final service = PlaybackService(engine, data);
      await service.init();
      addTearDown(() => service.dispose());

      final ended = <int>[];
      final sub = engine.events.listen((e) {
        if (e is EngineItemEnded) {
          ended.add(e.queueIndex);
        }
      });
      addTearDown(sub.cancel);

      await service.playTrackIds([a, b]);
      await waitSnap(service, (s) => s.playing);
      service.setMode(PlaybackMode.sequence);

      // 等到末条自然 EOF 入账
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (!ended.contains(1) && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      expect(ended, contains(1), reason: '末条（第 1 位）自然 EOF 已投递');

      // 停驻窗口：给足重载机会（若误路由会在此窗口内重新 playing）
      await Future<void>.delayed(const Duration(seconds: 4));
      final s = service.snapshot;
      expect(s.currentIndex, 1, reason: '停在末位不回零');
      expect(s.playing, isFalse, reason: '顺序模式一轮播完=停驻');
      expect(s.queue.map((t) => t.id).toList(), [a, b], reason: '不重采样');
    },
  );

  test(
    'REQ-PLAY-03 单曲模式：末条=同位重播（不回零）',
    timeout: const Timeout(Duration(seconds: 120)),
    () async {
      await seedRoot();
      final a = await seedTrack('探曲05.m4a');
      final b = await seedTrack('探曲07.ogg');

      final engine = MpvEngineAdapter();
      final service = PlaybackService(engine, data);
      await service.init();
      addTearDown(() => service.dispose());

      // 从第 1 位（末位）起播：单曲模式重播同位=1（若误为列表循环将回 0）
      await service.playTrackIds([a, b], startIndex: 1);
      await waitSnap(service, (s) => s.playing && s.currentIndex == 1);
      service.setMode(PlaybackMode.single);
      final startedAt = DateTime.now();

      final s = await waitSnap(
        service,
        (x) => x.playing && x.currentIndex == 1 && DateTime.now().difference(startedAt).inSeconds >= 3,
        limit: const Duration(seconds: 60),
      );
      expect(s.currentIndex, 1, reason: '单曲循环=同位重播（不回零）');
      expect(s.queue.last.id, b);
    },
  );

  test(
    'REQ-PLAY-06 插队「下一首播放」：镜像 _current+1 + 引擎物理增列→自然推进命中',
    timeout: const Timeout(Duration(seconds: 120)),
    () async {
      await seedRoot();
      final a = await seedTrack('探曲01.mp3', title: 'A曲');
      final b = await seedTrack('探曲02.mp3', title: 'B曲');
      final c = await seedTrack('探曲06.wav', title: 'C曲-插队');

      final engine = MpvEngineAdapter();
      final service = PlaybackService(engine, data);
      await service.init();
      addTearDown(() => service.dispose());

      await service.playTrackIds([a, b]);
      await waitSnap(service, (s) => s.playing && s.currentIndex == 0);

      await service.insertNextId(c);
      final afterInsert = service.snapshot;
      expect(afterInsert.queue.map((t) => t.id).toList(), [a, c, b],
          reason: '插队入 _current+1（立即生效于队列）');
      expect(afterInsert.currentIndex, 0, reason: '不打断当前曲');

      // 当前曲自然 EOF → mpv insert-next 物理位命中插队曲（镜像同步命中）
      final played = await waitSnap(
        service,
        (s) => s.currentIndex == 1 && s.playing,
        limit: const Duration(seconds: 60),
      );
      expect(played.currentTrack?.id, c,
          reason: '自然推进命中插队曲（引擎物理增列与服务镜像同位）');
      expect(played.queue.map((t) => t.id).toList(), [a, c, b]);
    },
  );

  test(
    'REQ-PLAY-03 随机模式：单轮不重复（池采样去重）+ 一轮末自动新一轮',
    timeout: const Timeout(Duration(seconds: 120)),
    () async {
      await seedRoot();
      for (final f in [
        '探曲01.mp3',
        '探曲02.mp3',
        '探曲03.mp3',
        '探曲04.m4a',
        '探曲05.m4a',
        '探曲06.wav',
        '探曲07.ogg',
        '探曲08.ogg',
        '探曲09.flac',
        '探曲10.flac',
      ]) {
        await seedTrack(f);
      }

      final engine = MpvEngineAdapter();
      final service = PlaybackService(engine, data);
      await service.init();
      addTearDown(() => service.dispose());

      final lite = await service.sampleRound(poolSize: 100);
      final ids = lite.map((t) => t.id).toList();
      expect(ids.length, 10, reason: '真池=10 首（严格池无少播名单）');
      expect(ids.toSet().length, 10, reason: '单轮不重复（REQ-PLAY-03 锚）');

      await service.startRandom(poolSize: 100);
      final s = await waitSnap(service, (x) => x.playing && x.queue.isNotEmpty);
      expect(s.mode, PlaybackMode.random, reason: '随机卡进入=随机模式');
      expect(s.queue.map((t) => t.id).toSet().length, s.queue.length,
          reason: '实际会话队列单轮无重复');
    },
  );

  test(
    'REQ-PL-05 历史容量：植入 500（分批 100/事务）+ 新播放 → flush 淘汰最旧（500）',
    timeout: const Timeout(Duration(seconds: 120)),
    () async {
      await seedRoot();
      final a = await seedTrack('探曲01.mp3');
      final b = await seedTrack('探曲02.mp3');
      final c = await seedTrack('探曲03.mp3');

      // 分批 100/批事务植入 500 条（played_at 递增：最旧=playedAt 1）
      var t = 1;
      for (var batch = 0; batch < 5; batch++) {
        await data.history.recordBatch([
          for (var i = 0; i < 100; i++)
            (
              trackId: [a, b, c][(batch * 100 + i) % 3],
              completed: true,
              playedAtMs: t++,
              deviceId: 'seed',
            ),
        ]);
      }
      expect(await data.history.historyTotal(), 500, reason: '植入 500 条');

      final oldest = (await data.history.historyPage(pageSize: 600)).last.$1;
      expect(oldest.playedAt, 1, reason: '最旧=playedAt 1（淘汰基准）');

      final engine = MpvEngineAdapter();
      final service = PlaybackService(engine, data);
      await service.init();
      addTearDown(() => service.dispose());

      // 第 501 条=真播放动作（next 记一条 completed=false）→ flush 触发淘汰
      await service.playTrackIds([a]);
      await waitSnap(service, (s) => s.playing);
      await service.next();
      await service.flushHistory();

      expect(await data.history.historyTotal(), 500, reason: '超容即淘汰回 500（D9-3）');
      final rows = await data.history.historyPage(pageSize: 600);
      expect(rows.any((r) => r.$1.id == oldest.id), isFalse,
          reason: '最旧一条被淘汰');
      expect(rows.first.$1.playedAt, greaterThan(500),
          reason: '新记录在「今天」首位（最新）');
    },
  );
}
