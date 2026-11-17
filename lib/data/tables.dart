/// drift 表定义（schema v1 全新起始；v2 无迁移链）。
///
/// 设计要点：
/// * 分组用 norm 列（小写折叠）GROUP BY 聚合，不再建 artists/albums 字典表。
/// * FTS 虚拟表 `track_index` 在 database.dart 迁移里创建，DAO 显式同事务维护。
/// * 元数据只读红线：本库不含任何"写回原文件"的字段或路径。
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

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get valueJson => text()();

  @override
  Set<Column> get primaryKey => {key};
}
