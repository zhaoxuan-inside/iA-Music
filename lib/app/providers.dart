/// 组合根（宪章：app/ 是全仓库唯一允许 new 具体实现的地方）。
///
/// db / Port 适配器 / 服务 / 插件与收集的装配都在这里（测试用 overrides
/// 注入 fake）。state 层经本文件拿 db 与服务——数据层类型（行类/状态枚举）
/// 也从这里中继，state 不直接 import data。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../adapters/covers/cover_fetch_adapter.dart';
import '../adapters/engine/just_audio_engine_adapter.dart';
import '../adapters/fingerprint/media_codec_chromaprint_adapter.dart';
import '../adapters/lyrics/lrclib_adapter.dart';
import '../adapters/metadata/metadata_reader_adapter.dart';
import '../data/database.dart';
import '../data/models/model_store.dart';
import '../domain/ports/cover_port.dart';
import '../domain/ports/embedding_port.dart';
import '../domain/ports/engine_port.dart';
import '../domain/ports/fingerprint_port.dart';
import '../domain/ports/lyrics_port.dart';
import '../domain/ports/metadata_port.dart';
import '../inference/litert_yamnet_adapter.dart';
import '../plugins/default_plugins.dart';
import '../plugins/plugin_registry.dart';
import '../plugins/plugin_runtime.dart';
import '../plugins/quickjs_plugin_runtime.dart';
import '../services/acoustid/acoustid_client.dart';
import '../services/collect/collect_service.dart';
import '../services/collect/source_plugins.dart';
import '../services/covers/cover_chain.dart';
import '../services/enrich/enrichment_service.dart';
import '../services/enrich/query_nlp.dart';
import '../services/log/log_file_writer.dart';
import '../services/lyrics/lyrics_pipeline.dart';
import '../services/playback/playback_service.dart';
import '../services/scan/root_watcher.dart';
import '../services/scan/scan_service.dart';
import '../services/settings/settings_service.dart';
import '../state/diagnostics.dart';
import 'config/acoustid_config.dart';
import 'config/embedding_config.dart';

/// state 层所需的 data 行类/状态枚举经此中继（state 禁 import data；
/// 类型可见性走组合根单一通道）。
export '../data/database.dart'
    show CollectStatusCol, CollectTaskRow, HistoryItem, IaDatabase, PlaylistDao,
         RepositoryRoot;

final dbProvider = Provider<IaDatabase>((ref) {
  final db = IaDatabase(openAppDatabase());
  ref.onDispose(db.close);
  return db;
});

final metadataPortProvider =
    Provider<MetadataPort>((ref) => const MetadataReaderAdapter());

final engineProvider = Provider<EnginePort>((ref) {
  final engine = JustAudioEngineAdapter();
  ref.onDispose(engine.dispose);
  return engine;
});

final lyricSearchProvider = Provider<LyricTextSearchPort>((ref) {
  final adapter = LrclibAdapter();
  ref.onDispose(adapter.dispose);
  return adapter;
});

final coverFetchProvider = Provider<CoverFetchPort>((ref) {
  final adapter = CoverFetchAdapter();
  ref.onDispose(adapter.dispose);
  return adapter;
});

final settingsServiceProvider =
    Provider<SettingsService>((ref) => SettingsService(ref.watch(dbProvider).settingsDao));

/// 追踪日志文件写入器（`<logs>/trace.log`，≤100MB 滚动）。
final logFileWriterProvider = FutureProvider<LogFileWriter>((ref) async {
  final dirs = await ref.watch(cacheDirsProvider.future);
  return LogFileWriter(dir: dirs.logs);
});

/// 应用私有目录集（covers / lyrics 兜底缓存 + plugins 插件根目录 + logs 日志）。
class CacheDirs {
  const CacheDirs({
    required this.covers,
    required this.lyrics,
    required this.plugins,
    required this.logs,
    required this.models,
  });

  final String covers;
  final String lyrics;

  /// 插件根目录（registry.json / `<id>`/main.js / `<id>`/kv.json）。
  final String plugins;

  /// 日志目录（trace.log，≤100MB 滚动）。
  final String logs;

