/// drift 表定义（schema v1 全新起始；v2 无迁移链）。
///
/// 设计要点：
/// * 分组用 norm 列（小写折叠）GROUP BY 聚合，不再建 artists/albums 字典表。
/// * FTS 虚拟表 `track_index` 在 database.dart 迁移里创建，DAO 显式同事务维护。
/// * 元数据只落库内显示字段——当前 schema 无写回原文件的字段或路径。
library;

import 'package:drift/drift.dart';

class RepositoryRoots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('TrackRow')
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get rootId => integer().references(RepositoryRoots, #id)();
  TextColumn get relPath => text()();
  TextColumn get path => text().unique()();
  TextColumn get title => text()();
  TextColumn get titleNorm => text()();
  TextColumn get artist => text()();
  TextColumn get artistNorm => text()();
  TextColumn get album => text()();
  TextColumn get albumNorm => text()();
  TextColumn get genre => text().withDefault(const Constant(''))();
  IntColumn get trackNo => integer().withDefault(const Constant(0))();

  /// 累计播放次数（record 历史时物化递增；常听面直读本列，
  /// 不再对 play_history 全表 GROUP BY——历史表随播放无限增长）。
  IntColumn get plays => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get contentHash => text().withDefault(const Constant(''))();
  TextColumn get audioFormat => text().withDefault(const Constant(''))();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get coverCheckedAt => dateTime().nullable()();
  DateTimeColumn get missingAt => dateTime().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  /// 元数据补全：true=歌手/歌名待反向重建；enrichedAt=补全完成时刻。
  BoolColumn get needsMeta => boolean().withDefault(const Constant(false))();
  DateTimeColumn get enrichedAt => dateTime().nullable()();

  /// 补全阶段完成时刻（结论性：匹配成功或确认无匹配都算已处理；
  /// 网络失败不打时刻——留待重试）。UI 阶段进度条据此直读，跨重启不丢。
  /// 专辑/音轨的来源只有 AcoustID releases（文字链无源，匹配成功也置
  /// 确认无——有值填值、无值结案，避免无限重试）。
  DateTimeColumn get titleMatchedAt => dateTime().nullable()();
  DateTimeColumn get artistMatchedAt => dateTime().nullable()();
  DateTimeColumn get lyricsAt => dateTime().nullable()();
  DateTimeColumn get albumMatchedAt => dateTime().nullable()();
  DateTimeColumn get trackMatchedAt => dateTime().nullable()();

  /// 连续硬失败次数（≥3 跳出待补全池；手动「开始补全」清零重试）。
  IntColumn get enrichAttempts => integer().withDefault(const Constant(0))();
}

@DataClassName('PlaylistRow')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get kind => textEnum<PlaylistKindCol>()();
  /// GitHub 拉取歌单：待提取曲目数（0=无待提取）。
  IntColumn get pending => integer().withDefault(const Constant(0))();
  /// 自定义歌单封面图片（应用沙箱内路径；null=用首曲封面/字块）。
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{name, kind}];
}

/// drift enum 列载体（domain 的 PlaylistKind 不 import 进 data 层）。
enum PlaylistKindCol { user, favorites }

class PlaylistTracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId => integer().references(Playlists, #id)();
  IntColumn get trackId => integer().references(Tracks, #id)();
  IntColumn get position => integer()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{playlistId, trackId}];
}

class PlayHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId => integer().references(Tracks, #id)();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

@DataClassName('LyricsMetaRow')
class LyricsMeta extends Table {
  IntColumn get trackId => integer().references(Tracks, #id)();
  /// none/sidecar/embedded/online/pasted
  TextColumn get kind => text().withDefault(const Constant('none'))();
  TextColumn get lrcPath => text().nullable()();
  IntColumn get offsetMs => integer().withDefault(const Constant(0))();
  BoolColumn get edited => boolean().withDefault(const Constant(false))();
  DateTimeColumn get fetchedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {trackId};
}

/// 音频嵌入向量（1:1 分表冷数据，与 lyrics_meta 同款模式）——不进 tracks 主行：
/// watch/get 物化整行，2-4KB blob 挂主表会让每次曲目列表查询都背着向量内存。
/// 再生缓存语义：模型重跑可重算，不进备份；vectorAt 记账保证跨重启续算。
@DataClassName('TrackVectorRow')
class TrackVectors extends Table {
  IntColumn get trackId => integer().references(Tracks, #id)();

  /// 嵌入模型标识（yamnet-1024-v1…）——向量没有模型版本就是死字节；
  /// 换模型按本列过滤重算，upsert 覆盖旧向量不混用。
  TextColumn get model => text()();
  IntColumn get dim => integer()();

  /// float32 LE 紧凑存（1024 维 = 4KB/首）——JSON 文本会膨胀 8-10 倍。
  BlobColumn get vec => blob()();
  DateTimeColumn get vectorAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {trackId};
}

/// 推理模型文件登记（模型文件管理域的记账面）。
/// 行存在 = 已就绪且 sha256 校验通过；文件本体在应用沙箱 models/ 目录，
/// 生命周期由 ModelStore 独占管理（data 层唯一所有权，inference 只消费路径）。
@DataClassName('ModelFileRow')
class ModelFiles extends Table {
  TextColumn get id => text()(); // 模型标识（kEmbeddingModel）
  TextColumn get url => text()(); // 下载源（记账/重下）
  TextColumn get sha256 => text()(); // 内容校验锚（与配置常量一致才复用）
  TextColumn get filePath => text()(); // 落盘绝对路径
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get readyAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get valueJson => text()();

  @override
  Set<Column> get primaryKey => {key};
}
