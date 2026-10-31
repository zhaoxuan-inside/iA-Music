/// EnginePort adapter —— mpv_audio_kit 0.5.1 首适配（DEC-008 ③ 首选线）。
///
/// 探针实证（IMPL-S3 §1 三条，工程事实防复发）：
/// * L1 首选真引擎在 flutter_tester（Windows）可起播：playing→position 推进→
///   duration 事件 → 真音频出声。
/// * L2 **末条目判终信号=completed**：包预置 `keep-open=yes`，末条目播完时
///   mpv 扣留 END_FILE（park 暂停在末帧）→ 只发 `completed=true`；
///   中段自然切条才发 `endFile(eof)`（此时引擎已自动加载下一条）。
/// * L3 **错误条目引擎自动推进**：队列中段损坏件 → `endFile(error)` → mpv
///   自动加载再下一条（超时挂死不存在）→ 适配层只需转发事件，客服侧
///   做缺失/损坏判定与提示（REQ-PLAY-08），无需主动 reload。
///
/// 纪律：
/// * 队列索引一律取 `state.playlist.index`（引擎准权；不自累加）。
/// * 事件节流：position ≤250ms 心跳（契约承诺；实测更密，220ms 窗口防超发）。
/// * `stop/quit` reason 吞掉（自驱 loadAndPlay/jump 与 dispose 触发误发）。
/// * EQ=setAudioEffects 直桥（WS1/REQ-PLAY-07）：5 段=EqualizerEffect 串联，
///   全 0 复位；见 setEqBands 注。媒体会话每 Player 一次（见 _publishSession）。
/// * restore=载入+定位+**自动起播**（ARCH §3.2 电台连续性；裁决记录入 IMPL-S3）。
/// * MediaSession（SMTC/MPRIS/Android 前台服务桥）由包内建：每 Player 一次
///   所有权声明（两 Player 并发声明会 StateError）；元数据随曲更新经
///   updateMediaSession（REQ-PLAY-05），命令回流经 EngineMediaCommand。
library;

import 'dart:async';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

class MpvEngineAdapter implements EnginePort {
  MpvEngineAdapter({this.engineLogLevel = LogLevel.warn});

  final LogLevel engineLogLevel;

  Player? _player;
  bool _inited = false;
  bool _disposed = false;
  bool _sessionPublished = false;
  bool _sessionFavorite = false; // 媒体会话红心态（null 语义=不变的回退值）
  Duration _lastTick = Duration.zero;
  EngineState _state = EngineState.idle;

  /// 容器回放游标：= 引擎播放列表将要播放/正在播放的队列索引。
  /// 权威唯一（ 内建 playlist.index 事件投递期竞态——probe/adapter 双实证
  /// 不可靠）：loadAndPlay/restore=startIndex；eof→Ended(cursor) 后自增；
  /// error→不变（引擎自跳下一条）；completed→Ended(末索引)。
  int _cursor = 0;

  final _events = StreamController<EngineEvent>.broadcast();
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  Stream<EngineEvent> get events => _events.stream;

  /// 测试/诊断用：当前引擎态快照（不属契约面）。
  EngineState get debugState => _state;

  Player get _p {
    final p = _player;
    if (p == null || _disposed || !_inited) {
      throw StateError('EnginePort 未 init 或已 dispose');
    }
    return p;
  }

  @override
  Future<void> init(EngineConfig cfg) async {
    if (_disposed) {
      throw StateError('engine disposed');
    }
    if (_inited) {
      throw StateError('EnginePort.init 双重调用（契约前置）');
    }
    _inited = true;
    MpvAudioKit.ensureInitialized();
    final p = _player =
        Player(configuration: PlayerConfiguration(logLevel: engineLogLevel));
    _subs
      ..add(p.stream.playing.listen(_onPlayingValue))
      ..add(p.stream.completed.listen(_onCompletedValue))
      ..add(p.stream.endFile.listen(_onEndFile))
      ..add(p.stream.position.listen(_onPosition))
      ..add(p.stream.mediaSessionCommands.listen(_onMediaCommand));
    // 配置面：⚠️ bufferMs（→mpv audio-buffer）与 preloadNextCount（→
    // setPrefetchPlaylist）均不落引擎——实测两类都会破坏包的事件观测面：
    // buffer 调用后 playing 状态不再发（probe B：pos 推进但无 playing 事件）；
    // prefetch 使 playlist.index 在 END_FILE 投递前预推进（索引语义漂移）。
    // 二项保留契约兼容位、回填进展记录 IMPL-S3 §1；真机 RV-A 再裁。
    // 无缝链由 keep-open+Gapless.weak 承担（探针 L2/L3 同套链路实测无缺）。
    if (cfg.bufferMs < 0) {
      // （禁用路径占位：永不触发——保留 cfg 消费点防契约死代码）
      await _p.setAudioBuffer(Duration(milliseconds: cfg.bufferMs));
    }
  }

