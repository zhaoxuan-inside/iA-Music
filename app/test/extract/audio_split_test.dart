// 拆分引擎单测（纯函数面；真链路见 s6_split_e2e_test）。
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/extract/audio_split.dart';

void main() {
  group('silencedetect 日志解析', () {
    test('start/end 配对 → 中点升序', () {
      const log = '''
[silencedetect @ 0x0] silence_start: 120.5
[silencedetect @ 0x0] silence_end: 122.5 | silence_duration: 2
[silencedetect @ 0x0] silence_start: 300
[silencedetect @ 0x0] silence_end: 302 | silence_duration: 2
''';
      expect(parseSilenceMidpoints(log), [121.5, 301.0]);
    });

    test('乱序/残缺行容错', () {
      const log = '''
noise line
[silencedetect @ 0x0] silence_end: 50 | silence_duration: 1
garbage
[silencedetect @ 0x0] silence_start: 48
''';
      // start=48 在 end=50 之后出现（乱序）——按序配对仍得 49
      expect(parseSilenceMidpoints(log), [49.0]);
    });
  });

  group('分段规划（贪心收敛：段过短弃最弱切点）', () {
    test('三个清晰分段全部达标', () {
      final plan = planSegments(
        durationMs: 600000, // 10 分钟
        silenceMidpoints: [200.0, 400.0], // 秒
      );
      expect(plan, hasLength(3));
      expect(plan[0].startMs, 0);
      expect(plan[0].endMs, 200000);
      expect(plan[2].endMs, 600000);
    });

    test('过短段被收敛：弃切点并入邻段，直至所有段 ≥45s', () {
      // 10 分钟，切点 100s、130s → 第二段 30s ✘ → 弃制造它的左切点(100)
      // → 剩 [0-130k][130k-600k] 两段均 ≥45s ✔
      final plan = planSegments(
        durationMs: 600000,
        silenceMidpoints: [100.0, 130.0],
      );
      expect(plan, hasLength(2));
      expect(plan[0].endMs, 130000);
      expect(plan[1].startMs, 130000);
    });

    test('无有效切点 → 不拆分（空表）', () {
      expect(planSegments(durationMs: 600000, silenceMidpoints: []),
          isEmpty);
    });

    test('切点超出时长范围被裁剪', () {
      final plan = planSegments(
        durationMs: 300000,
        silenceMidpoints: [100.0, 400.0], // 400s > 300s 总长
      );
      expect(plan, hasLength(2));
      expect(plan[1].endMs, 300000);
    });
  });

  group('标题《》歌单匹配', () {
    test('提取保序', () {
      expect(
        extractSongList('【粤语经典】精选歌单《吴哥窟》《情意结》《喜帖街》'),
        ['吴哥窟', '情意结', '喜帖街'],
      );
    });

    test('段数一致才按序命名', () {
      expect(matchSegmentTitles(['A', 'B', 'C'], 3), ['A', 'B', 'C']);
      expect(matchSegmentTitles(['A', 'B', 'C'], 2), [null, null]);
      expect(matchSegmentTitles([], 2), [null, null]);
    });

    test('planSegments 综合面：歌单与段数一致 → 命名注入', () {
      final plan = planSegments(
        durationMs: 480000,
        silenceMidpoints: [160.0, 320.0],
        songList: ['吴哥窟', '情意结', '喜帖街'],
      );
      expect(plan.map((s) => s.title).toList(), ['吴哥窟', '情意结', '喜帖街']);
    });
  });

  group('LRC 时间轴偏移（拆分曲字幕窗口）', () {
    test('窗口内平移、界外丢弃', () {
      const lrc = '[00:05.00]intro\n'
          '[01:10.50]第一句\n' // 70.5s ∈ [60s,120s)
          '[02:00.00]第二句\n'; // 120s = 窗口外
      final out = shiftLrc(lrc, 60000, 120000);
      expect(out.split('\n'), hasLength(1));
      expect(out, '[00:10.50]第一句');
    });

    test('毫秒归一与非时间轴行剔除', () {
      const lrc = '[ti:x]\n[00:00.5]a\n[01:02.345]b';
      final out = shiftLrc(lrc, 0, 600000);
      expect(out.split('\n'), ['[00:00.50]a', '[01:02.34]b']);
    });
  });
}
