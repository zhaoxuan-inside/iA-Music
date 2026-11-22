/// 黑屏根因复现：v6 迁移回填 SQL 用了驼峰列名，drift 生成的是蛇形列名
/// ——迁移抛「no such column」→ 数据库打不开 → App 启动黑屏。
/// （模拟器外最强证据：同一语句对真实 schema 直接执行。）
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';

void main() {
  late IaDatabase db;

  setUp(() async {
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() => db.close());

  test('真实 schema：蛇形列名存在，驼峰列名不存在', () async {
    final cols = await db.customSelect('PRAGMA table_info(tracks)').get();
    final names = [for (final r in cols) r.data['name'] as String];
    expect(names.contains('title_matched_at'), isTrue);
    expect(names.contains('artist_matched_at'), isTrue);
    expect(names.contains('lyrics_at'), isTrue);
    expect(names.contains('titleMatchedAt'), isFalse,
        reason: 'drift 生成蛇形列名——驼峰回填 SQL 必然 no such column');
  });

  test('复现黑屏：v6 原回填语句（驼峰）在真实 schema 上抛错', () async {
    Object? caught;
    try {
      await db.customStatement(
          'UPDATE tracks SET titleMatchedAt = CURRENT_TIMESTAMP, '
          'artistMatchedAt = CURRENT_TIMESTAMP, lyricsAt = CURRENT_TIMESTAMP '
          'WHERE enrichedAt IS NOT NULL');
    } on Object catch (e) {
      caught = e;
    }
    expect(caught, isNotNull, reason: 'no such column → 迁移失败 → 启动黑屏');
    expect('$caught', contains('column'));
  });

  test('修复后语句（蛇形）在真实 schema 上成功执行', () async {
    await db.customStatement(
        'UPDATE tracks SET title_matched_at = CURRENT_TIMESTAMP, '
        'artist_matched_at = CURRENT_TIMESTAMP, lyrics_at = CURRENT_TIMESTAMP '
        'WHERE enriched_at IS NOT NULL');
  });
}
