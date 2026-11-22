/// 本地扫描全链路：真实文件 + 内存 DB（不依赖 Android）。
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/entities/track.dart';
import 'package:ia_music/services/scan/scan_service.dart';

void main() {
  late IaDatabase db;

  setUp(() async {
    db = IaDatabase.connect(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
  });

  tearDown(() async => db.close());

  test('嵌套 Artist/Album 目录也能识别（回归）', () async {
    final tmp = Directory.systemTemp.createTempSync('ia_scan_nested');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final nested = Directory('${tmp.path}/Artist/Album')
      ..createSync(recursive: true);
    File('test/fixtures/library_smoke/探曲01.mp3')
        .copySync('${nested.path}/01.mp3');

    final rootId = await db.libraryDao.addRoot(tmp.path);
    final summary = await ScanService(db).scanRoot(rootId, tmp.path);

    expect(summary.inserted, 1);
    final tracks =
        await db.libraryDao.watchTracks(sort: TrackSort.title).first;
    expect(tracks.single.title, '探曲01');
    expect(tracks.single.artistDisplay, '测试歌手A');
  });

  test('扫描 fixtures：有效音频入库，损坏探针跳过', () async {
    final dir = Directory('test/fixtures/library_smoke').absolute;
    expect(dir.existsSync(), isTrue);
    final rootId = await db.libraryDao.addRoot(dir.path);

    final summary = await ScanService(db).scanRoot(rootId, dir.path);

    // 01-10 是有效音频；10_broken_probe / 11_empty_probe 应被跳过。
    expect(summary.inserted, 10,
        reason: '01-10 共 10 首有效音频；损坏探针应跳过');
    // 损坏件从此可计数、原因带文件名（曾经静默消失，只能靠数量对不上发现）
    expect(summary.failedFiles, 2, reason: '两个损坏探针');
    expect(summary.failedSamples, hasLength(2));
    expect(summary.failedSamples.join('\n'), contains('probe'),
        reason: '失败原因带文件名（日志可定位）');
    final tracks = await db.libraryDao.watchTracks(sort: TrackSort.title).first;
    expect(tracks, hasLength(10));
    // ignore: avoid_print
    print(tracks.map((t) => '${t.title} / ${t.artistDisplay} / ${t.albumDisplay}').join('\n'));
  });
}
