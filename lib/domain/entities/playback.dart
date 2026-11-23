/// 播放域 UI 快照（纯 Dart；service 持有，UI 经 state 消费）。
library;

import 'track.dart';

/// 循环模式（v3 队列行为；引擎侧映射 Media3 LoopMode）。
enum RepeatMode { off, all, one }

class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.queue,
    required this.index,
    required this.playing,
    required this.loading,
    required this.ended,
    required this.positionMs,
    required this.volume,
    required this.shuffle,
    required this.repeat,
    required this.sleepEndsAt,
  });

  const PlaybackSnapshot.initial()
      : this(
          queue: const <Track>[],
          index: -1,
          playing: false,
          loading: false,
          ended: false,
          positionMs: 0,
          volume: 100,
          shuffle: false,
          repeat: RepeatMode.off,
          sleepEndsAt: null,
        );

  final List<Track> queue;
  final int index;
  final bool playing;
  final bool loading;
  final bool ended;
  final int positionMs;
  final double volume;
  final bool shuffle;

  /// 循环模式（off/all/one）。
  final RepeatMode repeat;

  /// 睡眠定时到期时刻；null=未启用。
  final DateTime? sleepEndsAt;

  Track? get current => (index >= 0 && index < queue.length) ? queue[index] : null;

  /// 当前曲目时长（派生自曲库元数据；曾是从不更新的死字段——进度条与
  /// seekBy 的钳制一直拿 0 在比，进度环/拖拽 seek 全部失效）。
  int get durationMs => current?.durationMs ?? 0;

  PlaybackSnapshot copyWith({
    int? index,
    bool? playing,
    bool? loading,
    bool? ended,
    int? positionMs,
    double? volume,
    bool? shuffle,
    List<Track>? queue,
    RepeatMode? repeat,
    DateTime? sleepEndsAt,
  }) =>
      PlaybackSnapshot(
        queue: queue ?? this.queue,
        index: index ?? this.index,
        playing: playing ?? this.playing,
        loading: loading ?? this.loading,
        ended: ended ?? this.ended,
        positionMs: positionMs ?? this.positionMs,
        volume: volume ?? this.volume,
        shuffle: shuffle ?? this.shuffle,
        repeat: repeat ?? this.repeat,
        sleepEndsAt: sleepEndsAt ?? this.sleepEndsAt,
      );
}
