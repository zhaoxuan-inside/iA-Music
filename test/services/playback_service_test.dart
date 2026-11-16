/// 播放服务状态机测试——FakeEngine（不发真声，只对账事件）。
library;

import 'dart:async';

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
  double? lastVolume;

  @override
  Stream<EngineEvent> get events => _events.stream;

  void emit(EngineEvent e) => _events.add(e);

  @override
  Future<void> init() async {}

  @override
  Future<void> loadAndPlay(List<QueueItem> queue, int startIndex) async {
    loadCount++;
    startIndexes.add(startIndex);
  }

  @override
  Future<void> restore(List<QueueItem> queue, int startIndex, int positionMs) async {
    restoreCount++;
  }

  @override
  Future<void> play() async {}
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
  Future<void> updateMediaSession(MediaSessionInfo info) async {}
  @override
  Future<void> dispose() async => _events.close();
}

void main() {
  late IaDatabase db;
  late FakeEngine engine;
  late PlaybackService service;
  late List<Track> tracks;

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
    service = PlaybackService(
      engine: engine,
      db: db,
      settings: SettingsService(db.settingsDao),
    );
    await service.start(resumeSession: false);
  });

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
}
