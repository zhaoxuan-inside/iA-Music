/// 数据契约 v1 —— 14 表 + FTS 锚定表（DETAILED-DESIGN §1.2 逐字段映射）。
///
/// 惯例（§1.1）：
/// * 时长/时间=毫秒整数（`*_ms`/Unix `*_at`）；体积=字节。
/// * 同步表必备 `updated_at` + `device_id`；每条主业务记录含 `deleted_at`（软删）。
/// * 物理删仅限 play_history 500 淘汰与临时缓存（DEC-009 D9-3）。
/// * 凭据本体永不入 DB：只存 `credentials_ref`（SecureStore key，C50）。
///
/// 枚举存储=名字字符串（与 §1.2 ENUM(...) 值一致）。
/// 本文件常量名强制与 spec 一致（snake_case），故关闭 constant_identifier_names。
// ignore_for_file: constant_identifier_names
library;

import 'package:drift/drift.dart';

// ── 枚举目录（§1.2 唯一事实源）─────────────────────────────

/// repository_roots.mode
enum RepositoryMode { directory, synced_dir }

/// tracks.audio_format
enum AudioFormatSpec { mp3, flac, m4a, ogg, wav, ape }

/// playlists.kind
enum PlaylistKind { user, system_favorite }

/// lyrics_meta.type
enum LyricsSourceType { none, embed, lrc, paste, asr }

/// lyrics_gen_jobs.status（队列聚合 5 首批量=job 序列，串行执行 REQ-LYRAI-03）
enum LyricsJobStatus {
  queued,
  running,
  pausing,
  paused,
  preview,
  committed,
  failed,
  no_voice,
  cancelled,
}

/// extract_tasks.quality（§5.2 唯一事实源；'64k' 等非 Dart 标识符→显式映射）
enum TaskQuality { k64, k128, k192, hires }

/// TaskQuality ↔ §5.2 字符串值映射（64k/128k/192k/hires）。
class TaskQualityConverter extends TypeConverter<TaskQuality, String> {
  const TaskQualityConverter();

  static const Map<TaskQuality, String> _dbByValue = {
    TaskQuality.k64: '64k',
    TaskQuality.k128: '128k',
    TaskQuality.k192: '192k',
    TaskQuality.hires: 'hires',
  };

  static const Map<String, TaskQuality> _valueByDb = {
    '64k': TaskQuality.k64,
    '128k': TaskQuality.k128,
    '192k': TaskQuality.k192,
    'hires': TaskQuality.hires,
  };

  @override
  String toSql(TaskQuality value) => _dbByValue[value]!;

  @override
  TaskQuality fromSql(String fromDb) => _valueByDb[fromDb]!;
}

/// extract_tasks.status
enum ExtractTaskStatus {
  resolved,
  gating,
  gated,
  downloading,
  paused,
  transcoding,
  registered,
  failed,
  dup,
}

/// extract_tasks.error_code
/// noRepo=尚未配置音乐仓库（配置缺失，重试无意义；textEnum 存储=加值零迁移）。
enum ExtractErrorCode { network, auth, dup, disk, transcode, noRepo }

/// sync_channel.type
enum SyncChannelType { webdav, onedrive, gdrive, github }

/// tombstones.entity_kind
enum TombstoneKind { track, playlist, playlist_item, few_watch, lyrics_meta }

/// model_registry.status
enum ModelStatus { absent, downloading, paused, present }

/// tracks.cover_kind（S5 封面注册位；DETAILED-DESIGN §3.5「cover 状态列」落点）。
///
/// * `embedded`：音频内嵌图（唯一性由元数据解析确认）
/// * `sibling`：同目录同名图（REQ-LIB-04「同目录同名图」）
/// * `fetched`：联网抓取落盘 `<文件名>.cover.jpg`（REQ-LIB-08）
/// * `none`：已决策过且四级链均无命中（可于下次扫描/播放重试，非永久否决）
/// 注册位**只是缓存**：展示决策仍以「内嵌 > 同目录 > 联网 > 色块」真源为准，
/// 仅补缺不覆盖（C22）——任何时刻不得因注册位而拒绝更优来源。
enum CoverKind { embedded, sibling, fetched, none }

// ── 曲库域 ────────────────────────────────────────────────

/// 目录仓库根（REQ-LIB-05 扫描范围事实源）。
@TableIndex(name: 'idx_root_path', columns: {#path})
class RepositoryRoots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  TextColumn get label => text().nullable()();
  TextColumn get mode => textEnum<RepositoryMode>()();
  IntColumn get addedAt => integer()();
}

/// 艺术家字典（入库 upsert；name_norm 规范化唯一）。
class Artists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get nameNorm => text().unique()();
  TextColumn get sortKey => text().nullable()();
  IntColumn get updatedAt => integer()();
}