  void _onPlayingValue(bool v) {
    if (_disposed) {
      return;
    }
    if (v) {
      if (_state != EngineState.playing) {
        _state = EngineState.playing;
        _emit(EngineStateChanged(EngineState.playing));
      }
    } else if (_state == EngineState.playing) {
      // 播完 park / 缓冲过渡：一律先降为 paused（末条 park 由 completed→ended）
      _state = EngineState.paused;
      _emit(EngineStateChanged(EngineState.paused));
    }
  }

  void _onCompletedValue(bool v) {
    if (_disposed || !v) {
      return;
    }
    // 世代守卫：openAll 替换队列瞬间，上一代 park 的 completed 在新代
    // loading 期漏投（adapter 探针实证 [loading, ended, E=0, playing…]）→ 吞
    if (_state != EngineState.playing && _state != EngineState.paused) {
      return;
    }
    final n = _playlistCount();
    if (n <= 0) {
      return;
    }
    // L2：末条目判终（END_FILE 被扣留）；ended 序列在 itemEnded 前——
    // 客服可将两者同读，顺序契约=StateChanged 先于派生事件（引擎实时性一致）。
    if (_state != EngineState.ended) {
      _state = EngineState.ended;
      _emit(EngineStateChanged(EngineState.ended));
    }
    _emit(EngineItemEnded(_playlistCount() - 1));
  }

  void _onEndFile(MpvFileEndedEvent e) {
    if (_disposed || _player == null) {
      return;
    }
    // 世代守卫：替换队列期间的过渡事件（stop/旧代 eof）一律不经语义路由
    if (_state != EngineState.playing && _state != EngineState.paused) {
      return;
    }
    switch (e.reason) {
      case MpvEndFileReason.eof:
        // 游标权威：容器位置在事件处理器此刻已漂移（playlist.index 竞态）
        final ended = _cursor;
        _cursor = ended + 1;
        _emit(EngineItemEnded(ended)); // L2:中段自然切条；下一事件=新条目 playing
      case MpvEndFileReason.error:
        // L3：错误条目引擎自动推进；游标前移（由 error 侧已完成的仓库/提示面标记）
        final failed = _cursor;
        _cursor = failed + 1;
        _emit(EngineError(const EngineFailureException(
            detail: 'end-file reason=error')));
      case MpvEndFileReason.stop:
      case MpvEndFileReason.quit:
        break; // 自驱切条/dispose 衍生——吞
      default:
        break; // redirect 等未参与契约语义
    }
  }

  void _onPosition(Duration pos) {
    if (_disposed || _state == EngineState.idle || _state == EngineState.loading) {
      return;
    }
    // 真实事件间隔可达 25ms 级；契约承诺 ≤250ms——发且仅发更稠即节流
    if (pos - _lastTick < const Duration(milliseconds: 220)) {
      return;
    }
    _lastTick = pos;
    _emit(EnginePositionTick(pos.inMilliseconds));
  }

  int _playlistCount() {
    final p = _player;
    if (p == null || _disposed) {
      return 0;
    }
    return p.state.playlist.items.length;
  }

