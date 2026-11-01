/// EnginePort —— 播放引擎契约。
///
/// 双态实现：
/// * `MpvEngineAdapter`（首选，Dec-008 ③）
/// * `PairedEngineAdapter`（回退线，ISS-201/302 双态契约）
///
/// 实现一致性约束（ARCHITECTURE §3.2/§3.6）：
/// * 后台/锁屏/媒体键桥由实现内裝配（Android 前台服务通知 + 桌面 SMTC/MPRIS）。
/// * `restore` 失败→调用方重试 1 次→「播放服务异常」UI；实现不自行无限重试。
library;

import 'exceptions.dart';
import 'shared.dart';

/// 引擎消息（单流多态；实现必须按事件实际发生顺序推送）。
sealed class EngineEvent {
  const EngineEvent();
}

enum EngineState { idle, loading, playing, paused, ended, error }

final class EngineStateChanged extends EngineEvent {
  const EngineStateChanged(this.state);
  final EngineState state;
}

/// 进度心跳（实现承诺 ≤250ms 间隔；§5.2 语义）。
final class EnginePositionTick extends EngineEvent {
  const EnginePositionTick(this.positionMs);
  final int positionMs;
}

final class EngineItemEnded extends EngineEvent {
  const EngineItemEnded(this.queueIndex);
  final int queueIndex;
}

final class EngineError extends EngineEvent {
  const EngineError(this.cause);
  final ContractException cause;
}

/// 后台回收/会话失效（触发 calling 层 restore）。
final class EngineSessionLost extends EngineEvent {
  const EngineSessionLost();
}

/// 媒体命令类别（OS→App 回流：通知栏/锁屏/媒体键/蓝牙，REQ-PLAY-05）。
enum MediaCommandKind { play, pause, playPause, stop, next, previous, seekTo, seekBy, like }

/// 媒体会话命令回流（实现从包内 `mediaSessionCommands` 流映射；
/// play/pause/next/previous/seek 由调用方执行——服务是队列与模式权威）。
final class EngineMediaCommand extends EngineEvent {
  const EngineMediaCommand(this.kind, {this.positionMs, this.offsetMs});

  final MediaCommandKind kind;

  /// kind=seekTo：绝对位置毫秒。
  final int? positionMs;

  /// kind=seekBy：相对偏移毫秒（负=回退）。
  final int? offsetMs;
}

/// 媒体会话元数据（随曲更新：换曲/红心态变化时由服务侧推送）。
final class MediaSessionInfo {
  const MediaSessionInfo({
    this.title,
    this.artist,
    this.durationMs,
    this.favorite,
  });

  final String? title;
  final String? artist;
  final int? durationMs;

  /// null=不改变当前红心态（仅换曲更新元数据时）。
  final bool? favorite;
}

/// 引擎配置（跨端桥/缓冲）。
final class EngineConfig {
  const EngineConfig({
    this.adapterOverride,
    this.bufferMs = 3000,
    this.preloadNextCount = 2,
  });

  /// `null`=按端默认选择；显式值仅供 PoC/回退切换（ISS-201）。
  final String? adapterOverride;
  final int bufferMs;
  final int preloadNextCount;
}

/// 播放队列快照（调用方持有权威数据；引擎只消费）。
final class QueueSnapshot {
  const QueueSnapshot({required this.items, required this.startIndex});

  final List<TrackLite> items;
  final int startIndex;
}

/// 会话恢复快照。
final class SessionSnapshot {
  const SessionSnapshot({required this.items, required this.startIndex, required this.positionMs});

  final List<TrackLite> items;
  final int startIndex;
  final int positionMs;
}

abstract class EnginePort {
  /// 初始化；重复调用→`StateError`（契约前置）。
  Future<void> init(EngineConfig cfg);

  /// 加载队列并从 [QueueSnapshot.startIndex] 开始播放。
  Future<void> loadAndPlay(QueueSnapshot snapshot, int startIndex);

  Future<void> play();

  Future<void> pause();

  /// 绝对定位（毫秒）。
  Future<void> seekTo(int positionMs);

  /// 5 段 EQ（60/230/910/3600/14000 Hz，-12..+12 dB）；不支持端→`EngineCapabilityException`。
  Future<void> setEqBands(List<double> gains);

  /// 应用音量（percent，100=不衰减；>100 为增益，实现可按端钳制）。
  Future<void> setVolume(double volume);

  /// **插队**（REQ-PLAY-06）：把 [item] 插为当前曲之后立刻播放的下一首。
  /// * 语义=mvp「下一首播放」：不打断当前曲、引擎物理 playlist 立即增长
  ///   （mpv `loadfile <path> insert-next` 转义阀，S8 详记）。
  /// * 自然推进与手动 next 均按新序命中（游标/镜像同事务增列口径）。
  Future<void> insertNext(TrackLite item);

  /// 移除队列第 [index] 条（REQ-PLAY-06 队列管理；**不得为当前播放条**，
  /// 调用方守卫；实现同步维护游标；不打断当前曲播放）。
  Future<void> removeQueueIndex(int index);

  /// 停止播放并清空引擎队列（REQ-PLAY-06 队列清空）。
  Future<void> stopAll();

  /// 更新媒体会话元数据（REQ-PLAY-05：换曲/红心态变化随曲更新通知面；
  /// 实现只更新元数据，不重夺会话所有权）。
  Future<void> updateMediaSession(MediaSessionInfo info);

  /// 事件流（progress/state/ended/sessionLost/error）。
  Stream<EngineEvent> get events;

  /// 后台回收/崩溃后的会话恢复（队列+进度；含媒体会话重绑）。
  Future<void> restore(SessionSnapshot snapshot);

  /// 资源全净释放（§4.3：句柄/bridges/通知）。
  Future<void> dispose();
}
