/// LyricsService —— 歌词补全服务（2026-10-25 用户裁决：单级链路）。
///
/// 链路（LRCLIB 标题匹配级已按裁决移除）：
/// * 标题剖析（B 站多 P 分页形态：`<合集名> pNN NNN. 歌名 - 歌手`）。
/// * 本地 SenseVoice ASR 转写 → .lrc 同目录落盘（仅 Windows；识别现已
///   运行于专用 worker isolate，主线程不冻结）。
/// * 歌词正文反查（网易 1006，多句投票+时长锚）→ 正式歌名/歌手/专辑回写
///   → 网易标准歌词覆写 .lrc + 专辑封面落盘（fetched 档）。
/// * 未命中如实记 asr_unavailable，不伪造不占位。
/// * 歌词文件约定=**音频同目录 `.lrc`**；lyrics_meta.type=lrc 落账；
///   曲目变更走 revision 事件联动（hub 已接线）。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:ia_music/adapters/asr_adapter.dart';
import 'package:ia_music/adapters/netease_lyric_search.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/lyrics/asr_lyrics.dart';

final class LyricsOutcome {
  const LyricsOutcome(this.kind, {this.lrcPath, this.errorCode});
  final LyricsOutcomeKind kind;
  final String? lrcPath;
  final String? errorCode;
}

enum LyricsOutcomeKind { noMatch, asrUnavailable, asrGenerated }

final class LyricsService {
  LyricsService(
    this._db,
    this._lyrics, {
    this.asr,
    Future<String?> Function()? modelDirResolver,
    this.textSearch,
    this.onTrackEnriched,
  }) : _modelDir = modelDirResolver;

  final IaDatabase _db;
  final LyricsDao _lyrics;

  /// 本地 ASR 兜底（2026-10-25 装配：SenseVoice 应用内原生形态优先）。
  final LocalAsrPort? asr;
  final Future<String?> Function()? _modelDir;

  /// 歌词正文反查（2026-10-25 用户拍板：网易 1006；合集拆段无歌名场景）。
  final LyricTextSearchPort? textSearch;

  /// 反查命中改写歌名/歌手后回调（壳层 bump revision + 触发封面重取）。
  final void Function(int trackId)? onTrackEnriched;

  /// 串行运行（REQ-LYRAI-03 语义延用：同一时刻至多一个 job 在跑）。
  final List<int> _queue = [];
  bool _running = false;

