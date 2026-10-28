/// S1 DAO 门面（DETAILED-DESIGN §1.3 九组查询 + DEC-009 数据裁决的写路径）。
///
/// 纪律：
/// * FTS 写与 tracks 写**同事务**（D9-1）：`insertTrackWithIndex` / rebuild 调用点。
/// * 随机池=SQL 粗筛 + 内存采样（D9-2）；排除 deleted/missing/few_watch。
/// * play_history 淘汰=应用层批次（D9-3，100/批事务）。
/// * 物理删除仅 playlist_tracks/少播/淘汰/临时缓存（红线：业务记录一律软删）。
/// * 墓碑由 SyncEngine 域补写（S6）；本层提供登记/查询原语（**仅传播记录，无云端删除语义**）。
/// * 枚举匹配统一走 `.equals(...name)`（DB 值=名字字符串）。
library;

import 'dart:math';

import 'package:drift/drift.dart';
import 'package:pinyin/pinyin.dart';

import 'ia_database.dart';
import 'tables.dart';

// ── 曲库域：搜索 / 排序 / 随机池 / 扫描 diff / dup ───────────────

/// 曲库排序键（REQ-LIB-06：title/added_at/duration 临排，1 万行仅分页）。
enum LibrarySort { title, addedAt, duration }

/// 可选字段 → Companion 包装（absent=不写入该列；写入显式 Value）。
Value<T> opt<T>(T? v) => v == null ? Value<T>.absent() : Value<T>(v);

// ── 曲库域辅助（扫描层用）────────────────────────────────

/// 曲库浏览排序（REQ-LIB-06：最近/标题/歌手/时长）。
enum LibSort { recent, title, artist, duration }

/// 文本归一名（artists/albums 唯一锚 name_norm）：
/// trim → 压缩连续空白为单空格 → ASCII 小写（CJK 不受影响）。
String normalizeName(String raw) {
  final t = raw.trim();
  if (t.isEmpty) {
    return t;
  }
  return t.split(RegExp(r'\s+')).join(' ').toLowerCase();
}

/// 扫描批插请求（一次 flush ≤200 条=§3.1 批 200/事务）。
class ScannedTrackInput {
  const ScannedTrackInput({
    required this.rootId,
    required this.relPath,
    required this.mtime,
    required this.fileSize,
    required this.contentHash,
    required this.nowMs,
    this.title,
    this.artistDisplay,
    this.albumDisplay,
    this.durationMs,
    this.format = AudioFormatSpec.mp3,
    this.sampleRate,
    this.channels,
  });

  final int rootId;
  final String relPath;
  final int mtime;
  final int fileSize;
  final String contentHash;
  final int nowMs;
  final String? title;
  final String? artistDisplay;
  final String? albumDisplay;
  final int? durationMs;
  final AudioFormatSpec format;
  final int? sampleRate;
  final int? channels;
}

class LibraryDao {
  LibraryDao(this._db);

  final IaDatabase _db;

  // ① 全局搜索（REQ-NAV-04）：FTS 汉字前缀 + 拼音全拼/首字母；排除软删/缺失。
  Future<List<Track>> search(String query, {int limit = 50}) async {
    final match = matchFor(query);
    if (match == null) {
      return const [];
    }
    final rows = await _db
        .customSelect(
          'SELECT rowid AS rid FROM tracks_fts WHERE tracks_fts MATCH ? LIMIT ?',
          variables: [Variable.withString(match), Variable.withInt(limit)],
        )
        .get();
    final rids = rows.map((r) => r.read<int>('rid')).toList();
    if (rids.isEmpty) {
      return const [];
    }
    final found = await (_db.select(_db.tracks)
          ..where((t) =>
              t.id.isIn(rids) & t.deletedAt.isNull() & t.missingAt.isNull()))
        .get();
    final byId = {for (final t in found) t.id: t};
    return [for (final id in rids) if (byId[id] != null) byId[id]!];
  }