/// 专辑字典（同上）。
class Albums extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get nameNorm => text().unique()();
  TextColumn get sortKey => text().nullable()();
  IntColumn get updatedAt => integer()();
}

/// 曲目主表（六问基准）。
///
/// * `deletedAt` 与 `missingAt` 语义互斥（缺失≠移除）；
///   任一非空 ⇒ 不进随机池/搜索/歌单播放（§1.2 规则约束）。
/// * UNIQUE(root, rel_path) 承担增量扫描 diff（REQ-LIB-02）。
/// * idx_track_source 承担 dup 检测（REQ-EXT-06）。
@TableIndex(name: 'idx_track_album', columns: {#albumId})
@TableIndex(name: 'idx_track_artist', columns: {#artistId})
@TableIndex(name: 'idx_track_source', columns: {#sourceType, #sourceId})
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get rootId => integer().references(RepositoryRoots, #id)();
  TextColumn get relPath => text()();

  /// 标签缺失时由扫描以文件名兜底填充（可空→扫描层保证非空值写入）。
  TextColumn get title => text().nullable()();
  TextColumn get artistDisplay => text(
        // 原文案展示值（REQ-LIB-03 不改写tags）
      ).nullable()();
  TextColumn get albumDisplay => text().nullable()();
  IntColumn get artistId => integer().nullable().references(Artists, #id)();
  IntColumn get albumId => integer().nullable().references(Albums, #id)();

  /// 内容中位值（多来源时长统计后填充；未确定前可空）。
  IntColumn get durationMs => integer().nullable()();
  TextColumn get audioFormat => textEnum<AudioFormatSpec>()();
  IntColumn get fileSize => integer()();
  IntColumn get mtime => integer()();

  /// 入库时计算（范围=音频帧）；同步比对用。
  TextColumn get contentHash => text()();
  TextColumn get sourceType => text().nullable()(); // 恒 bilibili（通道收敛后预留）
  TextColumn get sourceId => text().nullable()(); // BV…
  IntColumn get sampleRate => integer().nullable()();
  IntColumn get channels => integer().nullable()();
  IntColumn get addedAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()(); // 软删位（REQ-LIB-07）
  IntColumn get missingAt => integer().nullable()(); // 缺失位（REQ-LIB-05）

  /// 封面注册位（S5；§3.5 —— library 域唯一写者）。
  /// 三列皆可空（未决策=null）；语义见 [CoverKind] 注释。
  TextColumn get coverKind => textEnum<CoverKind>().nullable()();
  /// 封面文件相对「音频所在目录」的路径（`sibling`/`fetched` 才有值）。
  TextColumn get coverRelPath => text().nullable()();
  /// 最近一次封面决策时刻（毫秒）；`none` 亦写入（用于下次扫描/播放重试口径）。
  IntColumn get coverCheckedAt => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {rootId, relPath}, // idx_track_root_rel UNIQUE(root,rel_path)
      ];
}

// ── 歌单域 ────────────────────────────────────────────────

/// 歌单（system_favorite 仅一行=部分唯一索引，onCreate 落 DDL）。
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// 跨端身份（WS6/REQ-SYNC-02：schema v3 迁移回填随机 UUID；
  /// 本地自增 id 设备无关，同步以 uuid 键控）。
  TextColumn get uuid => text().nullable()();
  TextColumn get kind => textEnum<PlaylistKind>()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()(); // 软删（REQ-PL-02）
}

/// 歌单曲目（UNIQUE(playlist,track)=REQ-PL-03 重复拦截 DB 级）。
@TableIndex(name: 'idx_pt_pos', columns: {#playlistId, #position})
class PlaylistTracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  IntColumn get addedAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {playlistId, trackId},
      ];
}

// ── 历史与少播 ──────────────────────────────────────────────

/// 播放历史（本地表，不参与同步）。
/// idx_history_played(played_at DESC)=onCreate 手写 DDL（drift 注解不带表达式索引）。
class PlayHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId => integer().references(Tracks, #id)();
  IntColumn get playedAt => integer()(); // Unix ms
  BoolColumn get completed => boolean()();
  TextColumn get deviceId => text()(); // device_id（本地生成）
}

/// 少播名单（REQ-PLAY-04；设置可清空=全表删除+墓碑）。
class FewWatchList extends Table {
  @override
  Set<Column> get primaryKey => {trackId};
  IntColumn get trackId => integer().references(Tracks, #id)();
  IntColumn get addedAt => integer()();
}

// ── 歌词域 ────────────────────────────────────────────────

/// 每曲一份歌词元数据（track_id PK=1:1）。
class LyricsMeta extends Table {
  @override
  Set<Column> get primaryKey => {trackId};
  IntColumn get trackId => integer().references(Tracks, #id)();
  TextColumn get type => textEnum<LyricsSourceType>()();
  TextColumn get lrcPath => text().nullable()(); // 同目录 .lrc（REQ-LYR-03）
  TextColumn get sourceText => text().nullable()(); // paste 临时内嵌
  IntColumn get offsetMs => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();
  BoolColumn get edited => boolean().withDefault(const Constant(false))();
}

/// ASR 生成任务（UNIQUE(track_id)=一任务一曲；串行 job 序列）。
class LyricsGenJobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get status => textEnum<LyricsJobStatus>()();
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  TextColumn get modelId =>
      text().nullable().references(ModelRegistry, #modelId)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get startedAt => integer().nullable()();
  IntColumn get finishedAt => integer().nullable()();
  TextColumn get errorCode => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {trackId},
      ];
}

// ── 提取域 ────────────────────────────────────────────────

/// 提取任务（UNIQUE(source_type,source_id)：同源重复→dup 状态而非重复行）。
class ExtractTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text()();
  TextColumn get url => text()();
  TextColumn get title => text().nullable()(); // resolve 后填
  TextColumn get uploader => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get quality => text().map(const TaskQualityConverter())();
  RealColumn get progressPct => real().withDefault(const Constant(0.0))();
  TextColumn get status => textEnum<ExtractTaskStatus>()();
  TextColumn get errorCode => textEnum<ExtractErrorCode>().nullable()();
  TextColumn get outputRelPath => text().nullable()(); // 私有目录内相对路径
  BoolColumn get cookiesUsed => boolean().withDefault(const Constant(false))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {sourceType, sourceId},
      ];
}

// ── 同步域 ────────────────────────────────────────────────

/// 同步通道（MVP 单通道：active=TRUE 恰 1 行=部分唯一 DDL）。
/// credentials_ref=SecureStore key；**凭据本体绝不入库**（C50）。
class SyncChannel extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<SyncChannelType>()();
  TextColumn get baseUrl => text()();
  TextColumn get remoteDir => text().withDefault(const Constant('iA-Music/'))();
  TextColumn get username => text().nullable()();
  TextColumn get credentialsRef => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  IntColumn get lastTestAt => integer().nullable()();

  /// 「last_test_at BOOLEAN result」落两列（六问自答：时间+结果分开存）。
  BoolColumn get lastTestOk => boolean().nullable()();
}

/// 上次同步结果（REQ-SYNC-07 成功 N/失败 M）。
class LastSyncState extends Table {
  @override
  Set<Column> get primaryKey => {channelId};
  IntColumn get channelId => integer().references(SyncChannel, #id)();
  IntColumn get lastStartedAt => integer().nullable()();
  IntColumn get lastCompletedAt => integer().nullable()();
  IntColumn get pendingUp => integer().nullable()();
  IntColumn get pendingDown => integer().nullable()();
  TextColumn get summaryJson => text().nullable()();
}

/// 墓碑（删除仅传播记录；**永不触发云端文件删除**——SyncChannelPort 无 delete 语义）。
@TableIndex(name: 'idx_tomb_kind_time', columns: {#entityKind, #deletedAt})
class Tombstones extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityKind => textEnum<TombstoneKind>()();
  IntColumn get entityLocalId => integer()();
  IntColumn get deletedAt => integer()();
  TextColumn get deletedByDevice => text()();
  IntColumn get remoteClearedAt => integer().nullable()();
}

/// 冲突副本（REQ-SYNC-04 可查看/删除=软删本行；列补遗=ISS-503）。
class ConflictCopies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get originKind => text()();
  IntColumn get originLocalId => integer()();
  TextColumn get winnerValueJson => text()();
  TextColumn get loserPayloadJson => text()();
  IntColumn get lostAt => integer()();
  IntColumn get deletedAt => integer().nullable()(); // 删除=软删本行（REQ-SYNC-04）
}

// ── 壳层域 ────────────────────────────────────────────────

/// 键值设置（指纹 keys：repo.paths/appearance.*/compliance.*/eq.user）。
class Settings extends Table {
  @override
  Set<Column> get primaryKey => {key};
  TextColumn get key => text()();
  TextColumn get value => text()(); // JSON
  IntColumn get updatedAt => integer()();
}

/// ASR 模型注册（DEC-010：模型为真实文件，sha256 必验）。
class ModelRegistry extends Table {
  @override
  Set<Column> get primaryKey => {modelId};
  TextColumn get modelId => text()(); // sensevoice-int8-20240717
  IntColumn get sizeBytes => integer().nullable()();
  TextColumn get sha256 => text().nullable()();
  TextColumn get status => textEnum<ModelStatus>()();
  TextColumn get localPath => text().nullable()();
  IntColumn get downloadedAt => integer().nullable()();
}
