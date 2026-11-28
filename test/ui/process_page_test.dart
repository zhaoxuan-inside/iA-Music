/// 歌曲处理页冒烟：五行进度（顺序断言）+ 提取行点入详情页 + 失败列表复制日志。
///
/// 遵守 UI 冒烟纪律（同 layout_smoke_test）：不碰真实数据库——drift 流查询
/// 在 widget 测试收尾 dispose 时要排定时器（StreamQueryStore.markAllClosed），
/// 会触发「Timer still pending」断言；数据 provider 用 Stream.value 最小
/// override。补全失败记录（KV 持久化）同样 override 掉。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/app/theme/app_theme.dart';
import 'package:ia_music/app/theme/design_tokens.dart';
import 'package:ia_music/data/database.dart';
import 'package:ia_music/domain/entities/track.dart';
import 'package:ia_music/state/collect_providers.dart';
import 'package:ia_music/state/enrich_controller.dart';
import 'package:ia_music/state/process_failures.dart';
import 'package:ia_music/ui/enrich/process_page.dart';

CollectTaskRow _row(int id, String title, CollectStatusCol status,
        int progress,
        {String? errorText}) =>
    CollectTaskRow(
      id: id,
      source: 'direct',
      query: '',
      url: 'http://x/$id.mp3',
      title: title,
      artist: '',
      status: status,
      progress: progress,
      errorText: errorText,
      createdAt: DateTime(2024, 1, 1),
    );

/// 四阶段顺序与 DAO 口径一致（歌名/歌词/封面/歌手）；歌词行含无词档。
const _stages = [
  EnrichStage('歌名', 2, 1, 10),
  EnrichStage('歌词', 1, 0, 10, 2),
  EnrichStage('封面', 5, 0, 10),
  EnrichStage('歌手', 1, 0, 10),
];

/// 补全失败列表替身（真实实现经 settings KV 落库，测试不碰 DB）。
class _FakeEnrichFailures extends ProcessFailureController {
  _FakeEnrichFailures(this.initial);

  final List<ProcessFailure> initial;

  @override
  List<ProcessFailure> build() => initial;
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    List<CollectTaskRow>? rows,
    List<ProcessFailure> enrichFailures = const [],
    Widget home = const ProcessPage(),
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        collectTasksProvider.overrideWith((ref) => Stream.value(rows ?? [
              _row(1, '完成歌', CollectStatusCol.done, 100),
              _row(2, '失败歌', CollectStatusCol.failed, 40,
                  errorText: '音频流下载失败：HTTP 404'),
              _row(3, '等待歌', CollectStatusCol.pending, 0),
            ])),
        enrichStagesProvider.overrideWith((ref) => Stream.value(_stages)),
        enrichFailuresProvider
            .overrideWith(() => _FakeEnrichFailures(enrichFailures)),
      ],
      child: MaterialApp(
        theme: buildIaTheme(accent: Color(0xFF207227), brightness: IaBrightness.dark),
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('五行处理进度按序渲染（提取 → 歌名 → 歌词 → 封面 → 歌手）',
      (tester) async {
    await pumpPage(tester);

    // 顺序断言：五行自上而下（提取行最上，四阶段按 DAO 口径排其后）。
    // enrich 默认态无当前曲——行文本即标签本身，用精确匹配避开页头副题。
    double topOf(String label) => tester.getTopLeft(find.text(label)).dy;
    final extractY = topOf('提取');
    expect(topOf('歌名'), greaterThan(extractY), reason: '歌名在提取之下');
    expect(topOf('歌词'), greaterThan(topOf('歌名')), reason: '歌词在歌名之下');
    expect(topOf('封面'), greaterThan(topOf('歌词')), reason: '封面在歌词之下');
    expect(topOf('歌手'), greaterThan(topOf('封面')), reason: '歌手在封面之下');

    // 提取行详情入口（3 任务：1 完成 1 失败 1 等待）
    expect(find.text('详情 ›'), findsOneWidget);
    expect(find.textContaining('成功 1'), findsWidgets);

    // 歌词行拆口径：有词/无词 分档（成功档只算拿到词，「确认无词」单列灰档）
    expect(find.textContaining('有词 1'), findsOneWidget);
    expect(find.textContaining('无词 2'), findsOneWidget);
    expect(find.textContaining('成功 1'), findsWidgets,
        reason: '其余阶段仍叫「成功」，歌词行独用有词口径');
  });

  testWidgets('提取行点入任务详情页', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('详情 ›'));
    await tester.pumpAndSettle();

    expect(find.text('提取详情'), findsOneWidget);
    expect(find.text('完成歌'), findsOneWidget);
  });

  testWidgets('失败倒序列表：提取在前补全在后，点击复制日志原文', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add(
            (call.arguments as Map<Object?, Object?>)['text'] as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    // 补全失败（更早）应排在提取失败（更晚）之下
    await pumpPage(tester, enrichFailures: [
      ProcessFailure(
        at: DateTime(2023, 12, 31, 12),
        kind: '歌名·歌词',
        title: '抖动歌',
        detail: 'Failed host lookup: fake.test',
      ),
    ]);

    final extractFailure = find.textContaining('提取 · 失败歌');
    final enrichFailure = find.textContaining('歌名·歌词 · 抖动歌');
    expect(extractFailure, findsOneWidget);
    expect(enrichFailure, findsOneWidget);
    expect(
        tester.getTopLeft(extractFailure).dy,
        lessThan(tester.getTopLeft(enrichFailure).dy),
        reason: '失败列表按时间倒序（新在上）');

    // 点击提取失败行：剪贴板收到 类型 + 歌名 + 日志原文，toast 反馈
    await tester.tap(extractFailure);
    await tester.pumpAndSettle();
    expect(copied, hasLength(1));
    expect(copied.single, contains('提取 · 失败歌'));
    expect(copied.single, contains('HTTP 404'));
    expect(find.text('已复制'), findsOneWidget);

    // 排空 toast 2.6s 自动收回的挂起定时器（UI 冒烟纪律）
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}