  /// FTS MATCH 构造：每个词 → 五列前缀（title/artist/album/pinyin_full/initials）。
  ///
  /// 清洗：剔除 FTS 语法字符（":*-^()|）后用**裸词**（FTS5 引号短语+`*` 不支持，
  /// 已实测零命中——schema 测试的裸词写法验证过）；ASCII 统一小写；全空 → null。
  String? matchFor(String query) {
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'["\:\*\-\^\(\)\|]'), '').toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) {
      return null;
    }
    const fields = ['title', 'artist', 'album', 'pinyin_full', 'pinyin_initials'];
    return terms.map((t) => '(${fields.map((f) => '$f:$t*').join(' OR ')})').join(' AND ');
  }

  /// 拼音（由 pinyin 包生成；未知字符保留原文小写）。
  String buildFullPinyin(String text) {
    final parts = text.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return parts.map((p) {
      try {
        return PinyinHelper.getPinyin(p, separator: ' ');
      } on PinyinException {
        return p.toLowerCase();
      }
    }).join(' ');
  }

  // ② 曲库浏览分页（REQ-LIB-02/06）：排除软删；缺失行保留（UI 缺失徽章）。
  Future<List<Track>> browse({
    LibrarySort sort = LibrarySort.title,
    int page = 0,
    int pageSize = 100,
  }) {
    return (_db.select(_db.tracks)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => switch (sort) {
                  LibrarySort.title => OrderingTerm.asc(t.title),
                  LibrarySort.addedAt => OrderingTerm.desc(t.addedAt),
                  LibrarySort.duration => OrderingTerm.asc(t.durationMs),
                }
          ])
          ..limit(pageSize, offset: page * pageSize))
        .get();
  }

  // ③ 随机池（REQ-NAV-02/PLAY-03；D9-2）：SQL 粗筛 + 内存采样（Fisher-Yates）。
  ///
  /// 排除：deleted_at 非空 / missing_at 非空 / 少播名单（NOT IN few_watch）。
  /// `includeFewWatch`=全库补满口径（NAV §3.5 规 1：池 <10 时含少播曲重采样，
  /// 仍须 playable 双 NULL 口径）；默认 false=严格随机池（S3 播放域消费）。
  Future<List<Track>> randomPool({
    int sampleSize = 50,
    int candidateCap = 1000,
    bool includeFewWatch = false,
  }) async {
    final fewNot = includeFewWatch
        ? ''
        : 'AND id NOT IN (SELECT track_id FROM few_watch_list)';
    final idRows = await _db
        .customSelect(
          'SELECT id FROM tracks WHERE deleted_at IS NULL AND missing_at IS NULL '
          '$fewNot LIMIT ?',
          variables: [Variable.withInt(candidateCap)],
        )
        .get();
    final ids = [for (final r in idRows) r.read<int>('id')];
    if (ids.isEmpty) {
      return const [];
    }
    final picks = ids.toList()..shuffle(Random());
    if (picks.length > sampleSize) {
      picks.removeRange(sampleSize, picks.length);
    }
    final found = await (_db.select(_db.tracks)..where((t) => t.id.isIn(picks))).get();
    final byId = {for (final t in found) t.id: t};
    return [for (final id in picks) if (byId[id] != null) byId[id]!];
  }

  // ⑦ 扫描 diff（REQ-LIB-02）原语 ──────────────────────────

  Future<Track?> findByRelPath(int rootId, String relPath) {
    return (_db.select(_db.tracks)
          ..where((t) => t.rootId.equals(rootId) & t.relPath.equals(relPath)))
        .getSingleOrNull();
  }

  /// 新曲入库（含 FTS **同事务**；D9-1）。源字段由提取域登记时单独补（REQ-EXT-03）。
  Future<int> insertTrackWithIndex(
    int rootId,
    String relPath, {
    required int mtime,
    required int fileSize,
    required String contentHash,
    required int nowMs,
    String? title,
    String? artistDisplay,
    String? albumDisplay,
    int? durationMs,
    AudioFormatSpec format = AudioFormatSpec.mp3,
    String? sourceType,
    String? sourceId,
    int? sampleRate,
    int? channels,
    int? artistId,
    int? albumId,
  }) =>
      _db.transaction(() => insertTrackCore(
            rootId,
            relPath,
            mtime: mtime,
            fileSize: fileSize,
            contentHash: contentHash,
            nowMs: nowMs,
            title: title,
            artistDisplay: artistDisplay,
            albumDisplay: albumDisplay,
            durationMs: durationMs,
            format: format,
            sourceType: sourceType,
            sourceId: sourceId,
            sampleRate: sampleRate,
            channels: channels,
            artistId: artistId,
            albumId: albumId,
          ));

  /// 插入核心（**不自带事务**——调用方负责包裹；FTS 与 tracks 写同事务=D9-1）。
  Future<int> insertTrackCore(
    int rootId,
    String relPath, {
    required int mtime,
    required int fileSize,
    required String contentHash,
    required int nowMs,
    String? title,
    String? artistDisplay,
    String? albumDisplay,
    int? durationMs,
    AudioFormatSpec format = AudioFormatSpec.mp3,
    String? sourceType,
    String? sourceId,
    int? sampleRate,
    int? channels,
    int? artistId,
    int? albumId,
  }) async {
    final id = await _db.into(_db.tracks).insert(TracksCompanion.insert(
          rootId: rootId,
          relPath: relPath,
          title: Value(title),
          artistDisplay: Value(artistDisplay),
          albumDisplay: Value(albumDisplay),
          durationMs: Value(durationMs),
          audioFormat: format,
          fileSize: fileSize,
          mtime: mtime,
          contentHash: contentHash,
          addedAt: nowMs,
          updatedAt: nowMs,
          sourceType: Value(sourceType),
          sourceId: Value(sourceId),
          sampleRate: Value(sampleRate),
          channels: Value(channels),
          artistId: Value(artistId),
          albumId: Value(albumId),
        ));
    await _db.updateTrackIndex(
      id,
      title: title ?? '',
      artist: artistDisplay ?? '',
      album: albumDisplay ?? '',
    );
    return id;
  }

  /// 批插（§3.1 批 200/事务）：字典 upsert + insert 核心 + FTS，**同一批事务**。
  Future<List<int>> insertTrackBatch(List<ScannedTrackInput> items) {
    return _db.transaction(() async {
      final ids = <int>[];
      for (final it in items) {
        final artistId = await _upsertArtist(it.artistDisplay, nowMs: it.nowMs);
        final albumId = await _upsertAlbum(it.albumDisplay, nowMs: it.nowMs);
        ids.add(await insertTrackCore(
          it.rootId,
          it.relPath,
          mtime: it.mtime,
          fileSize: it.fileSize,
          contentHash: it.contentHash,
          nowMs: it.nowMs,
          title: it.title,
          artistDisplay: it.artistDisplay,
          albumDisplay: it.albumDisplay,
          durationMs: it.durationMs,
          format: it.format,
          sampleRate: it.sampleRate,
          channels: it.channels,
          artistId: artistId,
          albumId: albumId,
        ));
      }
      return ids;
    });
  }

  /// 字典 upsert（同事务批用）；name_norm=normalizeName（trim+压缩空白+小写）。
  Future<int?> _upsertArtist(String? display, {required int nowMs}) async {
    if (display == null || display.trim().isEmpty) {
      return null;
    }
    final norm = normalizeName(display);
    final found = await (_db.select(_db.artists)
          ..where((a) => a.nameNorm.equals(norm)))
        .getSingleOrNull();
    if (found != null) {
      return found.id;
    }
    return _db.into(_db.artists).insert(
          ArtistsCompanion.insert(name: display, nameNorm: norm, updatedAt: nowMs),
        );
  }

  Future<int?> _upsertAlbum(String? display, {required int nowMs}) async {
    if (display == null || display.trim().isEmpty) {
      return null;
    }
    final norm = normalizeName(display);
    final found = await (_db.select(_db.albums)
          ..where((a) => a.nameNorm.equals(norm)))
        .getSingleOrNull();
    if (found != null) {
      return found.id;
    }
    return _db.into(_db.albums).insert(
          AlbumsCompanion.insert(name: display, nameNorm: norm, updatedAt: nowMs),
        );
  }

  /// 仓库根流（设置页；id 升稳定）。
  Stream<List<RepositoryRoot>> watchRoots() {
    return (_db.select(_db.repositoryRoots)
          ..orderBy([(r) => OrderingTerm.asc(r.id)]))
        .watch();
  }

  /// 仓库根快照（无 watch 调度依赖——FakeAsync/任意环境皆安全；页面用
  /// 「hub.revisions 事件驱动 Future 重取」模式消费）。
  Future<List<RepositoryRoot>> rootsSnapshot() {
    return (_db.select(_db.repositoryRoots)
          ..orderBy([(r) => OrderingTerm.asc(r.id)]))
        .get();
  }

  /// 曲库浏览流（REQ-LIB-06 四排序；排除软删；缺失行由 UI 灰显判 missing_at）。
  /// 同刻并列以 id 续稳定序（1 万首量级由 SQL 排序承担，不取全表到内存）。
  Stream<List<Track>> liveTracksSorted(LibSort sort) {
    final q = _tracksSortedQuery(sort);
    return q.watch();
  }

  /// 曲库浏览快照（同排序四按；S2 pages 消费形态——无 watch 调度依赖）。
  Future<List<Track>> liveTracksOnce(LibSort sort) {
    return _tracksSortedQuery(sort).get();
  }

  /// 曲库活行总数（我的页「曲库」卡口径：排除软删；缺失行在内=列表同构）。
  Future<int> libraryTotal() async {
    final row = await (_db.selectOnly(_db.tracks)
          ..addColumns([_db.tracks.id.count()])
          ..where(_db.tracks.deletedAt.isNull()))
        .getSingle();
    return row.read(_db.tracks.id.count()) ?? 0;
  }

  SimpleSelectStatement<$TracksTable, Track> _tracksSortedQuery(LibSort sort) {
    final q = _db.select(_db.tracks)..where((t) => t.deletedAt.isNull());
    switch (sort) {
      case LibSort.recent:
        q.orderBy([(t) => OrderingTerm.desc(t.addedAt), (t) => OrderingTerm.desc(t.id)]);
      case LibSort.title:
        q.orderBy([(t) => OrderingTerm.asc(t.title), (t) => OrderingTerm.asc(t.id)]);
      case LibSort.artist:
        q.orderBy([(t) => OrderingTerm.asc(t.artistDisplay), (t) => OrderingTerm.asc(t.title)]);
      case LibSort.duration:
        q.orderBy([(t) => OrderingTerm.desc(t.durationMs), (t) => OrderingTerm.asc(t.title)]);
    }
    return q;
  }

  /// 单行取（编辑/移除入口前置读；含软删行）。
  Future<Track?> rowById(int trackId) {
    return (_db.select(_db.tracks)..where((t) => t.id.equals(trackId)))
        .getSingleOrNull();
  }

  /// 根行取（watcher 启动前校验）。
  Future<RepositoryRoot?> rootById(int rootId) {
    return (_db.select(_db.repositoryRoots)
          ..where((r) => r.id.equals(rootId)))
        .getSingleOrNull();
  }

  /// 根内全部现存行（扫描 diff 基线；**含软删行**——复扫见盘上同路径→复活分支）。
  Future<List<Track>> rowsByRoot(int rootId) {
    return (_db.select(_db.tracks)..where((t) => t.rootId.equals(rootId))).get();
  }

  /// 展示位 reconcile（外部 tag 变更→库内同步；REQ-LIB-03 约束「编辑不写原文件」。
  /// 展示字段 + FTS **同事务**（D9-1）。
  Future<void> reconcileTrackMeta(
    int trackId, {
    required String title,
    required String? artist,
    required String? album,
    int? durationMs,
    required int nowMs,
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.tracks)..where((t) => t.id.equals(trackId))).write(
        TracksCompanion(
          title: Value(title),
          artistDisplay: Value(artist),
          albumDisplay: Value(album),
          durationMs: Value(durationMs),
          updatedAt: Value(nowMs),
        ),
      );
      await _db.updateTrackIndex(
        trackId,
        title: title,
        artist: artist ?? '',
        album: album ?? '',
      );
    });
  }

  /// 复活（软删行同路径文件回归：清 deleted_at/missing_at + 刷新元数据 + FTS 同事务）。
  Future<void> reviveTrack(
    int trackId, {
    required int mtime,
    required int fileSize,
    required String contentHash,
    required int nowMs,
    required String title,
    required String? artist,
    required String? album,
    int? durationMs,
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.tracks)..where((t) => t.id.equals(trackId))).write(
        TracksCompanion(
          deletedAt: const Value(null),
          missingAt: const Value(null),
          mtime: Value(mtime),
          fileSize: Value(fileSize),
          contentHash: Value(contentHash),
          title: Value(title),
          artistDisplay: Value(artist),
          albumDisplay: Value(album),
          durationMs: Value(durationMs),
          updatedAt: Value(nowMs),
        ),
      );
      await _db.updateTrackIndex(
        trackId,
        title: title,
        artist: artist ?? '',
        album: album ?? '',
      );
    });
  }

  /// 扫描命中已有曲：仅 mtime/size/hash 变化才写（触摸）；不动 FTS（展示字段未变）。
  Future<void> touchTrackOnRescan(
    int trackId, {
    required bool changed,
    required int mtime,
    required int fileSize,
    required String contentHash,
    required int nowMs,
  }) async {
    if (!changed) {
      return;
    }
    await (_db.update(_db.tracks)..where((t) => t.id.equals(trackId))).write(
      TracksCompanion(
        mtime: Value(mtime),
        fileSize: Value(fileSize),
        contentHash: Value(contentHash),
        updatedAt: Value(nowMs),
      ),
    );
  }

  /// 缺失标记（REQ-LIB-05）：缺失≠移除；与 deleted_at 互斥裁决由 Sync 域（S6）守。
  Future<void> markMissing(int trackId, int nowMs) =>
      (_db.update(_db.tracks)..where((t) => t.id.equals(trackId)))
          .write(TracksCompanion(missingAt: Value(nowMs), updatedAt: Value(nowMs)));

  Future<void> markPresent(int trackId, int nowMs) =>
      (_db.update(_db.tracks)..where((t) => t.id.equals(trackId)))
          .write(TracksCompanion(missingAt: const Value(null), updatedAt: Value(nowMs)));

  /// 软删（REQ-LIB-07：删除=置 deleted_at；不进随机池/搜索）。
  Future<void> softDeleteTrack(int trackId, int nowMs) =>
      (_db.update(_db.tracks)..where((t) => t.id.equals(trackId)))
          .write(TracksCompanion(deletedAt: Value(nowMs), updatedAt: Value(nowMs)));

  // ⑥ dup 检测（REQ-EXT-06）：同 source_type+source_id 任意行（含软删）。
  Future<Track?> findBySource(String sourceType, String? sourceId) {
    return (_db.select(_db.tracks)
          ..where((t) => t.sourceType.equals(sourceType)
                  & (sourceId == null
                      ? t.sourceId.isNull()
                      : t.sourceId.equals(sourceId))))
        .getSingleOrNull();
  }

  /// 全库计数（含过滤口径，供壳层/调试）。
  Future<int> countAll({bool excludeDeleted = true}) async {
    final q = _db.selectOnly(_db.tracks)
      ..addColumns([_db.tracks.id.count()]);
    if (excludeDeleted) {
      q.where(_db.tracks.deletedAt.isNull());
    }
    final row = await q.getSingle();
    return row.read(_db.tracks.id.count()) ?? 0;
  }
}