  /// 推理模型目录（ModelStore 在线下载落盘；data 层文件管理域）。
  final String models;
}

final cacheDirsProvider = FutureProvider<CacheDirs>((ref) async {
  final support = await getApplicationSupportDirectory();
  // 目录要显式创建：Dart 的文件写入不自动建父目录，缺目录时写入会失败。
  final dirs = CacheDirs(
    covers: '${support.path}${Platform.pathSeparator}covers',
    lyrics: '${support.path}${Platform.pathSeparator}lyrics',
    plugins: '${support.path}${Platform.pathSeparator}plugins',
    logs: '${support.path}${Platform.pathSeparator}logs',
    models: '${support.path}${Platform.pathSeparator}models',
  );
  await Directory(dirs.covers).create(recursive: true);
  await Directory(dirs.lyrics).create(recursive: true);
  await Directory(dirs.plugins).create(recursive: true);
  await Directory(dirs.logs).create(recursive: true);
  await Directory(dirs.models).create(recursive: true);
  return dirs;
});

/// 安装包版本元数据（pubspec version 的构建产物 versionName/versionCode）。
/// 关于页展示用——不再手写同步常量（曾连续 13 个发版漂移显示 v0.0.4）。
final packageInfoProvider = FutureProvider<PackageInfo>(
    (ref) => PackageInfo.fromPlatform());

// ── 插件域装配（自 state/plugin_providers.dart 迁入）──────────────────

/// 市场索引 URL（可指向自建仓库；默认空 = 未配置市场）。
const String marketUrlKey = 'plugins.market.url';

final pluginRegistryProvider = FutureProvider<PluginRegistry>((ref) async {
  final dirs = await ref.watch(cacheDirsProvider.future);
  final registry = PluginRegistry(dir: dirs.plugins);
  // 默认插件就位（幂等；版本升级覆盖；用户卸载过的跳过）
  final skipRaw =
      await ref.watch(settingsServiceProvider).getString(defaultUninstalledKey) ??
          '[]';
  final skip = (jsonDecode(skipRaw) as List?)
          ?.whereType<String>()
          .toSet() ??
      const <String>{};
  await ensureDefaultPlugins(registry, skip);
  return registry;
});

final pluginRuntimeProvider = FutureProvider<PluginRuntimePort>((ref) async {
  return QuickJsPluginRuntime(registry: await ref.watch(pluginRegistryProvider.future));
});

// ── 收集域装配（自 state/collect_providers.dart 迁入）──────────────────

/// 音频源插件门面（QuickJS 运行时 + 注册表之上的契约封装）。
final sourcePluginsProvider = FutureProvider<SourcePlugins>((ref) async {
  final registry = await ref.watch(pluginRegistryProvider.future);
  final runtime = await ref.watch(pluginRuntimeProvider.future);
  return SourcePlugins(registry, runtime,
      // 插件 match 抛错（崩/超时）→ 日志可见，不再伪装成「无法识别」
      onMatchError: (id, e, st) => unawaited(
          ref.read(diagnosticsProvider.notifier).record('插件路由 · $id', e, st)));
});

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

// ── 内容链路（封面 / 歌词 / 扫描 / 播放 / 补全）────────────────────────

final coverChainProvider = FutureProvider<CoverChain>((ref) async {
  final dirs = await ref.watch(cacheDirsProvider.future);
  return CoverChain(
    db: ref.watch(dbProvider),
    metadata: ref.watch(metadataPortProvider),
    fetcher: ref.watch(coverFetchProvider),
    cacheDir: dirs.covers,
  );
});

final lyricsPipelineProvider = FutureProvider<LyricsPipeline>((ref) async {
  final dirs = await ref.watch(cacheDirsProvider.future);
  return LyricsPipeline(
    db: ref.watch(dbProvider),
    metadata: ref.watch(metadataPortProvider),
    lyrics: ref.watch(lyricSearchProvider),
    cacheDir: dirs.lyrics,
  );
});

final scanServiceProvider = Provider<ScanService>((ref) {
  return ScanService(ref.watch(dbProvider));
});

