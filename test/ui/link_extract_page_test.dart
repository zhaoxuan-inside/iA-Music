/// 从链接提取页流程冒烟：多P 链接 → 勾选层 → 勾选件按 pin 定点入队；
/// 单P 直接入队；不可识别计数。API 用 stub 子类记录入队（不碰真实
/// 数据库/插件，同 extract_page_test 纪律）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/theme/app_theme.dart';
import 'package:ia_music/app/theme/design_tokens.dart';
import 'package:ia_music/state/collect_providers.dart';
import 'package:ia_music/ui/collect/link_extract_page.dart';

class _StubApi extends CollectTasksApi {
  _StubApi(super.ref);

  /// (source, url, title, artist) 入队记录
  final List<(String, String, String, String)> enqueued = [];
  int driveCalls = 0;

  @override
  Future<String?> routeSource(String url) async =>
      url.contains('unknown') ? null : 'bili';

  @override
  Future<SourcePreview?> previewTracks(String url) async {
    if (!url.contains('multi')) {
      return null; // 单P/预览失败 → 回退直接入队
    }
    return SourcePreview(
      source: 'bili',
      baseUrl: url,
      url: url,
      title: '多P视频',
      artist: 'UP主',
      tracks: [
        for (var i = 1; i <= 3; i++)
          SourcePreviewTrack(
              index: i, id: 'id$i', title: '第${i}P 歌曲', artist: 'UP主'),
      ],
    );
  }

  @override
  Future<void> enqueue(String source, String url,
      {String title = '', String artist = '', int? playlistId}) async {
    enqueued.add((source, url, title, artist));
  }

  @override
  Future<void> drive() async => driveCalls++;
}

/// overrideWith 闭包内才拿得到 Ref——用持有器把 stub 递给断言侧。
/// 每次 pumpPage 新开 ProviderContainer → ensure 恰好一次 → 每用例新实例。
class _ApiHolder {
  _StubApi? api;

  _StubApi ensure(Ref ref) => api = _StubApi(ref);
}

void main() {
  final holder = _ApiHolder();

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        collectTasksApiProvider.overrideWith(holder.ensure),
      ],
      child: MaterialApp(
        theme: buildIaTheme(accent: Color(0xFF207227), brightness: IaBrightness.dark),
        home: const LinkExtractPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// toast 2.6s 自动收回 + 300ms 收场动画——推过定时器避免测试收尾挂起
  Future<void> pumpPastToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('多P 链接：默认全选确认 → 3 个 pin 任务入队（预填曲名）',
      (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextField),
        'https://www.bilibili.com/video/BV-multi');
    await tester.tap(find.text('提取'));
    await tester.pumpAndSettle();

    expect(find.text('勾选要提取的分P'), findsOneWidget,
        reason: '多子曲目预览命中 → 弹勾选层');
    await tester.tap(find.textContaining('提取所选'));
    await tester.pumpAndSettle();

    final api = holder.api!;
    expect(api.enqueued.length, 3);
    expect(api.enqueued[0].$2, contains('#ia-track=1'));
    expect(api.enqueued[2].$2, contains('#ia-track=3'));
    expect(api.enqueued[0].$2, startsWith('https://www.bilibili.com/video/BV-multi'));
    expect(api.enqueued[0].$3, '第1P 歌曲', reason: '预填曲名即刻可读');
    expect(api.enqueued[0].$4, 'UP主');
    expect(api.driveCalls, 1);
    await pumpPastToast(tester);
  });

  testWidgets('多P 链接：取消一条 → 只入队剩余两条', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextField),
        'https://www.bilibili.com/video/BV-multi?p=1');
    await tester.tap(find.text('提取'));
    await tester.pumpAndSettle();

    // ?p=1 预选只 1 条 → 先节头全选回 3 条，再取消第 3P
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第3P 歌曲'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('提取所选'));
    await tester.pumpAndSettle();

    final api = holder.api!;
    expect(api.enqueued.length, 2);
    expect(api.enqueued[0].$2, contains('#ia-track=1'));
    expect(api.enqueued[1].$2, contains('#ia-track=2'));
    expect(find.text('勾选要提取的分P'), findsNothing, reason: '确认后弹层关闭');
    await pumpPastToast(tester);
  });

  testWidgets('单P 链接：不弹层直接入队（标题留空运行时补全）', (tester) async {
    await pumpPage(tester);
    await tester.enterText(
        find.byType(TextField), 'https://www.bilibili.com/video/BV-single');
    await tester.tap(find.text('提取'));
    await tester.pumpAndSettle();

    expect(find.text('勾选要提取的分P'), findsNothing);
    final api = holder.api!;
    expect(api.enqueued.length, 1);
    expect(api.enqueued[0].$2, 'https://www.bilibili.com/video/BV-single');
    expect(api.enqueued[0].$2, isNot(contains('#ia-track')));
    expect(api.enqueued[0].$3, '');
    expect(api.driveCalls, 1);
    await pumpPastToast(tester);
  });

  testWidgets('不可识别链接：拒绝入队并提示', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextField), 'https://unknown/x');
    await tester.tap(find.text('提取'));
    await tester.pumpAndSettle();

    final api = holder.api!;
    expect(api.enqueued, isEmpty);
    expect(api.driveCalls, 0);
    expect(find.text('没有可识别的链接'), findsOneWidget);
    await pumpPastToast(tester);
  });
}