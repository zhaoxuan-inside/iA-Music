/// EnginePort 适配——mpv_audio_kit 0.5.x（语义沿用 v1 探针实证）。
///
/// 引擎事实（v1 三条探针，防复发）：
/// * L1 末条目判终=completed（mpv keep-open 扣留 END_FILE）；
///   中段自然切条=endFile(eof)（引擎已自动加载下一条）。
/// * L2 错误条目引擎自动推进（endFile(error)）——适配层只转发事件。
/// * 队列索引权威=引擎 playlist.index；游标在 loadAndPlay/restore 锚齐。
/// * seek 用 raw `seek <sec> absolute`（0.5.x typed seek 在部分端 -12）。
library;

import 'dart:async';
import 'dart:io';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../domain/entities/playback.dart';
import '../../domain/errors.dart';
import '../../domain/ports/engine_port.dart';

class MpvEngineAdapter implements EnginePort {
  MpvEngineAdapter({this.engineLogLevel = LogLevel.warn});

  final LogLevel engineLogLevel;

  Player? _player;
  bool _inited = false;
  bool _disposed = false;
  bool _sessionPublished = false;
  bool _sessionFavorite = false;
  Duration _lastTick = Duration.zero;
  EngineState _state = EngineState.idle;
  int _cursor = 0;
  RepeatMode _repeat = RepeatMode.off;

  final _events = StreamController<EngineEvent>.broadcast();
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  Stream<EngineEvent> get events => _events.stream;

  Player get _p {
    final p = _player;
    if (p == null || _disposed || !_inited) {
      throw StateError('EnginePort 未 init 或已 dispose');
    }
    return p;
  }

  @override
  Future<void> init() async {
    if (_disposed) {
      throw StateError('engine disposed');
    }
    if (_inited) {
      throw StateError('EnginePort.init 双重调用');
    }
    _inited = true;
    MpvAudioKit.ensureInitialized();
    final p = _player =
        Player(configuration: PlayerConfiguration(logLevel: engineLogLevel));
    _subs
      ..add(p.stream.playing.listen(_onPlaying))
      ..add(p.stream.completed.listen(_onCompleted))
      ..add(p.stream.endFile.listen(_onEndFile))
      ..add(p.stream.position.listen(_onPosition))
      ..add(p.stream.mediaSessionCommands.listen(_onMediaCommand));
  }

  void _onPlaying(bool v) {
    if (_disposed) {
      return;
    }
    if (v) {
      if (_state != EngineState.playing) {
        _state = EngineState.playing;
        _emit(EngineStateChanged(EngineState.playing));
      }
    } else if (_state == EngineState.playing) {
      _state = EngineState.paused;
      _emit(EngineStateChanged(EngineState.paused));
    }
  }

  void _onCompleted(bool v) {
    if (_disposed || !v) {
      return;
    }
    // 世代守卫：队列替换瞬间旧代 park 的 completed 漏投 → 吞
    if (_state != EngineState.playing && _state != EngineState.paused) {
      return;
    }
    final n = _playlistCount();
    if (n <= 0) {
      return;
    }
    if (_state != EngineState.ended) {
      _state = EngineState.ended;
      _emit(EngineStateChanged(EngineState.ended));
    }
    _emit(EngineItemEnded(n - 1));
  }

  void _onEndFile(MpvFileEndedEvent e) {
    if (_disposed || _player == null) {
      return;
    }
    if (_state != EngineState.playing && _state != EngineState.paused) {
      return;
    }
    switch (e.reason) {
      case MpvEndFileReason.eof:
        final ended = _cursor;
        _cursor = ended + 1;
        _emit(EngineItemEnded(ended));
      case MpvEndFileReason.error:
        final failed = _cursor;
        _cursor = failed + 1;
        _emit(EngineFailed(EngineErrorCtor('end-file reason=error @$failed')));
      case MpvEndFileReason.stop:
      case MpvEndFileReason.quit:
        break; // 自驱切条/dispose 衍生——吞
      default:
        break;
    }
  }