// ── 历史与少播 ──────────────────────────────────────────────

class HistoryDao {
  HistoryDao(this._db);

  final IaDatabase _db;

  /// 记录一次播放（历史本地表不参与同步；§1.1）。
  Future<void> record({
    required int trackId,
    required bool completed,
    required String deviceId,
    required int nowMs,
  }) {
    return _db.into(_db.playHistory).insert(
          PlayHistoryCompanion.insert(
            trackId: trackId,
            playedAt: nowMs,
            completed: completed,
            deviceId: deviceId,
          ),
        );
  }

  /// 延迟合并写（ARCH §3.2「切歌完成事件批量写历史」）：多行**单事务**落库。
  /// S3 播放域消费：缓冲阈值/服务终止时 flush（播放事件条目=记录四元组）。
  Future<void> recordBatch(
    List<({int trackId, bool completed, int playedAtMs, String deviceId})> rows,
  ) {
    return _db.transaction(() async {
      for (final r in rows) {
        await record(trackId: r.trackId, completed: r.completed, deviceId: r.deviceId, nowMs: r.playedAtMs);
      }
    });
  }

  // ⑤ 历史分组（REQ-PL-05）：idx_history_played DESC；「按日分组」转盘由 UI 侧做。
  Future<List<(PlayHistoryData, Track)>> historyPage({
    int page = 0,
    int pageSize = 100,
  }) async {
    final q = _db.select(_db.playHistory)
        .join([innerJoin(_db.tracks, _db.tracks.id.equalsExp(_db.playHistory.trackId))])
      ..orderBy([OrderingTerm.desc(_db.playHistory.playedAt)])
      ..limit(pageSize, offset: page * pageSize);
    final rows = await q.get();
    return [
      for (final r in rows) (r.readTable(_db.playHistory), r.readTable(_db.tracks)),
    ];
  }

