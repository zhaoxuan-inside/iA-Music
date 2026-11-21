/// drift 数据库（schema v4：v3 + playlists.coverPath；库文件 ia_music_v2.db）。
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
  int get schemaVersion => 6;

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
          if (from < 4) {
            // v4：歌单自定义封面
            await m.addColumn(playlists, playlists.coverPath);
          }
          if (from < 5) {
            // v5：播放次数物化（常听面不再全表聚合）+ 历史计数回填
            await m.addColumn(tracks, tracks.plays);
            await customStatement(
                'UPDATE tracks SET plays = '
                '(SELECT COUNT(*) FROM play_history WHERE track_id = tracks.id)');
          }
          if (from < 6) {
            // v6：补全三阶段时刻（进度持久化，跨重启不从头）；
            //     旧管线已补全的行按已处理回填。
            await m.addColumn(tracks, tracks.titleMatchedAt);
            await m.addColumn(tracks, tracks.artistMatchedAt);
            await m.addColumn(tracks, tracks.lyricsAt);
            await m.addColumn(tracks, tracks.enrichAttempts);
            await customStatement(
                'UPDATE tracks SET titleMatchedAt = CURRENT_TIMESTAMP, '
                'artistMatchedAt = CURRENT_TIMESTAMP, lyricsAt = CURRENT_TIMESTAMP '
                'WHERE enrichedAt IS NOT NULL');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // 历史域索引：最近列表按时间倒序、计数按 track 归组（IF NOT
          // EXISTS 幂等；覆盖老库升级与全新安装两种路径）。
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_history_played_at '
              'ON play_history (played_at)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_history_track '
              'ON play_history (track_id)');
        },
      );
}

/// 应用执行器（bundled sqlite；drift_flutter 按端取 applicationSupport）。
QueryExecutor openAppDatabase() => driftDatabase(name: 'ia_music_v2');
