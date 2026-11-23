/// 提取与补全进度页冒烟：补全进度置顶（顺序断言）+ 提取聚合条点入详情页。
///
/// 遵守 UI 冒烟纪律（同 layout_smoke_test）：不碰真实数据库——drift 流查询
/// 在 widget 测试收尾 dispose 时要排定时器（StreamQueryStore.markAllClosed），
/// 会触发「Timer still pending」断言；数据 provider 用 Stream.value 最小
/// override。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/theme/app_theme.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/entities/track.dart';
import 'package:ia_music/state/collect_providers.dart';
import 'package:ia_music/state/enrich_controller.dart';
import 'package:ia_music/ui/settings/extract_page.dart';
import 'package:ia_music/ui/settings/extract_tasks_page.dart';

CollectTaskRow _row(int id, String title, CollectStatusCol status,
        int progress) =>
    CollectTaskRow(
      id: id,
      source: 'direct',
      query: '',
      url: 'http://x/$id.mp3',
      title: title,
      artist: '',
      status: status,
      progress: progress,
      createdAt: DateTime(2024, 1, 1),
    );

const _stages = [
  EnrichStage('歌名处理', 2, 1, 10),
  EnrichStage('歌手处理', 1, 0, 10),
  EnrichStage('歌词处理', 0, 0, 10),
];

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    List<CollectTaskRow>? rows,
    Widget home = const ExtractPage(),
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        collectTasksProvider.overrideWith((ref) => Stream.value(rows ?? [
              _row(1, '完成歌', CollectStatusCol.done, 100),
              _row(2, '失败歌', CollectStatusCol.failed, 40),
              _row(3, '等待歌', CollectStatusCol.pending, 0),
            ])),
        enrichStagesProvider.overrideWith((ref) => Stream.value(_stages)),
      ],
      child: MaterialApp(
        theme: buildIaTheme(accent: const Color(0xFF207227)),
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('补全进度置顶（先于提取进度渲染）+ 提取聚合条计数', (tester) async {
    await pumpPage(tester);

    final enrichY = tester.getTopLeft(find.text('补全进度（元数据三阶段）')).dy;
    final extractY = tester.getTopLeft(find.text('提取进度')).dy;
    expect(enrichY, lessThan(extractY), reason: '补全进度必须渲染在提取进度之上');

    expect(find.text('3 项任务 · 完成 1 · 失败 1 · 进行中/等待 1'), findsOneWidget);
    expect(find.text('详情 ›'), findsOneWidget);
  });

  testWidgets('点击提取聚合条 → 提取详情页（任务行 + 继续/重试按钮）', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.textContaining('项任务 · 完成 1'));
    await tester.pumpAndSettle();

    expect(find.text('提取详情'), findsOneWidget);
    expect(find.text('完成歌'), findsOneWidget);
    expect(find.text('direct · 完成 · 100%'), findsOneWidget);
    expect(find.text('direct · 失败 · 40%'), findsOneWidget);
    expect(find.text('继续 1'), findsOneWidget);
    expect(find.text('重试失败 1'), findsOneWidget);
    expect(find.textContaining('清理记录'), findsOneWidget,
        reason: '有可清记录时显示清理入口');
  });

  testWidgets('行内操作钮按状态渲染（暂停/开始/重试/删除）', (tester) async {
    await pumpPage(
      tester,
      rows: [
        _row(1, '完成歌', CollectStatusCol.done, 100),
        _row(2, '失败歌', CollectStatusCol.failed, 40),
        _row(3, '暂停歌', CollectStatusCol.paused, 20),
        _row(4, '运行歌', CollectStatusCol.running, 60),
      ],
      home: const ExtractTasksPage(),
    );

    expect(find.textContaining('已暂停'), findsOneWidget, reason: 'paused 状态标签');
    expect(find.textContaining('提取中'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget, reason: 'paused 行可开始');
    expect(find.text('暂停'), findsOneWidget, reason: 'running 行可暂停');
    expect(find.text('重试'), findsOneWidget, reason: 'failed 行可重试');
    expect(find.text('删除'), findsNWidgets(3),
        reason: 'done/paused/failed 行可删除（running 不可）');
    expect(find.textContaining('清理记录'), findsOneWidget);
  });
}
