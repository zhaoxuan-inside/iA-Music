/// 播放域服务 —— 随机池开播 / 自动连播 / 少播 / 缺失跳过 / 恢复（TASK-S3）。
///
/// 纪律（DETAILED-DESIGN §2.1/§3.6/§4.3 + ARCH §3.2）：
/// * 队列**权威=本服务**（契约：QueueSnapshot 只是引擎消费快照）；引擎列表
///   索引==队列索引（loadAndPlay 全量+startIndex 载入）。
/// * 历史=**延迟合并写**（ARCH §3.2）：事件入缓冲 → 阈值(8) 或显式 flush
///   单事务落库（HistoryDao.recordBatch）；500 淘汰（D9-3） flushed 随触发。
/// * 会话快照（内存/轻持久）=settings 表 `playback.session` JSON。
/// * 自然播完=completed=true 历史；跳过/损坏/缺曲=completed=false
///   （「该曲不写完成播放历史」的诚实口径：行仍记事实，完成位不真）。
/// * 缺失判定（真 fs stat）：EngineError→File.exists → missing→补写
///   `missing_at`（与扫描轮口径一致）+提示「文件缺失，已跳过」；
///   文件在位→损坏线提示「无法播放该文件（格式或文件损坏），已跳过」。
/// * 恢复=**重试 1 次**（§4.3；禁无限）；二次失败→跳进口播「播放服务异常」。
/// * 一轮播完（末条 park）→ 自动开新一轮（随机池重采样；豆瓣 FM 无限电台
///   行为线；池被清空→停驻仅 UI 空态，不再循环）。
/// * 墓碑由 SyncEngine 域（S6）补写——本服务只做少播名单业务写（S1 纪律沿用）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';

import '../data/daos.dart';
import '../data/ia_database.dart';
import '../l10n/s.dart';
import '../playlists/playlist_service.dart';

/// UI 消费快照（非契约；页面 StreamBuilder 直接吃）。
class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.playing,
    required this.currentIndex,
    required this.positionMs,
    required this.queue,
    required this.mode,
  });

  final bool playing;
  final int currentIndex;
  final int positionMs;
  final List<TrackLite> queue;
  final PlaybackMode mode;

  bool get isEmpty => queue.isEmpty;
  TrackLite? get currentTrack =>
      currentIndex >= 0 && currentIndex < queue.length ? queue[currentIndex] : null;
}

/// 循环模式（playback_prd §3.1：顺序/列表循环/单曲循环/随机；默认列表循环；
/// 「随机」与音乐空间随机卡同一语义——S4 DoD2 行为分岔由服务路由承担）。
enum PlaybackMode { loops, single, sequence, random }

enum PlaybackNoticeKind {
  emptyPool,
  missingSkip,
  corruptSkip,
  serviceBroken,
  fewWatched,
}

/// 顶部提示（REQ-PLAY-08 / PLAY §3.1 Toast 语义的服务面来源）。
class PlaybackNotice {
  const PlaybackNotice(this.kind, this.text);

  final PlaybackNoticeKind kind;
  final String text;
}

class PlaybackService {
  PlaybackService(this.engine, this.data, {this.deviceId = 'desktop-local'});

  final EnginePort engine;
  final DataAccess data;
  final String deviceId;

  /// 会话快照 settings 键（schema settings 指纹面板外的小键，DEC-009 惯例）。
  static const sessionKey = 'playback.session';

  /// EQ 增益（5 段 dB JSON 数组）与音量（percent 数字）持久化键（WS1）。
  static const eqKey = 'playback.eq';
  static const volumeKey = 'playback.volume';

  /// 历史阈值 8 → 自动冲（延迟合并写；不再大=实时性优先，诚实注记 IMPL-S3）。
  static const historyFlushThreshold = 8;

  bool _inited = false;
  bool _disposed = false;
  StreamSubscription<EngineEvent>? _sub;
  final _status = StreamController<PlaybackSnapshot>.broadcast();
  final _notices = StreamController<PlaybackNotice>.broadcast();
  final _histBuffer = <({int trackId, bool completed, int playedAtMs})>[];
  bool _recovering = false;
  int _recoverTries = 0;
  bool _playing = false;
  PlaybackNotice? _lastNotice;
  int? _sessionTrackId; // 媒体会话随曲更新去重锚（REQ-PLAY-05）
  PlaylistService? _plSvc; // 惰性歌单服务（媒体命令 like 回流面）

