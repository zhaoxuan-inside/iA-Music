/// 子曲目 pin 约定纯函数：构造/解析回环 + 剥片段。
/// （pin 的运行时语义——带 pin 跳过全量拆分只取第 N 条——由
/// collect_runner_test 端到端覆盖，这里只守约定本身的构造。）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/config/collect_config.dart';

void main() {
  test('trackPinUrl/trackPinOf 回环 + trackBaseUrl 剥片段', () {
    const base = 'https://www.bilibili.com/video/BV1?p=2';
    final pinned = trackPinUrl(base, 3);
    expect(pinned, '$base#ia-track=3');
    expect(trackPinOf(pinned), 3);
    expect(trackPinOf(base), isNull, reason: '干净 URL 无 pin');
    expect(trackPinOf('nonsense'), isNull);
    expect(trackBaseUrl(pinned), base);
    expect(trackBaseUrl('$base#ia-track=3#x'), base);
  });
}
