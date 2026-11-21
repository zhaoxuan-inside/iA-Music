/// 播放域 UI 状态：service 快照 → Notifier；命令直通服务。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/playback.dart';
import '../domain/entities/track.dart';
import '../services/playback/playback_service.dart';
import 'providers.dart';

class PlaybackController extends Notifier<PlaybackSnapshot> {
  @override
  PlaybackSnapshot build() {
    final service = ref.watch(playbackServiceProvider);
    unawaited(service.start(resumeSession: true));
    service.stream.listen((s) {
      if (state != s) {
        state = s;
      }
    });
    return service.snapshot;
  }

  PlaybackService get _service => ref.read(playbackServiceProvider);

  Future<void> playTracks(List<Track> tracks, {int startIndex = 0, bool? shuffle}) =>
      _service.playTracks(tracks, startIndex: startIndex, shuffle: shuffle);

  /// 点播：按曲目身份起播（UI 不算位置索引）。
  Future<void> playTrack(Track start, {List<Track>? queue, bool? shuffle}) =>
      _service.playTrack(start, queue: queue, shuffle: shuffle);

  Future<void> togglePlay() => _service.togglePlay();
  Future<void> next() => _service.next();
  Future<void> previous() => _service.previous();
  Future<void> seekTo(int ms) => _service.seekTo(ms);
  Future<void> setVolume(double v) => _service.setVolume(v);
  Future<void> toggleShuffle() => _service.toggleShuffle();
  Future<void> setRepeatMode(RepeatMode m) => _service.setRepeatMode(m);
  void setSleepTimer(int? minutes) => _service.setSleepTimer(minutes);
  void cancelSleepTimer() => _service.cancelSleepTimer();
  Future<void> playNext(Track t) => _service.playNext(t);
  Future<void> removeFromQueue(int i) => _service.removeFromQueue(i);
  Future<void> reorderQueue(int from, int to) => _service.reorderQueue(from, to);
  Future<void> clearQueue() => _service.clearQueue();
}

final playbackProvider =
    NotifierProvider<PlaybackController, PlaybackSnapshot>(PlaybackController.new);

/// 缺失/损坏跳过等播报横幅流。
final playbackNoticeProvider = StreamProvider<String>((ref) {
  return ref.watch(playbackServiceProvider).notices;
});