final playbackServiceProvider = Provider<PlaybackService>((ref) {
  final service = PlaybackService(
    engine: ref.watch(engineProvider),
    db: ref.watch(dbProvider),
    settings: ref.watch(settingsServiceProvider),
    // 播放域故障不再蒸发：恢复/装载失败（冷启动播放钮无反应这类）进诊断
    onError: (source, e, [st]) => unawaited(
        ref.read(diagnosticsProvider.notifier).record(source, e, st)),
  );
  ref.onDispose(service.dispose);
  return service;
});

final rootWatcherProvider = Provider<RootWatcher>((ref) {
  final db = ref.watch(dbProvider);
  final scan = ref.watch(scanServiceProvider);
  final watcher = RootWatcher(
    db,
    // 文件变更增量扫描：失败归属到扫描域日志（曾经是野错误漂进「未捕获」）
    (rootId, rootPath) {
      unawaited(() async {
        try {
          await scan.scanRoot(rootId, rootPath);
        } on Object catch (e, st) {
          unawaited(ref
              .read(diagnosticsProvider.notifier)
              .record('扫描 · watcher 增量', e, st));
        }
      }());
    },
    onWatchError: (rootPath, e, st) => unawaited(
        ref.read(diagnosticsProvider.notifier).record('根目录监听 · $rootPath', e, st)),
  );
  ref.onDispose(watcher.dispose);
  return watcher;
});

/// 音频指纹端口（MediaCodec 解码 + chromaprint FFI；原生库缺失 → null）。
final fingerprintPortProvider = FutureProvider<FingerprintPort?>((ref) async {
  return MediaCodecChromaprintAdapter();
});

/// 模型文件仓库（data 层文件管理域：在线下载/校验/落盘/登记的唯一管理面）。
final modelStoreProvider = FutureProvider<ModelStore>((ref) async {
  final dirs = await ref.watch(cacheDirsProvider.future);
  return ModelStore(ref.watch(dbProvider), dirs.models);
});

/// 音频嵌入端口（LiteRT + YAMNet 推理；模型文件管理在 data 层 ModelStore，
/// 经 resolveModel 回调接线——inference 不知存储与下载的存在）。
/// 不可用链：模型未下载/下载失败/原生侧缺失/模型装载失败 → null，
/// 补全管线按「端口不可用」会话级禁用向量轮，下一轮 runOnce 重试。
final embeddingPortProvider = FutureProvider<EmbeddingPort?>((ref) async {
  final store = await ref.watch(modelStoreProvider.future);
  final settings = ref.watch(settingsServiceProvider);
  return LitertYamnetAdapter(resolveModel: () async {
    final urlOverride = await settings.getString(kEmbeddingModelUrlKey);
    try {
      return await store.ensureReady(
        id: kEmbeddingModel,
        url: (urlOverride == null || urlOverride.isEmpty)
            ? kEmbeddingModelUrl
            : urlOverride,
        sha256: kEmbeddingModelSha256,
        sizeBytes: kEmbeddingModelBytes,
      );
    } on Object catch (e) {
      // 下载/校验失败原文进诊断（data 层不碰日志域，组合根中继）
      unawaited(
          ref.read(diagnosticsProvider.notifier).record('模型下载', e));
      return null;
    }
  });
});

/// AcoustID 查询客户端。
final acoustidClientProvider = Provider<AcoustidClient>(
    (ref) => AcoustidClient(apiKey: kAcoustidClientKey));

/// 元数据反向重建服务：指纹优先链（真·内容识别）→ NLP+网络搜索回退链。
final enrichmentServiceProvider = FutureProvider<EnrichmentService>((ref) async {
  final dirs = await ref.watch(cacheDirsProvider.future);
  final fp = await ref.watch(fingerprintPortProvider.future);
  final emb = await ref.watch(embeddingPortProvider.future);
  return EnrichmentService(ref.watch(dbProvider),
      ref.watch(lyricSearchProvider),
      cacheDir: dirs.lyrics,
      nlp: const QueryNlp(),
      fingerprintPort: fp,
      embeddingPort: emb,
      acoustid: ref.watch(acoustidClientProvider));
});
