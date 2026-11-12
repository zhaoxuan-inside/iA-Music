/// 播放域 UI 快照（纯 Dart；service 持有，UI 经 state 消费）。
library;

import 'track.dart';

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
      );
}