  /// 500 淘汰（D9-3）：超容按 played_at 删最旧；**应用层批次=100/条事务**。
  Future<int> pruneToCap({int cap = 500, int batch = 100}) async {
    var removedTotal = 0;
    for (;;) {
      final row =
          await _db.customSelect('SELECT count(*) c FROM play_history').getSingle();
      final over = row.read<int>('c') - cap;
      if (over <= 0) {
        break;
      }
      final d = over > batch ? batch : over;
      await _db.transaction(() async {
        final oldest = await (_db.select(_db.playHistory)
              ..orderBy([(h) => OrderingTerm.asc(h.playedAt)])
              ..limit(d))
            .get();
        await (_db.delete(_db.playHistory)
              ..where((h) => h.id.isIn(oldest.map((o) => o.id).toList())))
            .go();
      });
      removedTotal += d;
    }
    return removedTotal;
  }

  // 少播（REQ-PLAY-04）
  Future<void> addFewWatch(int trackId, int nowMs) =>
      _db.into(_db.fewWatchList).insert(
            FewWatchListCompanion.insert(
              trackId: Value(trackId),
              addedAt: nowMs,
            ),
          );

  Future<void> removeFewWatch(int trackId) =>
      (_db.delete(_db.fewWatchList)..where((f) => f.trackId.equals(trackId))).go();

