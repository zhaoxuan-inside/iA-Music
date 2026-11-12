/// MetadataPort 实现——audio_metadata_reader 只读封装。
///
/// 红线：绝不写回原始音频文件。readTags 不读内嵌图（封面走 readEmbeddedCover
/// 按需另读，避免扫描整库时二次大读）。
library;

import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as am;

import '../../domain/entities/../ports/metadata_port.dart';
import '../../domain/errors.dart';

class MetadataReaderAdapter implements MetadataPort {
  const MetadataReaderAdapter();

  @override
  Future<ParsedTags> readTags(String path) {
    return Future.sync(() {
      try {
        final m = am.readMetadata(File(path), getImage: false);
        final artist = (m.artist ?? '').trim();
        return ParsedTags(
          title: (m.title ?? '').trim(),
          artist: artist.isNotEmpty ? artist : (m.albumArtist ?? '').trim(),
          album: (m.album ?? '').trim(),
          trackNo: m.trackNumber ?? 0,
          durationMs: m.duration?.inMilliseconds ?? 0,
          audioFormat: _ext(path),
        );
      } on Object catch (e, st) {
        Error.throwWithStackTrace(MetadataError(detail: '$path: $e'), st);
      }
    });
  }

  @override
  Future<List<int>?> readEmbeddedCover(String path) {
    return Future.sync(() {
      try {
        final m = am.readMetadata(File(path), getImage: true);
        for (final p in m.pictures) {
          if (p.bytes.isNotEmpty) {
            return p.bytes;
          }
        }
        return null;
      } on Object {
        return null; // 封面读取失败不阻断封面链
      }
    });
  }

  @override
  Future<String?> readEmbeddedLyrics(String path) {
    return Future.sync(() {
      try {
        final m = am.readMetadata(File(path), getImage: false);
        final lrc = m.lyrics?.trim();
        return (lrc == null || lrc.isEmpty) ? null : lrc;
      } on Object {
        return null;
      }
    });
  }

  String _ext(String path) {
    final i = path.lastIndexOf('.');
    return i < 0 ? '' : path.substring(i + 1).toLowerCase();
  }
}