  final List<TrackLite> _queue = <TrackLite>[];
  int _current = 0;
  int _positionMs = 0;
  PlaybackMode _mode = PlaybackMode.loops; // PRD §3.1 默认列表循环
  double _volume = 100.0; // percent；持久化见 volumeKey
  List<double> _eq = const [0, 0, 0, 0, 0]; // 5 段 dB（UI 读面）

  Stream<PlaybackSnapshot> get status => _status.stream;
  Stream<PlaybackNotice> get notices => _notices.stream;
  PlaybackSnapshot get snapshot => _snap();

  /// 当前循环模式（只读；写经 [setMode]——驱动行为路由与 UI 图标）。
  PlaybackMode get mode => _mode;

  /// 模式切换（REQ-PLAY-03）：无引擎面——语义在「一轮末/自然推进」的路由。
  void setMode(PlaybackMode m) {
    _requireAlive();
    if (_mode == m) {
      return;
    }
    _mode = m;
    _push();
  }

  void _requireAlive() {
    if (!_inited || _disposed) {
      throw StateError('PlaybackService 未初始化或已终止');
    }
  }

  /// 复用判定（页面二次进入不重复 init）。
  bool get isReady => _inited && !_disposed;

  Future<void> init({String? adapterOverride}) async {
    if (_disposed) {
      throw StateError('PlaybackService 已终止');
    }
    if (_inited) {
      throw StateError('PlaybackService.init 双重调用');
    }
    _inited = true;
    await engine.init(EngineConfig(adapterOverride: adapterOverride));
    _sub = engine.events.listen(_onEngineEvent);
    await _restoreAudioPrefs();
    _push();
  }

