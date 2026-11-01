// S3 播放域服务测试——真引擎 + 真库 + 真 fixture 文件（DEC-010 全真）。
// TASK-S3 DoD2/3/4/5 服务面；Gherkin 锚：REQ-PLAY-04/REQ-PLAY-08/REQ-NAV-02。
//
// 教训复用（IMPL-S2 §4-L1–L5）：本文件全部为普通 `test()`真实异步（非
// widget/FakeAsync——引擎 isolate 事件在真 zone 可达）。
import 'dart:async';
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

  /// 真 fixture 音频目录（12 件：S2 真件库；行内缺失件=真不存在路径）。
  final fixtureDir = Directory('test/fixtures/library_smoke').absolute.path;

  setUp(() async {
    final gate = await openIaDatabaseMemory();
    db = gate.db;
    data = DataAccess(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// 播真文件的曲行（rel=文件名；一律指真件；missing=true 时真件缺位）。
  Future<int> seedTrack({
    required String file,
    String? title,
    bool missing = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final abs = '$fixtureDir/$file';
    final rowTitle = title ?? file.split('.').first;
    if (missing) {
      // 真空曲行：文件真不在（引擎会撞 load 错——REQ-PLAY-08 真链路）
      final del = File(abs);
      if (await del.exists()) {
        throw StateError('该用例语义要求 $abs 真缺失（fixture 冲突）');
      }
    } else if (!await File(abs).exists()) {
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
      1, // root
      file,
      mtime: now,
      fileSize: 4096,
      contentHash: 'hash-$file',
      nowMs: now,
      title: rowTitle,
      artistDisplay: '测试歌手',
      albumDisplay: '测试专辑',
      durationMs: 1900,
      format: spec,
    );
  }

  Future<int> seedRoot() => (db.into(db.repositoryRoots).insert(
        RepositoryRootsCompanion.insert(
          path: fixtureDir,
          mode: RepositoryMode.directory,
          addedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ));

  TrackLite liteOf(int id, String rel) => TrackLite(
        id: id,
        path: '$fixtureDir/$rel',
        title: rel.split('.').first,
        artistDisplay: '测试歌手',
        durationMs: 1900,
      );

  test(
    'startRandom（REQ-NAV-02 锚面）：真池采样→真播→自然 EOF=completed=true 历史'
    '（flush 链）',
    timeout: Timeout(Duration(seconds: 120)),
    () async {
      await seedRoot();
      await seedTrack(file: '探曲01.mp3');
      await seedTrack(file: '探曲02.mp3');
      await seedTrack(file: '探曲03.mp3'); // 池里再一首

      final engine = MpvEngineAdapter();
      final service = PlaybackService(engine, data);
      await service.init();
      addTearDown(() async {
        await service.dispose();
      });

      final playing = Completer<void>();
      final firstEnded = Completer<int>();
      late final StreamSubscription<EngineEvent> sub;
      sub = engine.events.listen((e) {
        if (e is EngineStateChanged && e.state == EngineState.playing) {
          if (!playing.isCompleted) {
            playing.complete();
          }
        }
        if (e is EngineItemEnded && !firstEnded.isCompleted) {
          firstEnded.complete(e.queueIndex);
        }
      });
      addTearDown(() => sub.cancel());

      await service.startRandom(poolSize: 50);
      await playing.future.timeout(const Duration(seconds: 30));
      final firstId = service.snapshot.queue[0].id; // 洗牌序→首曲以快照为准
      final qi = await firstEnded.future.timeout(const Duration(seconds: 40));
      // 第一首= ENGINE EOF（游标权威=适配器）
      expect(qi, 0, reason: '首轮首个自然 EOF=队列第 0 位');

      // 历史延迟合并写：手动冲 == 完整成批（阈值未满也能指挥）
      await service.flushHistory();
      final rows = (await data.history.historyPage(pageSize: 200))
          .map((r) => r.$1)
          .toList();
      expect(
        rows.where((r) => r.trackId == firstId && r.completed).length,
        1,
        reason: '自然播完=completed=true（自然 EOF 行）',
      );
      await service.dispose();
    },
  );

  test(
    'dislikeThenNext（REQ-PLAY-04 锚面）：少播名单落库+立即下一首+未完成历史',
    timeout: Timeout(Duration(seconds: 120)),
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
        await seedTrack(file: f);
      }

      final engine = MpvEngineAdapter();
      final service = PlaybackService(engine, data);
      await service.init();
      addTearDown(() async {
        await service.dispose();
      });
      final playing = Completer<void>();
      late final StreamSubscription<EngineEvent> sub;
      sub = engine.events.listen((e) {
        if (e is EngineStateChanged && e.state == EngineState.playing) {
          if (!playing.isCompleted) {
            playing.complete();
          }
        }
      });
      addTearDown(() => sub.cancel());

      await service.startRandom(poolSize: 100);
      await playing.future.timeout(const Duration(seconds: 30));
      final before = service.snapshot.currentTrack!;
      await service.dislikeThenNext();

      final after = service.snapshot.currentTrack!;
      expect(after.id, isNot(before.id), reason: '垃圾桶=当前曲立即跳下一首');

      final few = await data.history.fewWatchIds();
      expect(few, contains(before.id), reason: '垃圾桶曲=少播名单落库');

      // 该曲历史：跳过（未完成）
      await service.flushHistory();
      final rows = (await data.history.historyPage(pageSize: 200))
          .map((r) => r.$1)
          .toList();
      expect(
        rows.any((r) => r.trackId == before.id && !r.completed),
        isTrue,
        reason: '丢弃曲=completed=false（非完成播放事实）',
      );

      // 池污染口径：再次采样必不含少播曲（池=全库−少播）
      final pool = (await data.library.randomPool(sampleSize: 100)).map((t) => t.id);
      expect(pool, isNot(contains(before.id)));

      // 设置可清空（REQ-PLAY-04 末句）：清空→少播名单 0+池恢复
      await data.history.clearFewWatch();
      expect(await data.history.fewWatchIds(), isEmpty);
      expect(
        (await data.library.randomPool(sampleSize: 100)).map((t) => t.id),
        contains(before.id),
        reason: '清空后该曲可重新被随机到',
      );
      await service.dispose();
    },
  );

  test(
    '缺失自动跳过（REQ-PLAY-08 锚面）：真缺失行→顶部提示原话+missing_at 补写+'
    '完成位 false 历史+自动续播',
    timeout: Timeout(Duration(seconds: 120)),
    () async {
      await seedRoot();
      final t0 = await seedTrack(file: '探曲01.mp3');
      final missed = await seedTrack(file: '已消失曲.flac', missing: true);
      final t2 = await seedTrack(file: '探曲02.mp3');

      final engine = MpvEngineAdapter();
      final service = PlaybackService(engine, data);
      await service.init();
      addTearDown(() async {
        await service.dispose();
      });

      final playing = Completer<void>();
      final noticed = Completer<PlaybackNotice>();
      late final StreamSubscription<PlaybackNotice> subN;
      subN = service.notices.listen((n) {
        if (n.kind == PlaybackNoticeKind.missingSkip && !noticed.isCompleted) {
          noticed.complete(n);
        }
      });
      addTearDown(() => subN.cancel());
      late final StreamSubscription<EngineEvent> sub;
      sub = engine.events.listen((e) {
        if (e is EngineStateChanged && e.state == EngineState.playing) {
          if (!playing.isCompleted) {
            playing.complete();
          }
        }
      });
      addTearDown(() => sub.cancel());

      // 确定性队列：真件→缺失件→真件
      await service.loadTracks([
        liteOf(t0, '探曲01.mp3'),
        liteOf(missed, '已消失曲.flac'),
        liteOf(t2, '探曲02.mp3'),
      ], startIndex: 0);
      await playing.future.timeout(const Duration(seconds: 30));
      final n = await noticed.future.timeout(const Duration(seconds: 45));
      expect(n.text, contains('文件缺失'), reason: 'REQ-PLAY-08 顶部提示原话');
      expect(n.text, contains('已跳过'));

      // 缺失账面：missing_at 补写（与扫描轮口径一致）+ completed=false 历史
      final row = await data.library.rowById(missed);
      expect(row!.missingAt, isNotNull, reason: '播放期真发现=missing_at 补写');
      await service.flushHistory();
      final rows = (await data.history.historyPage(pageSize: 200))
          .map((r) => r.$1)
          .toList();
      expect(
        rows.any((r) => r.trackId == missed && !r.completed),
        isTrue,
        reason: '缺失曲不写完成播放历史（completed=false 事实行）',
      );
      // 自动续播=第三首真在播（镜像推进）
      expect(service.snapshot.currentTrack!.id, t2);
      await service.dispose();
    },
  );

  test(
    '损坏自动跳过：文件在位但解码失败→「无法播放该文件」提示（播放页四态原话）',
    timeout: Timeout(Duration(seconds: 120)),
    () async {
      await seedRoot();
      final t0 = await seedTrack(file: '探曲01.mp3');
      final broken = await seedTrack(file: '10_broken_probe.mp3'); // 真坏件（S2 库）
      final t2 = await seedTrack(file: '探曲02.mp3');

      final engine = MpvEngineAdapter();
      final service = PlaybackService(engine, data);
      await service.init();
      addTearDown(() async {
        await service.dispose();
      });

      final noticed = Completer<PlaybackNotice>();
      late final StreamSubscription<PlaybackNotice> subN;
      subN = service.notices.listen((n) {
        if (n.kind == PlaybackNoticeKind.corruptSkip && !noticed.isCompleted) {
          noticed.complete(n);
        }
      });
      addTearDown(() => subN.cancel());

      await service.loadTracks([
        liteOf(t0, '探曲01.mp3'),
        liteOf(broken, '10_broken_probe.mp3'),
        liteOf(t2, '探曲02.mp3'),
      ], startIndex: 0);
      final n = await noticed.future
          .timeout(const Duration(seconds: 60), onTimeout: () {
        throw StateError('损坏跳过提示未在 60s 内送达');
      });
      expect(n.text, contains('无法播放该文件'));
      expect(n.text, contains('已跳过'));
      final row = await data.library.rowById(broken);
      expect(row!.missingAt, isNull, reason: '在位文件=不标 missing（损坏非缺失）');
      await service.dispose();
    },
  );

  test(
    'restore（DoD5）：kill 前→会话 JSON 轻持久；重启服务→restore 队列+进度+ Mechanics 版起播',
    timeout: Timeout(Duration(seconds: 150)),
    () async {
      await seedRoot();
      for (final f in ['探曲01.mp3', '探曲02.mp3', '探曲03.mp3']) {
        await seedTrack(file: f);
      }

      // A：正常会话——播 ~1.1s 后终（kill 语义）
      final engineA = MpvEngineAdapter();
      final serviceA = PlaybackService(engineA, data);
      await serviceA.init();
      final playing = Completer<void>();
      final ticked = Completer<int>();
      late final StreamSubscription<EngineEvent> subA;
      subA = engineA.events.listen((e) {
        if (e is EngineStateChanged && e.state == EngineState.playing) {
          if (!playing.isCompleted) {
            playing.complete();
          }
        }
        if (e is EnginePositionTick && e.positionMs >= 900) {
          if (!ticked.isCompleted) {
            ticked.complete(e.positionMs);
          }
        }
      });
      addTearDown(() => subA.cancel());
      await serviceA.startRandom(poolSize: 100);
      await playing.future.timeout(const Duration(seconds: 30));
      final killedAt = await ticked.future.timeout(const Duration(seconds: 60));
      final savedIdx = serviceA.snapshot.currentTrack!.path;
      await serviceA.dispose(); // kill（dispose 落会话终值=历史冲+会话派发）

      // 会话侧写：settings 表真有 playback.session JSON
      final raw = await data.shell.value(PlaybackService.sessionKey);
      expect(raw, isNotNull, reason: '会话轻持久=DoD5 前置');
      final snap = PlaybackService.decodeSessionJson(raw!);
      expect(snap, isNotNull);
      expect(snap!.items.where((t) => t.path == savedIdx), isNotEmpty);

      // B：新服务（真重启）→ restore：队列回位+进度≥kill 前-330ms+自动起播
      final engineB = MpvEngineAdapter();
      final serviceB = PlaybackService(engineB, data);
      await serviceB.init();
      final playingB = Completer<void>();
      final tickedB = Completer<int>();
      late final StreamSubscription<EngineEvent> subB;
      subB = engineB.events.listen((e) {
        if (e is EngineStateChanged && e.state == EngineState.playing) {
          if (!playingB.isCompleted) {
            playingB.complete();
          }
        }
        if (e is EnginePositionTick && e.positionMs >= killedAt - 330) {
          if (!tickedB.isCompleted) {
            tickedB.complete(e.positionMs);
          }
        }
      });
      addTearDown(() => subB.cancel());
      final restored = await serviceB.restoreFromDisk();
      expect(restored, isTrue, reason: 'restore=队列+进度捏位+自动起播');
      expect(serviceB.snapshot.currentTrack!.path, savedIdx,
          reason: '恢复的队列=kill 前队');
      await playingB.future.timeout(const Duration(seconds: 30));
      await tickedB.future.timeout(const Duration(seconds: 30));
      await serviceB.dispose();
    },
  );

  test(
    '恢复二次失败（§4.3）：引擎外力破坏→restore 两次抛→「播放服务异常」notice+false',
    timeout: Timeout(Duration(seconds: 90)),
    () async {
      await seedRoot();
      await seedTrack(file: '探曲01.mp3');

      final engine = MpvEngineAdapter();
      final service = PlaybackService(engine, data);
      await service.init(); // 真引擎 init ✓
      addTearDown(() async {
        await service.dispose();
      });

      // 外力破坏=引擎真 dispose（模拟系统级回收失败态；真异常源）
      await engine.dispose();

      // 会话真值：往 settings 写一份合法 JSON（restore 有料可恢复）
      await data.shell.put(
        PlaybackService.sessionKey,
        '{"items":[{"id":1,"path":"x.mp3","title":"x","artist":"a",'
        '"durationMs":1}],"index":0,"pos":0}',
        nowMs: 0,
      );

      final noticed = Completer<PlaybackNotice>();
      late final StreamSubscription<PlaybackNotice> subN;
      subN = service.notices.listen((n) {
        if (n.kind == PlaybackNoticeKind.serviceBroken && !noticed.isCompleted) {
          noticed.complete(n);
        }
      });
      addTearDown(() => subN.cancel());

      final ok = await service.restoreFromDisk();
      expect(ok, isFalse, reason: '二次失败=返回 false');
      final n = await noticed.future.timeout(const Duration(seconds: 10));
      expect(n.text, '播放服务异常', reason: '§4.3 二次失败人话文案');
      await service.dispose();
    },
  );

  test(
    '池不足 10=全库补满（NAV §3.5 规 1）：少播挤到 2 首→含少播曲的开满队列',
    timeout: Timeout(Duration(seconds: 150)),
    () async {
      // 独立临时真目录：拷贝 S2 真 ffmpeg 产物为 12 个不同名真件
      // （共享 fixture 目录禁改：S2「真实计数 10/2」口径受保护）
      final tmp = await Directory.systemTemp.createTemp('ia_s3_pool12');
      addTearDown(() async {
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      });
      final names = <String>[
        for (final f in ['探曲01.mp3', '探曲02.mp3', '探曲03.mp3', '探曲04.m4a'])
          f,
        '探曲05.m4a',
        '探曲06.wav',
        '探曲07.ogg',
        '探曲08.ogg',
        '探曲09.flac',
        '探曲10.flac',
        '复播一.mp3',
        '复播二.mp3',
      ];
      await File(
        'test/fixtures/library_smoke/探曲01.mp3',
      ).absolute.copy('${tmp.path}/复播一.mp3');
      await File(
        'test/fixtures/library_smoke/探曲02.mp3',
      ).absolute.copy('${tmp.path}/复播二.mp3');
      for (var i = 0; i < 10; i++) {
        final name = names[i];
        await File('test/fixtures/library_smoke/$name').absolute
            .copy('${tmp.path}/$name');
      }

      final rootId = await (db.into(db.repositoryRoots).insert(
            RepositoryRootsCompanion.insert(
              path: tmp.absolute.path,
              mode: RepositoryMode.directory,
              addedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          ));
      final now = DateTime.now().millisecondsSinceEpoch;
      final ids = <int>[];
      for (final n in names) {
        ids.add(await data.library.insertTrackWithIndex(
          rootId,
          n,
          mtime: now,
          fileSize: 4096,
          contentHash: 'hash-$n',
          nowMs: now,
          title: n.split('.').first,
          artistDisplay: '测试歌手',
          albumDisplay: '测试专辑',
          durationMs: 1900,
        ));
      }
      for (final f in names.sublist(0, 10)) {
        if (!await File('${tmp.path}/$f').exists()) {
          throw StateError('临时真件缺位 $f');
        }
      }

      final engine = MpvEngineAdapter();
      final service = PlaybackService(engine, data);
      await service.init();
      addTearDown(() async {
        await service.dispose();
      });

      // 10 首打入少播→严格池=2
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (final id in ids.sublist(0, 10)) {
        await data.history.addFewWatch(id, nowMs);
      }
      expect(
        (await data.library.randomPool(sampleSize: 100)).length,
        2,
        reason: '少播后严格池只剩 2',
      );

      final played = Completer<void>();
      late final StreamSubscription<EngineEvent> sub;
      sub = engine.events.listen((e) {
        if (e is EngineStateChanged && e.state == EngineState.playing) {
          if (!played.isCompleted) {
            played.complete();
          }
        }
      });
      addTearDown(() => sub.cancel());
      await service.startRandom(poolSize: 100);
      await played.future.timeout(const Duration(seconds: 30));

      expect(service.snapshot.queue.length, names.length,
          reason: '池<10 → 全库补满（少播曲回场）');
      final poolIds = service.snapshot.queue.map((t) => t.id).toSet();
      expect(poolIds.containsAll(ids.toSet()), isTrue);
      await service.dispose();
    },
  );
}
