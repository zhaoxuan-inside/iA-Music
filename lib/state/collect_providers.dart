/// 收集域 providers：任务流 / GitHub 服务 / 执行服务 / 音频源插件门面 / NLP 查询。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../services/collect/collect_service.dart';
import '../services/collect/download_guard.dart';
import '../services/collect/source_plugins.dart';
import '../services/github/github_playlist_service.dart';
import 'diagnostics.dart';
import 'enrich_controller.dart';
import 'plugin_providers.dart';
import 'providers.dart';
import 'scan_controller.dart';

/// 收集任务实时流（提取进度子页的数据源）。
final collectTasksProvider = StreamProvider(
    (ref) => ref.watch(dbProvider).collectDao.watchAll());

/// GitHub 歌单拉取服务（单例；HttpClient 复用）。
final githubPlaylistServiceProvider =
    Provider<GithubPlaylistService>((ref) => GithubPlaylistService(ref.watch(dbProvider)));

/// 音频源插件门面（QuickJS 运行时 + 注册表之上的契约封装）。
final sourcePluginsProvider = FutureProvider<SourcePlugins>((ref) async {
  final registry = await ref.watch(pluginRegistryProvider.future);
  final runtime = await ref.watch(pluginRuntimeProvider.future);
  return SourcePlugins(registry, runtime,
      // 插件 match 抛错（崩/超时）→ 日志可见，不再伪装成「无法识别」
      onMatchError: (id, e, st) => unawaited(
          ref.read(diagnosticsProvider.notifier).record('插件路由 · $id', e, st)));
});

/// 登录态/插件变更信号：登录、退出、装/卸插件后 bump。
class SourceEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final sourceEpochProvider = NotifierProvider<SourceEpoch, int>(SourceEpoch.new);

/// 已启用的音频源插件（插件页增删/启停后由 pluginsProvider 变更触发重扫）。
final sourceHandlesProvider = FutureProvider<List<SourcePluginHandle>>((ref) async {
  ref.watch(sourceEpochProvider);
  ref.watch(pluginsProvider);
  final sources = await ref.watch(sourcePluginsProvider.future);
  return sources.enabled();
});

/// 登录态 family（登录/退出即时刷新；凭据在插件沙箱里，宿主只见状态）。
class SourceAuthStatus {
  const SourceAuthStatus({required this.loggedIn, required this.account});

  final bool loggedIn;
  final String account;
}

final sourceAuthStatusProvider =
    FutureProvider.family<SourceAuthStatus, String>((ref, pluginId) async {
  ref.watch(sourceEpochProvider);
  // 安装/启停/卸载即时刷新（pluginsProvider 状态变化也是登录态变更通道）
  ref.watch(pluginsProvider);
  final handles = await ref.watch(sourceHandlesProvider.future);
  final h = handles.where((x) => x.id == pluginId).firstOrNull;
  if (h == null) {
    return const SourceAuthStatus(loggedIn: false, account: '');
  }
  final st = await h.authStatus();
  return SourceAuthStatus(loggedIn: st.loggedIn, account: st.account);
});

/// 登录方式（qr / cookie / none）——收集页按它决定打开哪种登录页。
final sourceAuthKindProvider =
    FutureProvider.family<String, String>((ref, pluginId) async {
  ref.watch(sourceEpochProvider);
  // 安装/启停/卸载即时刷新（bump 之外的通道）
  ref.watch(pluginsProvider);
  final handles = await ref.watch(sourceHandlesProvider.future);
  final h = handles.where((x) => x.id == pluginId).firstOrNull;
  if (h == null) {
    return 'none';
  }
  return await h.authKind() ?? 'none';
});

/// 提取任务提交门面：UI 只经此入队与驱动，不触 data 层类型。
class CollectTasksApi {
  CollectTasksApi(this._ref);

  final Ref _ref;

  IaDatabase get _db => _ref.read(dbProvider);

  /// URL → 来源路由：逐个启用插件问 match()，不认领时按直链音频启发式；
  /// 都不认 → null（调用方提示无法识别）。
  Future<String?> routeSource(String url) async {
    final sources = await _ref.read(sourcePluginsProvider.future);
    final hit = await sources.routeUrl(url);
    if (hit != null) {
      return hit;
    }
    if (url.startsWith('http') &&
        RegExp(r'\.(mp3|m4a|flac|wav|ogg|opus|aac)(\?|$)')
            .hasMatch(url.toLowerCase())) {
      return 'direct';
    }
    return null;
  }

  /// 入队（来源：插件 id / direct；标题空由提取引擎运行时补全）。
  Future<void> enqueue(String source, String url,
      {String title = '', String artist = '', int? playlistId}) {
    return _db.collectDao
        .enqueue(source, url, title: title, artist: artist, playlistId: playlistId);
  }

