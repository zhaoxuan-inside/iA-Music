// 歌词解析单测（lyrics_page.parseLrc：多时间标签/无标签丢弃/排序）。
import 'package:flutter_test/flutter_test.dart';

import 'package:ia_music/ui/play/lyrics_page.dart';

void main() {
  test('多时间标签展开 + 按时间排序', () {
    final lrc = '[00:01.00][00:05.00]双时间行\n'
        '无标签行丢弃\n'
        '[00:03.50]第二句\n'
        '[01:02.03]尾声\n';
    final lines = parseLrc(lrc);
    expect(lines.length, 4, reason: '双时间标签展开为两行');
    expect(lines.map((l) => l.ms).toList(), [1000, 3500, 5000, 62030],
        reason: '时间排序：1000 < 3500 < 5000 < 62.03s');
    expect(lines.first.text, '双时间行');
    expect(lines.last.text, '尾声');
  });

  test('毫秒精度与全角冒号容错', () {
    final lines = parseLrc('[00:10:500]半秒精度\n[1:2]宽分钟\n');
    expect(lines[0].ms, 10500);
    expect(lines[1].ms, 62000);
  });

  test('空文本与纯文本不产出行', () {
    expect(parseLrc(''), isEmpty);
    expect(parseLrc('纯文本没有时间标签'), isEmpty);
  });
}
