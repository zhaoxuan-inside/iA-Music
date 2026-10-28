/// Library-owned cover decision and registry. Audio files are read only.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as am;
import 'package:contracts/contracts.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/tables.dart';

final class CoverResolution {
  const CoverResolution(this.kind, {this.localPath, this.bytes});
  final CoverKind kind;
  final String? localPath;
  final Uint8List? bytes;
}

/// 缓存条目：结果 + 守卫文件 mtime（守卫变化=源已变，须失效重判）。
final class _CoverCacheEntry {
  const _CoverCacheEntry(this.result, this.audioPath, this.guardMtimeMs);
  final CoverResolution result;
  final String audioPath;
  final int guardMtimeMs;
}

final class CoverChain {
  CoverChain(this._data, this._fetch);
  final DataAccess _data;
  final CoverFetchPort _fetch;
  static const onlineSettingKey = 'cover.autoFetch';
  final Map<int, Future<CoverResolution>> _inflight = {};

  static const _siblingExts = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'JPG',
    'JPEG',
    'PNG',
    'WEBP',
  ];

  /// 命中结果带校验缓存（上限 [cacheCap]，插入序淘汰最旧）：
  /// 列表滚动反复挂载同一行 TrackCover——旧实现每次挂载都重跑「新 isolate
  /// 全量解析音频元数据」。缓存命中只做 stat 校验（零 isolate/零网络），
  /// 且不改变探测语义：内嵌守卫=音频 mtime；同名图守卫=图自身 mtime；
  /// 缓存图（fetched）守卫=缓存图 mtime + 「无任何同目录兄弟图」——
  /// 新放的同名图必须按既有优先级顶掉缓存图（C22）。
  static const cacheCap = 256;
  final Map<int, _CoverCacheEntry> _hitCache = {};

  /// Coalesce list/play requests for the same track. Results are not permanently
  /// cached: next browse/play rechecks disk and may retry an earlier miss.
  Future<CoverResolution> decide(int trackId) {
    final entry = _hitCache[trackId];
    if (entry != null) {
      return _validate(entry).then((fresh) {
        if (fresh) {
          return entry.result;
        }
        _hitCache.remove(trackId);
        return decide(trackId); // 源已变 → 全量重判（含优先级重排）
      });
    }
    return _inflight.putIfAbsent(
      trackId,
      () => _decide(trackId).whenComplete(() {
        _inflight.remove(trackId);
      }),
    );
  }

  static String _stemOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? path : path.substring(0, dot);
  }

  static Future<int> _mtimeOf(String path) async {
    try {
      return (await File(path).lastModified()).millisecondsSinceEpoch;
    } on Exception {
      return -1;
    }
  }

  Future<bool> _validate(_CoverCacheEntry e) async {
    switch (e.result.kind) {
      case CoverKind.embedded:
        return await _mtimeOf(e.audioPath) == e.guardMtimeMs;
      case CoverKind.sibling:
        final p = e.result.localPath;
        return p != null && await _mtimeOf(p) == e.guardMtimeMs;
      case CoverKind.fetched:
        // 兄弟图出现（含替换语义）→ 立即失效
        final stem = _stemOf(e.audioPath);
        for (final ext in _siblingExts) {
          if (await File('$stem.$ext').exists()) {
            return false;
          }
        }
        return await _mtimeOf('${e.audioPath}.cover.jpg') == e.guardMtimeMs;
      case CoverKind.none:
        return false; // 未命中不入缓存（保留重试语义）
    }
  }

  Future<void> _remember(int id, File audio, CoverResolution result) async {
    switch (result.kind) {
      case CoverKind.none:
        return;
      case CoverKind.embedded:
        // 守卫=音频文件（内嵌图随音频字节变化）
        _store(id, result, audio.path, await _mtimeOf(audio.path));
      case CoverKind.sibling:
        final p = result.localPath;
        if (p != null) {
          _store(id, result, audio.path, await _mtimeOf(p));
        }
      case CoverKind.fetched:
        _store(id, result, audio.path,
            await _mtimeOf('${audio.path}.cover.jpg'));
    }
  }

  void _store(int id, CoverResolution result, String audioPath, int guard) {
    if (_hitCache.length >= cacheCap) {
      _hitCache.remove(_hitCache.keys.first);
    }
    _hitCache[id] = _CoverCacheEntry(result, audioPath, guard);
  }

  Future<CoverResolution> _decide(int id) async {
    try {
      final row = await _data.library.rowById(id);
      if (row == null || row.deletedAt != null) {
        return const CoverResolution(CoverKind.none);
      }
      final root = await _data.library.rootById(row.rootId);
      if (root == null) return const CoverResolution(CoverKind.none);
      final audio = File.fromUri(
        Directory(root.path).absolute.uri.resolve(row.relPath),
      );
      if (!await audio.exists()) return const CoverResolution(CoverKind.none);
      final local = await _local(audio);
      if (local != null) return await _register(id, audio, local);
      final enabled = await _data.shell.value(onlineSettingKey);
      if (enabled == 'false') {
        return await _register(
          id,
          audio,
          const CoverResolution(CoverKind.none),
        );
      }
      final result = await _fetch.fetchTrackCover(
        CoverQuery(
          trackId: id,
          title: row.title ?? '',
          artistDisplay: row.artistDisplay,
          albumDisplay: row.albumDisplay,
        ),
      );
      if (result != null) {
        final temporary = File(result.localPath);
        try {
          // Local art can appear while network IO was in flight. Recheck C22.
          final newer = await _local(audio);
          if (newer != null) return await _register(id, audio, newer);
          final current = await _data.library.rowById(id);
          if (!await audio.exists() ||
              current == null ||
              current.deletedAt != null) {
            return const CoverResolution(CoverKind.none);
          }
          final target = File('${audio.path}.cover.jpg');
          // Exclusive create protects existing files, even between check and write.
          try {
            await target.create(exclusive: true);
          } on FileSystemException {
            final winner = await _local(audio);
            return await _register(
              id,
              audio,
              winner ?? const CoverResolution(CoverKind.none),
            );
          }
          try {
            await target.writeAsBytes(
              await temporary.readAsBytes(),
              flush: true,
            );
          } on Exception {
            await target.delete();
            rethrow;
          }
          return await _register(
            id,
            audio,
            CoverResolution(CoverKind.fetched, localPath: target.path),
          );
        } finally {
          if (await temporary.exists()) await temporary.delete();
          // Adapter returns a dedicated temporary directory.
          if (await temporary.parent.exists() &&
              await temporary.parent.list().isEmpty) {
            await temporary.parent.delete();
          }
        }
      }
      return await _register(id, audio, const CoverResolution(CoverKind.none));
    } on Exception {
      // Metadata/disk/network failures leave playback and browsing available.
      return const CoverResolution(CoverKind.none);
    }
  }

  Future<CoverResolution> _register(
    int id,
    File audio,
    CoverResolution result,
  ) async {
    await _data.library.registerCover(
      id,
      kind: result.kind,
      relPath: result.localPath?.split(Platform.pathSeparator).last,
      checkedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _remember(id, audio, result);
    return result;
  }

  Future<CoverResolution?> _local(File audio) async {
    final embedded = await Isolate.run(() {
      try {
        final pictures = am.readMetadata(audio, getImage: true).pictures;
        if (pictures.isEmpty) return null;
        return (pictures
                    .where((p) => p.pictureType == am.PictureType.coverFront)
                    .firstOrNull ??
                pictures.first)
            .bytes;
      } on Exception {
        return null;
      }
    });
    if (embedded != null && embedded.isNotEmpty) {
      return CoverResolution(CoverKind.embedded, bytes: embedded);
    }
    final stem = _stemOf(audio.path);
    for (final ext in _siblingExts) {
      final file = File('$stem.$ext');
      if (await file.exists() && await file.length() > 0) {
        return CoverResolution(CoverKind.sibling, localPath: file.path);
      }
    }
    final fetched = File('${audio.path}.cover.jpg');
    if (await fetched.exists() && await fetched.length() > 0) {
      return CoverResolution(CoverKind.fetched, localPath: fetched.path);
    }
    return null;
  }
}
