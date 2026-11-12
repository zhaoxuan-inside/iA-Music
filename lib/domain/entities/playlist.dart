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
  });

  final int id;
  final String name;
  final PlaylistKind kind;
  final int trackCount;
  final DateTime createdAt;

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
