/// 听法策略目录测试：策略清单完整性 + 各策略取材接线（内存真库）。
/// 策略化后「有哪些电台」的唯一事实源是 listenStrategiesProvider——
/// 本测试锁死目录形状与 fetch 接线，防止改目录时静默丢策略。
library;

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/config/embedding_config.dart';
import 'package:ia_music/app/providers.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/state/listen_providers.dart';

void main() {
  late IaDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    container = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  Future<void> seed() async {
    final rootId = await db.libraryDao.addRoot('/music');
    await db.libraryDao.upsertScannedBatch([
      for (final (i, t) in ['S1', 'S2', 'S3'].indexed)
        TrackUpsert(
          rootId: rootId,
          relPath: 't$i.mp3',
          path: '/music/t$i.mp3',
          title: t,
          artist: 'A',
          album: '',
          genre: '',
          needsMeta: false,
          trackNo: 0,
          durationMs: 60000,
          sizeBytes: 10,
          contentHash: 'h$i',
          audioFormat: 'mp3',
        ),
    ]);
    final all = await db.libraryDao.getTracks();
    final by = {for (final t in all) t.title: t};
    // 播放：S1×2、S2×1 → 常听 = [S1, S2]，历史去重后只看得到 S1
    await db.historyDao.record(by['S1']!.id, completed: true);
    await db.historyDao.record(by['S1']!.id, completed: true);
    await db.historyDao.record(by['S2']!.id, completed: true);
    // 收藏 S2
    await db.playlistDao.setFavorite(by['S2']!.id, true);
    // 向量：种子 S1 [1,0]，S2 同向，S3 反向（1024 维，归一化语义）
    List<double> v2(double a, double b) =>
        [a, b, ...List.filled(kEmbeddingDim - 2, 0)];
    Uint8List bytes(List<double> v) =>
        Uint8List.sublistView(Float32List.fromList(v));
    await db.vectorDao.upsertVector(
        trackId: by['S1']!.id, model: kEmbeddingModel, dim: kEmbeddingDim, vec: bytes(v2(1, 0)));
    await db.vectorDao.upsertVector(
        trackId: by['S2']!.id, model: kEmbeddingModel, dim: kEmbeddingDim, vec: bytes(v2(1, 0)));
    await db.vectorDao.upsertVector(
        trackId: by['S3']!.id, model: kEmbeddingModel, dim: kEmbeddingDim, vec: bytes(v2(-1, 0)));
  }

  test('目录：六策略有序 + 编排参数（shuffle/种子/空库文案）', () async {
    await seed();
    final strategies = container.read(listenStrategiesProvider);
    expect(strategies.map((s) => s.id), [
      'random',
      'favorites',
      'top',
      'recent-added',
      'history',
      kListenStrategySimilar,
    ]);
    expect(strategies.where((s) => s.requiresSeed).map((s) => s.id),
        [kListenStrategySimilar], reason: '声音相似是唯一参数化策略，磁贴跳过');
    expect(strategies.firstWhere((s) => s.id == 'history').shuffle, isFalse,
        reason: '历史回放不打乱');
    expect(
        strategies
            .where((s) => !s.requiresSeed && s.id != 'history')
            .every((s) => s.shuffle && s.emptyHint.isNotEmpty),
        isTrue);
  });

  test('取材接线：六策略 fetch 全部连通', () async {
    await seed();
    final strategies = container.read(listenStrategiesProvider);
    Future<List<dynamic>> fetch(String id) =>
        strategies.firstWhere((s) => s.id == id).fetch(const ListenContext());

    final random = await fetch('random');
    expect(random, hasLength(3), reason: '随缘=全库可用');

    final favorites = await fetch('favorites');
    expect(favorites.map((t) => t.title), ['S2'], reason: '喜欢电台=收藏夹');

    final top = await fetch('top');
    expect(top.map((t) => t.title), ['S1', 'S2'],
        reason: '常听=plays 降序 Top12');

    final recent = await fetch('recent-added');
    expect(recent, hasLength(3), reason: '最近添加=addedAt 全集');

    final history = await fetch('history');
    // S1 录了两次只显一次（去重生效）；同秒时间戳下先后不定 → 集合断言
    expect(history.map((t) => t.title).toSet(), {'S1', 'S2'},
        reason: '历史回放=去重序列');

    final s1 = (await db.libraryDao.getTracks()).firstWhere((t) => t.title == 'S1');
    final similar = await strategies
        .firstWhere((s) => s.id == kListenStrategySimilar)
        .fetch(ListenContext(seedTrackId: s1.id));
    expect(similar.map((t) => t.title), ['S2', 'S3'],
        reason: '声音相似=余弦降序排除自身');
  });

  test('similar 无种子：空表走空库引导（不炸 UI）', () async {
    final strategies = container.read(listenStrategiesProvider);
    final tracks = await strategies
        .firstWhere((s) => s.id == kListenStrategySimilar)
        .fetch(const ListenContext());
    expect(tracks, isEmpty);
  });
}
