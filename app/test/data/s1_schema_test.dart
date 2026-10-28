// S1 数据契约底座行为测试（DEC-010：drift 内存库=真 sqlite3 引擎）
//
// 覆盖：
//  1) 17 表 + FTS 全建（§1.2）
//  2) FTS 拼音双列同事务写 + MATCH（D9-1 / REQ-NAV-04）
//  3) EXPLAIN QUERY PLAN 抽查 3 条（§1.3：dup 检测/歌单浏览/历史分组）
//  4) 迁移回退门演练：表缺失→只读兜底+引导文案（§1.4）
//  5) 部分唯一约束：system_favorite 单行 / active 通道单行（DB 级红规）
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('S1 schema v1', () {
    late IaDbGate gate;
    setUp(() async {
      gate = await openIaDatabaseMemory();
    });
    tearDown(() async {
      await gate.db.close();
    });

    test('17 表 + track_index 全建（§1.2 十四表展开）', () async {
      final rows = await gate.db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      ).get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      for (final t in [
        'repository_roots', 'artists', 'albums', 'tracks', 'playlists',
        'playlist_tracks', 'play_history', 'few_watch_list', 'lyrics_meta',
        'lyrics_gen_jobs', 'extract_tasks', 'sync_channel', 'last_sync_state',
        'tombstones', 'conflict_copies', 'settings', 'model_registry',
      ]) {
        expect(names, contains(t), reason: '缺表 $t');
      }
      expect(names, contains('track_index'));
    });

    test('FTS 拼音双列：同事务写 + 全拼/首字母命中（REQ-NAV-04）', () async {
      final db = gate.db;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.transaction(() async {
        final root = await db.into(db.repositoryRoots).insert(
              RepositoryRootsCompanion.insert(
                path: 'E:/music',
                mode: RepositoryMode.directory,
                addedAt: now,
              ),
            );
        final trackId = await db.into(db.tracks).insert(TracksCompanion.insert(
          rootId: root,
          relPath: 'A/夜黑雾.flac',
          title: const Value('夜黑雾'),
          artistDisplay: const Value('声无哀乐'),
          albumDisplay: const Value('奇谈物语'),
          durationMs: const Value(240000),
          audioFormat: AudioFormatSpec.flac,
          fileSize: 12345678,
          mtime: now,
          contentHash: 'hash-1',
          addedAt: now,
          updatedAt: now,
        ));
        await db.updateTrackIndex(
          trackId,
          title: '夜黑雾',
          artist: '声无哀乐',
          album: '奇谈物语',
        );
      });

      // 汉字前缀命中（unicode61 全段 token + 前缀）
      final byHanzi = await gate.db
          .customSelect("SELECT rowid FROM tracks_fts WHERE tracks_fts MATCH 'title: 夜黑*'")
          .get();
      expect(byHanzi.map((r) => r.read<int>('rowid')), contains(1));

      // 拼音首字母 yhw/swal/qtwy（pinyin_initials 前缀）
      final initials = await db
          .customSelect("SELECT rowid FROM tracks_fts WHERE tracks_fts MATCH 'pinyin_initials: yhw*'")
          .get();
      expect(initials.map((r) => r.read<int>('rowid')), contains(1));

      // 全拼短语（pinyin_full）
      final full = await db
          .customSelect("SELECT rowid FROM tracks_fts WHERE tracks_fts MATCH 'pinyin_full: \"ye hei wu\"'")
          .get();
      expect(full.map((r) => r.read<int>('rowid')), contains(1));

      // 同事务纪律：FTS 行与锚定行一致
      final anchor = await db
          .customSelect('SELECT count(*) c FROM track_index')
          .getSingle();
      expect(anchor.read<int>('c'), 1);
      final ftsCount = await db
          .customSelect('SELECT count(*) c FROM tracks_fts')
          .getSingle();
      expect(ftsCount.read<int>('c'), 1);
    });

    test('EXPLAIN QUERY PLAN ①：dup 检测走 idx_track_source（REQ-EXT-06）', () async {
      final plan = await gate.db
          .customSelect("EXPLAIN QUERY PLAN SELECT id FROM tracks WHERE source_type='bilibili' AND source_id='BV1xx'")
          .get();
      final detail = plan.map((r) => r.read<String>('detail')).join('|');
      expect(detail, contains('idx_track_source'));
    });

    test('EXPLAIN QUERY PLAN ②：歌单浏览走 idx_pt_pos（REQ-PL-04/06）', () async {
      final plan = await gate.db
          .customSelect('EXPLAIN QUERY PLAN SELECT id FROM playlist_tracks WHERE playlist_id=1 ORDER BY position')
          .get();
      final detail = plan.map((r) => r.read<String>('detail')).join('|');
      expect(detail, contains('idx_pt_pos'));
    });

    test('EXPLAIN QUERY PLAN ③：历史分组走 idx_history_played DESC（REQ-PL-05）', () async {
      final plan = await gate.db
          .customSelect('EXPLAIN QUERY PLAN SELECT id FROM play_history ORDER BY played_at DESC LIMIT 10')
          .get();
      final detail = plan.map((r) => r.read<String>('detail')).join('|');
      expect(detail, contains('idx_history_played'));
    });

    test('DB 级红规①：system_favorite 仅一行（部分唯一）', () async {
      final db = gate.db;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.playlists).insert(
              PlaylistsCompanion.insert(
                kind: PlaylistKind.system_favorite, name: '收藏', createdAt: now, updatedAt: now),
          );
      await expectLater(
        db.into(db.playlists).insert(
              PlaylistsCompanion.insert(
                    kind: PlaylistKind.system_favorite,
                    name: '重复收藏',
                    createdAt: now,
                    updatedAt: now),
            ),
        throwsA(anything),
      );
    });

    test('DB 级红规②：active 同步通道恰一行（C44）', () async {
      final db = gate.db;
      await db.into(db.syncChannel).insert(
            SyncChannelCompanion.insert(
              type: SyncChannelType.webdav,
              baseUrl: 'https://dav.example.com',
              credentialsRef: const Value('webdav.creds'),
              isActive: const Value(true),
            ),
          );
      await expectLater(
        db.into(db.syncChannel).insert(
              SyncChannelCompanion.insert(
                type: SyncChannelType.github,
                baseUrl: 'https://api.github.com',
                credentialsRef: const Value('gh.token'),
                isActive: const Value(true),
              ),
            ),
        throwsA(anything),
      );
    });
  });

  group('S1 迁移回退门演练（§1.4）', () {
    test('期望表缺失 → 只读兜底 + 引导文案 + 写被拒', () async {
      final tmp = Directory.systemTemp.createTempSync('ia_db_gate_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final path = '${tmp.path}${Platform.pathSeparator}db.sqlite3';

      // 制造「schema 校验失败」现场：合法 sqlite 但表集不符（缺 3 张表）
      final raw = sqlite3.open(path);
      raw.execute('PRAGMA user_version=1');
      raw.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT, updated_at INT)');
      raw.close();

      final gate = await openIaDatabase(path);
      expect(gate.isReadOnlyGate, isTrue, reason: '校验失败必须转入只读回退门');
      expect(gate.gateCopy, contains('只读保护'));

      // 只读：SELECT 可行
      await gate.db.customSelect('SELECT 1').getSingle();

      // 只读：写操作被拒（不闪退——由调用方捕获呈现）
      await expectLater(
        gate.db.customStatement('CREATE TABLE x(id INTEGER)'),
        throwsA(anything),
      );
      await gate.db.close();
      final preserved = sqlite3.open(path, mode: OpenMode.readOnly);
      expect(preserved.select('PRAGMA user_version').first.values.first, 1,
          reason: '只读保护不能升级或改写异常库的版本');
      preserved.close();
    });

    test('干净文件 → 正常路径（非只读）', () async {
      final tmp = Directory.systemTemp.createTempSync('ia_db_ok_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final path = '${tmp.path}${Platform.pathSeparator}db.sqlite3';

      final gate = await openIaDatabase(path);
      expect(gate.isReadOnlyGate, isFalse);
      final v = await gate.db.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), kIaSchemaVersion);
      await gate.db.close();
    });
  });
}
