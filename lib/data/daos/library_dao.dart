/// 曲库域 DAO：查询/排序/搜索/扫描写入原语。业务裁决不在这里。
library;

import 'package:drift/drift.dart';

import '../../app/config/embedding_config.dart';
import '../../domain/entities/track.dart';
import '../database.dart';
import '../pinyin_text.dart';
import '../tables.dart';

part 'library_dao.g.dart';

@DriftAccessor(tables: [
  RepositoryRoots,
  Tracks,
  PlayHistory,
  PlaylistTracks,
  LyricsMeta,
  TrackVectors,
])
class LibraryDao extends DatabaseAccessor<IaDatabase> with _$LibraryDaoMixin {
  LibraryDao(super.db);

  Track _map(TrackRow r) => Track(
        id: r.id,
        rootId: r.rootId,
        relPath: r.relPath,
        path: r.path,
        title: r.title,
        artist: r.artist,
        album: r.album,
        genre: r.genre,
        durationMs: r.durationMs,
        sizeBytes: r.sizeBytes,
        contentHash: r.contentHash,
        audioFormat: r.audioFormat,
        trackNo: r.trackNo,
        coverPath: r.coverPath,
        addedAt: r.addedAt,
        needsMeta: r.needsMeta,
        enrichedAt: r.enrichedAt,
        missing: r.missingAt != null,
      );

  // ── 查询面 ──────────────────────────────────────────────────────────

  Stream<List<Track>> watchTracks({TrackSort sort = TrackSort.recentAdded}) =>
      _tracksQuery(sort).watch().map((rows) => rows.map(_map).toList());

  /// 曲目列表一次性取用（不开常驻 watch 流——随缘听歌取材等只读一次）。
  Future<List<Track>> getTracks({TrackSort sort = TrackSort.recentAdded}) =>
      _tracksQuery(sort).get().then((rows) => rows.map(_map).toList());

  SimpleSelectStatement<Tracks, TrackRow> _tracksQuery(TrackSort sort) {
    final q = select(tracks);
    switch (sort) {
      case TrackSort.title:
        q.orderBy([(u) => OrderingTerm.asc(u.titleNorm)]);
      case TrackSort.artist:
        q.orderBy([(u) => OrderingTerm.asc(u.artistNorm), (u) => OrderingTerm.asc(u.titleNorm)]);
      case TrackSort.album:
        q.orderBy([
          (u) => OrderingTerm.asc(u.albumNorm),
          (u) => OrderingTerm.asc(u.trackNo),
          (u) => OrderingTerm.asc(u.titleNorm),
        ]);
      case TrackSort.recentAdded:
        q.orderBy([(u) => OrderingTerm.desc(u.addedAt)]);
    }
    return q;
  }

