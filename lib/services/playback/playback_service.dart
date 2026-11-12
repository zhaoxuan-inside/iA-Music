/// 播放服务：队列权威 + 事件消费 + 历史与快照持久化。
///
/// 分工（引擎=播放执行，本服务=队列/模式/历史权威）：
/// * 引擎自然推进（eof/error 自动跳条）→ ItemEnded/Error 事件里对齐索引。
/// * 手动 next/previous → 记当前曲 completed=false 历史 → jumpTo。
/// * 缺失/损坏件 → 标 missing + 通知横幅（引擎已自动推进）。
/// * 会话快照节流写 settings；冷启动 restore（自动续播）。
library;

import 'dart:async';

import '../../data/database.dart';
import '../../domain/entities/playback.dart';
import '../../domain/entities/track.dart';
import '../../domain/ports/engine_port.dart';
import '../settings/settings_service.dart';

class PlaybackService {
  PlaybackService({
    required EnginePort engine,
    required IaDatabase db,
    required SettingsService settings,
  })  : _engine = engine,
        _library = db.libraryDao,
        _history = db.historyDao,
        _playlists = db.playlistDao,
        _settings = settings;

  final EnginePort _engine;
  final LibraryDao _library;
  final HistoryDao _history;
  final PlaylistDao _playlists;
  final SettingsService _settings;

  final _state = StreamController<PlaybackSnapshot>.broadcast();
  final _notices = StreamController<String>.broadcast();
  StreamSubscription<EngineEvent>? _sub;

  PlaybackSnapshot _snap = const PlaybackSnapshot.initial();
  Timer? _sessionTimer;
  bool _inited = false;
  bool _disposed = false;

  Stream<PlaybackSnapshot> get stream => _state.stream;
  Stream<String> get notices => _notices.stream;
  PlaybackSnapshot get snapshot => _snap;

  Future<void> start({required bool resumeSession}) async {
    if (_inited) {
      return;
    }
    _inited = true;
    await _engine.init();
    final volume = await _settings.getDouble(SettingKeys.volume, fallback: 100);
    final shuffle = await _settings.getBool(SettingKeys.shuffle);
    _snap = _snap.copyWith(volume: volume.clamp(0.0, 100.0), shuffle: shuffle);
    await _engine.setVolume(_snap.volume);
    _sub = _engine.events.listen(_onEvent);
    if (resumeSession) {
      await _tryRestore();
    }
    _emit();
  }

  // ── 对 UI 的命令面 ───────────────────────────────────────────────────

  /// 播放一批曲目（[startIndex] 起播；shuffle=保留起始曲、其余洗牌）。
  Future<void> playTracks(List<Track> tracks, {int startIndex = 0, bool? shuffle}) async {
    final playable = tracks.where((t) => !t.missing && t.path.isNotEmpty).toList();
    if (playable.isEmpty) {
      return;
    }
    var index = startIndex.clamp(0, playable.length - 1);
    final useShuffle = shuffle ?? _snap.shuffle;
    if (useShuffle) {
      final start = playable[index];
      final rest = playable.where((t) => t.id != start.id).toList()
        ..shuffle();
      playable
        ..clear()
        ..add(start)
        ..addAll(rest);
      index = 0;
    }
    _snap = _snap.copyWith(queue: playable, index: index, ended: false, loading: true, shuffle: useShuffle);
    _emit();
    await _engine.loadAndPlay(_toItems(playable), index);
    await _recordHistory(playable[index], completed: false);
    await _publishMediaSession();
    _emit();
  }

  Future<void> togglePlay() =>
      _snap.playing || _snap.loading ? pause() : play();

  Future<void> play() => _engine.play();

  Future<void> pause() => _engine.pause();

  Future<void> next() async {
    final i = _snap.index;
    if (i >= 0 && i < _snap.queue.length - 1) {
      await _recordHistory(_snap.queue[i], completed: false);
      _snap = _snap.copyWith(index: i + 1, ended: false, positionMs: 0);
      _emit();
      await _engine.jumpTo(i + 1);
      await _publishMediaSession();
    }
  }

