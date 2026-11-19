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
  Timer? _sleepTimer;
  double? _preSleepVolume;
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
    final repeatName = await _settings.getString(SettingKeys.repeat);
    final repeat = RepeatMode.values.asNameMap()[repeatName] ?? RepeatMode.off;
    _snap = _snap.copyWith(
        volume: volume.clamp(0.0, 100.0), shuffle: shuffle, repeat: repeat);
    await _engine.setVolume(_snap.volume);
    await _engine.setRepeatMode(repeat);
    _sub = _engine.events.listen(_onEvent);
    if (resumeSession) {
      await _tryRestore();
    }
    _emit();
  }

  // ── 对 UI 的命令面 ───────────────────────────────────────────────────

  /// 播放一批曲目（[startIndex] 起播；shuffle=保留起始曲、其余洗牌）。
  ///
  /// [startIndex] 是调用方列表的索引——列表可能含缺失/损坏行，过滤后
  /// 索引会错位（点谁播谁都对不上）。这里按曲目标识映射回可播列表的
  /// 真实位置：起播曲不可播时顺延到其后第一首可播曲。
  Future<void> playTracks(List<Track> tracks, {int startIndex = 0, bool? shuffle}) async {
    final playable = tracks.where((t) => !t.missing && t.path.isNotEmpty).toList();
    if (playable.isEmpty) {
      return;
    }
    var index = _mapStartIndex(tracks, playable, startIndex);
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

  /// 调用方列表索引 → 可播列表索引（按曲目 id 对齐；缺失行不再错位）。
  int _mapStartIndex(List<Track> tracks, List<Track> playable, int startIndex) {
    final posById = {for (var i = 0; i < playable.length; i++) playable[i].id: i};
    if (startIndex >= 0 && startIndex < tracks.length) {
      final mapped = posById[tracks[startIndex].id];
      if (mapped != null) {
        return mapped;
      }
      // 起播曲不可播：顺延到其后第一首可播曲
      for (var i = startIndex + 1; i < tracks.length; i++) {
        final m = posById[tracks[i].id];
        if (m != null) {
          return m;
        }
      }
    }
    return 0;
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

  /// 设置循环模式（off/all/one；引擎映射 + 持久化）。
  Future<void> setRepeatMode(RepeatMode mode) async {
    _snap = _snap.copyWith(repeat: mode);
    _emit();
    await _engine.setRepeatMode(mode);
    await _settings.setString(SettingKeys.repeat, mode.name);
  }

  /// 睡眠定时：[minutes] 分钟后 5s 音量淡出并暂停；null=取消。
  void setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    if (minutes == null || minutes <= 0) {
      _snap = _snap.copyWith(sleepEndsAt: null);
      _emit();
      return;
    }
    _preSleepVolume = _snap.volume;
    final endsAt = DateTime.now().add(Duration(minutes: minutes));
    _sleepTimer = Timer(
        Duration(minutes: minutes),
        () => unawaited(_fadeOutAndPause(endsAt)));
    _snap = _snap.copyWith(sleepEndsAt: endsAt);
    _emit();
  }

  /// 5s 线性淡出后暂停（音量恢复原值，下一次播放不哑）。
  Future<void> _fadeOutAndPause(DateTime endsAt) async {
    const steps = 10;
    const stepMs = 500;
    final from = _snap.volume;
    for (var i = 1; i <= steps; i++) {
      await _engine.setVolume(from * (1 - i / steps));
      await Future<void>.delayed(const Duration(milliseconds: stepMs));
    }
    await pause();
    await _engine.setVolume(from); // 恢复音量（暂停态下静音会延续到下曲）
    _preSleepVolume = null;
    if (_snap.sleepEndsAt == endsAt) {
      _snap = _snap.copyWith(sleepEndsAt: null);
      _emit();
    }
  }

  /// 取消睡眠定时（淡出中断，音量不受影响）。
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (_preSleepVolume != null) {
      unawaited(_engine.setVolume(_preSleepVolume!));
      _preSleepVolume = null;
    }
    _snap = _snap.copyWith(sleepEndsAt: null);
    _emit();
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
    await _engine.insertNext(QueueItem(
        path: track.path,
        title: track.title,
        artist: track.artist,
        album: track.album,
        durationMs: track.durationMs,
        coverPath: track.coverPath));
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

  /// 拖拽重排：[from] 条目移除后插到 [to]（onReorderItem 口径，最终索引=to）。
  /// 队列权威在本服务：镜像列表先行，引擎 playlist-move 跟随。
  Future<void> reorderQueue(int from, int to) async {
    if (from < 0 || from >= _snap.queue.length) {
      return;
    }
    if (to < 0 || to > _snap.queue.length || to == from) {
      return;
    }
    final q = List<Track>.of(_snap.queue);
    final moved = q.removeAt(from);
    q.insert(to, moved);
    var index = _snap.index;
    if (index == from) {
      index = to;
    } else if (from < index && index <= to) {
      index--;
    } else if (to <= index && index < from) {
      index++;
    }
    _snap = _snap.copyWith(queue: q, index: index);
    _emit();
    await _engine.moveQueueIndex(from, to);
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
      case EngineIndexChanged(:final queueIndex):
        if (queueIndex >= 0 && queueIndex < _snap.queue.length) {
          _snap = _snap.copyWith(
              index: queueIndex, positionMs: 0, ended: false);
          unawaited(_publishMediaSession());
        }
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
          QueueItem(
              path: t.path,
              title: t.title,
              artist: t.artist,
              album: t.album,
              durationMs: t.durationMs,
              coverPath: t.coverPath),
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
    _sleepTimer?.cancel();
    await _sub?.cancel();
    await _engine.dispose();
    await _state.close();
    await _notices.close();
  }
}