  /// 设置可清空=物理全表删除（§1.2：该操作产生 sync 墓碑——**墓碑由 SyncEngine 补写**）。
  Future<int> clearFewWatch() => _db.delete(_db.fewWatchList).go();

  /// 少播名单读取（池口径核对/UI 徽章面；仅本地域）。
  Future<List<int>> fewWatchIds() async {
    final rows = await _db.select(_db.fewWatchList).get();
    return [for (final r in rows) r.trackId];
  }

  /// 播放总数（我的页「最近播放」卡口径；不分页计数）。
  Future<int> historyTotal() async {
    final row = await (_db.selectOnly(_db.playHistory)
          ..addColumns([_db.playHistory.id.count()]))
        .getSingle();
    return row.read(_db.playHistory.id.count()) ?? 0;
  }
}

// ── 歌单域 ────────────────────────────────────────────────

class PlaylistDao {
  PlaylistDao(this._db);

  final IaDatabase _db;

  // ④ 歌单浏览（REQ-PL-04/06）：idx_pt_pos 顺序 + tracks 联查（缺失/软删标记透出 UI）。
  Future<List<(PlaylistTrack, Track)>> browse(int playlistId) async {
    final q = _db.select(_db.playlistTracks).join([
      innerJoin(_db.tracks, _db.tracks.id.equalsExp(_db.playlistTracks.trackId)),
      innerJoin(
          _db.playlists, _db.playlists.id.equalsExp(_db.playlistTracks.playlistId)),
    ])
      ..where(_db.playlistTracks.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(_db.playlistTracks.position)]);
    final rows = await q.get();
    return [
      for (final r in rows)
        (r.readTable(_db.playlistTracks), r.readTable(_db.tracks)),
    ];
  }

  /// 收藏夹兜底（REQ-PL-01：system_favorite 恰一行；DB 级部分唯一兜底）。
  /// 并发调用（每帧刷新面）安全：撞唯一索引即回读既有行，不抛给调用方。
  Future<Playlist> ensureFavorite({required int nowMs}) async {
    final existing = await _favoriteOrNull();
    if (existing != null) {
      return existing;
    }
    try {
      final id = await _db.into(_db.playlists).insert(
            PlaylistsCompanion.insert(
              kind: PlaylistKind.system_favorite,
              name: '我喜欢的音乐', // PRD REQ-PL-01 系统歌单规范名（S4 归正）
              createdAt: nowMs,
              updatedAt: nowMs,
            ),
          );
      return await (_db.select(_db.playlists)..where((p) => p.id.equals(id)))
          .getSingle();
    } on Exception {
      // 竞态：另一调用已建行（部分唯一索引生效）→ 回读既有
      final again = await _favoriteOrNull();
      if (again != null) {
        return again;
      }
      rethrow;
    }
  }

  Future<Playlist?> _favoriteOrNull() => (_db.select(_db.playlists)
        ..where((p) => p.kind.equals('system_favorite'))
        ..limit(1))
      .getSingleOrNull();

  /// 新建歌单（REQ-PL-02）。
  Future<Playlist> create(String name, {required int nowMs}) async {
    final id = await _db.into(_db.playlists).insert(
          PlaylistsCompanion.insert(
            kind: PlaylistKind.user,
            name: name,
            createdAt: nowMs,
            updatedAt: nowMs,
          ),
        );
    return (_db.select(_db.playlists)..where((p) => p.id.equals(id))).getSingle();
  }

  /// 加入歌曲：position=max+1；重复 → false（REQ-PL-03 DB UNIQUE 拦截）。
  Future<bool> addTrack(int playlistId, int trackId, {required int nowMs}) async {
    try {
      return await _db.transaction<bool>(() async {
        final maxRow = await _db
            .customSelect(
              'SELECT COALESCE(MAX(position),-1)+1 AS next FROM playlist_tracks WHERE playlist_id=?',
              variables: [Variable.withInt(playlistId)],
            )
            .getSingle();
        final position = maxRow.read<int>('next');
        final id = await _db.into(_db.playlistTracks).insert(
              PlaylistTracksCompanion.insert(
                playlistId: playlistId,
                trackId: trackId,
                position: position,
                addedAt: nowMs,
              ),
            );
        return id > 0;
      });
    } on Exception {
      return false;
    }
  }

  /// 移出歌曲（业务动作；playlist_tracks 无软删列——§1.2 表设计）。
  Future<void> removeTrack(int playlistId, int trackId) =>
      (_db.delete(_db.playlistTracks)
            ..where((t) =>
                t.playlistId.equals(playlistId) & t.trackId.equals(trackId)))
          .go();

  /// 时间戳刷新（收藏 toggling 伴生写；updated_at 口径=列表排序新鲜度）。
  Future<void> touchUpdatedAt(int playlistId, int nowMs) =>
      (_db.update(_db.playlists)..where((p) => p.id.equals(playlistId)))
          .write(PlaylistsCompanion(updatedAt: Value(nowMs)));

  /// 拖拽排序（REQ-PL-06）：全量有序 trackIds → 重排 position（同事务）。
  Future<void> reorder(
    int playlistId, {
    required List<int> orderedTrackIds,
    required int nowMs,
  }) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedTrackIds.length; i++) {
        await (_db.update(_db.playlistTracks)
              ..where((t) =>
                  t.playlistId.equals(playlistId) &
                  t.trackId.equals(orderedTrackIds[i])))
            .write(PlaylistTracksCompanion(position: Value(i)));
      }
      await (_db.update(_db.playlists)..where((p) => p.id.equals(playlistId)))
          .write(PlaylistsCompanion(updatedAt: Value(nowMs)));
    });
  }

  /// 歌单删除（REQ-PL-02：删除=软删不物理删）。
  Future<void> softDeletePlaylist(int playlistId, int nowMs) =>
      (_db.update(_db.playlists)..where((p) => p.id.equals(playlistId)))
          .write(PlaylistsCompanion(deletedAt: Value(nowMs), updatedAt: Value(nowMs)));

  // ═══ S4 增量 ══════════════════════════════════════════════

  /// 歌单全列（REQ-PL-02/04：排除软删；附曲目计数——我的页三卡红心入口面）。
  Future<List<(Playlist, int)>> listAll() async {
    final pls = await (_db.select(_db.playlists)
          ..where((p) => p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
        .get();
    final out = <(Playlist, int)>[];
    for (final p in pls) {
      final cnt = await (_db.selectOnly(_db.playlistTracks)
            ..addColumns([_db.playlistTracks.id.count()])
            ..where(_db.playlistTracks.playlistId.equals(p.id)))
          .getSingle();
      final c = cnt.read(_db.playlistTracks.id.count()) ?? 0;
      out.add((p, c));
    }
    return out;
  }

  /// 重复判（REQ-PL-03 拦截语境 UI 原话来源：already-in 感知）。
  Future<bool> contains(int playlistId, int trackId) async =>
      (await (_db.select(_db.playlistTracks)
                ..where((t) =>
                    t.playlistId.equals(playlistId) & t.trackId.equals(trackId)))
              .getSingleOrNull()) !=
      null;

  /// 曲目计数（我的页红心卡；单歌单）。
  Future<int> trackCount(int playlistId) async {
    final row = await (_db.selectOnly(_db.playlistTracks)
          ..addColumns([_db.playlistTracks.id.count()])
          ..where(_db.playlistTracks.playlistId.equals(playlistId)))
        .getSingle();
    return row.read(_db.playlistTracks.id.count()) ?? 0;
  }
}

// ── 同步域（S6 消费主体）────────────────────────────────────

class SyncDao {
  SyncDao(this._db);

  final IaDatabase _db;

  Future<SyncChannelData?> currentChannel() =>
      (_db.select(_db.syncChannel)..where((c) => c.isActive.equals(true)))
          .getSingleOrNull();

  /// 通道保存/激活（C44 单通道）：全关 → 单开；凭据本体**永不入 DB**（C50）。
  Future<void> applyChannel(
    SyncChannelType type,
    String baseUrl, {
    required String credentialsRef,
    String? username,
  }) async {
    try {
      await _db.transaction(() async {
        await (_db.update(_db.syncChannel))
            .write(SyncChannelCompanion(isActive: const Value(false)));
        final existing = await (_db.select(_db.syncChannel)
              ..where((c) =>
                  c.type.equals(type.name) & c.baseUrl.equals(baseUrl)))
            .getSingleOrNull();
        if (existing != null) {
          await (_db.update(_db.syncChannel)
                ..where((c) => c.id.equals(existing.id)))
              .write(SyncChannelCompanion(
            credentialsRef: Value(credentialsRef),
            username: Value(username),
            isActive: const Value(true),
          ));
        } else {
          await _db.into(_db.syncChannel).insert(
                SyncChannelCompanion.insert(
                  type: type,
                  baseUrl: baseUrl,
                  credentialsRef: Value(credentialsRef),
                  username: Value(username),
                  isActive: const Value(true),
                ),
              );
        }
      });
    } on Exception catch (e) {
      if (_isUniqueViolation(e)) {
        // 部分唯一 uq_sync_channel_single_active：active>1 应不可能（先全关）——防御性重抛
        rethrow;
      }
      rethrow;
    }
  }

  bool _isUniqueViolation(Object e) {
    final s = e.toString();
    return s.contains('UNIQUE constraint failed') ||
        s.contains('uq_sync_channel_single_active');
  }

  // ⑧ 墓碑比较（REQ-SYNC-04/05）：idx_tomb_kind_time 顺序读。
  Future<List<Tombstone>> pendingTombstones({int limit = 200}) =>
      (_db.select(_db.tombstones)
            ..where((t) => t.remoteClearedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.entityKind),
              (t) => OrderingTerm.desc(t.deletedAt),
            ])
            ..limit(limit))
          .get();

  /// 墓碑登记（kind+localId）；**仅传播记录，永不触发云端文件删除**（代码级红线）。
  Future<void> recordTombstone(
    TombstoneKind kind, {
    required int localId,
    required String deletedByDevice,
    required int nowMs,
  }) =>
      _db.into(_db.tombstones).insert(
            TombstonesCompanion.insert(
              entityKind: kind,
              entityLocalId: localId,
              deletedAt: nowMs,
              deletedByDevice: deletedByDevice,
            ),
          );

  Future<void> markTombstoneRemoteCleared(List<int> ids, int nowMs) =>
      (_db.update(_db.tombstones)..where((t) => t.id.isIn(ids)))
          .write(TombstonesCompanion(remoteClearedAt: Value(nowMs)));

  /// 上次同步状态（REQ-SYNC-07 成功 N/失败 M 摘要）。
  Future<void> upsertLastSync({
    required int channelId,
    int? pendingUp,
    int? pendingDown,
    String? summaryJson,
    int? lastStartedAt,
    required int nowMs,
  }) async {
    final existing = await (_db.select(_db.lastSyncState)
          ..where((s) => s.channelId.equals(channelId)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.lastSyncState).insert(
            LastSyncStateCompanion.insert(
              channelId: Value(channelId),
              pendingUp: Value(pendingUp),
              pendingDown: Value(pendingDown),
              summaryJson: Value(summaryJson),
            ),
          );
    } else {
      await (_db.update(_db.lastSyncState)
            ..where((s) => s.channelId.equals(channelId)))
          .write(LastSyncStateCompanion(
        lastStartedAt: Value(lastStartedAt ?? existing.lastStartedAt),
        lastCompletedAt: Value(nowMs),
        pendingUp: Value(pendingUp),
        pendingDown: Value(pendingDown),
        summaryJson: Value(summaryJson),
      ));
    }
  }
}