  void _onPosition(Duration pos) {
    if (_disposed ||
        _state == EngineState.idle ||
        _state == EngineState.loading) {
      return;
    }
    // 实测事件间隔可到 25ms 级——契约承诺 ≤250ms，发更稠即节流
    if (pos - _lastTick < const Duration(milliseconds: 220)) {
      return;
    }
    _lastTick = pos;
    _emit(EnginePositionTick(pos.inMilliseconds));
  }

  void _onMediaCommand(MediaSessionCommand c) {
    if (_disposed) {
      return;
    }
    switch (c) {
      case MediaSessionCommandPlay _:
        _emit(const EngineMediaCommand(MediaCommandKind.play));
      case MediaSessionCommandPause _:
        _emit(const EngineMediaCommand(MediaCommandKind.pause));
      case MediaSessionCommandPlayPause _:
        _emit(const EngineMediaCommand(MediaCommandKind.playPause));
      case MediaSessionCommandStop _:
        _emit(const EngineMediaCommand(MediaCommandKind.stop));
      case MediaSessionCommandNext _:
        _emit(const EngineMediaCommand(MediaCommandKind.next));
      case MediaSessionCommandPrevious _:
        _emit(const EngineMediaCommand(MediaCommandKind.previous));
      case MediaSessionCommandSeekTo(:final position):
        _emit(EngineMediaCommand(MediaCommandKind.seekTo,
            positionMs: position.inMilliseconds));
      case MediaSessionCommandSeekBy(:final offset):
        _emit(EngineMediaCommand(MediaCommandKind.seekBy,
            offsetMs: offset.inMilliseconds));
      case MediaSessionCommandLike _:
        _emit(const EngineMediaCommand(MediaCommandKind.like));
      case MediaSessionCommandSetRepeatMode _:
      case MediaSessionCommandSetShuffle _:
      case MediaSessionCommandSetPlaybackRate _:
        break; // 包内 auto-apply，不应到达；防御吞
    }
  }

  void _emit(EngineEvent e) {
    if (!_events.isClosed) {
      _events.add(e);
    }
  }

  Media _mediaOf(QueueItem t) => Media(
        Uri.file(t.path).toString(),
        extras: {'title': t.title, 'artist': t.artist},
      );

  int _playlistCount() {
    final p = _player;
    if (p == null || _disposed) {
      return 0;
    }
    return p.state.playlist.items.length;
  }

  @override
  Future<void> loadAndPlay(List<QueueItem> queue, int startIndex) async {
    final p = _p;
    _cursor = startIndex;
    _state = EngineState.loading;
    _emit(EngineStateChanged(EngineState.loading));
    await p.openAll([for (final it in queue) _mediaOf(it)],
        play: true, index: startIndex);
    await setRepeatMode(_repeat);
    await _publishSessionOnce(p, queue, startIndex);
  }

  @override
  Future<void> restore(List<QueueItem> queue, int startIndex, int positionMs) async {
    final p = _p;
    _cursor = startIndex;
    _state = EngineState.loading;
    _emit(EngineStateChanged(EngineState.loading));
    await p.openAll([for (final it in queue) _mediaOf(it)],
        play: false, index: startIndex);
    await setRepeatMode(_repeat);
    final ready = await _waitLoaded(p, startIndex);
    if (ready && positionMs > 0) {
      await p.seek(Duration(milliseconds: positionMs), relative: false);
    }
    await _publishSessionOnce(p, queue, startIndex);
    await p.play(); // 会话恢复=自动续播
  }

  @override
  Future<void> play() async {
    final p = _p;
    await _waitLoaded(p, -1);
    await p.play();
  }

  @override
  Future<void> pause() async {
    final p = _p;
    await _waitLoaded(p, -1);
    await p.pause();
  }

  @override
  Future<void> seekTo(int positionMs) async {
    final p = _p;
    await _waitLoaded(p, -1);
    try {
      await p.sendRawCommand(['seek', '${positionMs / 1000.0}', 'absolute']);
    } on Object {
      throw EngineError(detail: 'seek command failed @$positionMs');
    }
  }

