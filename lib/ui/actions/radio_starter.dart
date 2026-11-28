/// 电台开播编排（听法策略的唯一执行入口）：
/// fetch → 空判（策略文案）→ shuffle → 播放 → toast。
///
/// 三个消费面共用本编排：listen_page 磁贴（无种子）、playing_page 随缘
/// 大磁贴（无种子、无成功 toast）、曲目长按菜单「声音相似电台」（带
/// 种子、toast 覆写）。策略只给曲目列表，编排细节全在此收口。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/listen_providers.dart';
import '../../state/playback_controller.dart';
import '../shared/ui_kit.dart';

/// 按策略开播一部电台。
/// [successToast] = 是否弹成功 toast（随缘大磁贴历史上无，保持原行为）。
Future<void> startRadio(
  WidgetRef ref,
  BuildContext context,
  ListenStrategy strategy, {
  ListenContext ctx = const ListenContext(),
  bool successToast = true,
  String? toastTitle,
  String? toastMessage,
}) async {
  final tracks = await strategy.fetch(ctx);
  if (!context.mounted) {
    return;
  }
  if (tracks.isEmpty) {
    showWpToast(context, title: strategy.label, message: strategy.emptyHint);
    return;
  }
  await ref
      .read(playbackProvider.notifier)
      .playTracks(tracks, shuffle: strategy.shuffle);
  if (context.mounted && successToast) {
    showWpToast(context,
        title: toastTitle ?? '听法',
        message: toastMessage ?? strategy.successToast);
  }
}

/// 按策略 id 从目录取策略（参数化策略的菜单入口用）。
ListenStrategy strategyById(List<ListenStrategy> strategies, String id) =>
    strategies.firstWhere((s) => s.id == id);