// ── 提取域（S3 下游消费）──────────────────────────────────

class ExtractDao {
  ExtractDao(this._db);

  final IaDatabase _db;

  /// 建任务：同源已存在 → 返回现有行且 isNew=false（REQ-EXT-06 dup=复用行不重复建行）。
  Future<(ExtractTask, bool)> createOrGet({
    required String sourceType,
    required String sourceId,
    required String url,
    required TaskQuality quality,
    required int nowMs,
  }) async {
    final existing = await (_db.select(_db.extractTasks)
          ..where((t) =>
              t.sourceType.equals(sourceType) & t.sourceId.equals(sourceId)))
        .getSingleOrNull();
    if (existing != null) {
      return (existing, false);
    }
    final id = await _db.into(_db.extractTasks).insert(
          ExtractTasksCompanion.insert(
            sourceType: sourceType,
            sourceId: sourceId,
            url: url,
            quality: quality,
            status: ExtractTaskStatus.resolved,
            createdAt: nowMs,
            updatedAt: nowMs,
          ),
        );
    final row = await (_db.select(_db.extractTasks)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    return (row, true);
  }

  /// 任务状态机推进（边界+进度+产物路径）。
  Future<void> updateTask(
    int taskId, {
    ExtractTaskStatus? status,
    double? progressPct,
    String? outputRelPath,
    ExtractErrorCode? errorCode,
    bool? cookiesUsed,
    int? retryCount,
    int? durationMs,
    String? title,
    String? uploader,
  }) =>
      (_db.update(_db.extractTasks)..where((t) => t.id.equals(taskId))).write(
        ExtractTasksCompanion(
          status: opt(status),
          progressPct: opt(progressPct),
          outputRelPath: opt(outputRelPath),
          errorCode: opt(errorCode),
          cookiesUsed: opt(cookiesUsed),
          retryCount: opt(retryCount),
          durationMs: opt(durationMs),
          title: opt(title),
          uploader: opt(uploader),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
}

// ── 歌词域（S6/S7 消费主体）────────────────────────────────

class LyricsDao {
  LyricsDao(this._db);

  final IaDatabase _db;

  Future<LyricsMetaData?> metaFor(int trackId) =>
      (_db.select(_db.lyricsMeta)..where((m) => m.trackId.equals(trackId)))
          .getSingleOrNull();

  Future<void> upsertMeta({
    required int trackId,
    required LyricsSourceType type,
    int offsetMs = 0,
    String? lrcPath,
    String? sourceText,
    bool edited = false,
    required int nowMs,
  }) async {
    final existing = await metaFor(trackId);
    if (existing == null) {
      await _db.into(_db.lyricsMeta).insert(
            LyricsMetaCompanion.insert(
              trackId: Value(trackId),
              type: type,
              offsetMs: Value(offsetMs),
              lrcPath: Value(lrcPath),
              sourceText: Value(sourceText),
              edited: Value(edited),
              updatedAt: nowMs,
            ),
          );
    } else {
      await (_db.update(_db.lyricsMeta)..where((m) => m.trackId.equals(trackId)))
          .write(LyricsMetaCompanion(
        type: Value(type),
        offsetMs: Value(offsetMs),
        lrcPath: Value(lrcPath),
        sourceText: Value(sourceText),
        edited: Value(edited),
        updatedAt: Value(nowMs),
      ));
    }
  }

  /// 队列登记（REQ-LYRAI-03 串行）：同曲有未终态 job → null；终态 job → 重排为 queued。
  Future<LyricsGenJob?> schedule(
    int trackId, {
    required String modelId,
    required int nowMs,
  }) async {
    final existing = await (_db.select(_db.lyricsGenJobs)
          ..where((j) => j.trackId.equals(trackId)))
        .getSingleOrNull();
    const runningOrPending = [
      LyricsJobStatus.queued,
      LyricsJobStatus.running,
      LyricsJobStatus.pausing,
      LyricsJobStatus.paused,
      LyricsJobStatus.preview,
    ];
    if (existing != null && runningOrPending.contains(existing.status)) {
      return null;
    }
    if (existing != null) {
      final jobId = existing.id;
      await (_db.update(_db.lyricsGenJobs)..where((j) => j.id.equals(jobId)))
          .write(LyricsGenJobsCompanion(
        status: Value(LyricsJobStatus.queued),
        progress: const Value(0.0),
        modelId: Value(modelId),
        errorCode: const Value(null),
        createdAt: Value(nowMs),
        updatedAt: Value(nowMs),
      ));
      return (_db.select(_db.lyricsGenJobs)..where((j) => j.id.equals(jobId))).getSingle();
    }
    final id = await _db.into(_db.lyricsGenJobs).insert(
          LyricsGenJobsCompanion.insert(
            trackId: trackId,
            status: LyricsJobStatus.queued,
            createdAt: nowMs,
            updatedAt: nowMs,
            modelId: Value(modelId),
          ),
        );
    return (_db.select(_db.lyricsGenJobs)..where((j) => j.id.equals(id))).getSingle();
  }

  /// 串行取队首（created_at 升序）→ running。
  Future<LyricsGenJob?> claimNext({required int nowMs}) async {
    final next = await (_db.select(_db.lyricsGenJobs)
          ..where((j) => j.status.equals(LyricsJobStatus.queued.name))
          ..orderBy([(j) => OrderingTerm.asc(j.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    if (next == null) {
      return null;
    }
    await (_db.update(_db.lyricsGenJobs)..where((j) => j.id.equals(next.id)))
        .write(LyricsGenJobsCompanion(
      status: Value(LyricsJobStatus.running),
      startedAt: Value(nowMs),
      updatedAt: Value(nowMs),
    ));
    return (_db.select(_db.lyricsGenJobs)..where((j) => j.id.equals(next.id)))
        .getSingle();
  }

  Future<void> setProgress(int jobId, double pct, {required int nowMs}) =>
      (_db.update(_db.lyricsGenJobs)..where((j) => j.id.equals(jobId))).write(
        LyricsGenJobsCompanion(
          progress: Value(pct),
          status: Value(LyricsJobStatus.running),
          updatedAt: Value(nowMs),
        ),
      );

  /// 终态写入（committed/failed/no_voice/cancelled/preview）。
  Future<void> finish(
    int jobId, {
    required LyricsJobStatus terminal,
    String? errorCode,
    required int nowMs,
  }) =>
      (_db.update(_db.lyricsGenJobs)..where((j) => j.id.equals(jobId))).write(
        LyricsGenJobsCompanion(
          status: Value(terminal),
          errorCode: errorCode == null ? const Value(null) : Value(errorCode),
          finishedAt: Value(nowMs),
          updatedAt: Value(nowMs),
        ),
      );
}

// ── 壳层域（设置/模型注册最小 CRUD；S2 消费）────────────────

class ShellDao {
  ShellDao(this._db);

  final IaDatabase _db;

  Future<Setting?> get(String key) =>
      (_db.select(_db.settings)..where((s) => s.key.equals(key))).getSingleOrNull();

  Future<String?> value(String key) async {
    final row = await get(key);
    return row?.value;
  }

  /// upsert（首 Put 即建行；无静默丢写）。
  Future<void> put(String key, String jsonValue, {required int nowMs}) =>
      _db.into(_db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: key,
              value: jsonValue,
              updatedAt: nowMs,
            ),
          );

  Future<void> upsertModel(
    String modelId, {
    required int? sizeBytes,
    required String? sha256,
    required ModelStatus status,
    required String? localPath,
    required int? downloadedAt,
  }) =>
      _db.into(_db.modelRegistry).insertOnConflictUpdate(
            ModelRegistryCompanion.insert(
              modelId: modelId,
              sizeBytes: Value(sizeBytes),
              sha256: Value(sha256),
              status: status,
              localPath: Value(localPath),
              downloadedAt: Value(downloadedAt),
            ),
          );
}

// ── 聚合门面 ───────────────────────────────────────────────

/// DAO 聚合门面：调用方一次注入 [IaDatabase]。
class DataAccess {
  DataAccess(this.db);

  final IaDatabase db;

  LibraryDao get library => LibraryDao(db);
  HistoryDao get history => HistoryDao(db);
  PlaylistDao get playlists => PlaylistDao(db);
  SyncDao get sync => SyncDao(db);
  ExtractDao get extract => ExtractDao(db);
  LyricsDao get lyrics => LyricsDao(db);
  ShellDao get shell => ShellDao(db);
}