  @override
  Future<void> jumpTo(int index) async {
    final p = _p;
    try {
      await p.sendRawCommand(['playlist-play-index', '$index']);
    } on Object catch (e, st) {
      Error.throwWithStackTrace(EngineError(detail: 'jumpTo($index) 失败: $e'), st);
    }
  }

  @override
  Future<void> setVolume(double volume) => _p.setVolume(volume);

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    _repeat = mode;
    final p = _p;
    try {
      switch (mode) {
        case RepeatMode.off:
          await p.sendRawCommand(['set', 'loop-file', 'no']);
          await p.sendRawCommand(['set', 'loop-playlist', 'no']);
        case RepeatMode.all:
          await p.sendRawCommand(['set', 'loop-playlist', 'inf']);
          await p.sendRawCommand(['set', 'loop-file', 'no']);
        case RepeatMode.one:
          await p.sendRawCommand(['set', 'loop-playlist', 'no']);
          await p.sendRawCommand(['set', 'loop-file', 'inf']);
      }
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
          EngineError(detail: 'setRepeatMode($mode) 失败: $e'), st);
    }
  }

  @override
  Future<void> insertNext(QueueItem item) async {
    final p = _p;
    try {
      await p.sendRawCommand(['loadfile', item.path, 'insert-next']);
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
          EngineError(detail: 'insertNext 失败: $e'), st);
    }
  }

  @override
  Future<void> removeQueueIndex(int index) async {
    final p = _p;
    try {
      await p.sendRawCommand(['playlist-remove', '$index']);
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
          EngineError(detail: 'removeQueueIndex 失败: $e'), st);
    }
    if (index < _cursor) {
      _cursor--;
    }
  }

  @override
  Future<void> stopAll() async {
    final p = _p;
    await p.stop();
    _cursor = 0;
  }

  @override
  Future<void> updateMediaSession(MediaSessionInfo info) async {
    if (_disposed || _player == null) {
      return;
    }
    await _applySession(
      title: info.title,
      artist: info.artist,
      durationMs: info.durationMs,
      favorite: info.favorite,
    );
  }

  /// 载入就绪轮询（上界 5s）：duration>0 且（要求时）索引到位。
  Future<bool> _waitLoaded(Player p, int startIndex) async {
    final sw = Stopwatch()..start();
    while (sw.elapsed < const Duration(seconds: 5)) {
      if (_disposed) {
        return false;
      }
      final st = p.state;
      if (st.duration > Duration.zero &&
          (startIndex < 0 || st.playlist.index == startIndex)) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    return false;
  }

  Future<void> _publishSessionOnce(
      Player p, List<QueueItem> queue, int startIndex) async {
    if (_sessionPublished) {
      return;
    }
    _sessionPublished = true;
    // flutter_tester 无 MethodChannel 宿主：桥调用会毒化引擎事件流（v1 实证）→ 跳过
    if (Platform.environment['FLUTTER_TEST'] != null) {
      return;
    }
    final t = (startIndex >= 0 && startIndex < queue.length)
        ? queue[startIndex]
        : null;
    await _applySession(
      title: t?.title,
      artist: t?.artist,
    );
  }

  Future<void> _applySession({
    String? title,
    String? artist,
    int? durationMs,
    bool? favorite,
  }) async {
    final p = _player;
    if (p == null) {
      return;
    }
    if (favorite != null) {
      _sessionFavorite = favorite;
    }
    try {
      await p.setMediaSession(MediaSession(
        title: title,
        artist: artist,
        duration: durationMs != null && durationMs > 0
            ? Duration(milliseconds: durationMs)
            : null,
        isFavorite: _sessionFavorite,
      ));
    } on Object {
      // 真桥临时不可用（MPRIS 无会话等）——音频主线不受阻
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _player?.dispose();
    _player = null;
    _state = EngineState.idle;
    _sessionPublished = false;
    await _events.close();
  }
}
