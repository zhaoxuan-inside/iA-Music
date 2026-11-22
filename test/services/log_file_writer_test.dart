/// 日志文件写入器测试——追加保序、≤100MB 滚动（trace.log → trace.1.log）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/services/log/log_file_writer.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('log_writer_test');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  test('追加保序：多来源并发写入按提交顺序落盘', () async {
    final w = LogFileWriter(dir: dir.path);
    await Future.wait([
      w.writeLine('one'),
      w.writeLine('two'),
      w.writeLine('three'),
    ]);
    final content = await File(
        '${dir.path}${Platform.pathSeparator}trace.log')
        .readAsString();
    expect(content, 'one\ntwo\nthree\n');
  });

  test('滚动：超过上限 → trace.log 改名 trace.1.log，新文件从零开始', () async {
    final w = LogFileWriter(dir: dir.path, maxBytes: 24);
    await w.writeLine('AAAA'); // 5B
    await w.writeLine('BBBB'); // 10B
    await w.writeLine('CCCC'); // 15B
    await w.writeLine('DDDD'); // 20B
    await w.writeLine('EEEE'); // 25B ≥ 24 → 本次写完前不滚，下一条触发
    await w.writeLine('FFFF');

    final current =
        await File('${dir.path}${Platform.pathSeparator}trace.log')
            .readAsString();
    final backup =
        await File('${dir.path}${Platform.pathSeparator}trace.1.log')
            .readAsString();

    expect(current, 'FFFF\n', reason: '滚动后新文件只含最新内容');
    expect(backup, contains('AAAA'));
    expect(backup, contains('EEEE'), reason: '滚动前的全部内容进备份一代');
  });

  test('滚动只保留一代：两次滚动删除更旧备份', () async {
    final w = LogFileWriter(dir: dir.path, maxBytes: 10);
    await w.writeLine('AAAA'); // 5B
    await w.writeLine('BBBB'); // 10B → 达阈值，下一条滚
    await w.writeLine('CCCC'); // 滚：A→1.log；当前=CCCC
    await w.writeLine('DDDD'); // 5B
    await w.writeLine('EEEE'); // 10B → 达阈值
    await w.writeLine('FFFF'); // 滚：CCCC→1.log（旧 1.log 被删）

    final backup =
        await File('${dir.path}${Platform.pathSeparator}trace.1.log')
            .readAsString();
    expect(backup, contains('CCCC'), reason: '一代备份被新一代覆盖');
    expect(backup, contains('DDDD'), reason: '滚动触发点=达阈值后的下一笔');
    expect(backup, isNot(contains('AAAA')));
  });
}
