/// EnrichService —— 本地扫描曲目识别修正（2026-10-30 用户裁决）。
///
/// 语义（与 B 站采集曲目同方案：锚定命中即回写）：
/// * 层级兜底：LRCLIB 文本匹配（时长锚 ±2s 内建于适配器）→ 网易名称搜索
///   （时长锚 ±3s）→ ASR 转写正文反查（Windows；委托 ExtractQueue.lyrics
///   既有 B 站链路，零复制）。
/// * 回写面=**DB 展示字段 + 同目录旁车文件**（REQ-LIB-03 红线：不改音频）：
///   身份→`applyIdentity`（字典+tracks+FTS 同事务）；歌词→同目录 `.lrc` +
///   lyrics_meta(lrc)；封面→`<音频名>.cover.jpg`（fetched 档，CoverChain 天然衔接）。
/// * 守卫：lyrics_meta.edited=true → 不落任何歌词文件（身份回写照常）——
///   唯一保守偏差，防覆盖用户手改歌词。
/// * 仅纯文本歌词不落盘（无时间轴不回填，`_completeFromIdentity` 同纪律）。
/// * 触发：扫描新增/复活曲目自动入队（ScanReport.addedTrackIds）+ 设置页
///   每根手动「识别修正」；串行队列 + 条间限速（礼貌出网）。
library;

import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:ia_music/adapters/netease_lyric_search.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';

/// 单曲修正产物（evidence/测试断言面；asrDelegated=tier3 已委托 B 站链路）。
final class EnrichOutcome {
  const EnrichOutcome({
    this.identityWritten = false,
    this.lyricsWritten = false,
    this.coverWritten = false,
    this.asrDelegated = false,
  });

  final bool identityWritten;
  final bool lyricsWritten;
  final bool coverWritten;
  final bool asrDelegated;

  bool get touched => identityWritten || lyricsWritten || coverWritten;
}

final class EnrichService {
  EnrichService({
    required IaDatabase db,
    required this.lrclib,
    required this.songSearch,
    required this.asrFallback,
    this.onTrackEnriched,
  })  : _lyrics = DataAccess(db).lyrics,
        _lib = DataAccess(db).library;

  final LyricsDao _lyrics;
  final LibraryDao _lib;

  /// tier 1：LRCLIB 文本匹配（contracts LyricsPort；测试注入 fake）。
  final LyricsPort lrclib;

  /// tier 2：网易名称搜索（SongSearchPort；测试注入 fake）。
  final SongSearchPort songSearch;

  /// tier 3：ASR 兜底（= ExtractQueue.lyrics.runForTrack；Android/无模型时
  /// 返回 asrUnavailable，天然 no-op）。
  final Future<void> Function(int trackId) asrFallback;

  /// 修正命中回调（壳层 bump revision + 封面按新身份重取）。
  final void Function(int trackId)? onTrackEnriched;

  /// 条间限速（串行队列已保证同时至多一曲；再垫间隔防高频出网）。
  static const kTrackGapMs = 1000;

  final List<int> _queue = [];
  bool _running = false;
  bool _disposed = false;

  /// 在跑曲目（去重含在跑：_drain 同步 removeAt 后 _queue 已不含它——
  /// 全量扫描报告与 watcher 增量报告重叠时可重复入队同一曲，实证）。
  int? _current;

  void enqueue(int trackId) {
    if (_disposed || _current == trackId || _queue.contains(trackId)) {
      return;
    }
    _queue.add(trackId);
    if (!_running) {
      _running = true;
      _drain();
    }
  }

  void enqueueAll(Iterable<int> trackIds) {
    for (final id in trackIds) {
      enqueue(id);
    }
  }

  Future<void> _drain() async {
    var first = true;
    while (_queue.isNotEmpty && !_disposed) {
      final trackId = _queue.removeAt(0);
      _current = trackId;
      if (!first) {
        await Future<void>.delayed(const Duration(milliseconds: kTrackGapMs));
      }
      first = false;
      try {
        await runForTrack(trackId);
      } catch (_) {
        // 工作循环永不崩（LyricsService 同款）：单条失败不打断后续。
      }
      _current = null;
    }
    _running = false;
  }

  void dispose() {
    _disposed = true;
    _queue.clear();
  }

