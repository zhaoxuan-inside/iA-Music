/// EnginePort 适配——AndroidX Media3 / ExoPlayer（just_audio）。
///
/// 无 mpv、无自编译播放器：队列/无缝衔接/后台播放/锁屏控制交给 Android 官方
/// Media3；通知与耳机键由 just_audio_background（audio_service）接管。
library;

import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart'
    show MediaItem;

import '../../domain/entities/playback.dart';
import '../../domain/ports/engine_port.dart';
import 'audio_bootstrap.dart';

class JustAudioEngineAdapter implements EnginePort {
  AudioPlayer? _player;

  /// 队列是否已装载（insert/remove/move 的前置条件）。
  bool _playlistLoaded = false;
  final _events = StreamController<EngineEvent>.broadcast();
  final _subs = <StreamSubscription<dynamic>>[];

  List<QueueItem> _queue = const [];
  int _index = 0;
  int _lastIndex = 0;
  int _lastPosition = -1;
  EngineState _state = EngineState.idle;
  RepeatMode _repeat = RepeatMode.off;
  double _volume = 100;
  bool _inited = false;
  bool _disposed = false;
  bool _suppressIndex = false;
  bool _completedEmitted = false;
  Timer? _suppressTimer;

  AudioPlayer get _p {
    final p = _player;
    if (p == null || _disposed) {
      throw StateError('EnginePort 未 init 或已 dispose');
    }
    return p;
  }

  @override
  Stream<EngineEvent> get events => _events.stream;

  void _emit(EngineEvent e) {
    if (!_events.isClosed) {
      _events.add(e);
    }
  }

  void _emitState(EngineState state) {
    if (_state == state) {
      return;
    }
    _state = state;
    _emit(EngineStateChanged(state));
  }