  /// 启动回放持久化的音量/EQ（best-effort：读不到/应用失败不阻塞播放主线）。
  Future<void> _restoreAudioPrefs() async {
    try {
      final vol = await data.shell.value(volumeKey);
      if (vol != null && vol.isNotEmpty) {
        final v = double.tryParse(vol);
        if (v != null && v >= 0) {
          _volume = v.clamp(0.0, 150.0);
          await engine.setVolume(_volume);
        }
      }
      final eq = await data.shell.value(eqKey);
      if (eq != null && eq.isNotEmpty) {
        final list = (jsonDecode(eq) as List? ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(growable: false);
        if (list.length == 5) {
          await engine.setEqBands(list);
          _eq = list;
        }
      }
    } on Object {
      // 预置恢复失败（引擎不支持/值损坏）→ 保持默认，UI 打开时可见真实态
    }
  }

  // ── 状态/通知面 ────────────────────────────────────────────

  PlaybackSnapshot _snap() => PlaybackSnapshot(
        playing: _playing,
        currentIndex: _current,
        positionMs: _positionMs,
        queue: List.unmodifiable(_queue),
        mode: _mode,
      );

  void _push() {
    if (_status.isClosed) {
      return;
    }
    _status.add(_snap());
    // 媒体会话随曲更新（REQ-PLAY-05）：换曲即推送元数据（title/artist/duration；
    // favorite=null=不改变红心态）。position tick 高频到达，trackId 去重。
    final cur = _queue.isNotEmpty && _current >= 0 && _current < _queue.length
        ? _queue[_current]
        : null;
    if (cur != null && cur.id != _sessionTrackId) {
      _sessionTrackId = cur.id;
      unawaited(engine.updateMediaSession(MediaSessionInfo(
        title: cur.title,
        artist: cur.artistDisplay,
        durationMs: cur.durationMs > 0 ? cur.durationMs : null,
      )));
    }
  }

  void _notify(PlaybackNotice n) {
    _lastNotice = n;
    if (!_notices.isClosed) {
      _notices.add(n);
    }
  }

  /// 最新提示（单一值读面：FakeAsync widget 环境下 broadcast 事件跨 zone
  /// 不成帧（IMPL-S2 §4-L3）——S3 UI 顶部横幅用「每帧重读」语义消费）。
  PlaybackNotice? get lastNotice => _lastNotice;

  // ── 随机池（D9-2：SQL 粗筛 + 内存采样由 DAO；此处组合绝对路径） ──

  Future<List<TrackLite>> sampleRound({int poolSize = 200}) async {
    final lib = data.library;
    var rows = await lib.randomPool(sampleSize: poolSize, candidateCap: 1000);
    if (rows.length < 10) {
      // NAV §3.5 规 1：池不足 10 → 全库补满（含少播曲；仍 playable 双 NULL 口径）
      rows = await lib.randomPool(
        sampleSize: poolSize,
        candidateCap: 1000,
        includeFewWatch: true,
      );
    }
    final roots = await _rootsMap();
    final lite = <TrackLite>[];
    for (final t in rows) {
      final item = _liteOf(t, roots);
      if (item != null) {
        lite.add(item);
      }
    }
    return lite; // DAO 采样序=Fisher-Yates 洗牌序 → 引擎按此直推=单轮不重复
  }

  /// 绝对路径拼接口径（与 scan_service 正斜杠归一一致）。
  static String joinAbs(String rootPath, String rel) {
    final dir = rootPath.replaceAll('\\', '/');
    return dir.endsWith('/') ? '$dir$rel' : '$dir/$rel';
  }

  /// 行→队列项组装（唯一拼装面：绝对路径 join + 根缺失=丢弃）。
  TrackLite? _liteOf(Track row, Map<int, RepositoryRoot> roots) {
    final root = roots[row.rootId];
    if (root == null) {
      return null;
    }
    return TrackLite(
      id: row.id,
      path: joinAbs(root.path, row.relPath),
      title: row.title ?? '',
      artistDisplay: row.artistDisplay ?? '',
      durationMs: row.durationMs ?? 0,
    );
  }

  Future<Map<int, RepositoryRoot>> _rootsMap() async =>
      {for (final r in await data.library.rootsSnapshot()) r.id: r};

  Future<void> startRandom({int poolSize = 200}) async {
    _requireAlive();
    _mode = PlaybackMode.random; // 随机卡进入=随机模式（DEC-004 会话语义）
    final lite = await sampleRound(poolSize: poolSize);
    if (lite.isEmpty) {
      _notify(PlaybackNotice(
        PlaybackNoticeKind.emptyPool,
        msg.emptyPoolForShuffle,
      ));
      _playing = false;
      _push();
      return;
    }
    _queue
      ..clear()
      ..addAll(lite);
    _current = 0;
    _positionMs = 0;
    await engine.loadAndPlay(QueueSnapshot(items: _queue, startIndex: 0), 0);
    await _persistSession();
    _push();
  }

  /// **按 id 起播**（REQ-PLAY-01 行：曲库行点击/歌单「播放全部」；S4 收口）。
  /// * 模式默认=列表循环（PRD §3.1「默认：列表循环」；播放页模式按钮可切）。
  /// * 路径解析在服务内（根目录 joinAbs），页面不越域读他表。
  Future<void> playTrackIds(List<int> ids, {int startIndex = 0}) async {
    _requireAlive();
    final lite = <TrackLite>[];
    // 根映射一次性装配（此前在循环内逐曲重查 roots=N+1 查询）。
    final roots = await _rootsMap();
    for (final id in ids) {
      final row = await data.library.rowById(id);
      if (row == null) {
        continue; // 幽灵 id（并发软删）→ 跳过不入队
      }
      final item = _liteOf(row, roots);
      if (item != null) {
        lite.add(item);
      }
    }
    if (lite.isEmpty) {
      _notify(PlaybackNotice(
        PlaybackNoticeKind.emptyPool,
        msg.emptyPoolForPlay,
      ));
      return;
    }
    _mode = PlaybackMode.loops;
    await loadTracks(lite, startIndex: startIndex);
  }

  /// 显式装载（DoD4/DoD6 锚定的确定性队列；S4 页面跳转复用）。
  Future<void> loadTracks(List<TrackLite> items, {int startIndex = 0}) async {
    _requireAlive();
    _queue
      ..clear()
      ..addAll(items);
    _current = startIndex.clamp(0, items.isEmpty ? 0 : items.length - 1);
    _positionMs = 0;
    await engine.loadAndPlay(
      QueueSnapshot(items: _queue, startIndex: _current),
      _current,
    );
    await _persistSession();
    _push();
  }

  /// **插队「下一首播放」**（REQ-PLAY-06）：镜像 `_current+1` + 引擎物理增列
  /// （不打断当前曲——mpv insert-next）；空队列=直接起播该曲。
  Future<void> insertNextId(int trackId) async {
    _requireAlive();
    final row = await data.library.rowById(trackId);
    if (row == null) {
      return;
    }
    final roots = await _rootsMap();
    final lite = _liteOf(row, roots);
    if (lite == null) {
      return;
    }
    if (_queue.isEmpty) {
      _mode = PlaybackMode.loops;
      await loadTracks([lite], startIndex: 0);
      return;
    }
    _queue.insert((_current + 1).clamp(0, _queue.length), lite);
    await engine.insertNext(lite);
    _push();
    await _persistSession();
  }

  // ── 控制面 ────────────────────────────────────────────────

  /// 垃圾桶（REQ-PLAY-04）：当前曲入少播名单 + 立即下一首；Toast 由 UI 发。
  Future<void> dislikeThenNext() async {
    _requireAlive();
    if (_queue.isEmpty) {
      return;
    }
    final cur = _queue[_current];
    _histAdd(trackId: cur.id, completed: false); // 未播完=非完成播放（事实口径）
    await data.history.addFewWatch(cur.id, _nowMs());
    // PLAY §3.1 首点 Toast 原话（UI 顶部提示面；S4 视觉页沿用）
    _notify(PlaybackNotice(PlaybackNoticeKind.fewWatched, msg.fewWatchedNotice));
    final target = _current + 1;
    await _moveTo(target);
    await flushHistory();
  }

  /// 手动下一首（同队列 startIndex 前移；越界→一轮尾部路由）。
  Future<void> next() async {
    _requireAlive();
    if (_queue.isEmpty) {
      return;
    }
    _histAdd(trackId: _queue[_current].id, completed: false);
    final target = _current + 1;
    await _moveTo(target);
    await flushHistory();
  }

  /// 手动上一首（REQ-PLAY §3.1：>3s 回本曲开头；≤3s 切上一首；队首要求 →0）。
  Future<void> previous() async {
    _requireAlive();
    if (_queue.isEmpty) {
      return;
    }
    if (_positionMs > 3000) {
      await engine.seekTo(0);
      _positionMs = 0;
      await _persistSession();
      _push();
      return;
    }
    final target = _current > 0 ? _current - 1 : 0;
    await engine.loadAndPlay(
      QueueSnapshot(items: _queue, startIndex: target),
      target,
    );
    await _persistSession();
    _push();
  }

  Future<void> play() {
    _requireAlive();
    return engine.play();
  }

  Future<void> pause() {
    _requireAlive();
    return engine.pause();
  }

  /// 队列页跳播（REQ-PLAY-06 队列面）：指定队列位立即起播（同位覆盖）。
  Future<void> jumpTo(int index) async {
    _requireAlive();
    if (index < 0 || index >= _queue.length) {
      return;
    }
    _histAdd(trackId: _queue[_current].id, completed: false); // 离开当前曲=未完成
    await _moveTo(index);
    await flushHistory();
  }

  Future<void> seekTo(int ms) {
    _requireAlive();
    return engine.seekTo(ms);
  }

  Future<void> _moveTo(int target) async {
    if (target >= _queue.length) {
      // 越界=一轮尾部 → 模式化收尾路由
      await _roundTail();
    } else {
      _current = target;
      // 塞入位置=上一首已事实性跳过（completed=false 已记）——下一首即刻起
      await engine.loadAndPlay(
        QueueSnapshot(items: _queue, startIndex: target),
        target,
      );
      _positionMs = 0;
    }
    await _persistSession();
    _push();
  }

  /// 一轮末/越界的模式化路由（REQ-PLAY-03：图标状态与队列行为一致）。
  Future<void> _roundTail() async {
    switch (_mode) {
      case PlaybackMode.random:
        // FM 无限电台：池重采样开新一轮（空池→停驻）
        await _applyEmptyOrReload();
        return;
      case PlaybackMode.loops:
        // 列表循环：同队重播（整队从 0）
        _current = 0;
        _positionMs = 0;
        await engine.loadAndPlay(
          QueueSnapshot(items: _queue, startIndex: 0),
          0,
        );
        return;
      case PlaybackMode.single:
        // 单曲循环：同位重播
        _positionMs = 0;
        await engine.loadAndPlay(
          QueueSnapshot(items: _queue, startIndex: _current),
          _current,
        );
        return;
      case PlaybackMode.sequence:
        // 顺序：一轮播完=自然停驻（播放态假置；不重载）
        _playing = false;
        _positionMs = 0;
        return;
    }
  }

  /// EQ 统一缝（WS1 直桥后=真生效；失败仍 false=UI 明示不支持面保留）。
  /// * 成功即持久化（`playback.eq`，5 段 dB JSON），init 时回放。
  Future<bool> setEqBands(List<double> gains) async {
    _requireAlive();
    try {
      await engine.setEqBands(gains);
      _eq = List.of(gains.take(5), growable: false);
      await data.shell.put(
        eqKey,
        jsonEncode([for (final g in gains.take(5)) g]),
        nowMs: _nowMs(),
      );
      return true;
    } on EngineCapabilityException {
      return false;
    }
  }

  /// 音量（percent，0..150；>100=增益，PRD REQ-PLAY-01 桌面滑杆面）。
  double get volume => _volume;

  /// 当前 EQ 增益（只读快照；UI 初始化回显用）。
  List<double> get eqGains => List.unmodifiable(_eq);

  Future<void> setVolume(double v) async {
    _requireAlive();
    _volume = v.clamp(0.0, 150.0);
    await engine.setVolume(_volume);
    await data.shell.put(volumeKey, _volume.toString(), nowMs: _nowMs());
  }

  // ── 引擎事件接线 ──────────────────────────────────────────

  void _onEngineEvent(EngineEvent e) {
    switch (e) {
      case EngineStateChanged(:final state):
        switch (state) {
          case EngineState.playing:
            _playing = true;
            _recoverTries = 0;
          case EngineState.paused:
            _playing = false;
          case EngineState.ended:
            _playing = false;
          case EngineState.idle:
          case EngineState.loading:
          case EngineState.error:
            break;
        }
        _push();
      case EnginePositionTick(:final positionMs):
        _positionMs = positionMs;
        _push();
      case EngineItemEnded(:final queueIndex):
        _onItemEnded(queueIndex);
      case EngineError(:final cause):
        _onEngineFailure(cause);
      case EngineSessionLost():
        _onSessionLost();
      case EngineMediaCommand(:final kind, :final positionMs, :final offsetMs):
        _onMediaCommand(kind, positionMs, offsetMs);
    }
  }

  /// OS→App 媒体命令（REQ-PLAY-05）：通知栏/锁屏/媒体键/蓝牙。
  void _onMediaCommand(MediaCommandKind kind, int? positionMs, int? offsetMs) {
    switch (kind) {
      case MediaCommandKind.play:
        unawaited(play());
      case MediaCommandKind.pause:
        unawaited(pause());
      case MediaCommandKind.playPause:
        _playing ? unawaited(pause()) : unawaited(play());
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
          unawaited(seekTo((_positionMs + offsetMs).clamp(0, 1 << 31)));
        }
      case MediaCommandKind.like:
        unawaited(_toggleFavoriteForMedia());
    }
  }

