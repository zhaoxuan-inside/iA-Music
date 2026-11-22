/// 曲目实体（纯 Dart；展示口径的字段直存，分组用 norm 列聚合）。
library;

class Track {
  const Track({
    required this.id,
    required this.rootId,
    required this.relPath,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.durationMs,
    required this.sizeBytes,
    required this.contentHash,
    required this.audioFormat,
    required this.trackNo,
    required this.coverPath,
    required this.addedAt,
    this.needsMeta = false,
    this.enrichedAt,
    this.missing = false,
  });

  final int id;
  final int rootId;
  final String relPath;
  final String path;
  final String title;
  final String artist;
  final String album;

  /// 流派裸值（真实标签解析；空串=无标签，UI 隐藏流派入口）。
  final String genre;
  final int durationMs;
  final int sizeBytes;
  final String contentHash;
  final String audioFormat;
  final int trackNo;

  /// 封面缓存路径（应用私有目录相对）；null=尚未决议。
  final String? coverPath;
  final DateTime addedAt;

  /// 元数据补全：true=歌手/歌名缺失，等待反向重建。
  final bool needsMeta;
  final DateTime? enrichedAt;

  /// 磁盘上已找不到（诚实灰显；不参与随机/连播）。
  final bool missing;

  String get artistDisplay => artist.isEmpty ? '未知歌手' : artist;
  String get albumDisplay => album.isEmpty ? '未知专辑' : album;
  String get genreDisplay => genre.isEmpty ? '' : genre;

  Track copyWith(
          {String? coverPath,
          bool? missing,
          String? title,
          String? artist,
          bool? needsMeta,
          DateTime? enrichedAt}) =>
      Track(
        id: id,
        rootId: rootId,
        relPath: relPath,
        path: path,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album,
        genre: genre,
        durationMs: durationMs,
        sizeBytes: sizeBytes,
        contentHash: contentHash,
        audioFormat: audioFormat,
        trackNo: trackNo,
        coverPath: coverPath ?? this.coverPath,
        addedAt: addedAt,
        needsMeta: needsMeta ?? this.needsMeta,
        enrichedAt: enrichedAt ?? this.enrichedAt,
        missing: missing ?? this.missing,
      );
}

/// 曲库排序口径。
enum TrackSort { title, artist, album, recentAdded }

/// 专辑聚合（GROUP BY albumNorm 的视图行）。
class AlbumGroup {
  const AlbumGroup({
    required this.album,
    required this.artist,
    required this.trackCount,
    required this.totalDurationMs,
  });

  final String album;
  final String artist;
  final int trackCount;
  final int totalDurationMs;
}

/// 艺术家聚合视图行。
class ArtistGroup {
  const ArtistGroup({required this.artist, required this.trackCount});

  final String artist;
  final int trackCount;
}

/// 流派聚合视图行（按 genre 分组的专辑数）。
class GenreGroup {
  const GenreGroup({required this.genre, required this.albumCount});

  final String genre;
  final int albumCount;
}

/// 常听单曲聚合行（曲目 + 累计播放次数）。
class TrackPlays {
  const TrackPlays({required this.track, required this.plays});

  final Track track;
  final int plays;
}

/// 补全阶段进度行（三态：成功=结论性已处理；失败=连续硬失败耗尽；其余待处理）。
class EnrichStage {
  const EnrichStage(this.label, this.done, this.failed, this.total);

  final String label;

  /// 成功条数（进度条从左往右，绿色）。
  final int done;

  /// 失败条数（进度条从右往左，红色）。
  final int failed;

  /// 总盘 = 成功 + 失败 + 待处理。
  final int total;

  /// 成功占比 0..1（总盘为空视为已完成——无事可做）。
  double get successFraction =>
      total <= 0 ? 1.0 : (done / total).clamp(0.0, 1.0);

  /// 失败占比 0..1。
  double get failedFraction =>
      total <= 0 ? 0.0 : (failed / total).clamp(0.0, 1.0);

  /// 待处理条数（中段灰）。
  int get pending => (total - done - failed).clamp(0, total);
}
