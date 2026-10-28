/// iA-Music 数据库装配（S1）：schema v2 + FTS5 + 迁移回退门（DETAILED-DESIGN §1.4）。
///
/// * drift 唯一持久层（ARCHITECTURE §2.2 单一写入路径）。
/// * 回退门：schema 校验失败 → 只读连接 + 壳层引导文案（不闪退、不丢数据）。
/// * FTS 写与业务事务同批（DEC-009 D9-1）：调用方必在 `transaction` 内使用
///   [IaDatabase.updateTrackIndex]。
/// * v2（S5 封面链）：tracks 增 coverKind/coverRelPath/coverCheckedAt 注册位。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:pinyin/pinyin.dart';
import 'package:sqlite3/sqlite3.dart';

import 'tables.dart';

part 'ia_database.g.dart';

const int kIaSchemaVersion = 2;

/// 校验期望的表集合（17 表 + FTS 锚定表 track_index；tracks_fts 为虚拟表另行查）。
const List<String> _kExpectedTables = [
  'repository_roots', 'artists', 'albums', 'tracks',
  'playlists', 'playlist_tracks', 'play_history', 'few_watch_list',
  'lyrics_meta', 'lyrics_gen_jobs', 'extract_tasks',
  'sync_channel', 'last_sync_state', 'tombstones', 'conflict_copies',
  'settings', 'model_registry', 'track_index',
];

/// 仅注解索引无法表达的 DDL（§1.2/§1.3 落地）。
const List<String> kExtraDdl = [
  // FTS 外部内容锚定表（rowid 对齐 tracks.id；含 pinyin 双列——外部内容模式
  // 全行投影按 content 表列名回查，故 pinyin_full/initials 必须在锚定表同名存在）
  'CREATE TABLE IF NOT EXISTS track_index ('
      'id INTEGER NOT NULL PRIMARY KEY, '
      "title TEXT NOT NULL DEFAULT '', "
      "artist TEXT NOT NULL DEFAULT '', "
      "album TEXT NOT NULL DEFAULT '', "
      "pinyin_full TEXT NOT NULL DEFAULT '', "
      "pinyin_initials TEXT NOT NULL DEFAULT '')",
  // FTS5：标题/歌手/专辑 + 拼音全拼/首字母双列（DEC-009 D9-1）
  'CREATE VIRTUAL TABLE IF NOT EXISTS tracks_fts USING fts5('
      "title, artist, album, pinyin_full, pinyin_initials, "
      "content='track_index', content_rowid='id')",
  // system_favorite 仅一行（REQ-PL-01 收藏夹）
  "CREATE UNIQUE INDEX IF NOT EXISTS uq_playlist_single_favorite "
      "ON playlists(kind) WHERE kind='system_favorite'",
  // MVP 单通道（C44）：active=TRUE 恰 1 行
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_sync_channel_single_active '
      'ON sync_channel(is_active) WHERE is_active=1',
  // 历史分组（REQ-PL-05）：DESC 表达式索引
  'CREATE INDEX IF NOT EXISTS idx_history_played '
      'ON play_history(played_at DESC)',
];

/// schema 校验失败（回退门入口）。
class SchemaGateException implements Exception {
  const SchemaGateException(this.message, {this.detail});

  final String message;

  /// 校验时的技术细节（quick_check 输出/缺失表列表）。
  final String? detail;

  @override
  String toString() => 'SchemaGateException: $message${detail == null ? '' : ' [$detail]'}';
}

const String kRecoveryHint =
    '数据库打开异常：已进入只读保护，你的数据未丢失；请在设置的「修复引导」中处理。';

/// 打开结果：db + 是否处于回退门（只读）。
class IaDbGate {
  const IaDbGate._(this.db, this.isReadOnlyGate);

  final IaDatabase db;
  final bool isReadOnlyGate;

  /// 组装回退门文案（壳层直接展示）。
  String get gateCopy => kRecoveryHint;
}

/// 打开数据库；正常路径失败→只读兜底重开（§1.4 回退门）。
///
/// 若只读兜底也失败（如文件非 SQLite），直接上抛——由壳层停止页兜底。
Future<IaDbGate> openIaDatabase(String path) async {
  await File(path).parent.create(recursive: true);

  // 原始 sqlite3 预检（仅对已存在文件）：表集不符/损坏 → 直接走只读分支。
  // （避免「drift 半开实例持有文件锁」：drift 首查才触开，beforeOpen 抛出后
  //  底层句柄可能未随 close 释放——Windows 上锁住临时目录。）
  if (await File(path).exists()) {
    if (!_rawSchemaOk(path)) {
      return _openReadOnlyGate(path);
    }
  }

  final db = IaDatabase(_nativeFileRw(path));
  try {
    await _forceOpen(db);
    return IaDbGate._(db, false);
  } on SchemaGateException {
    try {
      await db.close();
    } catch (_) {
      // 原连接关闭失败不掩盖回退门语义
    }
    return _openReadOnlyGate(path);
  }
}