  /// 通知栏红心（MediaAction.like 回流）：对当前曲 toggle 并回写会话态。
  Future<void> _toggleFavoriteForMedia() async {
    final cur = snapshot.currentTrack;
    if (cur == null) {
      return;
    }
    final added = await (_plSvc ??= PlaylistService(data)).toggleFavorite(
      cur.id,
      nowMs: _nowMs(),
    );
    await engine.updateMediaSession(MediaSessionInfo(
      title: cur.title,
      artist: cur.artistDisplay,
      durationMs: cur.durationMs > 0 ? cur.durationMs : null,
      favorite: added,
    ));
  }

  /// 页面红心切换后回写媒体会话（REQ-PL-01 通知面一致性）。
  Future<void> notifyFavoriteChanged(int trackId, bool favorite) async {
    if (_sessionTrackId != trackId) {
      return;
    }
    final cur = snapshot.currentTrack;
    if (cur == null) {
      return;
    }
    await engine.updateMediaSession(MediaSessionInfo(
      title: cur.title,
      artist: cur.artistDisplay,
      durationMs: cur.durationMs > 0 ? cur.durationMs : null,
      favorite: favorite,
    ));
  }

  void _onItemEnded(int qi) {
    if (qi < 0 || qi >= _queue.length) {
      return;
    }
    final item = _queue[qi];
    _histAdd(trackId: item.id, completed: true); // 自然 EOF=完成播放
    if (qi + 1 < _queue.length) {
      _current = qi + 1;
      _positionMs = 0;
      unawaited(_persistSession());
      unawaited(_histMaybeFlush());
    } else {
      // 末条 park=一轮播完 → 模式化路由（随机=池重采样新轮；列表循环=同队重播；
      // 单曲=同位重播；顺序=停驻）——REQ-PLAY-03 行为分岔
      unawaited(_roundTail());
    }
    _push();
  }

