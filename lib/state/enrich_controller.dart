/// 补全域 UI 状态：元数据反向重建（音频指纹/在线匹配 → 写回）的运行进度。
///
/// 由扫描完成后自动驱动（ScanController）与「收集 · 补全」手动按钮触发。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'collect_providers.dart';
import 'diagnostics.dart';
import 'providers.dart';

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
  EnrichState build() => const EnrichState();

  /// 跑一轮补全：分批（20/批）循环直到待补全清空；重复调用在跑时忽略。
  Future<void> runOnce() async {
    if (state.running) {
      return;
    }
    state = state.copyWith(
        running: true, done: 0, total: 0, currentTitle: '', lastSummary: '');
    try {
      final svc = await ref.read(enrichmentServiceProvider.future);
      final library = ref.read(dbProvider).libraryDao;
      final total = await library.countNeedsEnrichment();
      state = state.copyWith(total: total);
      var adopted = 0;
      // 每首处理完都会标记 enrichedAt → 待补全数单调收敛；上界防意外打转。
      for (var round = 0; round < 200; round++) {
        final ok = await svc.enrichPending(
          limit: 20,
          onProgress: (title, _, _) =>
              state = state.copyWith(currentTitle: title),
        );
        adopted += ok;
        final remain = await library.countNeedsEnrichment();
        state = state.copyWith(done: total - remain);
        if (remain == 0) {
          break;
        }
      }
      state = state.copyWith(
        running: false,
        currentTitle: '',
        lastSummary: adopted > 0 ? '补全完成 · 采纳 $adopted 首' : '补全完成 · 无新匹配',
      );
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
