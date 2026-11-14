/// 收集域 providers：任务流 / GitHub 服务 / 执行服务 / NLP 查询。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/fingerprint/mpv_chromaprint_adapter.dart';
import '../../app/config/acoustid_config.dart';
import '../../domain/ports/fingerprint_port.dart';
import '../services/acoustid/acoustid_client.dart';
import '../services/collect/collect_service.dart';
import '../services/enrich/enrichment_service.dart';
import '../services/enrich/query_nlp.dart';
import '../services/github/github_playlist_service.dart';
import 'providers.dart';

/// 收集任务实时流（提取进度子页的数据源）。
final collectTasksProvider = StreamProvider(
    (ref) => ref.watch(dbProvider).collectDao.watchAll());

/// GitHub 歌单拉取服务（单例；HttpClient 复用）。
final githubPlaylistServiceProvider =
    Provider<GithubPlaylistService>((ref) => GithubPlaylistService(ref.watch(dbProvider)));

/// 收集执行服务（依赖扫描服务做下载后的真实入库）。
final collectRunnerProvider = FutureProvider<CollectRunner>((ref) async {
  final scan = ref.watch(scanServiceProvider);
  final dirs = await ref.watch(cacheDirsProvider.future);
  return CollectRunner(ref.watch(dbProvider), scan, cacheDir: dirs.lyrics);
});

/// 音频指纹端口（mpv 解码 + chromaprint FFI；原生库缺失 → null）。
final fingerprintPortProvider = FutureProvider<FingerprintPort?>((ref) async {
  return MpvChromaprintAdapter();
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