  void _onEngineFailure(ContractException cause) {
    if (cause is EngineCapabilityException) {
      return; // 能力线（S3=明示不支持）不该经事件面——防御吞掉
    }
    final failed = _current < _queue.length ? _queue[_current] : null;
    unawaited(_advanceAfterFailure(failed));
  }

  Future<void> _advanceAfterFailure(TrackLite? failed) async {
    // 真实 fs 判定（不靠异常文本猜原因）：缺失→missing_at 补写+提示；
    // 在位→损坏/格式线提示（REQ-PLAY-08 原话 / 播放页四态原话）
    if (failed != null) {
      final exists = await File(failed.path).exists();
      final row = await data.library.rowById(failed.id);
      final rowMissing = row?.missingAt != null;
      if (!exists || rowMissing) {
        if (!exists) {
          await data.library.markMissing(failed.id, _nowMs());
        }
        _notify(PlaybackNotice(
          PlaybackNoticeKind.missingSkip,
          msg.missingSkipped(failed.title),
        ));
      } else {
        _notify(PlaybackNotice(
          PlaybackNoticeKind.corruptSkip,
          msg.corruptSkipped(failed.title),
        ));
      }
      _histAdd(trackId: failed.id, completed: false); // 该曲不写完成播放历史
      await flushHistory();
    }
    if (_current + 1 < _queue.length) {
      _current = _current + 1; // L3：引擎已自动推进下一曲——镜像对齐即可
      _positionMs = 0;
      await _persistSession();
      _push();
    } else {
      await _roundTail(); // 失败于末条=一轮收口 → 模式化路由（同 _onItemEnded）
    }
  }

