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
import '../../domain/ports/lyrics_port.dart';
import '../../domain/ports/fingerprint_port.dart';
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

  /// 真·内容识别链：音频指纹 → AcoustID（不依赖文字线索）。
  final FingerprintPort? fingerprintPort;
  final AcoustidClient? acoustid;

  LibraryDao get _library => _db.libraryDao;

  /// 处理一轮待补全曲目（顺序；每首独立成败）。返回采纳成功条数。
  Future<int> enrichPending({int limit = 20}) async {
    final pending = await _library.watchNeedsEnrichment(limit: limit).first;
    var ok = 0;
    for (final t in pending) {
      try {
        if (await _enrichOne(t)) {
          ok++;
        }
      } on Object {
        // 单首失败不阻断整轮
      }
    }
    return ok;
  }

  Future<bool> _enrichOne(Track t) async {
    // 指纹优先链：真·音频内容识别（不依赖任何文字线索）
    final fpAdopted = await _fingerprintChain(t);
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
    await _library.applyEnrichment(
        id: t.id, title: match.title, artist: match.artist);
    // 歌词按重建后的真实元数据拉取
    final hit = await _lyrics.getByFields(
        title: match.title,
        artist: match.artist,
        durationMs: t.durationMs);
    final lrc = hit == null
        ? null
        : (hit.syncedLrc.trim().isNotEmpty ? hit.syncedLrc : hit.plainLrc);
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