  @override
  Future<void> init() async {
    if (_inited) {
      throw StateError('EnginePort.init 双重调用');
    }
    _inited = true;
    // 后台服务绑定完成后再建播放器（通知栏/锁屏才有 MediaSession）。
    // 必须等绑定完成，不能只等一小段：绑定在途时建播放器/装带 tag 的源，
    // just_audio_background 内部 `late _audioHandler` 尚未赋值 → 装载抛
    // LateInitializationError 且包内单实例锁被毒化，进程内再也装不进
    // 队列——冷启动恢复会话后播放钮永远无反应（杀死 APP 重进复现）。
    // 「服务没起来也要能播」在 just_audio_background 架构下本就不成立；
    // 内部自带 10s 超时 + 异常兜底，绑定异常时此处最迟十几秒放行。
    await ensureAudioService().timeout(kAudioServiceBind, onTimeout: () {});
    final player = _player = AudioPlayer();
    _subs
      ..add(player.playerStateStream.listen(_onPlayerState))
      ..add(player.positionStream.listen(_onPosition))
      ..add(player.currentIndexStream.listen(_onIndex))
      ..add(player.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace _) => _onError(e),
      ));
  }

  void _onPlayerState(PlayerState s) {
    if (_disposed) {
      return;
    }
    final st = switch (s.processingState) {
      ProcessingState.loading || ProcessingState.buffering => EngineState.loading,
      ProcessingState.completed => EngineState.ended,
      ProcessingState.ready =>
        s.playing ? EngineState.playing : EngineState.paused,
      ProcessingState.idle => EngineState.idle,
    };
    _emitState(st);
    if (s.processingState == ProcessingState.completed && !_completedEmitted) {
      _completedEmitted = true;
      _emit(EngineItemEnded(_index));
    } else if (s.processingState != ProcessingState.completed) {
      _completedEmitted = false;
    }
  }

  void _onPosition(Duration d) {
    final ms = d.inMilliseconds;
    if (ms == _lastPosition) {
      return;
    }
    _lastPosition = ms;
    _emit(EnginePositionTick(ms));
  }

  void _onIndex(int? idx) {
    if (idx == null || idx == _lastIndex) {
      return;
    }
    final old = _lastIndex;
    _lastIndex = idx;
    _index = idx;
    if (_suppressIndex) {
      _suppressIndex = false;
      _suppressTimer?.cancel();
      return;
    }
    if (idx == old + 1) {
      // 自然切条 / 通知栏下一首：服务按「上一首已结束」推进。
      _emit(EngineItemEnded(old));
    } else {
      // 通知栏上一首 / 大跨度跳转：服务直接对齐索引。
      _emit(EngineIndexChanged(idx));
    }
  }

  void _onError(Object e) {
    _emit(EngineFailed(EngineErrorCtor('$e')));
    final next = _index + 1;
    if (next < _queue.length) {
      unawaited(jumpTo(next));
    } else {
      _emitState(EngineState.ended);
    }
  }

  void _suppressOnce() {
    _suppressIndex = true;
    _suppressTimer?.cancel();
    _suppressTimer = Timer(const Duration(milliseconds: 400), () {
      _suppressIndex = false;
    });
  }

  AudioSource _audioSource(QueueItem item) {
    Uri? art;
    final cover = item.coverPath;
    if (cover != null && cover.isNotEmpty && File(cover).existsSync()) {
      art = Uri.file(cover);
    }
    return AudioSource.uri(
      Uri.file(item.path),
      tag: MediaItem(
        id: item.path,
        title: item.title,
        artist: item.artist,
        album: item.album.isEmpty ? null : item.album,
        duration:
            item.durationMs > 0 ? Duration(milliseconds: item.durationMs) : null,
        artUri: art,
      ),
    );
  }

  List<AudioSource> _buildSources(List<QueueItem> queue) =>
      [for (final item in queue) _audioSource(item)];

  Future<void> _playSource(int index, {Duration? initialPosition}) async {
    final player = _p;
    _queue = List<QueueItem>.of(_queue);
    _index = index;
    _lastIndex = index;
    _lastPosition = -1;
    _completedEmitted = false;
    _suppressOnce();
    await player.setAudioSources(_buildSources(_queue),
        initialIndex: index, initialPosition: initialPosition ?? Duration.zero);
    _playlistLoaded = true;
    await player.setLoopMode(_loopMode);
    await player.setVolume(_volume / 100);
    await player.play();
  }

  LoopMode get _loopMode => switch (_repeat) {
        RepeatMode.off => LoopMode.off,
        RepeatMode.all => LoopMode.all,
        RepeatMode.one => LoopMode.one,
      };

  @override
  Future<void> loadAndPlay(List<QueueItem> queue, int startIndex) async {
    _queue = List<QueueItem>.of(queue);
    _index = startIndex.clamp(0, _queue.length - 1);
    await _playSource(_index);
  }

  @override
  Future<void> restore(
      List<QueueItem> queue, int startIndex, int positionMs) async {
    _queue = List<QueueItem>.of(queue);
    _index = startIndex.clamp(0, _queue.length - 1);
    await _playSource(_index,
        initialPosition: Duration(milliseconds: positionMs));
  }

  @override
  Future<void> play() => _p.play();

  @override
  Future<void> pause() => _p.pause();

  @override
  Future<void> seekTo(int positionMs) =>
      _p.seek(Duration(milliseconds: positionMs));

  @override
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _queue.length) {
      return;
    }
    _index = index;
    _lastIndex = index;
    _lastPosition = -1;
    _suppressOnce();
    await _p.seek(Duration.zero, index: index);
    await _p.play();
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0, 100);
    await _p.setVolume(_volume / 100);
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    _repeat = mode;
    await _p.setLoopMode(_loopMode);
  }

  @override
  Future<void> insertNext(QueueItem item) async {
    if (!_playlistLoaded) {
      return;
    }
    final at = (_index + 1).clamp(0, _queue.length);
    await _p.insertAudioSource(at, _audioSource(item));
    _queue = List<QueueItem>.of(_queue)..insert(at, item);
  }

  @override
  Future<void> removeQueueIndex(int index) async {
    if (!_playlistLoaded || index < 0 || index >= _queue.length) {
      return;
    }
    await _p.removeAudioSourceAt(index);
    _queue = List<QueueItem>.of(_queue)..removeAt(index);
    if (index < _index) {
      _index--;
    }
  }

  @override
  Future<void> moveQueueIndex(int from, int to) async {
    if (!_playlistLoaded) {
      return;
    }
    await _p.moveAudioSource(from, to);
    final q = List<QueueItem>.of(_queue);
    final moved = q.removeAt(from);
    q.insert(to, moved);
    _queue = q;
    if (_index == from) {
      _index = to;
    } else if (from < _index && _index <= to) {
      _index--;
    } else if (to <= _index && _index < from) {
      _index++;
    }
    _lastIndex = _index;
  }

  @override
  Future<void> stopAll() async {
    await _p.stop();
    _playlistLoaded = false;
    _queue = const [];
    _index = -1;
    _lastIndex = -1;
    _lastPosition = -1;
    _emitState(EngineState.idle);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _suppressTimer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await _player?.dispose();
    await _events.close();
  }
}
