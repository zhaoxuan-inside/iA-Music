/// 歌词管线——全仓唯一一份（获取/解析/.lrc 落盘/偏移回写）。
///
/// 决议序（每曲一份 lyrics_meta 记账）：
/// 1. DB meta 有 lrcPath（sidecar/pasted）→ 读文件
/// 2. 内嵌歌词（audio USLT/LYRICS）
/// 3. 在线（LRCLIB）→ 写 sidecar（尽力）→ meta kind=online
/// 偏移只存 DB（渲染期生效），不改写歌词文件。
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../../data/database.dart';
import '../../domain/entities/lyrics.dart';
import '../../domain/entities/track.dart';
import '../../domain/errors.dart';
import '../../domain/ports/lyrics_port.dart';
import '../../domain/ports/metadata_port.dart';

class LyricsPipeline {
  LyricsPipeline({
    required IaDatabase db,
    required MetadataPort metadata,
    required LyricTextSearchPort lyrics,
    required this.cacheDir,
  })  : _meta = db.lyricsDao,
        _metadata = metadata,
        _lyrics = lyrics;

  final LyricsDao _meta;
  final MetadataPort _metadata;
  final LyricTextSearchPort _lyrics;

  /// sidecar 写不进音频目录时的兜底目录（应用私有）。
  final String cacheDir;

  Future<LyricsResult> resolve(Track track, {bool allowOnline = true}) async {
    final meta = await _meta.metaOf(track.id);
    final offsetMs = meta?.offsetMs ?? 0;

    // 1. DB 指向的 lrc 文件（sidecar / pasted / 既往 online）
    final lrcPath = meta?.lrcPath;
    if (lrcPath != null && lrcPath.isNotEmpty) {
      final f = File(lrcPath);
      if (f.existsSync()) {
        try {
          final doc = parseLrc(f.readAsStringSync(), kind: _kindOf(meta!.kind));
          if (doc.lines.isNotEmpty) {
            return LyricsResult(doc: doc, offsetMs: offsetMs);
          }
        } on Object {
          // 文件损坏：继续走决议链
        }
      }
    }

    // 2. 内嵌
    final embedded = await _metadata.readEmbeddedLyrics(track.path);
    if (embedded != null && embedded.trim().isNotEmpty) {
      final doc = parseLrc(embedded, kind: LyricSourceKind.embedded);
      final use = doc.lines.isNotEmpty
          ? doc
          : LyricDoc(
              lines: [
                for (final line in embedded.split(RegExp(r'\r?\n')))
                  if (line.trim().isNotEmpty) LyricLine(tMs: 0, text: line.trim()),
              ],
              sourceKind: LyricSourceKind.embedded,
            );
      await _remember(track.id, kind: 'embedded', lrcPath: null, edited: meta?.edited ?? false, offsetMs: offsetMs);
      return LyricsResult(doc: use, offsetMs: offsetMs);
    }

    // 3. 在线（edited 守卫位：用户粘过歌词的不覆盖）
    if (allowOnline && !(meta?.edited ?? false)) {
      try {
        final hit = await _lyrics.getByFields(
          title: track.title,
          artist: track.artist,
          durationMs: track.durationMs > 0 ? track.durationMs : null,
        );
        final text = hit?.syncedLrc.trim().isNotEmpty == true
            ? hit!.syncedLrc
            : hit?.plainLrc ?? '';
        if (text.trim().isNotEmpty) {
          final path = await _writeSidecar(track, text);
          await _remember(track.id, kind: 'online', lrcPath: path, edited: false, offsetMs: offsetMs);
          return LyricsResult(doc: parseLrc(text, kind: LyricSourceKind.online), offsetMs: offsetMs);
        }
      } on NetworkError {
        // 离线：不记账，下次再试
      } on Object {
        // 其余失败：不记账不阻断
      }
    }
    return LyricsResult(doc: const LyricDoc(lines: [], sourceKind: LyricSourceKind.none), offsetMs: offsetMs);
  }

  /// 用户粘贴歌词（守卫位 edited=true，永不覆盖）。
  Future<void> savePasted(Track track, String text) async {
    final path = await _writeSidecar(track, text);
    final meta = await _meta.metaOf(track.id);
    await _remember(
      track.id,
      kind: 'pasted',
      lrcPath: path,
      edited: true,
      offsetMs: meta?.offsetMs ?? 0,
    );
  }

  /// 偏移调整（渲染期生效；不碰歌词文件）。
  Future<void> setOffset(Track track, int offsetMs) async {
    final meta = await _meta.metaOf(track.id);
    await _meta.upsert(
      track.id,
      LyricsMetaCompanion(
        kind: Value(meta?.kind ?? 'none'),
        lrcPath: Value(meta?.lrcPath),
        offsetMs: Value(offsetMs),
        edited: Value(meta?.edited ?? false),
      ),
    );
  }

  Future<void> _remember(
    int trackId, {
    required String kind,
    required String? lrcPath,
    required bool edited,
    required int offsetMs,
  }) {
    return _meta.upsert(
      trackId,
      LyricsMetaCompanion(
        kind: Value(kind),
        lrcPath: Value(lrcPath),
        offsetMs: Value(offsetMs),
        edited: Value(edited),
        fetchedAt: Value(DateTime.now()),
      ),
    );
  }

  /// sidecar = 同名 .lrc；写不进（只读挂载等）→ cacheDir 兜底。返回实际路径。
  Future<String?> _writeSidecar(Track track, String text) async {
    final dot = track.path.lastIndexOf('.');
    final sidecar =
        '${dot < 0 ? track.path : track.path.substring(0, dot)}.lrc';
    try {
      final f = File(sidecar);
      await f.writeAsString(text, flush: true);
      return sidecar;
    } on Object {
      try {
        final f = File('$cacheDir/lyrics_${track.id}.lrc');
        await f.parent.create(recursive: true);
        await f.writeAsString(text, flush: true);
        return f.path;
      } on Object {
        return null; // 全失败：不记账路径，内容下次重取
      }
    }
  }

  LyricSourceKind _kindOf(String kind) {
    switch (kind) {
      case 'sidecar':
        return LyricSourceKind.sidecar;
      case 'embedded':
        return LyricSourceKind.embedded;
      case 'online':
        return LyricSourceKind.online;
      case 'pasted':
        return LyricSourceKind.pasted;
      default:
        return LyricSourceKind.none;
    }
  }
}
