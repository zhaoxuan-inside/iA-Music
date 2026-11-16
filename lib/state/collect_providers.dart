/// 收集域 providers：任务流 / GitHub 服务 / 执行服务 / 平台客户端 / NLP 查询。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/fingerprint/media_codec_chromaprint_adapter.dart';
import '../../app/config/acoustid_config.dart';
import '../../data/database.dart';
import '../../domain/ports/fingerprint_port.dart';
import '../services/acoustid/acoustid_client.dart';
import '../services/collect/bilibili_client.dart';
import '../services/collect/collect_service.dart';
import '../services/collect/platform_store.dart';
import '../services/collect/youtube_client.dart';
import '../services/enrich/enrichment_service.dart';
import '../services/enrich/query_nlp.dart';
import '../services/github/github_playlist_service.dart';
import 'diagnostics.dart';
import 'providers.dart';

/// 收集任务实时流（提取进度子页的数据源）。
final collectTasksProvider = StreamProvider(
    (ref) => ref.watch(dbProvider).collectDao.watchAll());

/// GitHub 歌单拉取服务（单例；HttpClient 复用）。
final githubPlaylistServiceProvider =
    Provider<GithubPlaylistService>((ref) => GithubPlaylistService(ref.watch(dbProvider)));

/// 平台账号存取（cookie 持久化）。
final platformStoreProvider =
    Provider<PlatformStore>((ref) => PlatformStore(ref.watch(settingsServiceProvider)));

/// 平台登录态（登录/退出即时刷新）。
///
/// KV 里的 cookie 没有自己的事件流：登录/退出后 bump 这个 epoch，
/// 所有平台登录态 provider 会重新读一遍，而不是依赖调用方记得刷新。
class PlatformLoginEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final platformLoginEpochProvider =
    NotifierProvider<PlatformLoginEpoch, int>(PlatformLoginEpoch.new);

final platformLoginProvider =
    StreamProvider.family<bool, PlatformId>((ref, id) async* {
  ref.watch(platformLoginEpochProvider);
  final store = ref.watch(platformStoreProvider);
  yield await store.loggedIn(id);
});

/// 登录 cookie 的字节长度（只用于状态自检；不暴露内容）。
final platformCookieLengthProvider =
    FutureProvider.family<int, PlatformId>((ref, id) async {
  ref.watch(platformLoginEpochProvider);
  final store = ref.watch(platformStoreProvider);
  final cookies = await store.cookies(id);
  return cookies?.length ?? 0;
});

/// 提取任务提交门面：UI 只经此入队与驱动，不触 data 层类型。
class CollectTasksApi {
  CollectTasksApi(this._ref);

  final Ref _ref;

  IaDatabase get _db => _ref.read(dbProvider);

  /// 入队（来源：bilibili / youtube / direct；标题空由引擎运行时补全）。
  Future<void> enqueue(String source, String url,
      {String title = '', String artist = '', int? playlistId}) {
    return _db.collectDao
        .enqueue(source, url, title: title, artist: artist, playlistId: playlistId);
  }

  /// 驱动执行器跑一轮（异步、可重复调用）。
  Future<void> drive() async {
    final runner = await _ref.read(collectRunnerProvider.future);
    try {
      await runner.runOnce();
    } on Object catch (e, st) {
      // 队列执行的野错误必须收口：记入诊断，僵尸任务由下一轮回收重跑。
      unawaited(_ref
          .read(diagnosticsProvider.notifier)
          .record('收集队列', e, st));
    }
  }

  /// 批量任务失败重试。
  Future<int> retryFailed() => _db.collectDao.retryFailed();
}

final collectTasksApiProvider =
    Provider<CollectTasksApi>(CollectTasksApi.new);

/// B 站客户端（HTTP 复用）。
final bilibiliClientProvider = Provider<BilibiliClient>((ref) {
  final client = BilibiliClient(ref.watch(platformStoreProvider));
  ref.onDispose(client.dispose);
  return client;
});

/// YouTube 客户端（HTTP 复用）。
final youtubeClientProvider = Provider<YoutubeClient>((ref) {
  final client = YoutubeClient(ref.watch(platformStoreProvider));
  ref.onDispose(client.dispose);
  return client;
});

/// 收集执行服务（依赖扫描服务做下载后的真实入库）。
final collectRunnerProvider = FutureProvider<CollectRunner>((ref) async {
  final scan = ref.watch(scanServiceProvider);
  final dirs = await ref.watch(cacheDirsProvider.future);
  return CollectRunner(ref.watch(dbProvider), scan,
      cacheDir: dirs.lyrics,
      bilibili: ref.watch(bilibiliClientProvider),
      youtube: ref.watch(youtubeClientProvider));
});

/// 音频指纹端口（MediaCodec 解码 + chromaprint FFI；原生库缺失 → null）。
final fingerprintPortProvider = FutureProvider<FingerprintPort?>((ref) async {
  return MediaCodecChromaprintAdapter();
});

/// AcoustID 查询客户端。
final acoustidClientProvider = Provider<AcoustidClient>(
    (ref) => AcoustidClient(apiKey: kAcoustidClientKey));

/// 元数据反向重建服务：指纹优先链（真·内容识别）→ NLP+网络搜索回退链。
final enrichmentServiceProvider = FutureProvider<EnrichmentService>((ref) async {
  final dirs = await ref.watch(cacheDirsProvider.future);
  final fp = await ref.watch(fingerprintPortProvider.future);
  return EnrichmentService(ref.watch(dbProvider),
      ref.watch(lyricSearchProvider),
      cacheDir: dirs.lyrics,
      nlp: const QueryNlp(),
      fingerprintPort: fp,
      acoustid: ref.watch(acoustidClientProvider));
});
