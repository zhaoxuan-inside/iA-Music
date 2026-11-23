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
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(kFtsDdl);
        },
        onUpgrade: (m, from, to) async {
          // 幂等加列：失败迁移可能已加列但版本号未推进（黑屏修复场景），
          // 直接 addColumn 会撞 duplicate column——先 PRAGMA 查存在性。
          Future<void> ensureCol(
              String table, String column, String ddl) async {
            final rows = await customSelect('PRAGMA table_info($table)').get();
            final names = [for (final r in rows) r.data['name'] as String];
            if (!names.contains(column)) {
              await customStatement('ALTER TABLE $table ADD COLUMN $ddl');
            }
          }

          if (from < 5) {
            // v5：播放次数物化（常听面不再全表聚合）+ 历史计数回填
            await ensureCol('tracks', 'plays',
                'plays INTEGER NOT NULL DEFAULT 0');
            await customStatement(
                'UPDATE tracks SET plays = '
                '(SELECT COUNT(*) FROM play_history WHERE track_id = tracks.id)');
          }
          if (from < 6) {
            // v6：补全三阶段时刻（进度持久化，跨重启不从头）；
            //     旧管线已补全的行按已处理回填。
            //     列名必须用 drift 生成的蛇形名（title_matched_at…）——
            //     驼峰会让迁移抛 no such column，数据库打不开 → 启动黑屏。
            await ensureCol('tracks', 'title_matched_at',
                'title_matched_at INTEGER');
            await ensureCol('tracks', 'artist_matched_at',
                'artist_matched_at INTEGER');
            await ensureCol('tracks', 'lyrics_at', 'lyrics_at INTEGER');
            await ensureCol('tracks', 'enrich_attempts',
                'enrich_attempts INTEGER NOT NULL DEFAULT 0');
            // drift DateTime 默认存整数秒——回填必须写 int（CURRENT_TIMESTAMP
            // 是文本，读回会解析失败）。
            await customStatement(
                'UPDATE tracks SET '
                'title_matched_at = CAST(strftime(\'%s\',\'now\') AS INTEGER), '
                'artist_matched_at = CAST(strftime(\'%s\',\'now\') AS INTEGER), '
                'lyrics_at = CAST(strftime(\'%s\',\'now\') AS INTEGER) '
                'WHERE enriched_at IS NOT NULL');
          }
          if (from < 7) {
            // v7：收集任务失败原因原文——提取失败从「只标 failed 无处可查」
            // 到任务行可见 + 日志追踪可复制；重排（重试/僵尸回收）时清空。
            // 极老库可能缺 collect_tasks 表：createAll 幂等建表（IF NOT
            // EXISTS）后再加列，否则 ALTER 撞 no such table。
            await m.createAll();
            await ensureCol('collect_tasks', 'error_text', 'error_text TEXT');
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
          // 曲库域索引：此前 tracks 只有主键/唯一路径两个索引，下列查询
          // 全是全表扫——按根扫描 diff（root_id）、缺失行过滤（missing_at）、
          // 常听面排序（plays）、补全池选取与计数（needs_meta+enriched_at）。
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_tracks_root '
              'ON tracks (root_id)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_tracks_missing '
              'ON tracks (missing_at)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_tracks_plays '
              'ON tracks (plays)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_tracks_enrich '
              'ON tracks (needs_meta, enriched_at)');
          // 收集域：队列状态机查询（pending/running/failed 各态选取）。
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_collect_status '
              'ON collect_tasks (status)');
        },
      );
}

/// 应用执行器（bundled sqlite；drift_flutter 按端取 applicationSupport）。
QueryExecutor openAppDatabase() => driftDatabase(name: 'ia_music_v2');
