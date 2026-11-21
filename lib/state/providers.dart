/// 组合 provider：db / Port 适配器 / 服务（测试用 overrides 注入 fake）。
///
/// 纪律：具体实现的构造只允许出现在本文件（组合根）。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../adapters/covers/cover_fetch_adapter.dart';
import '../adapters/engine/just_audio_engine_adapter.dart';
import '../adapters/lyrics/lrclib_adapter.dart';
import '../adapters/metadata/metadata_reader_adapter.dart';
import '../data/database.dart';
import '../domain/ports/cover_port.dart';
import '../domain/ports/engine_port.dart';
import '../domain/ports/lyrics_port.dart';
import '../domain/ports/metadata_port.dart';
import '../services/covers/cover_chain.dart';
import '../services/lyrics/lyrics_pipeline.dart';
import '../services/playback/playback_service.dart';
import '../services/scan/root_watcher.dart';
import '../services/scan/scan_service.dart';
import '../services/settings/settings_service.dart';

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

/// 应用私有目录集（covers / lyrics 兜底缓存 + plugins 插件根目录）。
class CacheDirs {
  const CacheDirs({
    required this.covers,
    required this.lyrics,
    required this.plugins,
  });

  final String covers;
  final String lyrics;

  /// 插件根目录（registry.json / `<id>`/main.js / `<id>`/kv.json）。
  final String plugins;
}

final cacheDirsProvider = FutureProvider<CacheDirs>((ref) async {
  final support = await getApplicationSupportDirectory();
  // 目录要显式创建：Dart 的文件写入不自动建父目录，缺目录时写入会失败。
  final dirs = CacheDirs(
    covers: '${support.path}${Platform.pathSeparator}covers',
    lyrics: '${support.path}${Platform.pathSeparator}lyrics',
    plugins: '${support.path}${Platform.pathSeparator}plugins',
  );
  await Directory(dirs.covers).create(recursive: true);
  await Directory(dirs.lyrics).create(recursive: true);
  await Directory(dirs.plugins).create(recursive: true);
  return dirs;
});

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
  );
  ref.onDispose(service.dispose);
  return service;
});

final rootWatcherProvider = Provider<RootWatcher>((ref) {
  final db = ref.watch(dbProvider);
  final scan = ref.watch(scanServiceProvider);
  final watcher = RootWatcher(db, (rootId, rootPath) {
    unawaited(scan.scanRoot(rootId, rootPath));
  });
  ref.onDispose(watcher.dispose);
  return watcher;
});