  /// 驱动执行器跑一轮（异步、可重复调用）。
  Future<void> drive() async {
    // 发布目标是用户选定的音乐目录（共享存储）——分区存储下需要
    // 「所有文件访问」；未授予则本轮直接停（任务留在队列原样不动）。
    final granted =
        await _ref.read(scanProvider.notifier).ensureAudioPermission();
    if (!granted) {
      unawaited(_ref.read(diagnosticsProvider.notifier).record('提取',
          '存储权限未授予——系统设置里允许「所有文件访问」后重试'));
      return;
    }
    final runner = await _ref.read(collectRunnerProvider.future);
    try {
      final (processed, failed) = await runner.runOnce();
      // 轮次汇总进日志（失败明细由 onTaskError 逐条记录，不在此重复）
      if (processed > 0 || failed > 0) {
        unawaited(_ref
            .read(diagnosticsProvider.notifier)
            .record('提取', '本轮完成 $processed · 失败 $failed'));
      }
    } on Object catch (e, st) {
      // 队列执行的野错误必须收口：记入诊断，僵尸任务由下一轮回收重跑。
      unawaited(_ref
          .read(diagnosticsProvider.notifier)
          .record('收集队列', e, st));
    }
    // 队列清空即续跑补全：新入库的缺元数据件不等下次扫描/启动
    // （resumeIfNeeded 自带运行中/空池守卫，重复调用安全）。
    unawaited(_ref.read(enrichProvider.notifier).resumeIfNeeded());
  }

  /// 批量任务失败重试。
  Future<int> retryFailed() => _db.collectDao.retryFailed();

  /// 单任务暂停：pending/failed → paused（DAO）；running → 登记取消
  /// （下载泵检查点触发转 paused）并即时置 paused 反馈。
  Future<void> pauseTask(int id) async {
    final row = await _db.collectDao.taskById(id);
    if (row == null) {
      return;
    }
    if (row.status == CollectStatusCol.running) {
      (await _ref.read(collectRunnerProvider.future)).cancelTask(id);
    }
    await _db.collectDao.pauseTask(id);
  }

  /// 单任务开始/重试：回 pending 重新入队并驱动一轮。
  Future<void> startTask(int id) async {
    await _db.collectDao.resumeTask(id);
    await drive();
  }

  /// 删除任务：运行中先登记取消；记录行删除（音频/歌词文件不动）；
  /// 临时残留清理；GitHub 歌单未完成任务回减 pending 计数。
  Future<void> deleteTask(int id) async {
    final row = await _db.collectDao.taskById(id);
    if (row == null) {
      return;
    }
    if (row.status == CollectStatusCol.running) {
      (await _ref.read(collectRunnerProvider.future)).cancelTask(id);
    }
    if (row.playlistId != null && row.status != CollectStatusCol.done) {
      // 删除未完成的歌单任务：回减 pending 计数（仅成功路径减过）
      await _db.playlistDao.decrementPending(row.playlistId!);
    }
    await _db.collectDao.deleteTask(id);
    final dirs = await _ref.read(cacheDirsProvider.future);
    await cleanupTaskTmp(dirs.lyrics, id);
  }

  /// 清理任务记录（done+failed 行；音频/歌词文件不动）。
  Future<int> clearFinished() async {
    final n = await _db.collectDao.clearFinished();
    if (n > 0) {
      unawaited(_ref
          .read(diagnosticsProvider.notifier)
          .record('提取', '已清理 $n 条任务记录'));
    }
    return n;
  }
}

final collectTasksApiProvider =
    Provider<CollectTasksApi>(CollectTasksApi.new);

/// 收集执行服务（依赖扫描服务做下载后的真实入库）。
final collectRunnerProvider = FutureProvider<CollectRunner>((ref) async {
  final scan = ref.watch(scanServiceProvider);
  final dirs = await ref.watch(cacheDirsProvider.future);
  final sources = await ref.watch(sourcePluginsProvider.future);
  return CollectRunner(ref.watch(dbProvider), scan,
      cacheDir: dirs.lyrics,
      sources: sources,
      // 单任务失败原因不再蒸发：错误原文进日志追踪（任务行另有 errorText）
      onTaskError: (title, e, st) => unawaited(
          ref.read(diagnosticsProvider.notifier).record('提取 · $title', e, st)),
      onTaskSoftError: (source, e) =>
          unawaited(ref.read(diagnosticsProvider.notifier).record(source, e)));
});

/// 音频指纹端口（MediaCodec 解码 + chromaprint FFI）→ AcoustID 客户端 →
/// 元数据反向重建服务：三个补全 provider 已迁往组合根 providers.dart
/// （纪律：具体实现的构造只允许出现在组合根）。
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
