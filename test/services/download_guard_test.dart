/// download_guard 测试：泵字节计数 + 取消令牌（运行中暂停/删除的通道）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/services/collect/download_guard.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dl_guard_test');
    addTearDown(() => dir.delete(recursive: true));
  });

  test('泵：全量字节计数', () async {
    final tmp = File('${dir.path}/ok.bin');
    final sink = tmp.openWrite();
    final received = await pumpDownload(
      source: Stream<List<int>>.fromIterable([
        [1, 2, 3],
        [4, 5],
      ]),
      sink: sink,
      onChunk: null,
    );
    await sink.close();
    expect(received, 5);
    expect(tmp.lengthSync(), 5);
  });

  test('取消令牌：cancelled 触发 → 抛 CollectCancelledException（不再消费）', () async {
    final tmp = File('${dir.path}/cancel.bin');
    final sink = tmp.openWrite();
    var chunks = 0;
    var cancelled = false;
    await expectLater(
      pumpDownload(
        source: Stream<List<int>>.fromIterable([
          [1],
          [2],
          [3],
        ]),
        sink: sink,
        onChunk: (_) async {
          chunks++;
          if (chunks >= 2) {
            cancelled = true;
          }
        },
        cancelled: () => cancelled,
      ),
      throwsA(isA<CollectCancelledException>()),
    );
    await sink.close();
    expect(chunks, 2, reason: '第二个 chunk 后取消，后续不再消费');
  });

  test('未取消：cancelled 回调恒 false 不影响正常泵完', () async {
    final tmp = File('${dir.path}/nocancel.bin');
    final sink = tmp.openWrite();
    final received = await pumpDownload(
      source: Stream<List<int>>.fromIterable([
        [9],
      ]),
      sink: sink,
      onChunk: null,
      cancelled: () => false,
    );
    await sink.close();
    expect(received, 1);
  });
}