  /// 提取注册后联动入口（EXT-08 withLyrics：job 已 schedule → 排队处理）。
  void enqueue(int trackId) {
    if (_queue.contains(trackId)) {
      return;
    }
    _queue.add(trackId);
    if (!_running) {
      _running = true;
      _drain();
    }
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      final trackId = _queue.removeAt(0);
      try {
        await runForTrack(trackId);
      } catch (_) {
        // 工作循环永不崩（§4.3 同款）：单条失败不打断后续。
      }
    }
    _running = false;
  }

  /// B 站多 P 分页标题剖析 → (歌名, 歌手?)。
  /// 真形态（BV1ANQqBTEVU 分页实测）：`<合集名> pNN NNN. 歌名 - 歌手` →
  /// 剥「全部前缀+分页号 pNN」→ 剥「NNN. 编号」→ 末 dash 切（歌名, 歌手）；
  /// dash 兼容全角/长破折号（－ – —）；无 dash → 回退（原题, null）。
  static (String, String?) parseBiliPageTitle(String raw) {
    var s = raw.trim();
    s = s.replaceFirst(RegExp(r'^.*?\bp\d+\s+'), ''); // <合集名>…pNN
    s = s.replaceFirst(RegExp(r'^\d+[.．]\s*'), ''); // NNN. 编号
    s = s.trim();
    final m = RegExp(r'^(.+?)\s+[-－–—]\s+(.+)$').firstMatch(s);
    if (m != null) {
      final song = m.group(1)!.trim();
      final artist = m.group(2)!.trim();
      if (song.isNotEmpty && artist.isNotEmpty) {
        return (song, artist);
      }
    }
    return (s, null);
  }

  /// 单曲全量（2026-10-25 用户裁决：去掉 LRCLIB 标题匹配级）：
  /// 剖析标题 → 直接 ASR 转写 → 歌词正文反查 → 网易标准歌词/封面回填。
  Future<LyricsOutcome> runForTrack(int trackId) async {
    final track = await (_db.select(
      _db.tracks,
    )..where((t) => t.id.equals(trackId))).getSingleOrNull();
    if (track == null || track.deletedAt != null) {
      return const LyricsOutcome(LyricsOutcomeKind.noMatch);
    }
    final (song, _) = LyricsService.parseBiliPageTitle(track.title ?? '');
    if (song.trim().isEmpty) {
      return const LyricsOutcome(
        LyricsOutcomeKind.asrUnavailable,
        errorCode: 'asr_unavailable',
      );
    }
    final asrOutcome = await _runAsrFallback(track);
    return asrOutcome ??
        const LyricsOutcome(
          LyricsOutcomeKind.asrUnavailable,
          errorCode: 'asr_unavailable',
        );
  }

  /// ASR 主路：模型在位 → 转写音频 → LRC 成形 → 同目录 .lrc + lyrics_meta →
  /// 歌词正文反查（网易 1006）→ 身份回写 + 标准歌词/封面回填。不可用=null。
  Future<LyricsOutcome?> _runAsrFallback(Track track) async {
    final asr = this.asr;
    final resolver = _modelDir;
    if (asr == null || resolver == null) {
      return null;
    }
    final modelDir = await resolver();
    if (modelDir == null) {
      return null;
    }
    final root = await (_db.select(
      _db.repositoryRoots,
    )..where((r) => r.id.equals(track.rootId))).getSingleOrNull();
    if (root == null) {
      return null;
    }
    final audioPath =
        '${root.path.replaceAll('\\', '/')}/${track.relPath.replaceAll('\\', '/')}';
    final tokens = await asr.transcribe(
      modelDir: modelDir,
      audioPath: audioPath,
    );
    if (tokens == null || tokens.isEmpty) {
      return null;
    }
    final lyrics = asrTokensToLyrics(tokens);
    if (lyrics.lrc.isEmpty) {
      return null;
    }
    final rel = track.relPath.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
    final absPath = '${root.path}${Platform.pathSeparator}$rel';
    final f = File(absPath);
    f.createSync(recursive: false);
    f.writeAsStringSync(lyrics.lrc, flush: true);
    await _lyrics.upsertMeta(
      trackId: track.id,
      type: LyricsSourceType.lrc,
      lrcPath: rel,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    // 歌词正文反查（合集拆段无歌名）：多句投票+时长锚 → 正式歌名/歌手 →
    // 改写轨行（歌名/歌手/专辑）+ 回调（revision bump + 封面按新身份重取）。
    final search = textSearch;
    if (search != null) {
      final lines = lyrics.plainText
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final id = await search.identifyByLyrics(
        lines,
        durationMs: track.durationMs,
      );
      if (id != null && id.title.isNotEmpty) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        int? artistId;
        if (id.artist.isNotEmpty) {
          artistId = await _upsertArtistName(id.artist, nowMs);
        }
        await (_db.update(
          _db.tracks,
        )..where((t) => t.id.equals(track.id))).write(
          TracksCompanion(
            title: Value(id.title),
            artistDisplay: id.artist.isNotEmpty
                ? Value(id.artist)
                : const Value.absent(),
            albumDisplay: (id.album ?? '').isNotEmpty
                ? Value(id.album!)
                : const Value.absent(),
            artistId: artistId != null ? Value(artistId) : const Value.absent(),
            updatedAt: Value(nowMs),
          ),
        );
        await _db.updateTrackIndex(
          track.id,
          title: id.title,
          artist: id.artist,
          album: id.album ?? '',
        );
        // D12-4①②「补全成完整的歌」：标准歌词回填 + 网易封面落盘
        //（fetched 档 `<音频名>.cover.jpg` 与 CoverChain 天然衔接，零链改动）。
        await _completeFromIdentity(search, track, root, id, rel);
        onTrackEnriched?.call(track.id);
      }
    }
    return LyricsOutcome(LyricsOutcomeKind.asrGenerated, lrcPath: rel);
  }

  /// 反查身份 → ①标准歌词覆写 .lrc ②网易封面落盘（D12-4；失败静默不阻塞）。
  Future<void> _completeFromIdentity(
    LyricTextSearchPort search,
    Track track,
    dynamic root,
    LyricsIdentity id,
    String lrcRel,
  ) async {
    try {
      final synced = await search.fetchSyncedLyrics(id.songId);
      if (synced != null && synced.contains('[')) {
        final lrcAbs = '${root.path}${Platform.pathSeparator}$lrcRel';
        File(lrcAbs).writeAsStringSync(synced, flush: true);
      }
      final cover = await search.fetchCover(id.songId);
      if (cover != null && cover.bytes.isNotEmpty) {
        final coverRel =
            track.relPath.replaceAll(RegExp(r'\.[^.]+$'), '.cover.jpg');
        final coverAbs =
            '${root.path}${Platform.pathSeparator}$coverRel';
        File(coverAbs).writeAsBytesSync(cover.bytes, flush: true);
      }
    } catch (_) {
      // 补全失败不回滚身份写回（歌名/歌手已落库；下次扫描可重试封面链）。
    }
  }

  /// 字典 upsert（与 LibraryDao._upsertArtist 同构；norm 唯一键复用）。
  Future<int?> _upsertArtistName(String display, int nowMs) async {
    final norm = normalizeName(display);
    final found = await (_db.select(
      _db.artists,
    )..where((a) => a.nameNorm.equals(norm))).getSingleOrNull();
    if (found != null) {
      return found.id;
    }
    return _db
        .into(_db.artists)
        .insert(
          ArtistsCompanion.insert(
            name: display,
            nameNorm: norm,
            updatedAt: nowMs,
          ),
        );
  }
}
