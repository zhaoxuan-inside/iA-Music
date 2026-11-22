/// 元数据反向重建服务：对缺元数据的曲目，用 时长锚定 + 在线歌词库匹配
/// 反向得到 歌名/歌手/歌词 并写回曲目行。
///
/// 策略（诚实边界）：
/// * 匹配依据 = 文件名线索 + 音频时长（±3s）——真·音频指纹（chromaprint）
///   需原生库，列入二期；误匹配风险由保守采纳策略控制：
///   仅当候选唯一且时长吻合才采纳。
/// * 匹配成功 → 歌名/歌手写回曲目行 + 歌词入 LyricsMeta（kind=online，缓存文件）。
/// * 已尝试但未匹配的曲目标记 enrichedAt，避免无限重试。
library;

import 'dart:io';

import 'package:drift/drift.dart';

import '../../data/database.dart';
import '../../domain/entities/track.dart';
import '../../domain/errors.dart';
import '../../domain/ports/fingerprint_port.dart';
import '../../domain/ports/lyrics_port.dart';
import '../acoustid/acoustid_client.dart';
import 'query_nlp.dart';

class EnrichmentService {
  EnrichmentService(this._db, this._lyrics,
      {required this.cacheDir,
      this.nlp = const QueryNlp(),
      this.fingerprintPort,
      this.acoustid});

  final IaDatabase _db;
  final LyricTextSearchPort _lyrics;
  final String cacheDir;

  /// 本地 NLP：分词/去噪/构造候选搜索词。
  final QueryNlp nlp;

  /// 指纹链本实例禁用（AcoustID key 无效等配置级致命错误后置位）：
  /// 后续曲目直走文字链，不再逐曲浪费指纹计算 + HTTP 往返（全库千首级
  /// 时是小时级的纯浪费）。key 是编译期常量，修正必经重启——实例级
  /// 标志与之一致，重启自愈。
  bool _fingerprintDisabled = false;

  /// 真·内容识别链：音频指纹 → AcoustID（不依赖文字线索）。
  final FingerprintPort? fingerprintPort;
  final AcoustidClient? acoustid;

  LibraryDao get _library => _db.libraryDao;

  /// 处理一轮待补全曲目（顺序；每首独立成败）。
  ///
  /// 返回 (采纳成功数, 完成数)：完成 = 本轮真正写回/标记过的曲目数
  /// （匹配成功、无候选、无匹配都算）；抛错曲目不计完成——未写回就留在
  /// 待补全池，由调用方裁决（整轮零完成时中断，避免原地打转）。
  /// [onProgress] 上报 (当前曲, 本轮已完成, 本轮总数)，供 UI 进度展示；
  /// [onError] 单曲硬失败回调（带错误原文，供诊断/日志追踪）。
  Future<(int, int)> enrichPending(
      {int limit = 20,
      void Function(String currentTitle, int done, int total)? onProgress,
      void Function(String title, Object error)? onError,
      void Function(String source, Object error)? onSoftError}) async {
    final pending = await _library.watchNeedsEnrichment(limit: limit).first;
    var ok = 0;
    var completed = 0;
    for (final t in pending) {
      onProgress?.call(t.title, completed, pending.length);
      try {
        if (await _enrichOne(t, onSoftError: onSoftError)) {
          ok++;
        }
        completed++;
      } on Object catch (e) {
        // 单首失败不阻断整轮：硬失败计数 +1（≥3 暂出池），阶段时刻不打
        // ——进度条如实停在未处理，待手动重试或网络恢复。
        onError?.call(t.title, e);
        await _library.bumpEnrichAttempts(t.id);
      }
    }
    return (ok, completed);
  }