  /// 单曲三级兜底（命中即止的层级推进：tier2 仅当 tier1 无同步歌词；
  /// tier3 仅当 tier1/tier2 一无所获——身份已知时 ASR 兜底纯浪费且有
  /// 二次误判覆盖风险）。
  Future<EnrichOutcome> runForTrack(int trackId) async {
    final track = await _lib.rowById(trackId);
    if (track == null || track.deletedAt != null) {
      return const EnrichOutcome();
    }
    final root = await _lib.rootById(track.rootId);
    if (root == null) {
      return const EnrichOutcome();
    }
    final meta = await _lyrics.metaFor(trackId);
    final lyricsLocked = meta?.edited ?? false; // 用户手改歌词 → 不落盘

    var curTitle = track.title ?? '';
    var curArtist = track.artistDisplay ?? '';
    var curAlbum = track.albumDisplay ?? '';
    var identityWritten = false;
    var lyricsWritten = false;
    var coverWritten = false;

    // ── tier 1：LRCLIB 文本匹配（时长锚 ±2s 内建于适配器） ──────────────
    final res = await lrclib.resolve(LyricsQuery(
      trackId: track.id,
      title: curTitle,
      artistDisplay: curArtist.isEmpty ? null : curArtist,
      albumDisplay: curAlbum.isEmpty ? null : curAlbum,
      durationMs: track.durationMs,
    ));
    if (res != null) {
      final canonical = _pickIdentity(
        title: res.trackName,
        artist: res.artistName,
        album: res.albumName,
      );
      if (canonical != null) {
        await _lib.applyIdentity(
          track.id,
          title: canonical.title,
          artist: canonical.artist,
          album: canonical.album,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        );
        curTitle = canonical.title ?? curTitle;
        curArtist = canonical.artist ?? curArtist;
        curAlbum = canonical.album ?? curAlbum;
        identityWritten = true;
      }
      if (!lyricsLocked &&
          (res.syncedLyrics?.contains('[') ?? false)) {
        lyricsWritten = await _writeLrc(track, root.path, res.syncedLyrics!);
      }
    }

    // ── tier 2：网易名称搜索（tier1 无同步歌词时推进；用（可能已修正的）
    //   现名检索，锚 ±3s） ────────────────────────────────────────────
    if (!lyricsWritten && !lyricsLocked) {
      final id = await songSearch.searchByName(
        title: curTitle,
        artist: curArtist.isEmpty ? null : curArtist,
        durationMs: track.durationMs,
      );
      if (id != null) {
        if (!identityWritten) {
          await _lib.applyIdentity(
            track.id,
            title: id.title,
            artist: id.artist,
            album: id.album,
            nowMs: DateTime.now().millisecondsSinceEpoch,
          );
          identityWritten = true;
        }
        final synced = await songSearch.fetchSyncedLyrics(id.songId);
        if (synced != null && synced.contains('[')) {
          lyricsWritten = await _writeLrc(track, root.path, synced);
        }
        final cover = await songSearch.fetchCover(id.songId);
        if (cover != null && cover.bytes.isNotEmpty) {
          coverWritten = _writeCover(track, root.path, cover.bytes);
        }
      }
    }

    // ── tier 3：ASR 正文反查兜底（一无所获才推进；B 站链路全托管，
    //   含其自身 onTrackEnriched 回调——此处不重复触发） ────────────────
    if (!identityWritten && !lyricsWritten && !lyricsLocked) {
      await asrFallback(track.id);
      return EnrichOutcome(asrDelegated: true);
    }

    if (identityWritten || lyricsWritten || coverWritten) {
      onTrackEnriched?.call(track.id);
    }
    return EnrichOutcome(
      identityWritten: identityWritten,
      lyricsWritten: lyricsWritten,
      coverWritten: coverWritten,
    );
  }

  /// 命中身份裁剪：LRCLIB 正名可为空串（仅歌词命中场景）→ 全空=无身份可写。
  ({String? title, String? artist, String? album})? _pickIdentity({
    required String title,
    required String artist,
    String? album,
  }) {
    final t = title.trim();
    final a = artist.trim();
    final al = (album ?? '').trim();
    if (t.isEmpty && a.isEmpty && al.isEmpty) {
      return null;
    }
    return (
      title: t.isEmpty ? null : t,
      artist: a.isEmpty ? null : a,
      album: al.isEmpty ? null : al,
    );
  }

  /// 同目录 `.lrc` 落盘 + lyrics_meta(lrc) 落账（relPath 扩展名替换惯例，
  /// 与 lyrics_service ASR 落盘同构）。旁车已存在（外来 .lrc）→ 不覆盖，
  /// 仅在未落账时补账（填缺）。返回 true=歌词在位。
  Future<bool> _writeLrc(Track track, String rootPath, String lrcText) async {
    final rel = track.relPath.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
    final abs = '$rootPath${Platform.pathSeparator}$rel';
    final f = File(abs);
    if (f.existsSync()) {
      final existing = await _lyrics.metaFor(track.id);
      if (existing == null || existing.type == LyricsSourceType.none) {
        await _lyrics.upsertMeta(
          trackId: track.id,
          type: LyricsSourceType.lrc,
          lrcPath: rel,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
      return true;
    }
    f.createSync(recursive: false);
    f.writeAsStringSync(lrcText, flush: true);
    await _lyrics.upsertMeta(
      trackId: track.id,
      type: LyricsSourceType.lrc,
      lrcPath: rel,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    return true;
  }

  /// 网易封面字节 → `<音频名>.cover.jpg`（fetched 档命名，CoverChain sibling
  /// 档天然可见；已存在不覆盖）。
  bool _writeCover(Track track, String rootPath, List<int> bytes) {
    final coverRel = track.relPath.replaceAll(RegExp(r'\.[^.]+$'), '.cover.jpg');
    final coverAbs = '$rootPath${Platform.pathSeparator}$coverRel';
    final f = File(coverAbs);
    if (f.existsSync()) {
      return false;
    }
    f.writeAsBytesSync(bytes, flush: true);
    return true;
  }
}
