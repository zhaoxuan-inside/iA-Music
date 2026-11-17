/// 歌单与播放历史实体（纯 Dart）。
library;

enum PlaylistKind { user, favorites }

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.kind,
    required this.trackCount,
    required this.createdAt,
    this.pendingCount = 0,
    this.coverPath,
  });

  final int id;
  final String name;
  final PlaylistKind kind;
  final int trackCount;
  final DateTime createdAt;

  /// GitHub 拉取歌单：等待提取的曲目数（0/null=无）。
  final int pendingCount;

  /// 自定义歌单封面（应用沙箱内图片路径；null=未设置）。
  final String? coverPath;

  bool get isSystem => kind == PlaylistKind.favorites;
}

class PlaylistEntry {
  const PlaylistEntry({required this.trackId, required this.position});

  final int trackId;
  final int position;
}

class HistoryEntry {
  const HistoryEntry({
    required this.trackId,
    required this.playedAt,
    required this.completed,
  });

  final int trackId;
  final DateTime playedAt;
  final bool completed;
}