  /// 恢复线（ARCH §3.2 / DETAIL §3.6）：EngineSessionLost → restore 重试 1 次
  /// → 二次失败「播放服务异常」（禁无限重试）。
  void _onSessionLost() {
    unawaited(_recoverOnce());
  }

  Future<void> _recoverOnce() async {
    if (_recovering || _disposed) {
      return;
    }
    _recovering = true;
    try {
      final snap = SessionSnapshot(
        items: List.of(_queue),
        startIndex: _current,
        positionMs: _positionMs,
      );
      await engine.restore(snap);
      _recoverTries++;
    } on Object {
      if (_recoverTries >= 1) {
        _notify(PlaybackNotice(
          PlaybackNoticeKind.serviceBroken,
          msg.serviceBrokenNotice,
        ));
        _playing = false;
        _push();
      } else {
        _recoverTries++;
        unawaited(_recoverRetry());
      }
    } finally {
      _recovering = false;
    }
  }

  Future<void> _recoverRetry() async {
    if (_recovering || _disposed) {
      return;
    }
    _recovering = true;
    try {
      await engine.restore(SessionSnapshot(
        items: List.of(_queue),
        startIndex: _current,
        positionMs: _positionMs,
      ));
    } on Object {
      _notify(PlaybackNotice(
        PlaybackNoticeKind.serviceBroken,
        msg.serviceBrokenNotice,
      ));
      _playing = false;
      _push();
    } finally {
      _recovering = false;
    }
  }

  Future<void> _applyEmptyOrReload() async {
    if (_disposed) {
      return; // 终态竞态吞（unawaited 侧链不外溢 zone 错误）
    }
    final lite = await sampleRound();
    if (lite.isEmpty) {
      _playing = false;
      _notify(PlaybackNotice(
        PlaybackNoticeKind.emptyPool,
        msg.emptyPoolForShuffle,
      ));
      _push();
      return;
    }
    _queue
      ..clear()
      ..addAll(lite);
    _current = 0;
    _positionMs = 0;
    try {
      await engine.loadAndPlay(QueueSnapshot(items: _queue, startIndex: 0), 0);
    } on Object {
      if (_disposed) {
        return; // dispose 竞态——引擎已不可控，静默收尾
      }
      rethrow;
    }
    await _persistSession();
    _push();
  }

