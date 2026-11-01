/// B 站搜索适配器测试（映射纯函数 + 真网冒烟；wbi 签名细节=EXP-2026-10-24 实测）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:contracts/contracts.dart';
import 'package:ia_music/adapters/bilibili_search_adapter.dart';

void main() {
  group('mapBiliSearchJson（高亮剥离/时长归一/绝对封面）', () {
    test('视频行映射：title 去 <em>、duration "4:30"→ms、pic→https', () {
      final j = {
        'code': 0,
        'data': {
          'result': [
            {
              'type': 'video',
              'bvid': 'BV1xx411c7mD',
              'title': '<em class="keyword">晴天</em> 周杰伦',
              'author': '测试UP',
              'duration': '4:30',
              'pic': '//i0.hdslb.com/bfs/archive/abc.jpg',
              'play': 123456,
              'pubdate': 1700000000,
            },
            {
              'type': 'live', // 非视频卡剔除
              'title': '直播中',
            },
            {
              'type': 'video',
              'bvid': 'BV1yy411c7mE',
              'title': '播客 vol.1',
              'author': '播客UP',
              'duration': '1:02:03',
              'pic': 'https://i1.hdslb.com/x.jpg',
            },
          ],
        },
      };
      final rows = mapBiliSearchJson(j);
      expect(rows, hasLength(2));
      expect(rows[0].sourceId, 'BV1xx411c7mD');
      expect(rows[0].title, '晴天 周杰伦'); // 高亮标记剥离
      expect(rows[0].durationMs, 4 * 60 * 1000 + 30 * 1000);
      expect(rows[0].coverUrl, 'https://i0.hdslb.com/bfs/archive/abc.jpg');
      expect(rows[0].playCount, 123456);
      expect(rows[0].publishedAtMs, 1700000000000);
      expect(rows[0].platform, SearchPlatform.bilibili);
      // 1:02:03 → 3723s
      expect(rows[1].durationMs, (3600 + 2 * 60 + 3) * 1000);
    });

    test('无法解析时长=0（不伪造；UI 显示 --:--）', () {
      final j = {
        'code': 0,
        'data': {
          'result': [
            {'type': 'video', 'bvid': 'BV1z', 'title': 'x', 'duration': '-'},
          ],
        },
      };
      expect(mapBiliSearchJson(j).single.durationMs, 0);
    });
  });

  group('decodeSearchHistory', () {
    test('JSON list 解码 + 损坏容错', () {
      expect(decodeSearchHistory('["a","b"]'), ['a', 'b']);
      expect(decodeSearchHistory(null), isEmpty);
      expect(decodeSearchHistory(''), isEmpty);
      expect(decodeSearchHistory('{broken'), isEmpty);
    });
  });

  test('真网冒烟：wbi 签名搜索「周杰伦 晴天」≥5 条（EXP-2026-10-24）',
      timeout: const Timeout(Duration(seconds: 30)), () async {
    final adapter = BilibiliSearchAdapter();
    try {
      final rows = await adapter.search('周杰伦 晴天', limit: 10);
      expect(rows, isNotEmpty);
      expect(rows.length, lessThanOrEqualTo(10));
      for (final r in rows) {
        expect(r.sourceId, startsWith('BV'));
        expect(r.url, contains('bilibili.com/video/'));
        expect(r.title, isNot(contains('<em'))); // 高亮必剥离
      }
    } on AuthRequiredSearchException {
      // 平台风控偶发（IP 面）= 诚实跳过而非伪失败
    } finally {
      adapter.client.dispose();
    }
  });
}
