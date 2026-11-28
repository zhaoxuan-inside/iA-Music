/// LRC 解析/成形纯函数测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/domain/entities/lyrics.dart';

void main() {
  group('parseLrc', () {
    test('基本时间轴 + 多时间戳行', () {
      const src = '[00:01.00]hello\n[00:05.00][00:10.50]world\n';
      final doc = parseLrc(src);
      expect(doc.lines.map((l) => l.tMs), [1000, 5000, 10500]);
      expect(doc.lines.map((l) => l.text), ['hello', 'world', 'world']);
    });

    test('meta 标签忽略 + offset 生效', () {
      const src = '[ti:song]\n[offset:500]\n[00:03.00]abc';
      final doc = parseLrc(src);
      expect(doc.lines.single.tMs, 2500); // 3000 - 500
    });

    test('空输入与乱输入 → 空文档', () {
      expect(parseLrc('').lines, isEmpty);
      expect(parseLrc('no stamps here').lines, isEmpty);
      expect(parseLrc('[99:99:garbage]').lines, isEmpty);
    });

    test('行序自动升序', () {
      const src = '[00:10.00]b\n[00:02.00]a';
      final doc = parseLrc(src);
      expect(doc.lines.first.text, 'a');
    });
  });

  group('lineIndexAt', () {
    final doc = parseLrc('[00:01.00]a\n[00:05.00]b\n[00:09.00]c');

    test('起始前 → null', () {
      expect(doc.lineIndexAt(0), isNull);
      expect(doc.lineIndexAt(999), isNull);
    });

    test('命中行与跨行边界', () {
      expect(doc.lineIndexAt(1000), 0);
      expect(doc.lineIndexAt(4999), 0);
      expect(doc.lineIndexAt(5000), 1);
      expect(doc.lineIndexAt(99999), 2);
    });
  });

  group('formatLrc roundtrip', () {
    test('解析→成形→再解析 幂等', () {
      const src = '[00:01.50]one\n[01:02.03]two\n';
      final doc = parseLrc(src);
      final text = formatLrc(doc.lines);
      final reparsed = parseLrc(text);
      expect(reparsed.lines.map((l) => (l.tMs, l.text)).toList(),
          doc.lines.map((l) => (l.tMs, l.text)).toList());
    });

    test('offset 写入并可在渲染侧抵消', () {
      final doc = parseLrc('[00:02.00]x');
      final text = formatLrc(doc.lines, offsetMs: 1500);
      expect(text, contains('[offset:1500]'));
    });
  });

  test('looksSynced', () {
    expect(looksSynced(parseLrc('[00:01.00]a\n[00:02.00]b\n[00:03.00]c\n[00:04.00]d')), isTrue);
    expect(looksSynced(parseLrc('[00:01.00]a')), isFalse);
    expect(looksSynced(parseLrc('plain text lyrics\nsecond line')), isFalse);
  });

  group('parseLrcOrPlain', () {
    test('纯文本逐行成形（tMs=0，不丢内容）', () {
      final doc = parseLrcOrPlain('plain text lyrics\nsecond line\n',
          kind: LyricSourceKind.online);
      expect(doc.lines, hasLength(2));
      expect(doc.lines.every((l) => l.tMs == 0), isTrue);
      expect(doc.lines.map((l) => l.text),
          ['plain text lyrics', 'second line']);
      expect(doc.sourceKind, LyricSourceKind.online);
    });

    test('带时间轴的 LRC 与 parseLrc 完全一致', () {
      final doc = parseLrcOrPlain('[00:01.00]a\n[00:05.00]b');
      expect(doc.lines.map((l) => l.tMs), [1000, 5000]);
    });

    test('混合文本：有戳行存在时无戳行维持 parseLrc 契约（丢弃）', () {
      final doc = parseLrcOrPlain('[00:01.00]a\nno stamp line');
      expect(doc.lines, hasLength(1));
    });

    test('空白仍为空文档（决议链继续往下走）', () {
      expect(parseLrcOrPlain('  \n \n').lines, isEmpty);
    });
  });
}
