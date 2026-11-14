/// drift 数据库（schema v3：v2 + tracks.needsMeta/enrichedAt；库文件 ia_music_v2.db）。
/// 收集任务（CollectTasks）与 v3 列同批引入。
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/collect_dao.dart';
import 'daos/history_dao.dart';
import 'daos/library_dao.dart';
import 'daos/playlist_dao.dart';
import 'daos/settings_dao.dart';
import 'tables.dart';

export 'daos/collect_dao.dart';
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
    CollectTasks,
  ],
  daos: [LibraryDao, PlaylistDao, HistoryDao, CollectDao, LyricsDao, SettingsDao],
)
class IaDatabase extends _$IaDatabase {
  IaDatabase(super.e);

  /// 测试/诊断：内存库或自定义执行器。
  IaDatabase.connect(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(kFtsDdl);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2：tracks.genre（真实标签解析入库；无标签为空串）
            //    + playlists.pending（GitHub 拉取歌单待提取数）
            //    + collect_tasks（GitHub 歌单拉取/提取队列，落库）
            await m.addColumn(tracks, tracks.genre);
            await m.addColumn(playlists, playlists.pending);
            await m.createTable(collectTasks);
          }
          if (from < 3) {
            // v3：元数据补全（根据歌曲时长反向重建 歌名/歌手/歌词）
            await m.addColumn(tracks, tracks.needsMeta);
            await m.addColumn(tracks, tracks.enrichedAt);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// 应用执行器（bundled sqlite；drift_flutter 按端取 applicationSupport）。
QueryExecutor openAppDatabase() => driftDatabase(name: 'ia_music_v2');