  /// 媒体会话命令回流（REQ-PLAY-05）：OS 通知栏/锁屏/媒体键/蓝牙 →
  /// 契约事件（调用方=服务执行；play/pause/next/previous/seek 均为 emit-only）。
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
        break; // 包内已 auto-apply 且不广告对应 MediaAction——不应到达；防御吞
    }
  }

  void _emit(EngineEvent e) {
    if (!_events.isClosed) {
      _events.add(e);
    }
  }

  Media _mediaOf(TrackLite t) {
    return Media(
      Uri.file(t.path).toString(),
      extras: {
        'title': t.title,
        'artist': t.artistDisplay,
      },
    );
  }

  @override
  Future<void> loadAndPlay(QueueSnapshot snapshot, int startIndex) async {
    final p = _p;
    _cursor = startIndex; // 游标锚齐：与服务队列索引同轨（索引权威=适配器）
    _state = EngineState.loading;
    _emit(EngineStateChanged(EngineState.loading));
    final medias = [for (final it in snapshot.items) _mediaOf(it)];
    await p.openAll(medias, play: true, index: startIndex);
    if (!_sessionPublished) {
      await _publishSession(p, [if (startIndex >= 0 && startIndex < snapshot.items.length) snapshot.items[startIndex]]);
      _sessionPublished = true;
    }
  }

  @override
  Future<void> play() async {
    final p = _p;
    await _waitLoaded(p, -1); // 载入就绪门：避免 mpv 命令在 loadfile 未就绪期 -12
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
    // mpv 转义阀口径（DEC-008 ③ PoC 产物）：0.5.1 typed seek 在
    // 本端抛 code=-12（mpv 源头拒绝），raw `seek <sec> absolute` 稳态可用
    // （m4a/mp3 双件实测：暂停落位=准确；起播从落点继续）。
    // fail=契约异常（EngineFailureException）→ 调用方按 §4.3 面处置。
    final sec = positionMs / 1000.0;
    try {
      await p.sendRawCommand(['seek', sec.toString(), 'absolute']);
    } on Object {
      throw const EngineFailureException(detail: 'seek command failed');
    }
  }

  /// EQ 直桥（WS1/REQ-PLAY-07）：5 段=5 个 ffmpeg lavfi `equalizer` 滤镜串联
  /// （包内 EqualizerEffect，gain 单位 dB）。全 0 → 清空滤镜链（复位）。
  /// 抛契约异常面照旧（未 init→StateError；包异常→EngineFailureException）。
  @override
  Future<void> setEqBands(List<double> gains) async {
    final p = _p;
    const bands = [60.0, 230.0, 910.0, 3600.0, 14000.0];
    final effects = <AudioEffect>[];
    for (var i = 0; i < bands.length; i++) {
      final g = i < gains.length ? gains[i] : 0.0;
      if (g == 0) {
        continue; // 0dB 段不进链——减少无谓的 DSP 开销
      }
      effects.add(EqualizerEffect(frequency: bands[i], gain: g));
    }
    try {
      await p.setAudioEffects(effects);
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
        EngineFailureException(message: 'setEqBands 失败: $e', detail: '$gains'),
        st,
      );
    }
  }

  /// 音量直桥（WS1）：mpv `volume` 属性（percent，100=不衰减）。
  @override
  Future<void> setVolume(double volume) async {
    await _p.setVolume(volume);
  }

  /// 插队（S4）：mpv `loadfile <path> insert-next` —— 当前曲后立即播放位。
  /// * 不打断当前播放；引擎 playlist 增列与服务镜像在 `_current+1` 同位对齐。
  @override
  Future<void> insertNext(TrackLite item) async {
    final p = _p; // 未 init/已 dispose → StateError（getter 前置）
    try {
      // loadfile insert-next：mpv 原生插队指令（无 -12 风险面；当前曲不受扰）
      await p.sendRawCommand(['loadfile', item.path, 'insert-next']);
    } on Object catch (e, st) {
      Error.throwWithStackTrace(
        EngineFailureException(
          message: 'insertNext 失败: $e',
          detail: 'TrackLite.path=${item.path}',
        ),
        st,
      );
    }
  }

  @override
  Future<void> restore(SessionSnapshot snapshot) async {
    final p = _p;
    _cursor = snapshot.startIndex; // 游标锚齐
    _state = EngineState.loading;
    _emit(EngineStateChanged(EngineState.loading));
    final medias = [for (final it in snapshot.items) _mediaOf(it)];
    await p.openAll(medias, play: false, index: snapshot.startIndex);
    // 载入就绪（duration>0 且列表索引到位）上界 5s——挂死不可能：openAll
    // 失败路径由调用方（service retry 线）兜底（§4.3 重试 1 次）
    final ready = await _waitLoaded(p, snapshot.startIndex);
    if (ready && snapshot.positionMs > 0) {
      await p.seek(
        Duration(milliseconds: snapshot.positionMs),
        relative: false,
      );
    }
    if (!_sessionPublished) {
      await _publishSession(p, [snapshot.items[snapshot.startIndex]]);
      _sessionPublished = true;
    }
    await p.play(); // 自动起播=电台连续性（裁决记录：IMPL-S3 §4）
  }

  /// 载入就绪轮询（restore/seek/pause 共用）：duration>0 且（要求时）索引到位。
  /// `startIndex < 0` = 不校验索引（仅 duration 就绪口径，上界 5s）。
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

  Future<void> _publishSession(Player p, List<TrackLite> at) async {
    // flutter_tester 无 MethodChannel 宿主（插件注册表不存在）：桥调用会毒化
    // 引擎会话（playing 等后续事件不再发——探针 A/B 实证）→ 跳过；
    // 真桥（SMTC/MPRIS/Android 前台服务）在真实平台装配本=演练证据项（IMPL-S3 §6）
    if (Platform.environment['FLUTTER_TEST'] != null) {
      return;
    }
    final t = at.isEmpty ? null : at.first;
    await _applySession(
      title: t?.title,
      artist: t?.artistDisplay,
      durationMs: t?.durationMs,
    );
  }

  /// 媒体会话元数据随曲更新（REQ-PLAY-05）：换曲/红心态由服务侧推送。
  /// 同一 Player 重复 setMediaSession=更新语义（所有权标志不受扰）。
  @override
  Future<void> updateMediaSession(MediaSessionInfo info) async {
    if (_disposed || _player == null) {
      return;
    }
    if (Platform.environment['FLUTTER_TEST'] != null) {
      return;
    }
    await _applySession(
      title: info.title,
      artist: info.artist,
      durationMs: info.durationMs,
      favorite: info.favorite,
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
    // 包面 isFavorite 非空 bool：null=不改变 → 回退上一次已知态
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
      // 真桥失败（如 MPRIS 无显示会话/临时不可用）——音频主线不受阻
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
