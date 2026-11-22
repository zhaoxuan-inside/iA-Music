/// 迁移升级真测试：手工构建 v4 旧库（含既有补全行）→ drift 打开触发
/// 4→6 迁移 → 断言列存在 / 回填生效 / 二次打开幂等（黑屏修复的端到端防线）。
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;
  late File dbFile;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('ia_migration_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    dbFile = File('${dir.path}${Platform.pathSeparator}app.db');

    // 手工搭建 v4 形态的库：tracks 少 v5/v6 新列，play_history 照旧；
    // 一行旧补全记录（enriched_at 非空）验证回填；user_version = 4。
    final raw = sqlite3.open(dbFile.path);
    raw.execute('CREATE TABLE tracks ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'root_id INTEGER NOT NULL, '
        'rel_path TEXT NOT NULL, '
        'path TEXT NOT NULL UNIQUE, '
        'title TEXT NOT NULL, title_norm TEXT NOT NULL, '
        'artist TEXT NOT NULL, artist_norm TEXT NOT NULL, '
        'album TEXT NOT NULL, album_norm TEXT NOT NULL, '
        'genre TEXT NOT NULL DEFAULT \'\', '
        'track_no INTEGER NOT NULL DEFAULT 0, '
        'duration_ms INTEGER NOT NULL DEFAULT 0, '
        'size_bytes INTEGER NOT NULL DEFAULT 0, '
        'content_hash TEXT NOT NULL DEFAULT \'\', '
        'audio_format TEXT NOT NULL DEFAULT \'\', '
        'cover_path TEXT, cover_checked_at INTEGER, '
        'missing_at INTEGER, added_at INTEGER NOT NULL, '
        'needs_meta INTEGER NOT NULL DEFAULT 0, '
        'enriched_at INTEGER)');
    raw.execute('CREATE TABLE play_history ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'track_id INTEGER NOT NULL REFERENCES tracks(id), '
        'played_at INTEGER NOT NULL, '
        'completed INTEGER NOT NULL DEFAULT 0)');
    raw.execute('INSERT INTO tracks (root_id, rel_path, path, title, title_norm,'
        ' artist, artist_norm, album, album_norm, added_at, needs_meta, enriched_at)'
        " VALUES (1, 'a.mp3', '/music/a.mp3', '旧歌', '旧歌', '歌手', '歌手',"
        " '专辑', '专辑', strftime('%s','now'), 0, strftime('%s','now'))");
    raw.execute('PRAGMA user_version = 4');
    raw.close();
  });

  Future<List<String>> trackColumns(IaDatabase db) async {
    final cols = await db.customSelect('PRAGMA table_info(tracks)').get();
    return [for (final r in cols) r.data['name'] as String];
  }

  test('v4 → v7：加列幂等、回填生效、二次打开不炸', () async {
    final db = IaDatabase.connect(NativeDatabase(dbFile));
    // 迁移已在打开时执行
    final cols = await trackColumns(db);
    expect(cols, containsAll([
      'plays',
      'title_matched_at',
      'artist_matched_at',
      'lyrics_at',
      'enrich_attempts',
    ]));

    // v7：collect_tasks 表缺失时 createAll 幂等补建，error_text 到位
    final taskCols = await db.customSelect('PRAGMA table_info(collect_tasks)').get();
    expect([for (final r in taskCols) r.data['name']], contains('error_text'),
        reason: '夹具 v4 无 collect_tasks——迁移须幂等补表再加列');

    // 回填：旧行三阶段时刻已写（整数秒）且非空
    final row = await db
        .customSelect('SELECT title_matched_at, plays FROM tracks')
        .get()
        .then((rows) => rows.single);
    expect(row.data['title_matched_at'], isA<int>(),
        reason: 'drift DateTime 存整数秒，文本会读崩');
    expect(row.data['plays'], 0, reason: '旧行无播放历史');

    // 二次打开：幂等（ensureCol + 回填重跑不炸）
    await db.close();
    final db2 = IaDatabase.connect(NativeDatabase(dbFile));
    expect(await trackColumns(db2), containsAll(['title_matched_at']));
    await db2.close();
  });

  test('全新安装：onCreate 直接 v7 schema，无迁移路径', () async {
    final db = IaDatabase.connect(NativeDatabase.memory());
    final cols = await trackColumns(db);
    expect(cols, containsAll(['title_matched_at', 'enrich_attempts']));
    await db.close();
  });
}