  Future<Track?> trackById(int id) async {
    final row = await (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  /// 会话恢复用：按绝对路径批量取曲目（保序）。
  Future<List<Track>> tracksByPaths(List<String> paths) async {
    if (paths.isEmpty) {
      return const <Track>[];
    }
    final rows = await (select(tracks)..where((t) => t.path.isIn(paths))).get();
    final byPath = {for (final r in rows) r.path: _map(r)};
    return [for (final p in paths) if (byPath[p] != null) byPath[p]!];
  }

  /// 全库可用曲目（非缺失），供随机/全部播放取材。
  Future<List<Track>> availableTracks() async {
    final rows = await (select(tracks)..where((t) => t.missingAt.isNull())).get();
    return rows.map(_map).toList();
  }

  Stream<int> watchAvailableCount() {
    final count = tracks.id.count();
    final q = selectOnly(tracks)..addColumns([count])..where(tracks.missingAt.isNull());
    return q.watchSingle().map((r) => r.read(count) ?? 0);
  }

  // ── 聚合面 ──────────────────────────────────────────────────────────

  Stream<List<AlbumGroup>> watchAlbums() {
    final album = tracks.album;
    final artist = tracks.artist;
    final albumNorm = tracks.albumNorm;
    final cnt = tracks.id.count();
    final dur = tracks.durationMs.sum();
    final q = selectOnly(tracks)
      ..addColumns([album, artist, albumNorm, cnt, dur])
      ..where(tracks.missingAt.isNull())
      ..groupBy([albumNorm])
      ..orderBy([OrderingTerm.asc(albumNorm)]);
    return q.watch().map(
          (rows) => rows
              .map((r) => AlbumGroup(
                    album: r.read(album) ?? '',
                    artist: r.read(artist) ?? '',
                    trackCount: r.read(cnt) ?? 0,
                    totalDurationMs: r.read(dur) ?? 0,
                  ))
              .toList(),
        );
  }

  Stream<List<Track>> watchAlbumTracks(String albumNorm) {
    return (select(tracks)
          ..where((t) => t.albumNorm.equals(albumNorm) & t.missingAt.isNull())
          ..orderBy([
            (u) => OrderingTerm.asc(u.trackNo),
            (u) => OrderingTerm.asc(u.titleNorm),
          ]))
        .watch()
        .map((rows) => rows.map(_map).toList());
  }

  Stream<List<ArtistGroup>> watchArtists() {
    final artist = tracks.artist;
    final artistNorm = tracks.artistNorm;
    final cnt = tracks.id.count();
    final q = selectOnly(tracks)
      ..addColumns([artist, artistNorm, cnt])
      ..where(tracks.missingAt.isNull())
      ..groupBy([artistNorm])
      ..orderBy([OrderingTerm.asc(artistNorm)]);
    return q.watch().map(
          (rows) => rows
              .map((r) => ArtistGroup(
                    artist: r.read(artist) ?? '',
                    trackCount: r.read(cnt) ?? 0,
                  ))
              .toList(),
        );
  }

  Stream<List<Track>> watchArtistTracks(String artistNorm) {
    return (select(tracks)
          ..where((t) => t.artistNorm.equals(artistNorm) & t.missingAt.isNull())
          ..orderBy([
            (u) => OrderingTerm.asc(u.albumNorm),
            (u) => OrderingTerm.asc(u.trackNo),
          ]))
        .watch()
        .map((rows) => rows.map(_map).toList());
  }

  /// 专辑首曲（磁贴封面用；单行 LIMIT 查询，替代 watch 全列表取 first——
  /// 每个磁贴开一条整表 watch 是滚动卡顿与流噪音的来源）。
  Future<Track?> albumFirstTrack(String albumNorm) {
    return (select(tracks)
          ..where((t) => t.albumNorm.equals(albumNorm) & t.missingAt.isNull())
          ..orderBy([
            (u) => OrderingTerm.asc(u.trackNo),
            (u) => OrderingTerm.asc(u.titleNorm),
          ])
          ..limit(1))
        .get()
        .then((rows) => rows.isEmpty ? null : _map(rows.first));
  }

  // ── 流派面（真实标签解析；空流派不参与聚合） ─────────────────────────

  /// 流派列表（按专辑数排序；genre 为空的行不入组）。
  Stream<List<GenreGroup>> watchGenres() {
    final genre = tracks.genre;
    final albumNorm = tracks.albumNorm;
    final cnt = albumNorm.count(distinct: true);
    final q = selectOnly(tracks)
      ..addColumns([genre, cnt])
      ..where(tracks.missingAt.isNull() & tracks.genre.equals('').not())
      ..groupBy([genre])
      ..orderBy([OrderingTerm.desc(cnt)]);
    return q.watch().map(
          (rows) => rows
              .map((r) => GenreGroup(
                    genre: r.read(genre) ?? '',
                    albumCount: r.read(cnt) ?? 0,
                  ))
              .toList(),
        );
  }

  /// 某流派的专辑聚合（组内取该流派的曲目行参与分组）。
  Stream<List<AlbumGroup>> watchGenreAlbums(String genre) {
    final album = tracks.album;
    final artist = tracks.artist;
    final albumNorm = tracks.albumNorm;
    final cnt = tracks.id.count();
    final dur = tracks.durationMs.sum();
    final q = selectOnly(tracks)
      ..addColumns([album, artist, albumNorm, cnt, dur])
      ..where(tracks.missingAt.isNull() & tracks.genre.equals(genre))
      ..groupBy([albumNorm])
      ..orderBy([OrderingTerm.asc(albumNorm)]);
    return q.watch().map(
          (rows) => rows
              .map((r) => AlbumGroup(
                    album: r.read(album) ?? '',
                    artist: r.read(artist) ?? '',
                    trackCount: r.read(cnt) ?? 0,
                    totalDurationMs: r.read(dur) ?? 0,
                  ))
              .toList(),
        );
  }

  // ── 常听面（直读 tracks.plays 物化计数；不再聚合 play_history） ─────

  /// 常听专辑（按累计播放次数排序；未播过的不出现）。
  ///
  /// plays 已在 record 时物化递增（v5），此查询只扫 tracks 单表——
  /// 每次播放不再触发 tracks×play_history 全表 GROUP BY。
  Stream<List<AlbumGroup>> watchTopAlbums({int limit = 12}) {
    final album = tracks.album;
    final artist = tracks.artist;
    final albumNorm = tracks.albumNorm;
    final cnt = tracks.id.count();
    final dur = tracks.durationMs.sum();
    final plays = tracks.plays.sum();
    final query = selectOnly(tracks)
      ..addColumns([album, artist, albumNorm, cnt, dur, plays])
      ..where(tracks.missingAt.isNull() & tracks.plays.isBiggerThanValue(0))
      ..groupBy([albumNorm])
      ..orderBy([OrderingTerm.desc(plays)])
      ..limit(limit);
    return query.watch().map(
          (rows) => rows
              .map((r) => AlbumGroup(
                    album: r.read(album) ?? '',
                    artist: r.read(artist) ?? '',
                    trackCount: r.read(cnt) ?? 0,
                    totalDurationMs: r.read(dur) ?? 0,
                  ))
              .toList(),
        );
  }

  /// 常听单曲（按累计播放次数排序；未播过的不出现）。
  ///
  /// 单曲粒度：无专辑元数据的收集曲不会被折叠进同一个「未知专辑」磁贴，
  /// 「常听与历史」页因此总能如实反映播放次数。
  /// 常听单曲一次性取用（听法取材只读一次，不开常驻 watch 流）。
  Future<List<TrackPlays>> getTopTracks({int limit = 12}) =>
      _topTracksQuery(limit).get().then((rows) => [
            for (final r in rows)
              TrackPlays(track: _map(r), plays: r.plays),
          ]);

  Stream<List<TrackPlays>> watchTopTracks({int limit = 12}) =>
      _topTracksQuery(limit).watch().map((rows) => [
            for (final r in rows)
              TrackPlays(track: _map(r), plays: r.plays),
          ]);

  SimpleSelectStatement<Tracks, TrackRow> _topTracksQuery(int limit) {
    return select(tracks)
      ..where((t) =>
          t.missingAt.isNull() & t.plays.isBiggerThanValue(0))
      ..orderBy([(u) => OrderingTerm.desc(u.plays)])
      ..limit(limit);
  }

  // ── 删除面（曲库内移除一首；文件删除由调用方处理） ────────────────────

  /// 彻底移除一首曲目：FTS / 歌单条目 / 播放历史 / 歌词元数据 / 主行。
  /// 外键已开启（beforeOpen PRAGMA），先清引用行再删主行。
  Future<void> purgeTrack(int id) {
    return transaction(() async {
      await _deleteFts(id);
      await (delete(playlistTracks)..where((pt) => pt.trackId.equals(id))).go();
      await (delete(playHistory)..where((h) => h.trackId.equals(id))).go();
      await (delete(lyricsMeta)..where((m) => m.trackId.equals(id))).go();
      await (delete(tracks)..where((t) => t.id.equals(id))).go();
    });
  }

  // ── 元数据补全面（反向重建：时长锚定 + 在线匹配） ────────────────────

  /// 待补全曲目（needsMeta 未处理；连续硬失败 ≥3 次的暂出池），最旧优先。
  /// 一次性取用版：补全轮次只读一次，不开常驻 watch 流。
  Future<List<Track>> needsEnrichment({int limit = 25}) =>
      _needsEnrichmentQuery(limit).get().then((rows) => rows.map(_map).toList());

  Stream<List<Track>> watchNeedsEnrichment({int limit = 25}) =>
      _needsEnrichmentQuery(limit).watch().map((rows) => rows.map(_map).toList());

  SimpleSelectStatement<Tracks, TrackRow> _needsEnrichmentQuery(int limit) {
    return select(tracks)
      ..where((t) =>
          t.needsMeta &
          t.missingAt.isNull() &
          t.enrichedAt.isNull() &
          t.enrichAttempts.isSmallerThanValue(3))
      ..orderBy([(u) => OrderingTerm.asc(u.addedAt)])
      ..limit(limit);
  }

  /// 待补全数量（补全进度条的总数；暂出池的耗尽行不计）。
  Future<int> countNeedsEnrichment() {
    final cnt = countAll();
    final query = selectOnly(tracks)
      ..addColumns([cnt])
      ..where(tracks.needsMeta &
          tracks.missingAt.isNull() &
          tracks.enrichedAt.isNull() &
          tracks.enrichAttempts.isSmallerThanValue(3));
    return query.map((row) => row.read(cnt) ?? 0).getSingle();
  }

  /// 补全写回：歌名/歌手 + [album]/[trackNo]（有值才采纳——AcoustID
  /// releases 是唯一来源，文字链无源传 null 保持原值）+ 补全时刻。
  /// 同步打满五个阶段时刻——结论性进度（匹配成功或确认无匹配都算已处理），
  /// 阶段进度条据此直读。显示列存原文，norm 列另算（normKey 曾误写显示列
  /// ——补全采纳的歌名全小写）。
  Future<void> applyEnrichment({
    required int id,
    required String title,
    required String artist,
    String? album,
    int? trackNo,
  }) {
    final now = DateTime.now();
    return (update(tracks)..where((t) => t.id.equals(id))).write(
      TracksCompanion(
        title: Value(title),
        titleNorm: Value(normKey(title)),
        artist: Value(artist),
        artistNorm: Value(normKey(artist)),
        album: album == null ? const Value.absent() : Value(album),
        albumNorm:
            album == null ? const Value.absent() : Value(normKey(album)),
        trackNo: trackNo == null ? const Value.absent() : Value(trackNo),
        needsMeta: const Value(false),
        enrichedAt: Value(now),
        titleMatchedAt: Value(now),
        artistMatchedAt: Value(now),
        lyricsAt: Value(now),
        albumMatchedAt: Value(now),
        trackMatchedAt: Value(now),
        enrichAttempts: const Value(0),
      ),
    );
  }

  /// 用户手动编辑曲目元数据（编辑歌曲信息页保存）。单事务：
  /// 显示字段存原文（norm 列另行规整）+ FTS 行整行重建（含拼音双列）+
  /// needsMeta 清位——用户编辑即结论，补全管道不再回写覆盖。
  ///
  /// 与重扫的关系：扫描只在文件 size 变化时重解析（scan_service diff），
  /// 应用内编辑不动音频文件 → 编辑跨重扫保留；文件被外部改动才按 tag
  /// 重新导入（导入语义，非缺陷）。
  Future<void> editTrackMeta({
    required int id,
    required String title,
    required String artist,
    required String album,
    required String genre,
    required int trackNo,
  }) {
    final now = DateTime.now();
    return transaction(() async {
      await (update(tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(
          title: Value(title),
          titleNorm: Value(normKey(title)),
          artist: Value(artist),
          artistNorm: Value(normKey(artist)),
          album: Value(album),
          albumNorm: Value(normKey(album)),
          genre: Value(genre),
          trackNo: Value(trackNo),
          needsMeta: const Value(false),
          enrichedAt: Value(now),
          titleMatchedAt: Value(now),
          artistMatchedAt: Value(now),
          albumMatchedAt: Value(now),
          trackMatchedAt: Value(now),
        ),
      );
      await _deleteFts(id);
      // 拼音列按字段分别生成（粘连 token 不得跨字段，与 upsertScannedBatch 同规）
      final py = [
        pinyinFull(title),
        pinyinFull(artist),
        pinyinFull(album),
      ].where((s) => s.isNotEmpty).join(' ');
      final pyHead = [
        pinyinInitials(title),
        pinyinInitials(artist),
        pinyinInitials(album),
      ].where((s) => s.isNotEmpty).join(' ');
      await customInsert(
        'INSERT INTO track_index(track_id, title, artist, album, pinyin_full, pinyin_initials) '
        'VALUES(?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withInt(id),
          Variable.withString(ftsText(title)),
          Variable.withString(ftsText(artist)),
          Variable.withString(ftsText(album)),
          Variable.withString(py),
          Variable.withString(pyHead),
        ],
      );
    });
  }

  /// 硬失败记账（网络不可用/文件不可读）：阶段时刻不打，计数 +1，
  /// ≥3 次暂出待补全池，避免同一批失败件原地打转。
  /// customStatement 自增不会触发 stream 刷新——补手动 notifyUpdates，
  /// 否则「歌曲处理」页的失败计数滞后到下一次表写入才更新。
  Future<void> bumpEnrichAttempts(int id) async {
    await customStatement(
        'UPDATE tracks SET enrich_attempts = enrich_attempts + 1 WHERE id = ?',
        [id]);
    notifyUpdates({TableUpdate.onTable(tracks)});
  }

  /// 手动「开始补全」清零失败计数（耗尽行重新获得重试机会）。
  /// 同 bumpEnrichAttempts——customStatement 后补手动 stream 通知。
  Future<void> resetEnrichAttempts() async {
    await customStatement(
        'UPDATE tracks SET enrich_attempts = 0 WHERE enrich_attempts >= 3');
    notifyUpdates({TableUpdate.onTable(tracks)});
  }

  /// 补全阶段进度（歌曲处理页四行进度条的数据面；全部直读 tracks 表，跨重启不丢）：
  /// * 歌名：已结论（titleMatchedAt） vs 总盘（已结论 + 待处理 needsMeta）；
  /// * 歌词：拿到词（lyrics_meta 有记账） + 确认无词（已结论无产出） vs
  ///   总盘（已结论 + needsMeta 未处理）；
  /// * 封面：已有封面（coverPath 非空） vs 全部存活曲目——封面链按需决议
  ///   （内嵌/同名图/在线，看歌时才解析），无批处理管道，失败恒 0；
  /// * 歌手：已结论（artistMatchedAt） vs 总盘（已结论 + needsMeta 且歌手空）。
  /// 耗尽行（连续失败 ≥3）不计入待处理——总盘随之收缩，进度条可走满。
  Stream<List<EnrichStage>> watchEnrichStages() {
    final alive = tracks.missingAt.isNull();
    // 失败桶：有过硬失败记录且尚未结论的行——失败即时可见，不等耗尽
    final failedPool = tracks.needsMeta.equals(true) &
        tracks.enrichAttempts.isBiggerOrEqualValue(1) &
        alive;
    // 歌名
    final titleDone =
        tracks.id.count(filter: alive & tracks.titleMatchedAt.isNotNull());
    final titleFailed =
        tracks.id.count(filter: failedPool & tracks.titleMatchedAt.isNull());
    final titleTotal = tracks.id.count(
        filter: alive &
            (tracks.titleMatchedAt.isNotNull() | tracks.needsMeta.equals(true)));
    // 歌词：成功口径=有词（lyrics_meta 记账行；kind='none' 的偏移孤儿行不算），
    // 无词=补全已结论（lyricsAt）但无记账——lyricsAt 曾全计入「成功」，绿灯虚高。
    // LEFT JOIN 按 trackId 主键 1:1，不放大其余计数。
    final lyricsHas = lyricsMeta.trackId.count(
        filter: alive &
            lyricsMeta.kind
                .isIn(const ['sidecar', 'embedded', 'online', 'pasted']));
    final lyricsMissed = tracks.id.count(
        filter: alive &
            tracks.lyricsAt.isNotNull() &
            (lyricsMeta.trackId.isNull() | lyricsMeta.kind.equals('none')));
    final lyricsFailed =
        tracks.id.count(filter: failedPool & tracks.lyricsAt.isNull());
    final lyricsTotal = tracks.id.count(
        filter: alive &
            (tracks.lyricsAt.isNotNull() | tracks.needsMeta.equals(true)));
    // 封面（覆盖面：已有封面 vs 全部存活曲目；决议是按需的，失败不记账）
    final coverTotal = tracks.id.count(filter: alive);
    final coverDone =
        tracks.id.count(filter: alive & tracks.coverPath.isNotNull());
    // 歌手
    final artistDone =
        tracks.id.count(filter: alive & tracks.artistMatchedAt.isNotNull());
    final artistFailed = tracks.id.count(
        filter: failedPool &
            tracks.artist.equals('') &
            tracks.artistMatchedAt.isNull());
    final artistTotal = tracks.id.count(
        filter: alive &
            (tracks.artistMatchedAt.isNotNull() |
                (tracks.needsMeta.equals(true) & tracks.artist.equals(''))));
    // 专辑/音轨：来源只有 AcoustID releases（文字链无源）——done=已结论
    // 且有值；missed=已结论确认无（合辑/平台源无专辑信息，灰档不算成功，
    // 与歌词行同口径）；total=已结论 + needsMeta 待处理（needsMeta=false
    // 的局部标签件不入自动补全盘，缺失走手动编辑）。
    final albumDone = tracks.id.count(
        filter: alive &
            tracks.albumMatchedAt.isNotNull() &
            tracks.album.equals('').not());
    final albumMissed = tracks.id.count(
        filter:
            alive & tracks.albumMatchedAt.isNotNull() & tracks.album.equals(''));
    final albumFailed = tracks.id.count(
        filter: failedPool & tracks.albumMatchedAt.isNull());
    final albumTotal = tracks.id.count(
        filter: alive &
            (tracks.albumMatchedAt.isNotNull() | tracks.needsMeta.equals(true)));
    final trackDone = tracks.id.count(
        filter: alive &
            tracks.trackMatchedAt.isNotNull() &
            tracks.trackNo.isBiggerThanValue(0));
    final trackMissed = tracks.id.count(
        filter: alive &
            tracks.trackMatchedAt.isNotNull() &
            tracks.trackNo.isBiggerThanValue(0).not());
    final trackFailed = tracks.id.count(
        filter: failedPool & tracks.trackMatchedAt.isNull());
    final trackTotal = tracks.id.count(
        filter: alive &
            (tracks.trackMatchedAt.isNotNull() | tracks.needsMeta.equals(true)));
    // 向量：done=已有当前模型向量（join 行 vectorAt 非空）；failed=有硬失败
    // 记账且尚无向量；total=全部存活（向量独立于元数据结论，全集都要算）。
    final vectorDone =
        tracks.id.count(filter: alive & trackVectors.vectorAt.isNotNull());
    final vectorFailed = tracks.id.count(
        filter: alive &
            trackVectors.trackId.isNull() &
            tracks.enrichAttempts.isBiggerOrEqualValue(1));
    final vectorTotal = tracks.id.count(filter: alive);
    final q = selectOnly(tracks)
      ..join([
        leftOuterJoin(lyricsMeta, lyricsMeta.trackId.equalsExp(tracks.id)),
        // 按 (track_id, model) 过滤的 1:1 join——无当前模型向量的行
        // trackVectors.trackId 为 null，即「未算」。
        leftOuterJoin(
            trackVectors,
            trackVectors.trackId.equalsExp(tracks.id) &
                trackVectors.model.equals(kEmbeddingModel)),
      ])
      ..addColumns([
        titleDone, titleFailed, titleTotal,
        lyricsHas, lyricsMissed, lyricsFailed, lyricsTotal,
        coverDone, coverTotal,
        artistDone, artistFailed, artistTotal,
        albumDone, albumMissed, albumFailed, albumTotal,
        trackDone, trackMissed, trackFailed, trackTotal,
        vectorDone, vectorFailed, vectorTotal,
      ]);
    return q.watch().map((rows) {
      final r = rows.isEmpty ? null : rows.first;
      int read(Expression<int> e) => r == null ? 0 : (r.read(e) ?? 0);
      return [
        EnrichStage('歌名', read(titleDone), read(titleFailed),
            read(titleTotal)),
        EnrichStage('歌词', read(lyricsHas), read(lyricsFailed),
            read(lyricsTotal), read(lyricsMissed)),
        EnrichStage('封面', read(coverDone), 0, read(coverTotal)),
        EnrichStage('歌手', read(artistDone), read(artistFailed),
            read(artistTotal)),
        EnrichStage('专辑', read(albumDone), read(albumFailed),
            read(albumTotal), read(albumMissed)),
        EnrichStage('音轨', read(trackDone), read(trackFailed),
            read(trackTotal), read(trackMissed)),
        EnrichStage('向量', read(vectorDone), read(vectorFailed),
            read(vectorTotal)),
      ];
    });
  }

  // ── 搜索面（FTS 五列前缀 AND；rank 排序） ────────────────────────────

  Stream<List<Track>> watchSearchResults(String query) {
    final match = buildFtsMatch(query);
    if (match.isEmpty) {
      return Stream.value(const <Track>[]);
    }
    return customSelect(
      'SELECT t.id AS t_id, t.root_id, t.rel_path, t.path, t.title, t.artist, '
      't.album, t.genre, t.duration_ms, t.size_bytes, t.content_hash, t.audio_format, '
      't.track_no, t.cover_path, t.added_at, t.missing_at '
      'FROM track_index f JOIN tracks t ON t.id = f.track_id '
      'WHERE track_index MATCH ? AND t.missing_at IS NULL '
      'ORDER BY rank LIMIT 200',
      variables: [Variable(match)],
      readsFrom: {tracks},
    ).watch().map((rows) {
      return rows
          .map((r) => Track(
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
              ))
          .toList();
    });
  }

  // ── 扫描写入原语 ────────────────────────────────────────────────────

  Stream<List<RepositoryRoot>> watchRoots() => select(repositoryRoots).watch();

  Future<List<RepositoryRoot>> allRoots() => select(repositoryRoots).get();

  Future<int> addRoot(String path) =>
      into(repositoryRoots).insert(RepositoryRootsCompanion.insert(path: path));

  Future<void> removeRoot(int rootId) {
    return transaction(() async {
      final ids = await (select(tracks)..where((t) => t.rootId.equals(rootId)))
          .map((r) => r.id)
          .get();
      for (final id in ids) {
        await _deleteFts(id);
      }
      await (delete(tracks)..where((t) => t.rootId.equals(rootId))).go();
      await (delete(repositoryRoots)..where((r) => r.id.equals(rootId))).go();
    });
  }

  /// 某根目录下已入库的 (relPath, sizeBytes, hash, missingAt, id) 供 diff。
  Future<List<ScannedExisting>> existingForRoot(int rootId) async {
    final rows = await (select(tracks)..where((t) => t.rootId.equals(rootId))).get();
    return rows
        .map((r) => ScannedExisting(
              id: r.id,
              relPath: r.relPath,
              sizeBytes: r.sizeBytes,
              contentHash: r.contentHash,
              missing: r.missingAt != null,
            ))
        .toList();
  }

  /// 批量落库（≤200 一事务）：tracks upsert + FTS 同事务增删。
  Future<void> upsertScannedBatch(List<TrackUpsert> batch) {
    return transaction(() async {
      for (final u in batch) {
        final companion = TracksCompanion.insert(
          rootId: u.rootId,
          relPath: u.relPath,
          path: u.path,
          title: u.title,
          titleNorm: normKey(u.title),
          artist: u.artist,
          artistNorm: normKey(u.artist),
          album: u.album,
          albumNorm: normKey(u.album),
          genre: Value(u.genre),
          needsMeta: Value(u.needsMeta),
          trackNo: Value(u.trackNo),
          durationMs: Value(u.durationMs),
          sizeBytes: Value(u.sizeBytes),
          contentHash: Value(u.contentHash),
          audioFormat: Value(u.audioFormat),
        );
        final id = await into(tracks).insert(
          companion,
          onConflict: DoUpdate((_) => companion, target: [tracks.path]),
        );
        await _deleteFts(id);
        // 拼音列按字段分别生成（粘连 token 不得跨字段，否则歌手整串前缀无法命中）
        final py = [
          pinyinFull(u.title),
          pinyinFull(u.artist),
          pinyinFull(u.album),
        ].where((s) => s.isNotEmpty).join(' ');
        final pyHead = [
          pinyinInitials(u.title),
          pinyinInitials(u.artist),
          pinyinInitials(u.album),
        ].where((s) => s.isNotEmpty).join(' ');
        await customInsert(
          'INSERT INTO track_index(track_id, title, artist, album, pinyin_full, pinyin_initials) '
          'VALUES(?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withInt(id),
            Variable.withString(ftsText(u.title)),
            Variable.withString(ftsText(u.artist)),
            Variable.withString(ftsText(u.album)),
            Variable.withString(py),
            Variable.withString(pyHead),
          ],
        );
      }
    });
  }

  /// 标记缺失（诚实灰显；不删除行）。
  Future<void> markMissing(List<int> ids) {
    if (ids.isEmpty) {
      return Future.value();
    }
    return (update(tracks)..where((t) => t.id.isIn(ids) & t.missingAt.isNull()))
        .write(TracksCompanion(missingAt: Value(DateTime.now())));
  }

  /// 复活（文件回来了）。
  Future<void> revive(List<int> ids) {
    if (ids.isEmpty) {
      return Future.value();
    }
    return (update(tracks)..where((t) => t.id.isIn(ids)))
        .write(const TracksCompanion(missingAt: Value(null)));
  }

  Future<void> updateCover(int trackId, String? coverPath) {
    return (update(tracks)..where((t) => t.id.equals(trackId))).write(
      TracksCompanion(coverPath: Value(coverPath), coverCheckedAt: Value(DateTime.now())),
    );
  }

  Future<void> _deleteFts(int trackId) => customUpdate(
        'DELETE FROM track_index WHERE track_id = ?',
        variables: [Variable.withInt(trackId)],
      );
}

/// 扫描 diff 用的已入库行快照。
class ScannedExisting {
  const ScannedExisting({
    required this.id,
    required this.relPath,
    required this.sizeBytes,
    required this.contentHash,
    required this.missing,
  });

  final int id;
  final String relPath;
  final int sizeBytes;
  final String contentHash;
  final bool missing;
}

/// 扫描批写入载荷（service 组装，DAO 只落库）。
class TrackUpsert {
  const TrackUpsert({
    required this.rootId,
    required this.relPath,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.needsMeta,
    required this.trackNo,
    required this.durationMs,
    required this.sizeBytes,
    required this.contentHash,
    required this.audioFormat,
  });

  final int rootId;
  final String relPath;
  final String path;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final bool needsMeta;
  final int trackNo;
  final int durationMs;
  final int sizeBytes;
  final String contentHash;
  final String audioFormat;
}
