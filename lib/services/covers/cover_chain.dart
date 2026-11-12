/// 封面链——全仓唯一一份（四级决议）。
///
/// 决议序：DB 缓存位 → 内嵌 → 同名图 → 在线（限速）→ null（UI 首字母色块）。
/// 成功位写回 tracks.coverPath（绝对路径）；在线失败只冷却本次，不记账。
library;

import 'dart:io';

import '../../data/database.dart';
import '../../domain/entities/track.dart';
import '../../domain/errors.dart';
import '../../domain/ports/cover_port.dart';
import '../../domain/ports/metadata_port.dart';

class CoverChain {
  CoverChain({
    required IaDatabase db,
    required MetadataPort metadata,
    required CoverFetchPort fetcher,
    required this.cacheDir,
  })  : _library = db.libraryDao,
        _metadata = metadata,
        _fetcher = fetcher;

  final LibraryDao _library;
  final MetadataPort _metadata;
  final CoverFetchPort _fetcher;

  final String cacheDir;

  final Map<int, Future<File?>> _inflight = {};

  /// 决议一首曲目的封面文件；无 → null。
  Future<File?> coverFor(Track track, {bool allowOnline = true}) {
    final existing = _inflight[track.id];
    if (existing != null) {
      return existing;
    }
    final fut = _resolve(track, allowOnline: allowOnline).whenComplete(() {
      _inflight.remove(track.id);
    });
    _inflight[track.id] = fut;
    return fut;
  }

  Future<File?> _resolve(Track track, {required bool allowOnline}) async {
    // 1. DB 缓存位
    final cached = track.coverPath;
    if (cached != null && cached.isNotEmpty) {
      final f = File(cached);
      if (f.existsSync()) {
        return f;
      }
      await _library.updateCover(track.id, null); // 缓存文件丢了：清位
    }

    // 2. 内嵌
    final embedded = await _metadata.readEmbeddedCover(track.path);
    if (embedded != null) {
      final saved = await _saveCache(track.id, embedded);
      if (saved != null) {
        await _library.updateCover(track.id, saved.path);
        return saved;
      }
    }

    // 3. 同名图（音频同目录、同 basename）
    final sidecar = _findSidecar(track.path);
    if (sidecar != null) {
      await _library.updateCover(track.id, sidecar.path);
      return sidecar;
    }

    // 4. 在线
    if (allowOnline) {
      try {
        final hit = await _fetcher.fetch(CoverQuery(
          title: track.title,
          artist: track.artist,
          album: track.album.isEmpty ? null : track.album,
        ));
        if (hit != null) {
          final saved = await _saveCache(track.id, hit.bytes);
          if (saved != null) {
            await _library.updateCover(track.id, saved.path);
            return saved;
          }
        }
      } on NetworkError {
        return null; // 离线：本次冷却
      } on Object {
        return null;
      }
    }
    return null;
  }

  File? _findSidecar(String audioPath) {
    final dot = audioPath.lastIndexOf('.');
    final base = dot < 0 ? audioPath : audioPath.substring(0, dot);
    for (final ext in const ['.jpg', '.jpeg', '.png', '.webp']) {
      final f = File('$base$ext');
      if (f.existsSync()) {
        return f;
      }
    }
    return null;
  }

  Future<File?> _saveCache(int trackId, List<int> bytes) async {
    try {
      final dir = Directory(cacheDir);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      final f = File('${dir.path}/cover_$trackId.jpg');
      await f.writeAsBytes(bytes, flush: true);
      return f;
    } on Object {
      return null;
    }
  }
}
