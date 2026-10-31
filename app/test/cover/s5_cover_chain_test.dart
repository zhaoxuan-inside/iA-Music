import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/cover_fetch_adapter.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/cover_chain.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('C22 同名图优先：真库注册且真 HTTP 外呼为零，音频字节不变', () async {
    final dir = await Directory.systemTemp.createTemp('ia_s5_');
    final db = (await openIaDatabaseMemory()).db;
    final fetch = CoverFetchAdapter();
    final chain = CoverChain(DataAccess(db), fetch);
    addTearDown(() async {
      fetch.close();
      await db.close();
      await dir.delete(recursive: true);
    });
    final audio = await File('test/fixtures/library_smoke/探曲03.mp3')
        .copy('${dir.path}/song.mp3');
    await File('test/fixtures/cover/local.jpg').copy('${dir.path}/song.jpg');
    final before = await audio.readAsBytes();
    final root = await db
        .into(db.repositoryRoots)
        .insert(
          RepositoryRootsCompanion.insert(
            path: dir.path,
            mode: RepositoryMode.directory,
            addedAt: 1,
          ),
        );
    final id = await DataAccess(db).library.insertTrackWithIndex(
      root,
      'song.mp3',
      mtime: 1,
      fileSize: before.length,
      contentHash: 'real-fixture',
      nowMs: 1,
      title: '探曲03',
    );
    final result = await chain.decide(id);
    expect(result.kind, CoverKind.sibling);
    expect(result.localPath, '${dir.path}${Platform.pathSeparator}song.jpg');
    expect(fetch.requestCount, 0);
    expect(
      (await DataAccess(db).library.rowById(id))!.coverKind,
      CoverKind.sibling,
    );
    expect(await audio.readAsBytes(), before);
  });

  test('内嵌优先于同名图和缓存图；并发调用合流；重复浏览零外呼', () async {
    final dir = await Directory.systemTemp.createTemp('ia_s5_embedded_');
    final db = (await openIaDatabaseMemory()).db;
    final fetch = CoverFetchAdapter();
    final data = DataAccess(db);
    final chain = CoverChain(data, fetch);
    addTearDown(() async {
      fetch.close();
      await db.close();
      await dir.delete(recursive: true);
    });
    final audio = await File('test/fixtures/cover/embedded.mp3')
        .copy('${dir.path}/song.mp3');
    await File('test/fixtures/cover/local.jpg').copy('${dir.path}/song.jpg');
    await File('test/fixtures/cover/local.jpg').copy('${audio.path}.cover.jpg');
    final before = await audio.readAsBytes();
    final root = await db
        .into(db.repositoryRoots)
        .insert(
          RepositoryRootsCompanion.insert(
            path: dir.path,
            mode: RepositoryMode.directory,
            addedAt: 1,
          ),
        );
    final id = await data.library.insertTrackWithIndex(
      root,
      'song.mp3',
      mtime: 1,
      fileSize: before.length,
      contentHash: 'real-embedded',
      nowMs: 1,
      title: '探曲03',
    );
    final first = chain.decide(id);
    expect(identical(first, chain.decide(id)), isTrue);
    expect((await first).kind, CoverKind.embedded);
    expect(
      (await chain.decide(id)).bytes,
      await File('test/fixtures/cover/local.jpg').readAsBytes(),
    );
    expect(fetch.requestCount, 0);
    final row = (await data.library.rowById(id))!;
    expect(row.coverKind, CoverKind.embedded);
    expect(row.coverRelPath, isNull);
    expect(row.title, '探曲03');
    expect(row.contentHash, 'real-embedded');
    expect(row.updatedAt, 1);
    expect(await audio.readAsBytes(), before);
  });

  test('缓存落盘图优先联网；新同名图替换缓存注册位；关闭抓取静默色块', () async {
    final dir = await Directory.systemTemp.createTemp('ia_s5_cache_');
    final db = (await openIaDatabaseMemory()).db;
    final fetch = CoverFetchAdapter();
    final data = DataAccess(db);
    final chain = CoverChain(data, fetch);
    addTearDown(() async {
      fetch.close();
      await db.close();
      await dir.delete(recursive: true);
    });
    await File('test/fixtures/library_smoke/探曲03.mp3')
        .copy('${dir.path}/song.mp3');
    final cached = await File('test/fixtures/cover/local.jpg')
        .copy('${dir.path}/song.mp3.cover.jpg');
    final root = await db
        .into(db.repositoryRoots)
        .insert(
          RepositoryRootsCompanion.insert(
            path: dir.path,
            mode: RepositoryMode.directory,
            addedAt: 1,
          ),
        );
    final id = await data.library.insertTrackWithIndex(
      root,
      'song.mp3',
      mtime: 1,
      fileSize: 1,
      contentHash: 'cache-fixture',
      nowMs: 1,
      title: '探曲03',
    );
    expect((await chain.decide(id)).kind, CoverKind.fetched);
    final sibling = await File('test/fixtures/cover/local.jpg')
        .copy('${dir.path}/song.png');
    expect((await chain.decide(id)).kind, CoverKind.sibling);
    await sibling.delete();
    await cached.delete();
    await data.shell.put(CoverChain.onlineSettingKey, 'false', nowMs: 2);
    expect((await chain.decide(id)).kind, CoverKind.none);
    expect(fetch.requestCount, 0);
    expect((await data.library.rowById(id))!.coverKind, CoverKind.none);
  });

  test('真实 v1 库迁移 v2：封面列补齐，旧曲目和 FTS 保留', () async {
    final dir = await Directory.systemTemp.createTemp('ia_s5_migrate_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/library.sqlite';
    var db = (await openIaDatabase(path)).db;
    final data = DataAccess(db);
    final root = await db
        .into(db.repositoryRoots)
        .insert(
          RepositoryRootsCompanion.insert(
            path: dir.path,
            mode: RepositoryMode.directory,
            addedAt: 1,
          ),
        );
    final id = await data.library.insertTrackWithIndex(
      root,
      'song.mp3',
      mtime: 1,
      fileSize: 1,
      contentHash: 'migration',
      nowMs: 1,
      title: '旧曲',
    );
    await db.close();
    final raw = sqlite3.open(path);
    for (final column in ['cover_kind', 'cover_rel_path', 'cover_checked_at']) {
      raw.execute('ALTER TABLE tracks DROP COLUMN $column');
    }
    raw.execute('PRAGMA user_version=1');
    raw.close();
    db = (await openIaDatabase(path)).db;
    final row = await DataAccess(db).library.rowById(id);
    expect(row!.title, '旧曲');
    expect(row.coverKind, isNull);
    // WS6 schema v3：迁移链走到当前版本（v1→v2→v3 全链；kIaSchemaVersion）。
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      kIaSchemaVersion,
    );
    expect(
      (await db
              .customSelect(
                "SELECT rowid FROM tracks_fts WHERE tracks_fts MATCH '旧曲'",
              )
              .get())
          .length,
      1,
    );
    await db.close();
  });
}