  Future<void> previous() async {
    final i = _snap.index;
    if (i > 0) {
      if (_snap.positionMs > 3000) {
        await _engine.seekTo(0);
        return;
      }
      _snap = _snap.copyWith(index: i - 1, ended: false, positionMs: 0);
      _emit();
      await _engine.jumpTo(i - 1);
      await _publishMediaSession();
    }
  }

  Future<void> seekTo(int positionMs) => _engine.seekTo(positionMs);

  Future<void> setVolume(double volume) async {
    final v = volume.clamp(0.0, 100.0);
    _snap = _snap.copyWith(volume: v);
    _emit();
    await _engine.setVolume(v);
    await _settings.setDouble(SettingKeys.volume, v);
  }

  Future<void> toggleShuffle() async {
    final v = !_snap.shuffle;
    _snap = _snap.copyWith(shuffle: v);
    _emit();
    await _settings.setBool(SettingKeys.shuffle, v);
  }

  /// 下一首播放：插队（引擎物理 playlist + 服务镜像同位对齐）。
  Future<void> playNext(Track track) async {
    final i = _snap.index;
    if (i < 0 || _snap.queue.isEmpty) {
      await playTracks([track]);
      return;
    }
    final q = List<Track>.of(_snap.queue)..insert(i + 1, track);
    _snap = _snap.copyWith(queue: q);
    _emit();
    await _engine.insertNext(QueueItem(path: track.path, title: track.title, artist: track.artist));
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _snap.queue.length || index == _snap.index) {
      return; // 当前播放条不可移除（引擎契约）
    }
    final q = List<Track>.of(_snap.queue)..removeAt(index);
    _snap = _snap.copyWith(queue: q, index: index < _snap.index ? _snap.index - 1 : _snap.index);
    _emit();
    await _engine.removeQueueIndex(index);
  }

  Future<void> clearQueue() async {
    _snap = _snap.copyWith(queue: const [], index: -1, ended: true, positionMs: 0);
    _emit();
    await _engine.stopAll();
    await _settings.setJsonObject(SettingKeys.session, {});
  }

  // ── 引擎事件消费 ─────────────────────────────────────────────────────

  void _onEvent(EngineEvent e) {
    if (_disposed) {
      return;
    }
    switch (e) {
      case EngineStateChanged(:final state):
        _snap = _snap.copyWith(
          playing: state == EngineState.playing,
          loading: state == EngineState.loading,
          ended: state == EngineState.ended ? true : _snap.ended,
        );
      case EnginePositionTick(:final positionMs):
        _snap = _snap.copyWith(positionMs: positionMs);
        _scheduleSessionSave();
      case EngineItemEnded(:final queueIndex):
        _onItemEnded(queueIndex);
      case EngineFailed(:final error):
        _onEngineError(error);
      case EngineMediaCommand(:final kind, :final positionMs, :final offsetMs):
        _onMediaCommand(kind, positionMs, offsetMs);
    }
    _emit();
  }

  void _onItemEnded(int queueIndex) {
    final endedTrack =
        (queueIndex >= 0 && queueIndex < _snap.queue.length) ? _snap.queue[queueIndex] : null;
    if (endedTrack != null) {
      unawaited(_recordHistory(endedTrack, completed: true));
    }
    final nextIndex = queueIndex + 1;
    if (nextIndex < _snap.queue.length) {
      _snap = _snap.copyWith(index: nextIndex, positionMs: 0);
      unawaited(_publishMediaSession());
      unawaited(_recordHistory(_snap.queue[nextIndex], completed: false));
      unawaited(_saveSession());
    } else {
      _snap = _snap.copyWith(ended: true, positionMs: 0);
      unawaited(_saveSession());
    }
  }

  void _onEngineError(EngineErrorCtor error) {
    // 引擎已自动跳条：对齐索引 + 标缺失 + 通知
    final failedIndex = _snap.index;
    if (failedIndex >= 0 && failedIndex < _snap.queue.length) {
      final bad = _snap.queue[failedIndex];
      unawaited(_library.markMissing([bad.id]));
      _notices.add(bad.title);
    }
    final nextIndex = failedIndex + 1;
    if (nextIndex < _snap.queue.length) {
      _snap = _snap.copyWith(index: nextIndex, positionMs: 0);
      unawaited(_publishMediaSession());
    } else {
      _snap = _snap.copyWith(ended: true);
    }
  }

  void _onMediaCommand(MediaCommandKind kind, int? positionMs, int? offsetMs) {
    switch (kind) {
      case MediaCommandKind.play:
        unawaited(play());
      case MediaCommandKind.pause:
        unawaited(pause());
      case MediaCommandKind.playPause:
        unawaited(togglePlay());
      case MediaCommandKind.stop:
        unawaited(pause());
      case MediaCommandKind.next:
        unawaited(next());
      case MediaCommandKind.previous:
        unawaited(previous());
      case MediaCommandKind.seekTo:
        if (positionMs != null) {
          unawaited(seekTo(positionMs));
        }
      case MediaCommandKind.seekBy:
        if (offsetMs != null) {
          final target = (_snap.positionMs + offsetMs).clamp(0, _snap.durationMs).toInt();
          unawaited(seekTo(target));
        }
      case MediaCommandKind.like:
        final t = _snap.current;
        if (t != null) {
          unawaited(() async {
            final fav = await _playlists.isFavorite(t.id);
            await _playlists.setFavorite(t.id, !fav);
          }());
        }
    }
  }

  // ── 会话快照 ─────────────────────────────────────────────────────────

  void _scheduleSessionSave() {
    _sessionTimer ??= Timer(const Duration(seconds: 5), () {
      _sessionTimer = null;
      unawaited(_saveSession());
    });
  }

  Future<void> _saveSession() async {
    final q = _snap.queue;
    if (q.isEmpty) {
      return;
    }
    await _settings.setJsonObject(SettingKeys.session, {
      'paths': [for (final t in q) t.path],
      'index': _snap.index,
      'positionMs': _snap.positionMs,
    });
  }

  Future<void> _tryRestore() async {
    final session = await _settings.getJsonObject(SettingKeys.session);
    if (session == null || (session['paths'] as List<dynamic>?) == null) {
      return;
    }
    final paths = [for (final p in session['paths'] as List<dynamic>) p as String];
    var index = (session['index'] as num?)?.toInt() ?? 0;
    final positionMs = (session['positionMs'] as num?)?.toInt() ?? 0;
    final tracks = (await _library.tracksByPaths(paths)).where((t) => !t.missing).toList();
    if (tracks.isEmpty) {
      return;
    }
    // 路径可能部分失效：按存活集合重新定位
    final keptPaths = {for (final t in tracks) t.path};
    final originalOrder = [for (final p in paths) p];
    var aliveIndex = 0;
    for (var i = 0; i < originalOrder.length && i <= index; i++) {
      if (keptPaths.contains(originalOrder[i]) && i < index) {
        aliveIndex++;
      }
    }
    index = aliveIndex.clamp(0, tracks.length - 1);
    _snap = _snap.copyWith(queue: tracks, index: index, ended: false, loading: true);
    try {
      await _engine.restore(_toItems(tracks), index, positionMs);
    } on Object {
      _snap = _snap.copyWith(loading: false);
    }
  }

  // ── 杂项 ─────────────────────────────────────────────────────────────

  Future<void> _recordHistory(Track t, {required bool completed}) async {
    try {
      await _history.record(t.id, completed: completed);
    } on Object {
      // 历史失败不阻断播放
    }
  }

  Future<void> _publishMediaSession() async {
    final t = _snap.current;
    if (t == null) {
      return;
    }
    await _engine.updateMediaSession(MediaSessionInfo(
      title: t.title,
      artist: t.artist,
      durationMs: t.durationMs,
    ));
  }

  List<QueueItem> _toItems(List<Track> tracks) => [
        for (final t in tracks)
          QueueItem(path: t.path, title: t.title, artist: t.artist),
      ];

  void _emit() {
    if (!_state.isClosed) {
      _state.add(_snap);
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _saveSession();
    _sessionTimer?.cancel();
    await _sub?.cancel();
    await _engine.dispose();
    await _state.close();
    await _notices.close();
  }
}
