/// EnginePort —— 播放引擎契约（P1 口径：队列/播放控制/事件流/媒体会话）。
///
/// 实现注意：
/// * 事件顺序契约：StateChanged 先于派生事件；position 心跳 ≤250ms。
library;

import '../entities/playback.dart';

/// 引擎消息（单流多态，按实际发生顺序推送）。
sealed class EngineEvent {
  const EngineEvent();
}

enum EngineState { idle, loading, playing, paused, ended, error }

final class EngineStateChanged extends EngineEvent {
  const EngineStateChanged(this.state);
  final EngineState state;
}

/// 进度心跳（≤250ms 承诺）。
final class EnginePositionTick extends EngineEvent {
  const EnginePositionTick(this.positionMs);
  final int positionMs;
}

/// 中段自然切条或末条播完（index=队列索引）。
final class EngineItemEnded extends EngineEvent {
  const EngineItemEnded(this.queueIndex);
  final int queueIndex;
}

/// 外部（通知栏上一首/大跨度跳转）导致的索引变化；服务直接对齐。
final class EngineIndexChanged extends EngineEvent {
  const EngineIndexChanged(this.queueIndex);
  final int queueIndex;
}

final class EngineFailed extends EngineEvent {
  const EngineFailed(this.error);
  final EngineErrorCtor error;
}

/// 引擎错误载荷（保持 domain 可序列化；detail 面向日志）。
class EngineErrorCtor {
  const EngineErrorCtor(this.detail);
  final String detail;
}

/// 媒体命令回流（OS 通知栏/锁屏/媒体键 → 服务执行）。
enum MediaCommandKind { play, pause, playPause, stop, next, previous, seekTo, seekBy, like }

final class EngineMediaCommand extends EngineEvent {
  const EngineMediaCommand(this.kind, {this.positionMs, this.offsetMs});

  final MediaCommandKind kind;
  final int? positionMs;
  final int? offsetMs;
}

/// 队列条目（引擎只消费的最小面）。
class QueueItem {
  const QueueItem({
    required this.path,
    required this.title,
    required this.artist,
    this.album = '',
    this.durationMs = 0,
    this.coverPath,
  });

  final String path;
  final String title;
  final String artist;
  final String album;
  final int durationMs;

  /// 本地封面路径（通知栏/锁屏用；可空）。
  final String? coverPath;
}

abstract class EnginePort {
  /// 初始化；重复调用抛 StateError。
  Future<void> init();

  /// 加载队列并从 [startIndex] 起播。
  Future<void> loadAndPlay(List<QueueItem> queue, int startIndex);

  /// 会话恢复：载入→定位→自动续播（不打断地回到上次听的位置附近）。
  Future<void> restore(List<QueueItem> queue, int startIndex, int positionMs);

  Future<void> play();
  Future<void> pause();

  /// 绝对定位（毫秒）。
  Future<void> seekTo(int positionMs);

  /// 跳到队列第 [index] 条（manual next/previous 的底层）。
  Future<void> jumpTo(int index);

  /// 音量（0..100；100=不衰减）。
  Future<void> setVolume(double volume);

  /// 循环模式（引擎侧映射 loop 属性；加载队列后需重设）。
  Future<void> setRepeatMode(RepeatMode mode);

  /// 插队：把 [item] 插为当前曲后立刻播放的下一首（不打断当前曲）。
  Future<void> insertNext(QueueItem item);

  /// 移除队列第 [index] 条（不得为当前播放条；调用方守卫）。
  Future<void> removeQueueIndex(int index);

  /// 队列条目移动：[from] 条目移除后插到 [to]（最终索引 = [to]）。
  /// 语义同 List 的 removeAt(from)+insertAt(to)，与 Flutter
  /// ReorderableListView 的 onReorderItem 一致。
  Future<void> moveQueueIndex(int from, int to);

  /// 停止并清空引擎队列。
  Future<void> stopAll();

  Stream<EngineEvent> get events;

  /// 资源全净释放。
  Future<void> dispose();
}