  // ── 历史（延迟合并写 D9-3 接线）───────────────────────────

  void _histAdd({required int trackId, required bool completed}) {
    _histBuffer.add((
      trackId: trackId,
      completed: completed,
      playedAtMs: _nowMs(),
    ));
  }

  Future<void> _histMaybeFlush() async {
    if (_histBuffer.length >= historyFlushThreshold) {
      await flushHistory();
    }
  }

  /// 手动冲（测试 seam / 终止前行动力）。
  Future<void> flushHistory() async {
    if (_histBuffer.isEmpty) {
      return;
    }
    final batch = List.of(_histBuffer);
    _histBuffer.clear();
    await data.history.recordBatch([
      for (final r in batch)
        (
          trackId: r.trackId,
          completed: r.completed,
          playedAtMs: r.playedAtMs,
          deviceId: deviceId,
        ),
    ]);
    // 500 淘汰（D9-3）：批量落库后触发；批 100/事务内聚 HistoryDao
    await data.history.pruneToCap();
  }

  // ── 会话轻持久（DoD5：kill 后恢复）───────────────────────

  Future<void> _persistSession() async {
    if (_disposed || _queue.isEmpty) {
      return;
    }
    final encoded = jsonEncode({
      'items': [
        for (final t in _queue)
          {
            'id': t.id,
            'path': t.path,
            'title': t.title,
            'artist': t.artistDisplay,
            'durationMs': t.durationMs,
          },
      ],
      'index': _current,
      'pos': _positionMs,
    });
    await data.shell.put(sessionKey, encoded, nowMs: _nowMs());
  }

  /// 冷启动恢复（S9 壳层调用；DoD5 行动面）。
  Future<bool> restoreFromDisk() async {
    _requireAlive();
    final raw = await data.shell.value(sessionKey);
    if (raw == null) {
      return false;
    }
    final snap = decodeSessionJson(raw);
    if (snap == null) {
      return false; // 残损/异构快照 → 视作无会话（冷启动兜底，不复活错误态）
    }
    // 镜像回填**先于**引擎恢复：事件路由（游标/记账/快照面）全程有三域一致口径
    _queue
      ..clear()
      ..addAll(snap.items);
    _current = snap.startIndex.clamp(0, snap.items.isEmpty ? 0 : snap.items.length - 1);
    _positionMs = snap.positionMs;
    _push();
    try {
      await engine.restore(snap);
      return true;
    } on Object {
      // §4.3 重试 1 次（双态允许 adapter 切换；S3 单态——同一入口再试一次）
      try {
        await engine.restore(snap);
        return true;
      } on Object {
        _notify(PlaybackNotice(
          PlaybackNoticeKind.serviceBroken,
          msg.serviceBrokenNotice,
        ));
        return false;
      }
    }
  }

  /// 会话 JSON → 快照（自检防线：非法/异构=null）。
  static SessionSnapshot? decodeSessionJson(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map<String, Object?> ||
          m['items'] is! List ||
          m['index'] is! int ||
          m['pos'] is! int) {
        return null;
      }
      final items = <TrackLite>[];
      for (final it in (m['items'] as List<Object?>)) {
        if (it is Map<String, Object?> &&
            it['id'] is int &&
            it['path'] is String &&
            it['title'] is String &&
            it['artist'] is String &&
            it['durationMs'] is int) {
          items.add(TrackLite(
            id: it['id'] as int,
            path: it['path'] as String,
            title: it['title'] as String,
            artistDisplay: it['artist'] as String,
            durationMs: it['durationMs'] as int,
          ));
        } else {
          return null;
        }
      }
      return SessionSnapshot(
        items: items,
        startIndex: m['index'] as int,
        positionMs: m['pos'] as int,
      );
    } on Object {
      return null;
    }
  }

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  // ── 资源全净释放（§4.3：引擎句柄/桥/通知 + 历史冲 + 会话落库）─

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
    try {
      await flushHistory();
    } on Object {
      // 引擎已不可控时终态冲失败：缓冲保持内存残留=进程将退，不复发
    }
    await engine.dispose();
    await _status.close();
    await _notices.close();
  }
}
