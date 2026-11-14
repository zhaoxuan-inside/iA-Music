/// 扫描服务：目录遍历 → diff → isolate 批解析 → 批事务落库（FTS 同事务）。
///
/// 纪律：
/// * 批 ≤200 一事务；tag 解析 + stat + sha256 整批进 Isolate（不占 UI）。
/// * size 不变 = 跳过重解析（快速重扫）；size 变 = 重解析重哈希。
/// * 磁盘消失 = markMissing（诚实灰显，不删除行）；回来 = revive。
library;

import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as am;
import 'package:crypto/crypto.dart' show sha256;

import '../../data/database.dart';
import '../enrich/title_normalizer.dart';

class ScanProgress {
  const ScanProgress({required this.done, required this.total, this.phase = ScanPhase.parsing});

  final int done;
  final int total;
  final ScanPhase phase;
}

enum ScanPhase { walking, parsing, done }

class ScanSummary {
  const ScanSummary({
    required this.inserted,
    required this.updated,
    required this.missing,
    required this.revived,
  });

  final int inserted;
  final int updated;
  final int missing;
  final int revived;

  int get touched => inserted + updated + missing + revived;
}

class ScanService {
  ScanService(this._db, {this.batchSize = 200});

  final IaDatabase _db;

  /// 进度回调（可运行期替换；controller 负责接线）。
  void Function(ScanProgress progress)? onProgress;

  final int batchSize;

  LibraryDao get _library => _db.libraryDao;

  static const Set<String> audioExtensions = {
    'mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'oga', 'opus', 'wma', 'aiff', 'ape',
  };

  /// 全量扫所有根目录。
  Future<ScanSummary> scanAll() async {
    var total = const ScanSummary(inserted: 0, updated: 0, missing: 0, revived: 0);
    for (final root in await _library.allRoots()) {
      final s = await scanRoot(root.id, root.path);
      total = ScanSummary(
        inserted: total.inserted + s.inserted,
        updated: total.updated + s.updated,
        missing: total.missing + s.missing,
        revived: total.revived + s.revived,
      );
    }
    return total;
  }

  /// 扫单个根目录。
  Future<ScanSummary> scanRoot(int rootId, String rootPath) async {
    onProgress?.call(const ScanProgress(done: 0, total: 0, phase: ScanPhase.walking));
    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) {
      final existing = await _library.existingForRoot(rootId);
      await _library.markMissing([for (final e in existing) e.id]);
      return ScanSummary(inserted: 0, updated: 0, missing: existing.length, revived: 0);
    }
    final onDisk = _walk(rootDir).toList();

    final existing = await _library.existingForRoot(rootId);
    final byRel = {for (final e in existing) e.relPath: e};
    final onDiskSet = onDisk.toSet();

    final toRevive = <int>[];
    final toMissing = <int>[];
    final toParse = <String>[]; // relPath（新文件或 size 变化）
    for (final e in existing) {
      final diskPath = _abs(rootPath, e.relPath);
      final exists = onDiskSet.contains(e.relPath);
      if (exists) {
        if (e.missing) {
          toRevive.add(e.id);
        }
        final size = File(diskPath).lengthSync();
        if (size != e.sizeBytes) {
          toParse.add(e.relPath); // 变化件：重解析重哈希
        }
      } else {
        toMissing.add(e.id);
      }
    }
    for (final rel in onDisk) {
      if (!byRel.containsKey(rel)) {
        toParse.add(rel);
      }
    }

    if (toRevive.isNotEmpty) {
      await _library.revive(toRevive);
    }
    if (toMissing.isNotEmpty) {
      await _library.markMissing(toMissing);
    }