/// 原始引擎预检（quick_check + 期望表计数；与 drift 校验同一语义）。
bool _rawSchemaOk(String path) {
  final raw = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    final quick = raw.select('PRAGMA quick_check').first.values.first;
    if (quick != 'ok') {
      return false;
    }
    final placeholders = List.filled(_kExpectedTables.length, '?').join(',');
    final stmt = raw.prepare(
      "SELECT count(*) FROM sqlite_master WHERE type='table' AND name IN ($placeholders)",
    );
    final n = stmt.select(_kExpectedTables).first.values.first as int? ?? 0;
    stmt.close();
    return n == _kExpectedTables.length;
  } catch (_) {
    return false;
  } finally {
    raw.close();
  }
}

Future<IaDbGate> _openReadOnlyGate(String path) async {
  final ro = IaDatabase(_nativeFileRo(path))..getsReadOnlyTreatment = true;
  try {
    await _forceOpen(ro);
    return IaDbGate._(ro, true);
  } catch (_) {
    try {
      await ro.close();
    } catch (_) {}
    rethrow;
  }
}

/// 内存库（测试/演练用；=真 sqlite3，DEC-010）。
Future<IaDbGate> openIaDatabaseMemory() async {
  final db = IaDatabase(NativeDatabase.memory(setup: (raw) {
    raw.execute('PRAGMA foreign_keys=ON');
  }));
  await _forceOpen(db);
  return IaDbGate._(db, false);
}

NativeDatabase _nativeFileRw(String path) => NativeDatabase(
      File(path),
      setup: (raw) {
        raw.execute('PRAGMA foreign_keys=ON');
        raw.select('PRAGMA journal_mode=WAL');
      },
    );

/// 只读连接：sqlite3.open(readOnly) + NativeDatabase.opened（drift 2.35 无 readOnly 形参）。
NativeDatabase _nativeFileRo(String path) {
  final raw = sqlite3.open(path, mode: OpenMode.readOnly);
  // Recovery must never run schema upgrades or write PRAGMA user_version.
  return NativeDatabase.opened(raw, enableMigrations: false, setup: (d) {
    d.execute('PRAGMA foreign_keys=ON');
  });
}

/// 强制触开（drift 懒加载；首个查询时执行 beforeOpen 校验链）。
Future<void> _forceOpen(IaDatabase db) async {
  await db.customSelect('SELECT 1').getSingle();
}

@DriftDatabase(tables: [
  RepositoryRoots,
  Artists,
  Albums,
  Tracks,
  Playlists,
  PlaylistTracks,
  PlayHistory,
  FewWatchList,
  LyricsMeta,
  LyricsGenJobs,
  ExtractTasks,
  SyncChannel,
  LastSyncState,
  Tombstones,
  ConflictCopies,
  Settings,
  ModelRegistry,
])
class IaDatabase extends _$IaDatabase {
  IaDatabase(super.executor);

  /// 只读门标记：构造后、首查询前置位（beforeOpen 决定是否跳过 WAL 设置）。
  bool getsReadOnlyTreatment = false;

