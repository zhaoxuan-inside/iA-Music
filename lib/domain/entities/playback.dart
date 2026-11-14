/// 播放域 UI 快照（纯 Dart；service 持有，UI 经 state 消费）。
library;

import 'track.dart';

/// 循环模式（v3 队列行为；引擎侧映射 mpv loop 属性）。
enum RepeatMode { off, all, one }

class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.queue,
    required this.index,
    required this.playing,
    required this.loading,
    required this.ended,
    required this.positionMs,
    required this.durationMs,
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
          durationMs: 0,
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
  final int durationMs;
  final double volume;
  final bool shuffle;

  /// 循环模式（off/all/one）。
  final RepeatMode repeat;

  /// 睡眠定时到期时刻；null=未启用。
  final DateTime? sleepEndsAt;

  Track? get current => (index >= 0 && index < queue.length) ? queue[index] : null;

  PlaybackSnapshot copyWith({
    int? index,
    bool? playing,
    bool? loading,
    bool? ended,
    int? positionMs,
    int? durationMs,
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
        durationMs: durationMs ?? this.durationMs,
        volume: volume ?? this.volume,
        shuffle: shuffle ?? this.shuffle,
        repeat: repeat ?? this.repeat,
        sleepEndsAt: sleepEndsAt ?? this.sleepEndsAt,
      );
}