    var updated = 0;
    var inserted = 0;
    final total = toParse.length;
    for (var i = 0; i < total; i += batchSize) {
      final batch = toParse.sublist(i, (i + batchSize).clamp(0, total));
      onProgress?.call(ScanProgress(done: i, total: total, phase: ScanPhase.parsing));
      final outs = await _parseBatch(rootPath, batch);
      final rows = <TrackUpsert>[];
      for (final out in outs) {
        if (!out.ok) {
          continue; // 损坏/不可读：不入库（探针件永不污染曲库）
        }
        final existed = byRel[out.relPath];
        rows.add(TrackUpsert(
          rootId: rootId,
          relPath: out.relPath,
          path: _abs(rootPath, out.relPath),
          title: out.title,
          artist: out.artist,
          album: out.album,
          genre: out.genre,
          needsMeta: out.needsMeta,
          trackNo: out.trackNo,
          durationMs: out.durationMs,
          sizeBytes: out.sizeBytes,
          contentHash: out.hash,
          audioFormat: out.audioFormat,
        ));
        if (existed == null) {
          inserted++;
        } else {
          updated++;
        }
      }
      if (rows.isNotEmpty) {
        await _library.upsertScannedBatch(rows);
      }
    }
    onProgress?.call(ScanProgress(done: total, total: total, phase: ScanPhase.done));
    return ScanSummary(
      inserted: inserted,
      updated: updated,
      missing: toMissing.length,
      revived: toRevive.length,
    );
  }

  /// 递归收集音频相对路径；跳过隐藏目录与符号链接环。
  Iterable<String> _walk(Directory dir) sync* {
    final entries = dir.listSync(followLinks: false);
    for (final e in entries) {
      if (e is Link) {
        continue;
      }
      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (name.startsWith('.')) {
        continue;
      }
      if (e is Directory) {
        yield* _walk(e);
      } else if (e is File) {
        final ext = e.path.contains('.')
            ? e.path.substring(e.path.lastIndexOf('.') + 1).toLowerCase()
            : '';
        if (audioExtensions.contains(ext)) {
          yield e.path.substring(dir.path.length + 1).replaceAll('\\', '/');
        }
      }
    }
  }

  String _abs(String root, String rel) {
    final sep = Platform.pathSeparator;
    return '$root${root.endsWith(sep) ? '' : sep}${rel.replaceAll('/', sep)}';
  }

  Future<List<ParseOut>> _parseBatch(String rootPath, List<String> rels) {
    return Isolate.run(() => parseChunk(rootPath, rels));
  }
}

/// isolate 批解析单件结果。
class ParseOut {
  const ParseOut({
    required this.relPath,
    required this.ok,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.trackNo,
    required this.durationMs,
    required this.sizeBytes,
    required this.hash,
    required this.audioFormat,
    required this.needsMeta,
    this.error,
  });

  final String relPath;
  final bool ok;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final bool needsMeta;
  final int trackNo;
  final int durationMs;
  final int sizeBytes;
  final String hash;
  final String audioFormat;
  final String? error;
}

/// 批解析（静态、isolate 安全）：逐件真读 tag 裸值 + sha256。
/// 解析失败件 → ok=false（不中断整批）。
List<ParseOut> parseChunk(String rootPath, List<String> rels) {
  final outs = <ParseOut>[];
  final sep = Platform.pathSeparator;
  for (final rel in rels) {
    final abs = '$rootPath${rootPath.endsWith(sep) ? '' : sep}${rel.replaceAll('/', sep)}';
    try {
      final f = File(abs);
      final bytes = f.readAsBytesSync();
      final hash = sha256.convert(bytes).toString();
      final m = am.readMetadata(f, getImage: false);
      var artist = (m.artist ?? '').trim();
      if (artist.isEmpty) {
        artist = (m.albumArtist ?? '').trim();
      }
      final tagTitle = (m.title ?? '').trim();
      final fileBase = rel.substring(rel.lastIndexOf('/') + 1);
      final norm = normalizeTitle(
          raw: tagTitle, artistTag: artist.isNotEmpty ? artist : null, fileName: fileBase);
      if (artist.isEmpty && norm.artist != null) {
        artist = norm.artist!;
      }
      final needsMeta = artist.isEmpty || tagTitle.isEmpty;
      outs.add(ParseOut(
        relPath: rel,
        ok: true,
        title: norm.title,
        artist: artist,
        album: (m.album ?? '').trim(),
        genre: m.genres.isEmpty ? '' : m.genres.first.trim(),
        needsMeta: needsMeta,
        trackNo: m.trackNumber ?? 0,
        durationMs: m.duration?.inMilliseconds ?? 0,
        sizeBytes: bytes.length,
        hash: hash,
        audioFormat: rel.contains('.')
            ? rel.substring(rel.lastIndexOf('.') + 1).toLowerCase()
            : '',
      ));
    } on Object catch (e) {
      outs.add(ParseOut(
        relPath: rel,
        ok: false,
        title: '',
        artist: '',
        album: '',
        genre: '',
        needsMeta: false,
        trackNo: 0,
        durationMs: 0,
        sizeBytes: 0,
        hash: '',
        audioFormat: '',
        error: e.toString(),
      ));
    }
  }
  return outs;
}
