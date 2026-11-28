/// 分P 勾选弹层冒烟：节/行渲染、`?p=N` 预选、全选切换、确认回传 payload。
///
/// 纯 UI 组件测试（不依赖 riverpod/db）——数据即 SourcePreview 常量，
/// 经宿主按钮弹出后交互断言回传值。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/theme/app_theme.dart';
import 'package:ia_music/app/theme/design_tokens.dart';
import 'package:ia_music/state/collect_providers.dart';
import 'package:ia_music/ui/collect/link_extract_picker.dart';

SourcePreview _pv(String url, {int count = 3}) => SourcePreview(
      source: 'bili',
      baseUrl: url,
      url: url,
      title: '测试视频',
      artist: 'UP主',
      tracks: [
        for (var i = 1; i <= count; i++)
          SourcePreviewTrack(
              index: i, id: 'id$i', title: '第${i}P 歌曲', artist: 'UP主'),
      ],
    );

void main() {
  final picked = <List<(SourcePreview, Set<int>)>?>[];

  Future<void> pumpSheet(WidgetTester tester, List<SourcePreview> items) async {
    picked.clear();
    await tester.pumpWidget(MaterialApp(
      theme: buildIaTheme(accent: Color(0xFF207227), brightness: IaBrightness.dark),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                picked.add(await showLinkExtractPicker(context, items));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('默认全选：节头 + 分P 行 + 确认钮计数', (tester) async {
    await pumpSheet(tester, [_pv('https://www.bilibili.com/video/BV1')]);

    expect(find.text('勾选要提取的分P'), findsOneWidget);
    expect(find.text('测试视频'), findsOneWidget);
    expect(find.text('UP主 · 共 3 个分P'), findsOneWidget);
    expect(find.text('第1P 歌曲'), findsOneWidget);
    expect(find.text('第3P 歌曲'), findsOneWidget);
    expect(find.text('全不选'), findsOneWidget,
        reason: '默认全选态 → 节头提供「全不选」');
    expect(find.text('提取所选（3 个分P）'), findsOneWidget);
  });

  testWidgets('粘贴 ?p=2 链接 → 仅预选第 2P', (tester) async {
    await pumpSheet(tester, [_pv('https://www.bilibili.com/video/BV1?p=2')]);

    expect(find.text('提取所选（1 个分P）'), findsOneWidget);
  });

  testWidgets('取消一条 → 确认回传剩余勾选（顺序无关）', (tester) async {
    await pumpSheet(tester, [_pv('https://www.bilibili.com/video/BV1')]);

    await tester.tap(find.text('第3P 歌曲'));
    await tester.pumpAndSettle();
    expect(find.text('提取所选（2 个分P）'), findsOneWidget);

    await tester.tap(find.textContaining('提取所选'));
    await tester.pumpAndSettle();

    expect(picked.single, isNotNull);
    expect(picked.single!.length, 1);
    expect(picked.single!.first.$2, {1, 2});
  });

  testWidgets('节头全不选 → 确认钮禁用；再全选恢复', (tester) async {
    await pumpSheet(tester, [_pv('https://www.bilibili.com/video/BV1')]);

    await tester.tap(find.text('全不选'));
    await tester.pumpAndSettle();
    expect(find.text('未选择任何分P'), findsOneWidget);

    // 禁用态点击不产生回传
    await tester.tap(find.text('未选择任何分P'));
    await tester.pumpAndSettle();
    expect(picked, isEmpty, reason: '0 勾选时确认钮禁用，弹层未关闭');

    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    expect(find.text('提取所选（3 个分P）'), findsOneWidget);
  });

  test('?p=N 预选规则：命中该页 / 越界与缺省回退全选', () {
    expect(
        defaultPickedPage('https://www.bilibili.com/video/BV1?p=2', 3), {2});
    expect(
        defaultPickedPage('https://b23.tv/BV1?vd_source=a&p=3&x=1', 4), {3});
    expect(defaultPickedPage('https://www.bilibili.com/video/BV1?p=9', 3),
        {1, 2, 3},
        reason: '越界 p=N 回退全选');
    expect(defaultPickedPage('https://b23.tv/abc', 2), {1, 2},
        reason: '短链无 p 参数 → 全选');
  });
}