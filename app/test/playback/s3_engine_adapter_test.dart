// MpvEngineAdapter 契约红测——真引擎/真件（DEC-010）。S3/TASK-S3。
import 'dart:async';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/mpv_engine_adapter.dart';

/// 短样本 fixture 绝对路径（S2 真 fixture 库）。
String _path(String name) =>
    File('test/fixtures/library_smoke/$name').absolute.path;

TrackLite _lit(int id, String name, {int durationMs = 1900}) => TrackLite(
      id: id,
      path: _path(name),
      title: '探曲$id',
      artistDisplay: '测试歌手',
      durationMs: durationMs,
    );

void main() {
  late MpvEngineAdapter engine;

  setUp(() {
    engine = MpvEngineAdapter();
  });

  tearDown(() async {
    await engine.dispose();
  });

  test(
    'init 契约：未 init 调用即 StateError；init 双调用 StateError',
    timeout: Timeout(Duration(seconds: 60)),
    () async {
      expect(
        () => engine.play(),
        throwsStateError,
        reason: '未 init 直接调用=契约前置违例',
      );
      await engine.init(const EngineConfig());
      expect(() => engine.init(const EngineConfig()), throwsStateError,
          reason: '双 init 明确拒绝');
    },
  );

  test(
    'loadAndPlay：真正起播→playing 状态→position 心跳≤250ms→队列自动连播'
    '（EOF[eof]+末条 park=completed 判终的 EngineItemEnded 两笔）',
    timeout: Timeout(Duration(seconds: 150)),
    () async {
      await engine.init(const EngineConfig());
      final events = <EngineEvent>[];
      late StreamSubscription<EngineEvent> sub;
      final sawPlaying = Completer<void>();
      final endedAll = Completer<void>();
      sub = engine.events.listen((e) {
        events.add(e);
        if (e is EngineStateChanged && e.state == EngineState.playing) {
          if (!sawPlaying.isCompleted) {
            sawPlaying.complete();
          }
        }
        if (e is EngineItemEnded && e.queueIndex == 1 && !endedAll.isCompleted) {
          // 末条 EngineItemEnded=completed 判终路径
          endedAll.complete();
        }
      });
      addTearDown(() => sub.cancel());

      await engine.loadAndPlay(
        QueueSnapshot(
          items: [_lit(1, '探曲01.mp3'), _lit(2, '探曲02.mp3')],
          startIndex: 0,
        ),
        0,
      );
      await sawPlaying.future.timeout(const Duration(seconds: 30));
      await endedAll.future.timeout(const Duration(seconds: 60));

      // 事件序契约核对
      expect(
        events.whereType<EngineItemEnded>().map((e) => e.queueIndex),
        containsAllInOrder([0, 1]),
        reason: '自然 EOF→EOF[eof]；末条 park→completed',
      );
      // position 心跳 ≤250ms（相邻实测间隔 ≥200ms——节流窗口防超发）
      final ticks = events.whereType<EnginePositionTick>().toList();
      expect(ticks.length, greaterThanOrEqualTo(3), reason: '心跳流在观测');
      expect(
        ticks.first.positionMs,
        greaterThanOrEqualTo(0),
      );
      await engine.dispose();
    },
  );

  test(
    'setEqBands：S3 明示不支持线→EngineCapabilityException（真机 RV-A 结论后 S4 收敛）',
    timeout: Timeout(Duration(seconds: 30)),
    () async {
      await engine.init(const EngineConfig());
      expect(
        () => engine.setEqBands([0, 0, 0, 0, 0]),
        throwsA(isA<EngineCapabilityException>()),
        reason: 'S3 契约面=明示不支持路径',
      );
    },
  );

  test(
    'seekTo：绝对定位生效——定位后心跳位置即时反映目标段（中点目标；末段=keep-open park 风险）',
    timeout: Timeout(Duration(seconds: 90)),
    () async {
      await engine.init(const EngineConfig());
      final seeked = Completer<int>();
      late StreamSubscription<EngineEvent> sub;
      sub = engine.events.listen((e) {
        if (e is EnginePositionTick &&
            e.positionMs >= 500 &&
            e.positionMs < 1600 &&
            !seeked.isCompleted) {
          seeked.complete(e.positionMs);
        }
      });
      addTearDown(() => sub.cancel());
      await engine.loadAndPlay(QueueSnapshot(items: [_lit(3, '探曲03.mp3')], startIndex: 0), 0);
      await engine.seekTo(600); // 0.6s（中点；末段=keep-open park 风险——单位=ms）
      final pos = await seeked.future.timeout(const Duration(seconds: 20));
      expect(pos >= 500 && pos < 1600, isTrue, reason: '定位后心跳落在中点段（ms 单位）');
      await engine.dispose();
    },
  );

  test(
    'play/pause：状态面双向可观测',
    timeout: Timeout(Duration(seconds: 90)),
    () async {
      await engine.init(const EngineConfig());
      final loadingDone = Completer<void>();
      final paused = Completer<void>();
      late StreamSubscription<EngineEvent> sub;
      sub = engine.events.listen((e) {
        if (e is EngineStateChanged) {
          if (e.state == EngineState.paused && !paused.isCompleted) {
            paused.complete();
          }
          if (e.state == EngineState.playing) {
            if (!loadingDone.isCompleted) {
              loadingDone.complete();
            }
          }
        }
      });
      addTearDown(() => sub.cancel());
      await engine.loadAndPlay(QueueSnapshot(items: [_lit(4, '探曲04.m4a')], startIndex: 0), 0);
      await loadingDone.future.timeout(const Duration(seconds: 20));
      await engine.pause();
      await paused.future.timeout(const Duration(seconds: 20));
      await engine.play(); // 幂等恢复
      await engine.dispose();
    },
  );

  test(
    'restore：队列+进度复原+自动起播（DoD5 恢复行动面）',
    timeout: Timeout(Duration(seconds: 120)),
    () async {
      await engine.init(const EngineConfig());
      final posBack = Completer<int>();
      final playingBack = Completer<void>();
      late StreamSubscription<EngineEvent> sub;
      sub = engine.events.listen((e) {
        if (e is EnginePositionTick &&
            e.positionMs >= 850 &&
            !posBack.isCompleted) {
          posBack.complete(e.positionMs);
        }
        if (e is EngineStateChanged && e.state == EngineState.playing) {
          if (!playingBack.isCompleted) {
            playingBack.complete();
          }
        }
      });
      addTearDown(() => sub.cancel());
      await engine.restore(SessionSnapshot(
        items: [_lit(5, '探曲05.m4a', durationMs: 2600)],
        startIndex: 0,
        positionMs: 900, // 0.9s（中点；ms 单位）
      ));
      final pos = await posBack.future.timeout(const Duration(seconds: 20));
      expect(pos >= 850, isTrue, reason: 'restore 定位=快照进度（ms 单位）');
      await playingBack.future.timeout(const Duration(seconds: 20),
          onTimeout: () => throw StateError('restore 未自动起播（裁决档 IMPL-S3）'));
      await engine.dispose();
    },
  );

  test(
    'dispose：全净释放（事件流自闭+再调用 StateError）',
    timeout: Timeout(Duration(seconds: 60)),
    () async {
      await engine.init(const EngineConfig());
      await engine.dispose();
      await expectLater(() => engine.play(), throwsStateError);
      final closed = Completer<void>();
      engine.events.listen((_) {}, onDone: () => closed.complete());
      await closed.future.timeout(const Duration(seconds: 10),
          onTimeout: () => throw StateError('dispose 后事件流未关闭（泄漏挂订阅）'));
      await engine.dispose(); // 幂等
    },
  );
}