  Future<bool> _enrichOne(Track t,
      {void Function(String source, Object error)? onSoftError}) async {
    // 指纹优先链：真·音频内容识别（不依赖任何文字线索）。
    // 链内任何失败（如 AcoustID 400/key 无效）→ 回退文字链，绝不炸掉整曲
    // ——否则文字链永远没机会跑，所有曲目全部卡死。
    bool fpAdopted = false;
    if (!_fingerprintDisabled) {
      try {
        fpAdopted = await _fingerprintChain(t);
      } on AuthError catch (e) {
        // key 无效（配置级）：本实例禁用指纹链，后续曲目直走文字链；
        // 只记一次软失败，不逐曲刷屏。
        _fingerprintDisabled = true;
        onSoftError?.call('补全指纹链禁用（key 无效） · ${t.title}', e);
      } on Object catch (e) {
        onSoftError?.call('补全指纹链 · ${t.title}', e);
      }
    }
    if (fpAdopted) {
      return true;
    }
    // 回退链：本地 NLP 构造候选搜索词（文字线索）
    final queries =
        nlp.buildQueries(rawTitle: t.title, fileName: _fileBase(t.path));
    if (queries.isEmpty) {
      await _library.applyEnrichment(
          id: t.id, title: t.title, artist: t.artist);
      return false;
    }

    // 网络搜索 + 时长锚定 + 跨查询投票（同一 歌名|歌手 被多个查询命中=高置信）
    final votes = <String, int>{};
    final meta = <String, LrcMatch>{};
    for (final q in queries) {
      final ms = await _lyrics.searchMatches(q);
      for (final m in ms) {
        if (t.durationMs > 0 &&
            (m.durationMs - t.durationMs).abs() > 3000) {
          continue;
        }
        final key = '${m.trackName}|${m.artistName}';
        votes[key] = (votes[key] ?? 0) + 1;
        meta[key] = m;
        if ((votes[key] ?? 0) >= 3) {
          break;
        }
      }
      if (votes.isNotEmpty && votes.values.reduce((a, b) => a > b ? a : b) >= 3) {
        break;
      }
    }
    if (votes.isEmpty) {
      // 无匹配：保留归一化歌名，标记已尝试（enrichedAt），避免无限重试
      await _library.applyEnrichment(
          id: t.id, title: t.title, artist: t.artist);
      return false;
    }
    var bestKey = '';
    var bestVotes = -1;
    votes.forEach((k, v) {
      if (v > bestVotes) {
        bestVotes = v;
        bestKey = k;
      }
    });
    final best = meta[bestKey]!;
    final newTitle = best.trackName.isNotEmpty ? best.trackName : t.title;
    final newArtist = best.artistName.isNotEmpty ? best.artistName : t.artist;

    await _library.applyEnrichment(
        id: t.id, title: newTitle, artist: newArtist);
    await _saveLyrics(
        t.id, best.syncedLrc.trim().isNotEmpty ? best.syncedLrc : best.plainLrc);
    return true;
  }

  /// 指纹优先链：chromaprint 指纹 → AcoustID 最佳录音 → 采纳 歌名/歌手
  /// → 按新元数据从 LRCLIB 拉歌词。失败/无匹配 → false（回退文字链）。
  Future<bool> _fingerprintChain(Track t) async {
    final fpPort = fingerprintPort;
    final acoustid = this.acoustid;
    if (fpPort == null || acoustid == null || t.durationMs <= 0) {
      return false;
    }
    final fp = await fpPort.fingerprint(t.path, durationMs: t.durationMs);
    if (fp == null) {
      return false;
    }
    final match = await acoustid.lookup(
        fingerprint: fp.fingerprint, durationMs: fp.durationMs);
    if (match == null || match.title.isEmpty) {
      return false;
    }
    // 歌词先取（用匹配元数据，不依赖库内写回）——网络失败在写回前抛出，
    // 三阶段时刻都不打，曲目留在待补全池等待重试。
    final hit = await _lyrics.getByFields(
        title: match.title,
        artist: match.artist,
        durationMs: t.durationMs);
    final lrc = hit == null
        ? null
        : (hit.syncedLrc.trim().isNotEmpty ? hit.syncedLrc : hit.plainLrc);
    await _library.applyEnrichment(
        id: t.id, title: match.title, artist: match.artist);
    if (lrc != null && lrc.trim().isNotEmpty) {
      await _saveLyrics(t.id, lrc);
    }
    return true;
  }

  String _fileBase(String path) {
    final name = path.substring(path.lastIndexOf('/') + 1);
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  Future<void> _saveLyrics(int trackId, String lrc) async {
    if (lrc.trim().isEmpty) {
      return;
    }
    final f = File('$cacheDir/lyrics_enriched_$trackId.lrc');
    await f.writeAsString(lrc, flush: true);
    await _db.lyricsDao.upsert(
      trackId,
      LyricsMetaCompanion.insert(
        trackId: Value(trackId),
        kind: const Value('online'),
        lrcPath: Value(f.path),
      ),
    );
  }
}
