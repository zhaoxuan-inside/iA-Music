/// 收集域真机端到端验证（模拟器/真机运行）：
/// 设置 → 提取链接 → 粘贴 B 站链接 → 提取 → 任务完成 → 曲库出现新曲目。
///
/// 运行（需要出网能力；模拟器可走宿主机代理）：
/// `flutter test integration_test/collect_e2e_test.dart -d emulator-5554 \
///   --dart-define=IA_HTTP_PROXY=10.0.2.2:3128`
///
/// 断言口径：下载件经真实扫描入库后，曲库列表出现
/// 「Never Gonna Give You Up」（视频标题经命名与归一化链路还原）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/main.dart' as app;
import 'package:integration_test/integration_test.dart';

const String kBiliUrl = 'https://bilibili.com/video/BV1GJ411x7h7';
const String kExpectTitle = 'Never Gonna Give You Up';

/// 读取当前帧所有可见文本（诊断用）。
List<String> visibleTexts() => [
      for (final w in find.byType(Text).evaluate())
        if ((w.widget as Text).data != null) (w.widget as Text).data!,
    ];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('B 站链接提取 → 真实下载 → 扫描入库 → 曲库可见', (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ── 首启开箱仪式（flutter test 全新安装时才出现） ─────────────
    // READ_MEDIA_AUDIO 由外部 `adb shell pm grant` 在安装瞬间预授予，
    // 这里只处理 UI 两步：选色（跳过）→ 选目录（Music 预置项）。
    if (find.text('选一支主题色').evaluate().isNotEmpty) {
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text('Music'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.text('完成'));
      // 等扫描入库进 Hub（首次 10 件 isolate 解析，秒级）
      for (var i = 0;
          i < 20 && find.text('钉在墙上的').evaluate().isEmpty;
          i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // ── 设置 → 提取链接 ────────────────────────────────────────────
    await tester.dragUntilVisible(
      find.text('提取链接'),
      find.byType(PageView),
      const Offset(-360, 0),
      maxIteration: 12,
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('提取链接'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ── 粘贴链接 → 提取 ────────────────────────────────────────────
    await tester.enterText(find.byType(TextField).first, kBiliUrl);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.text('提取'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ── 进度页：任务行实时状态（等待 / 提取中 / 完成 / 失败） ──────
    final progressEntry = find.text('提取与补全进度');
    if (progressEntry.evaluate().isNotEmpty) {
      await tester.tap(progressEntry);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    String? taskStatus;
    final deadline = DateTime.now().add(const Duration(minutes: 4));
    var done = false;
    while (DateTime.now().isBefore(deadline) && !done) {
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      final statusTexts = [
        for (final t in visibleTexts())
          if (t.contains('bilibili ·') || t.contains('失败')) t,
      ];
      if (statusTexts.isNotEmpty) {
        debugPrint('[collect-e2e] ${statusTexts.join(' | ')}');
        final current = statusTexts.first;
        done = current.contains('完成') || current.contains('失败');
        taskStatus = current;
      }
    }

    if (taskStatus == null) {
      debugPrint('[collect-e2e] 可见文本：${visibleTexts().join(' | ')}');
      fail('4 分钟内未看到任何 bilibili 任务行——任务没有入队或进度页未刷新');
    }
    expect(done, isTrue, reason: '任务停在：$taskStatus');
    expect(taskStatus, contains('完成'), reason: '提取失败：$taskStatus');

    // ── 曲库：真实扫描入库后可见 ───────────────────────────────────
    await tester.pageBack();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.dragUntilVisible(
      find.text('音乐仓库'),
      find.byType(PageView),
      const Offset(360, 0),
      maxIteration: 12,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.dragUntilVisible(
      find.textContaining(kExpectTitle),
      find.byType(ListView).first,
      const Offset(0, -260),
      maxIteration: 30,
    );
    expect(find.textContaining(kExpectTitle), findsWidgets,
        reason: '提取完成但曲库未出现「$kExpectTitle」——扫描入库链路存在缺陷');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
