/// 补全域 UI 状态：元数据反向重建（音频指纹/在线匹配 → 写回）的运行进度。
///
/// 由扫描完成后自动驱动（ScanController）与「收集 · 补全」手动按钮触发。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/entities/track.dart';
import 'diagnostics.dart';

class EnrichState {
  const EnrichState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.currentTitle = '',
    this.lastSummary = '',
  });

  final bool running;
  final int done;
  final int total;
  final String currentTitle;
  final String lastSummary;

  EnrichState copyWith({
    bool? running,
    int? done,
    int? total,
    String? currentTitle,
    String? lastSummary,
  }) =>
      EnrichState(
        running: running ?? this.running,
        done: done ?? this.done,
        total: total ?? this.total,
        currentTitle: currentTitle ?? this.currentTitle,
        lastSummary: lastSummary ?? this.lastSummary,
      );
}

class EnrichController extends Notifier<EnrichState> {
  @override
  EnrichState build() {
    // keepAlive：本 provider 唯一的监听者是「提取与补全进度」页——离开页面
    // 即销毁会让补全循环随 notifier 静默死亡（曾表现为只补 ~100 首就
    // 「队列空闲」）。补全是后台长任务，生命周期与页面解耦。
    ref.keepAlive();
    return const EnrichState();
  }

  /// 启动续跑 / 扫描与收集入库后的按需补全：运行中或池空一律 no-op
  /// ——空池直接 runOnce 会跑出假的「补全中断 0/0」。
  Future<void> resumeIfNeeded() async {
    if (state.running) {
      return;
    }
    final pending =
        await ref.read(dbProvider).libraryDao.countNeedsEnrichment();
    if (pending == 0) {
      return;
    }
    await runOnce();
  }

  /// 跑一轮补全：分批（20/批）循环直到待补全清空；重复调用在跑时忽略。
  ///
  /// [reset] = 手动「开始补全」：先清零连续失败计数，耗尽行重获重试机会
  /// （扫描驱动的自动轮不重置，避免网络不可用时无限原地打转）。
  Future<void> runOnce({bool reset = false}) async {
    if (state.running) {
      return;
    }
    state = state.copyWith(
        running: true, done: 0, total: 0, currentTitle: '', lastSummary: '');
    try {
      final svc = await ref.read(enrichmentServiceProvider.future);
      final library = ref.read(dbProvider).libraryDao;
      if (reset) {
        await library.resetEnrichAttempts();
      }
      final total = await library.countNeedsEnrichment();
      state = state.copyWith(total: total);
      var adopted = 0;
      // 每首处理完都会标记 enrichedAt → 待补全数单调收敛；上界防意外打转。
      for (var round = 0; round < 200; round++) {
        final remainBefore = await library.countNeedsEnrichment();
        final (ok, processed) = await svc.enrichPending(
          limit: 20,
          // 逐曲推进：批前基线（DB 权威）+ 本轮完成数；批后以 remain 校准
          onProgress: (title, batchDone, _) => state = state.copyWith(
              currentTitle: title, done: total - remainBefore + batchDone),
          // 单曲硬失败 → 诊断 + 日志追踪（真实错误原文，不是猜测文案）
          onError: (title, e) => unawaited(ref
              .read(diagnosticsProvider.notifier)
              .record('补全 · $title', e)),
          // 指纹链软失败（如 AcoustID 400）→ 只记日志不炸曲，文字链接管
          onSoftError: (source, e) => unawaited(
              ref.read(diagnosticsProvider.notifier).record(source, e)),
        );
        adopted += ok;
        final remain = await library.countNeedsEnrichment();
        state = state.copyWith(done: total - remain);
        if (processed == 0) {
          // 整轮零完成：这批全部抛错（网络不可用/文件不可读）——未写回
          // 的曲目原样留在池里，继续循环只会原地打转，诚实中断。
          final summary =
              '补全中断：连续失败（网络不可用或文件不可读？）已推进 ${total - remain}/$total';
          state = state.copyWith(
              running: false, currentTitle: '', lastSummary: summary);
          unawaited(ref
              .read(diagnosticsProvider.notifier)
              .record('补全中断', summary));
          return;
        }
        if (remain == 0) {
          break;
        }
      }
      state = state.copyWith(
        running: false,
        currentTitle: '',
        lastSummary: adopted > 0 ? '补全完成 · 采纳 $adopted 首' : '补全完成 · 无新匹配',
      );
      // 轮次汇总进日志（与「补全中断」对称；单曲成败各有独立记录）
      unawaited(ref
          .read(diagnosticsProvider.notifier)
          .record('补全', '完成 · 采纳 $adopted / $total'));
    } on Object catch (e, st) {
      state = state.copyWith(
          running: false, currentTitle: '', lastSummary: '补全中断：$e');
      unawaited(
          ref.read(diagnosticsProvider.notifier).record('补全', e, st));
    }
  }
}

final enrichProvider = NotifierProvider<EnrichController, EnrichState>(
    EnrichController.new);

/// 补全三阶段进度（歌名/歌手/歌词，持久化于 tracks 行，跨重启不从头）。
final enrichStagesProvider = StreamProvider<List<EnrichStage>>(
    (ref) => ref.watch(dbProvider).libraryDao.watchEnrichStages());
