/// 跨 Port 共享最小类型。
library;

/// 曲目轻量视图（供引擎队列/随机池使用；DB 实体在 app 侧）。
final class TrackLite {
  const TrackLite({
    required this.id,
    required this.path,
    required this.title,
    required this.artistDisplay,
    required this.durationMs,
  });

  final int id;
  final String path;
  final String title;
  final String artistDisplay;
  final int durationMs;
}

/// 取消令牌（协作式取消；C38：响应点=块边界）。
class CancelToken {
  bool isCancelled = false;
}

/// 上传分块计划（断点续传自研，C36）。
final class ChunkPlan {
  const ChunkPlan({this.chunkSizeBytes = 8 * 1024 * 1024, this.concurrency = 2});

  final int chunkSizeBytes;
  final int concurrency;
}
