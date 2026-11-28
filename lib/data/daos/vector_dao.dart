/// 音频嵌入向量 DAO：1:1 冷数据分表（与 lyrics_meta 同款模式）。
/// 失败记账复用 tracks.enrichAttempts（与元数据补全同款三败出池）。
library;

import 'package:drift/drift.dart';

import '../../domain/entities/track.dart';
import '../database.dart';
import '../tables.dart';

part 'vector_dao.g.dart';

@DriftAccessor(tables: [TrackVectors, Tracks])
class VectorDao extends DatabaseAccessor<IaDatabase> with _$VectorDaoMixin {
  VectorDao(super.db);

  /// 覆盖写（PK=trackId，换模型重算即替换旧向量，不混用）。
  Future<void> upsertVector({
    required int trackId,
    required String model,
    required int dim,
    required Uint8List vec,
  }) {
    return into(trackVectors).insertOnConflictUpdate(
      TrackVectorsCompanion.insert(
        trackId: Value(trackId),
        model: model,
        dim: dim,
        vec: vec,
      ),
    );
  }

  Future<TrackVectorRow?> vectorOf(int trackId) =>
      (select(trackVectors)..where((v) => v.trackId.equals(trackId)))
          .getSingleOrNull();

  /// 全量向量（相似检索一次性载入内存索引；按 model 过滤，换模型不混用）。
  Future<List<TrackVectorRow>> allVectors(String model) =>
      (select(trackVectors)..where((v) => v.model.equals(model))).get();

  /// 待算池：存活曲目 ∩ 无该 model 向量 ∩ 连续硬失败 <3，最旧优先。
  /// LEFT JOIN 按 (track_id, model) 定位缺口——补全完的曲目也要向量，
  /// 与元数据池（needsMeta）互不约束。
  Future<List<Track>> poolForVector({required String model, int limit = 25}) async {
    final rows = await customSelect(
      _poolSelect('SELECT t.id AS t_id, t.root_id, t.rel_path, t.path, '
          't.title, t.artist, t.album, t.genre, t.duration_ms, t.size_bytes, '
          't.content_hash, t.audio_format, t.track_no, t.cover_path, '
          't.added_at, t.missing_at',
          tail: 'ORDER BY t.added_at LIMIT ?'),
      variables: [Variable.withString(model), Variable.withInt(limit)],
      readsFrom: {tracks},
    ).get();
    return rows.map(_trackFromRow).toList();
  }

  /// 待算数量（进度条总盘 + 启动恢复守卫）。
  Future<int> countWithoutVector({required String model}) async {
    final row = await customSelect(
      _poolSelect('SELECT COUNT(*) AS cnt'),
      variables: [Variable.withString(model)],
      readsFrom: {tracks},
    ).getSingle();
    return row.data['cnt'] as int? ?? 0;
  }

  /// 池口径唯一收口：存活 ∩ 无该 model 向量 ∩ 硬失败 <3。
  String _poolSelect(String projection, {String tail = ''}) =>
      '$projection FROM tracks t LEFT JOIN track_vectors v '
      'ON v.track_id = t.id AND v.model = ? '
      'WHERE t.missing_at IS NULL AND v.track_id IS NULL '
      'AND t.enrich_attempts < 3 $tail';

  Track _trackFromRow(QueryRow r) => Track(
        id: r.read<int>('t_id'),
        rootId: r.read<int>('root_id'),
        relPath: r.read<String>('rel_path'),
        path: r.read<String>('path'),
        title: r.read<String>('title'),
        artist: r.read<String>('artist'),
        album: r.read<String>('album'),
        genre: r.read<String>('genre'),
        durationMs: r.read<int>('duration_ms'),
        sizeBytes: r.read<int>('size_bytes'),
        contentHash: r.read<String>('content_hash'),
        audioFormat: r.read<String>('audio_format'),
        trackNo: r.read<int>('track_no'),
        coverPath: r.readNullable<String>('cover_path'),
        addedAt: r.read<DateTime>('added_at'),
        needsMeta: false,
        enrichedAt: null,
        missing: r.readNullable<DateTime>('missing_at') != null,
      );
}