  @override
  int get schemaVersion => kIaSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          for (final ddl in kExtraDdl) {
            await customStatement(ddl);
          }
        },
        onUpgrade: (m, from, to) async {
          // §1.4：版本链只增；后续版本在此追加 step。
          if (to < from) {
            throw SchemaGateException('schema 版本回退被拒绝',
                detail: 'from=$from to=$to');
          }
          // v1 → v2（S5 封面链）：tracks 增封面注册位三列（§3.5「cover 状态列」）。
          // 兼容一期=新列可空并存（旧行 null → 展示决策回落到真源四分链）。
          if (from < 2) {
            await m.addColumn(tracks, tracks.coverKind);
            await m.addColumn(tracks, tracks.coverRelPath);
            await m.addColumn(tracks, tracks.coverCheckedAt);
          }
        },
        beforeOpen: (details) async {
          if (!getsReadOnlyTreatment) {
            await customStatement('PRAGMA foreign_keys=ON');
            await customStatement('PRAGMA journal_mode=WAL');
            await _validateSchema();
          }
          // 只读门连接（getsReadOnlyTreatment=true）：schema 已知异常态——
          // 校验由壳层「修复引导」跟进；此处只保证连接可用（可读/写被拒）。
        },
      );

  /// 校验：quick_check=ok + 期望表齐备；失败抛 SchemaGateException（回退门）。
  Future<void> _validateSchema() async {
    final quickRow =
        (await customSelect('PRAGMA quick_check').get()).first;
    final quick = quickRow.read<String>('quick_check');
    if (quick != 'ok') {
      throw SchemaGateException('quick_check 未通过', detail: quick);
    }
    final placeholders = List.filled(_kExpectedTables.length, '?').join(',');
    final rows = await customSelect(
      "SELECT count(*) AS c FROM sqlite_master "
      "WHERE type='table' AND name IN ($placeholders)",
      variables: _kExpectedTables.map(Variable.withString).toList(),
    ).getSingle();
    final found = rows.read<int>('c');
    if (found != _kExpectedTables.length) {
      throw SchemaGateException('期望表缺失（$found/${_kExpectedTables.length}）',
          detail: 'v$kIaSchemaVersion 期望 ${_kExpectedTables.join(',')}');
    }
  }

  // ── FTS 同步（D9-1：与 tracks 写同事务）────────────────────

  /// 与 tracks 写入同事务调用：更新锚定行并同步 FTS（拼音由 pinyin 包生成）。
  ///
  /// 分段语义（标题/歌手/专辑各自分词；FTS unicode61 下短语边界=空格）：
  /// * pinyin_full=各段全拼；pinyin_initials=各段首字母。
  static ({String pinyinFull, String pinyinInitials}) buildPinyin(
    String title,
    String artist,
    String album,
  ) {
    String full(String s) {
      final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
      return parts.map((p) {
        try {
          return PinyinHelper.getPinyin(p, separator: ' ');
        } on PinyinException {
          return p.toLowerCase(); // 未知字符（生僻/emoji）：保留原文小写进 FTS
        }
      }).join(' ');
    }

    String initials(String s) {
      final parts = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
      return parts.map((p) => PinyinHelper.getShortPinyin(p)).join(' ');
    }

    return (
      pinyinFull: '${full(title)} ${full(artist)} ${full(album)}'.trim(),
      pinyinInitials: '${initials(title)} ${initials(artist)} ${initials(album)}'.trim(),
    );
  }

  /// 更新一曲的索引（锚定行 upsert + FTS 增量同步）。
  ///
  /// 必须与 tracks 行写处于**同一事务**（禁则：FTS 漂写）。
  Future<void> updateTrackIndex(
    int trackId, {
    required String title,
    required String artist,
    required String album,
  }) async {
    final p = buildPinyin(title, artist, album);

    // 1) 旧锚定行存在 → 'delete' 命令必须携带与建立索引时**完全一致的全列值**
    //    （含 pinyin 两列——FTS5 外部内容表 delete 部分列=静默索引损坏，已实证）
    final old = await customSelect(
      'SELECT id FROM track_index WHERE id=?',
      variables: [Variable.withInt(trackId)],
    ).get();
    if (old.isNotEmpty) {
      await customStatement(
        "INSERT INTO tracks_fts(tracks_fts, rowid, title, artist, album, pinyin_full, pinyin_initials) "
        "SELECT 'delete', id, title, artist, album, pinyin_full, pinyin_initials FROM track_index WHERE id=?",
        [trackId],
      );
    }

    // 2) 锚定行 upsert（含拼音两列；与 tracks 写同事务）
    await customStatement(
      'INSERT INTO track_index(id, title, artist, album, pinyin_full, pinyin_initials) '
      'VALUES(?,?,?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET title=excluded.title, artist=excluded.artist, '
      'album=excluded.album, pinyin_full=excluded.pinyin_full, pinyin_initials=excluded.pinyin_initials',
      [trackId, title, artist, album, p.pinyinFull, p.pinyinInitials],
    );

    // 3) 新值入 FTS
    await customStatement(
      'INSERT INTO tracks_fts(rowid, title, artist, album, pinyin_full, pinyin_initials) '
      'VALUES(?,?,?,?,?,?)',
      [trackId, title, artist, album, p.pinyinFull, p.pinyinInitials],
    );
  }
}
