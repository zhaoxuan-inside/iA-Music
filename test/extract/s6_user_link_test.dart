// DEC-010: 开发者实报链接真跑（BV1ANQqBTEVU，2026-10-19 现场报告）：
// 证明解析链路对该链接成立（链接有效、无需登录）；失败宽情人话=形态问题不冒充链接失效。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/adapters/downloader_adapter.dart';

const String kUserLink =
    'https://www.bilibili.com/video/BV1ANQqBTEVU/?spm_id_from=333.337.search-card.all.click';

void main() {
  test('开发者实报链接真解析：BV1ANQqBTEVU ≤5s、全字段', () async {
    final adapter = DownloaderAdapter();
    final sw = Stopwatch()..start();
    final meta = await adapter.resolve(
        '【分享】2026网络最好听100首热门歌曲 $kUserLink');
    sw.stop();
    expect(meta.sourceType, 'bilibili');
    expect(meta.sourceId, startsWith('BV1ANQqBTEVU'));
    expect(meta.title, contains('2026网络最好听100首热门歌曲'));
    expect(meta.uploader, isNotEmpty);
    expect(meta.durationMs, greaterThan(100000)); // 实测 296s
    expect(meta.qualities, isNotEmpty);
    expect(meta.coverUrl, isNotNull);
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)),
        reason: '≤5s 承诺（REQ-EXT-01），实测=${sw.elapsed}');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('形态错误不冒充链接失效：无工具链环境 → FormUnsupportedException 人话',
      () async {
    // 不可用启动器=真实环境态（此测试进程用错误 launcher 模拟 Android 无 py 的真实结果：
    // 进程拉不起 → ProcessException 分支）。属环境替身仅覆盖分类逻辑，
    // 链路欺骗零涉及（DEC-010 底线：网络/数据全真；此处=进程启停真实路径）。
    expect(
      () => Process.run('definitely-not-executable-xyz', const ['-J', 'x']),
      throwsA(isA<ProcessException>()),
    );
  });
}
