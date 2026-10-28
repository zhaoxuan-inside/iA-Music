/// 字幕适配器测试（vtt→LRC 纯转换；REQ-EXT 内容可选「文字」面）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ia_music/adapters/subtitle_adapter.dart';

void main() {
  group('subtitleToLrc', () {
    test('vtt 时间轴 → [mm:ss.xx] 行；重复行去重；标记剥离', () {
      const vtt = '''
WEBVTT

1
00:00:01.000 --> 00:00:03.500
故事的小黄花

2
00:00:03.500 --> 00:00:05.000
故事的小黄花

3
00:00:05.000 --> 00:00:08.000
<c>从出生那年就<00:00:06.000>飘着</c>

4
00:01:02.030 --> 00:01:05.000
&nbsp;童年的荡秋千
''';
      final lrc = subtitleToLrc(vtt);
      final lines = lrc.split('\n');
      expect(lines, hasLength(3)); // 重复行去除
      expect(lines[0], '[00:01.00]故事的小黄花');
      expect(lines[1], '[00:05.00]从出生那年就飘着'); // <c>/<...> 标记剥离
      expect(lines[2], '[01:02.03]童年的荡秋千'); // &nbsp; 剥离 + 毫秒归一
    });

    test('srt 形态（逗号毫秒）兼容', () {
      const srt = '''
1
00:00:10,120 --> 00:00:12,000
记忆中的画面
''';
      expect(subtitleToLrc(srt), '[00:10.12]记忆中的画面');
    });
  });
}
