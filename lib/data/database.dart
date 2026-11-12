/// drift 数据库（schema v1 全新起始；库文件 ia_music_v2.db 与 v1 隔离）。
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/history_dao.dart';
import 'daos/library_dao.dart';
import 'daos/playlist_dao.dart';
import 'daos/settings_dao.dart';
import 'tables.dart';

export 'daos/history_dao.dart';
export 'daos/library_dao.dart';
export 'daos/playlist_dao.dart';
export 'daos/settings_dao.dart';

part 'database.g.dart';

/// FTS 五列全文索引（unicode61；CJK 拆分与拼音双列由 DAO 写入侧完成）。
const String kFtsDdl =
    'CREATE VIRTUAL TABLE IF NOT EXISTS track_index USING fts5('
    'track_id UNINDEXED, title, artist, album, pinyin_full, pinyin_initials, '
    "tokenize='unicode61')";

@DriftDatabase(
  tables: [
    RepositoryRoots,
    Tracks,
    Playlists,
    PlaylistTracks,
    PlayHistory,
    LyricsMeta,
    Settings,
  ],
  daos: [LibraryDao, PlaylistDao, HistoryDao, LyricsDao, SettingsDao],
)
class IaDatabase extends _$IaDatabase {
  IaDatabase(super.e);

  /// 测试/诊断：内存库或自定义执行器。
  IaDatabase.connect(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(kFtsDdl);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// 应用执行器（bundled sqlite；drift_flutter 按端取 applicationSupport）。
QueryExecutor openAppDatabase() => driftDatabase(name: 'ia_music_v2');
