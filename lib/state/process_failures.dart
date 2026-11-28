/// 歌曲处理失败面：提取任务失败 + 补全单曲硬失败的统一倒序列表。
///
/// 两个来源、两种持久化：
/// * 提取失败 = collect_tasks 行（status=failed，errorText 原文，DB 权威，
///   重试/清理后自然消失——它是「当前失败状态」不是历史）；
/// * 补全失败 = 补全循环的单曲硬失败（网络不可用/文件不可读），tasks 表
///   只记计数不打原文——这里以 settings KV 追加 capped 列表（新在前，
///   最多 [maxEntries] 条，超出挤掉最旧），跨重启可读。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'collect_providers.dart';

/// 单条失败记录（类型 = 提取 / 歌名·歌手·歌词 组合）。
class ProcessFailure {
  const ProcessFailure({
    required this.at,
    required this.kind,
    required this.title,
    required this.detail,
  });

  final DateTime at;

  /// 失败类型（『提取』或补全阶段组合如『歌名·歌手·歌词』）。
  final String kind;
  final String title;

  /// 失败日志原文（点击复制的内容）。
  final String detail;

  Map<String, dynamic> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'kind': kind,
        'title': title,
        'detail': detail,
      };

  static ProcessFailure fromJson(Map<String, dynamic> j) => ProcessFailure(
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int? ?? 0),
        kind: j['kind'] as String? ?? '?',
        title: j['title'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
      );
}

/// 补全失败记录数上限（新记录挤掉最旧，列表永不无限膨胀）。
const maxEntries = 50;

/// 补全单曲硬失败的持久化列表（新在前）。keepAlive：补全是后台长任务，
/// 失败回调发生在无页面监听时——auto-dispose 会让记录静默丢失。
class ProcessFailureController extends Notifier<List<ProcessFailure>> {
  @override
  List<ProcessFailure> build() {
    ref.keepAlive();
    _load();
    return const [];
  }

  static const _key = 'process.failures';

  Future<void> _load() async {
    try {
      final raw = await ref.read(settingsServiceProvider).getString(_key);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final list = (jsonDecode(raw) as List<Object?>)
          .whereType<Map>()
          .map((j) => ProcessFailure.fromJson(j.cast<String, Object?>()))
          .toList();
      state = list;
    } on Object {
      // 持久化读取失败不打扰主流程（列表留空即可）
    }
  }

  /// 追加一条补全失败（新在前 + capped + 持久化）。
  Future<void> record(String kind, String title, Object error) async {
    final entry = ProcessFailure(
      at: DateTime.now(),
      kind: kind,
      title: title,
      detail: '$error',
    );
    state = [entry, ...state].take(maxEntries).toList();
    try {
      await ref
          .read(settingsServiceProvider)
          .setString(_key, jsonEncode([for (final e in state) e.toJson()]));
    } on Object {
      // 持久化失败不阻断（内存态仍在本会话可见）
    }
  }
}

final enrichFailuresProvider =
    NotifierProvider<ProcessFailureController, List<ProcessFailure>>(
        ProcessFailureController.new);

/// 歌曲处理页失败列表（倒序）：提取当前失败任务 + 补全失败记录，按时间新在前。
final processFailuresProvider = Provider<List<ProcessFailure>>((ref) {
  final tasks =
      ref.watch(collectTasksProvider).value ?? const <CollectTaskRow>[];
  final enrich = ref.watch(enrichFailuresProvider);
  final fromTasks = [
    for (final t in tasks)
      if (t.status == CollectStatusCol.failed)
        ProcessFailure(
          at: t.createdAt,
          kind: '提取',
          title: t.title,
          detail: t.errorText ?? '',
        ),
  ];
  return [...fromTasks, ...enrich]
    ..sort((a, b) => b.at.compareTo(a.at));
});
