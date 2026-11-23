/// 播放服务状态机测试——FakeEngine（不发真声，只对账事件）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/entities/playback.dart';
import 'package:ia_music/domain/entities/track.dart';
import 'package:ia_music/domain/ports/engine_port.dart';
import 'package:ia_music/services/playback/playback_service.dart';
import 'package:ia_music/services/settings/settings_service.dart';

class FakeEngine implements EnginePort {
  final _events = StreamController<EngineEvent>.broadcast();
  final List<int> startIndexes = [];
  int loadCount = 0;
  int restoreCount = 0;
  int jumpCount = 0;
  int playCount = 0;
  double? lastVolume;

  /// 注入失败（自愈路径测试）：下一次 restore/loadAndPlay 抛一次。
  bool failRestoreOnce = false;
  bool failLoadOnce = false;
  final List<int> restoreIndexes = [];
  final List<int> restorePositions = [];

  @override
  Stream<EngineEvent> get events => _events.stream;

  void emit(EngineEvent e) => _events.add(e);

  @override
  Future<void> init() async {}

  @override
  Future<void> loadAndPlay(List<QueueItem> queue, int startIndex) async {
    loadCount++;
    startIndexes.add(startIndex);
    if (failLoadOnce) {
      failLoadOnce = false;
      throw StateError('load failed');
    }
  }

  @override
  Future<void> restore(List<QueueItem> queue, int startIndex, int positionMs) async {
    restoreCount++;
    restoreIndexes.add(startIndex);
    restorePositions.add(positionMs);
    if (failRestoreOnce) {
      failRestoreOnce = false;
      throw StateError('restore failed');
    }
  }

  @override
  Future<void> play() async => playCount++;
  @override
  Future<void> pause() async {}
  @override
  Future<void> seekTo(int positionMs) async {}
  @override
  Future<void> jumpTo(int index) async => jumpCount++;
  @override
  Future<void> setVolume(double volume) async => lastVolume = volume;
  @override
  Future<void> setRepeatMode(RepeatMode mode) async {}
  @override
  Future<void> insertNext(QueueItem item) async {}
  @override
  Future<void> removeQueueIndex(int index) async {}
  @override
  Future<void> moveQueueIndex(int from, int to) async {}
  @override
  Future<void> stopAll() async {}
  @override
  Future<void> dispose() async => _events.close();
}

void main() {
  late IaDatabase db;
  late FakeEngine engine;
  late PlaybackService service;
  late List<Track> tracks;
  final recordedErrors = <String>[];

  setUp(() async {
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    final rootId = await db.libraryDao.addRoot('/music');
    await db.libraryDao.upsertScannedBatch([
      for (var i = 1; i <= 4; i++)
        TrackUpsert(
          rootId: rootId,
          relPath: 't$i.mp3',
          path: '/music/t$i.mp3',
          title: 'Track $i',
          artist: 'A',
          album: 'L',
          genre: '',
          needsMeta: false,
          trackNo: i,
          durationMs: 60000,
          sizeBytes: 10,
          contentHash: 'h$i',
          audioFormat: 'mp3',
        ),
    ]);
    tracks = await db.libraryDao.availableTracks();
    engine = FakeEngine();
    recordedErrors.clear();
    service = PlaybackService(
      engine: engine,
      db: db,
      settings: SettingsService(db.settingsDao),
      onError: (source, e, [st]) => recordedErrors.add('$source: $e'),
    );
    await service.start(resumeSession: false);
  });

  /// 重启服务做会话恢复测试（setUp 的服务不恢复）。
  Future<PlaybackService> restartedService({bool failRestore = false}) async {
    await service.dispose();
    engine = FakeEngine()..failRestoreOnce = failRestore;
    return service = PlaybackService(
      engine: engine,
      db: db,
      settings: SettingsService(db.settingsDao),
      onError: (source, e, [st]) => recordedErrors.add('$source: $e'),
    );
  }

  /// 预写会话快照（全部曲目，起播 [index]，断点 [positionMs]）。
  Future<void> writeSession(int index, int positionMs) async {
    await db.settingsDao.setValue(
        SettingKeys.session,
        jsonEncode({
          'paths': [for (final t in tracks) t.path],
          'index': index,
          'positionMs': positionMs,
        }));
  }

  tearDown(() async {
    await service.dispose();
    await db.close();
  });

  Future<void> pump() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('playTracks：加载队列并起播于 startIndex', () async {
    await service.playTracks(tracks, startIndex: 2);
    expect(engine.loadCount, 1);
    expect(engine.startIndexes.single, 2);
    expect(service.snapshot.current?.id, tracks[2].id);
  });

  test('playTrack：按曲目身份起播，队列顺序无关', () async {
    final shuffled = [tracks[3], tracks[1], tracks[0], tracks[2]];
    await service.playTrack(tracks[0], queue: shuffled);
    expect(service.snapshot.current?.id, tracks[0].id);
    expect(service.snapshot.queue.map((t) => t.id), shuffled.map((t) => t.id));
  });

  test('playTrack：队列含缺失行仍起播被点曲目', () async {
    await service.playTracks(tracks, startIndex: 0);
    engine.emit(const EngineFailed(EngineErrorCtor('broken file')));
    await pump();
    final bad = await db.libraryDao.trackById(tracks[0].id);
    expect(bad?.missing, isTrue);
    // 队列表里带一行已缺失（模拟 UI 持有的旧列表未刷新）：过滤后
    // 其余曲目前移一位，按 id 对位不受影响
    final stale = [bad!, tracks[1], tracks[2], tracks[3]];
    await service.playTrack(tracks[2], queue: stale);
    expect(service.snapshot.current?.id, tracks[2].id);
    expect(service.snapshot.queue.map((t) => t.id),
        [tracks[1].id, tracks[2].id, tracks[3].id]);
  });

  test('playTrack：不带队列 → 单曲队列', () async {
    await service.playTrack(tracks[1]);
    expect(service.snapshot.queue.map((t) => t.id), [tracks[1].id]);
    expect(service.snapshot.current?.id, tracks[1].id);
  });

  test('shuffle：起始曲固定在队首', () async {
    await service.playTracks(tracks, startIndex: 3, shuffle: true);
    expect(engine.startIndexes.single, 0);
    expect(service.snapshot.queue.first.id, tracks[3].id);
    expect(service.snapshot.queue.map((t) => t.id).toSet().length, 4);
  });

  test('自然播完 → 索引推进 + 历史 completed=true', () async {
    await service.playTracks(tracks, startIndex: 0);
    engine.emit(const EngineItemEnded(0));
    await pump();
    expect(service.snapshot.index, 1);
    final history = await db.historyDao.watchRecent().first;
    expect(
      history.any((h) => h.track.id == tracks[0].id && h.completed),
      isTrue,
    );
  });

  test('末曲播完 → ended（不回绕）', () async {
    await service.playTracks(tracks, startIndex: 3);
    engine.emit(const EngineItemEnded(3));
    await pump();
    expect(service.snapshot.ended, isTrue);
    expect(service.snapshot.index, 3);
  });

  test('手动 next → completed=false 历史 + jumpTo', () async {
    await service.playTracks(tracks, startIndex: 0);
    await service.next();
    await pump();
    expect(engine.jumpCount, 1);
    expect(service.snapshot.index, 1);
    final history = await db.historyDao.watchRecent().first;
    expect(history.first.track.id, tracks[0].id);
    expect(history.first.completed, isFalse);
  });

  test('previous：>3s 先回 0，否则跳上一曲', () async {
    await service.playTracks(tracks, startIndex: 2);
    engine.emit(const EnginePositionTick(5000));
    await pump();
    await service.previous();
    await pump();
    expect(service.snapshot.index, 2, reason: '位置 >3s 只 seek 不切曲');

    engine.emit(const EnginePositionTick(1000));
    await pump();
    await service.previous();
    await pump();
    expect(service.snapshot.index, 1);
  });

  test('引擎错误 → 标缺失 + 通知', () async {
    await service.playTracks(tracks, startIndex: 0);
    final noticeFuture = service.notices.first;
    engine.emit(const EngineFailed(EngineErrorCtor('broken file')));
    await pump();
    expect(service.snapshot.index, 1, reason: '引擎自动推进，索引对齐');
    final bad = await db.libraryDao.trackById(tracks[0].id);
    expect(bad?.missing, isTrue);
    final notice = await noticeFuture.timeout(
      const Duration(seconds: 1),
      onTimeout: () => '',
    );
    expect(notice, tracks[0].title);
  });

  test('插队 playNext', () async {
    await service.playTracks(tracks, startIndex: 0);
    await service.playNext(tracks[3]);
    expect(service.snapshot.queue[1].id, tracks[3].id);
  });

  test('拖拽重排 reorderQueue：下移 / 上移 + 当前索引对齐', () async {
    await service.playTracks(tracks, startIndex: 1); // 当前 = Track 2（idx1）
    // 下移：Track 2 (idx1) → 移除后插到 idx2，最终仍 idx2
    await service.reorderQueue(1, 2);
    expect(service.snapshot.queue.map((t) => t.id).toList(),
        [tracks[0].id, tracks[2].id, tracks[1].id, tracks[3].id]);
    expect(service.snapshot.index, 2); // 当前曲跟随条目移动
    // 上移：Track 4 (idx3) → 队首，当前 idx2 ≤ from 不动
    await service.reorderQueue(3, 0);
    expect(service.snapshot.queue.first.id, tracks[3].id);
    expect(service.snapshot.queue.last.id, tracks[1].id);
    expect(service.snapshot.index, 3); // from(3) 之后被移走：2 → 3
    expect(service.snapshot.current?.id, tracks[1].id);
  });

  test('音量持久化', () async {
    await service.setVolume(66);
    expect(engine.lastVolume, 66);
    final raw = await db.settingsDao.valueOf(SettingKeys.volume);
    expect(raw, isNotNull);
  });

  test('恢复失败 → 快照留队列但引擎空壳；play() 自愈重载接断点', () async {
    await writeSession(1, 30000);
    final svc = await restartedService(failRestore: true);
    await svc.start(resumeSession: true);
    // 快照恢复了（底部栏可见），但引擎装载失败：状态可辨、故障已上报
    expect(svc.snapshot.current?.id, tracks[1].id);
    expect(svc.snapshot.loading, isFalse);
    expect(engine.restoreCount, 1);
    expect(recordedErrors.where((e) => e.startsWith('播放 · 会话恢复失败')),
        hasLength(1));
    // 空壳引擎下点播放 → 自愈重载（不是无效的裸 play），接回会话断点
    await svc.play();
    expect(engine.restoreCount, 2);
    expect(engine.restoreIndexes.last, 1);
    expect(engine.restorePositions.last, 30000);
    expect(engine.playCount, 0);
    // 已装载后恢复裸播放语义
    await svc.play();
    expect(engine.playCount, 1);
  });

  test('恢复失败 → next() 按目标索引自愈重载', () async {
    await writeSession(1, 0);
    final svc = await restartedService(failRestore: true);
    await svc.start(resumeSession: true);
    await svc.next();
    expect(engine.restoreCount, 2, reason: 'jumpTo 对空壳引擎无效，改为重载');
    expect(engine.restoreIndexes.last, 2);
    expect(engine.restorePositions.last, 0);
    expect(svc.snapshot.index, 2);
  });

  test('装载失败 → loading 清除 + 上报；play() 自愈重载当前曲', () async {
    engine.failLoadOnce = true;
    await service.playTracks(tracks, startIndex: 2);
    expect(service.snapshot.loading, isFalse, reason: '装载失败不留悬挂 loading');
    expect(service.snapshot.current?.id, tracks[2].id);
    expect(recordedErrors.where((e) => e.startsWith('播放 · 装载队列')),
        hasLength(1));
    await service.play();
    expect(engine.restoreCount, 1);
    expect(engine.restoreIndexes.single, 2);
    expect(engine.restorePositions.single, 0);
  });
}
