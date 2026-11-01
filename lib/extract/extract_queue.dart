/// ExtractQueue —— DETAILED-DESIGN §3.2 方法 + §4.2 任务机（REQ-EXT-01..08）。
///
/// 语义锚：
/// * 前置门禁：`settings['compliance.acknowledged_at']` 非空才可执行下载
///   （REQ-ONB-03/EXT-07；未确认 → enqueue 抛状态门禁错，UI 引导确认声明）。
/// * dup：extract_tasks UNIQUE(source_type,source_id) **+** tracks.source 双保险
///   （REQ-EXT-06+DEC-002；skip→本行终态 dup；re-extract → 复位 resolved 重跑）。
/// * 不变量：产物先私有 staging 目录后注册；注册失败 → 产物 quarantine 隔离，
///   不影响曲库（§3.2 后置红线）。
/// * 重试：网络类指数退避 1s/4s/16s ≤3 次/任务（§4.3）；auth/transcode 不自动。
/// * 串行：同一时刻至多一个活动下载（EXT-04；页面离开不中断=服务级循环）。
/// * 歌词联动：注册成功后追加 lyrics_gen_jobs queued（EXT-08；`withLyrics`
///   在会话内持账——schema 无此列，§3.2 后置形态）。
/// * Cookie：cookiesRefKey 只携 SecureStore key；值只走 DownloaderAdapter 的
///   临时文件消费（C50：值不进 drift/日志）。
library;

import 'dart:async';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:drift/drift.dart';
import 'package:ia_music/adapters/asr_adapter.dart';
import 'package:ia_music/adapters/netease_lyric_search.dart';
import 'package:ia_music/adapters/downloader_adapter.dart';
import 'package:ia_music/adapters/metadata_adapter.dart';
import 'package:ia_music/adapters/subtitle_adapter.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/extract/audio_split.dart';
import 'package:ia_music/lyrics/lyrics_service.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:path_provider/path_provider.dart';

/// staging 根（T9A）：Windows=`<系统临时>/ia_extract`（与既有契约/测试面一致）；
/// Android=`cacheDir/ia_extract`（`Directory.systemTemp` 在 Android=/data/local/tmp，
/// 应用不可写——T9A 实测修正；确定性语义不变：同一任务跨 pause/resume 同一路径）。
Future<String> stagingRoot() async {
  if (Platform.isAndroid) {
    final t = await getTemporaryDirectory();
    return '${t.path}/ia_extract';
  }
  return '${Directory.systemTemp.path}/ia_extract';
}

sealed class ExtractQueueEvent {
  const ExtractQueueEvent(this.taskId);
  final int taskId;
}

/// 字幕侧队列任务单元（task 行 + 注册后的音频绝对路径）。
final class _SubsJob {
  const _SubsJob(this.task, this.audioPath);
  final ExtractTask task;
  final String audioPath;
}

/// 任务机逐态（UI 状态列表消费）。
final class ExtractStateChanged extends ExtractQueueEvent {
  const ExtractStateChanged(super.taskId, this.status, {this.message});
  final ExtractTaskStatus status;

  /// 人话信息（失败清单/Toast 附属文案）。
  final String? message;
}

/// 进度（0..100；任务行 progress_pct 同步）。
final class ExtractProgress extends ExtractQueueEvent {
  const ExtractProgress(super.taskId, this.percent);
  final double percent;
}

/// Toast 载体（PRD：「《X》已加入曲库」；trackId 可直通沉浸面）。
final class ExtractRegistered extends ExtractQueueEvent {
  const ExtractRegistered(super.taskId, this.trackId, this.title);
  final int trackId;
  final String title;
}

enum _Terminal { done, paused, failed }

/// extract_tasks.quality（TaskQuality）→ DownloaderPort.quality（Quality）同族映射。
Quality _qualityOf(TaskQuality q) {
  switch (q) {
    case TaskQuality.k64:
      return Quality.k64;
    case TaskQuality.k128:
      return Quality.k128;
    case TaskQuality.k192:
      return Quality.k192;
    case TaskQuality.hires:
      return Quality.hires;
  }
}

class ExtractQueue {
  ExtractQueue(
      {required IaDatabase db,
      required DownloaderPort downloader,
      this.hasLoginCookies,
      SubtitleAdapter? subtitles,
    this.onTrackEnriched,
  })
      : subtitles = subtitles ?? (Platform.isAndroid ? null : SubtitleAdapter()),
        _db = db,
        _down = downloader,
        _lib = DataAccess(db).library,
        _extract = DataAccess(db).extract,
        _lyrics = DataAccess(db).lyrics,
        _shell = DataAccess(db).shell {
    _events = StreamController.broadcast();
    _sub = _down.stream.listen(_onDownEvent);
  }

  final IaDatabase _db;
  final DownloaderPort _down;
  final LibraryDao _lib;
  final ExtractDao _extract;
  final LyricsDao _lyrics;
  final ShellDao _shell;

  /// 歌词反查命中回调（组合根注入：revision bump + 封面重取）。
  final void Function(int trackId)? onTrackEnriched;

  /// 登录 Cookie 门（组合根注入；true=任务与解析携 kCookieKey）。
  final Future<bool> Function()? hasLoginCookies;

  /// 字幕文本提取器（桌面 Process 形态；Android=null=诚实降级无该选项）。
  final SubtitleAdapter? subtitles;

  /// 登录态查询（门缺省=false；门异常按未登录）。
  Future<bool> _resolveLoginCookies() async {
    final gate = hasLoginCookies;
    if (gate == null) {
      return false;
    }
    try {
      return await gate();
    } on Exception {
      return false;
    }
  }

  /// 歌词补全服务（2026-10-25 单级链路：ASR → 歌词正文反查 → 网易补全；
  /// LRCLIB 标题匹配已按用户裁决移除；模型目录由 model_registry 解析）。
  late final LyricsService lyrics = LyricsService(
    _db,
    _lyrics,
    asr: Platform.isAndroid ? null : const AsrAdapter(),
    modelDirResolver: _presentModelDir,
    textSearch: Platform.isAndroid ? null : NetEaseLyricSearch(),
    onTrackEnriched: onTrackEnriched,
  );

  /// model_registry → present 模型的 local_path（无 present 行=null）。
  Future<String?> _presentModelDir() async {
    final rows = await (_db.select(_db.modelRegistry)
          ..where((m) => m.status.equalsValue(ModelStatus.present)))
        .get();
    for (final r in rows) {
      if ((r.localPath ?? '').isNotEmpty && r.modelId.contains('sensevoice')) {
        return r.localPath;
      }
    }
    return null;
  }

  late final StreamController<ExtractQueueEvent> _events;
  Stream<ExtractQueueEvent> get events => _events.stream;

  late final StreamSubscription<TaskEvent> _sub;

  /// 合规键（值=确认时刻 ISO8601）。
  static const String kComplianceKey = 'compliance.acknowledged_at';

  /// B 站 Cookie 的 SecureStore 键（登录高音质；C50 唯一进出）。
  static const String kCookieKey = 'bilibili.cookies';

  /// PRD §3：默认 仓库/提取/ 子目录（settings 可改位=M9 面板；S6 默认位）。
  static const String kExtractRelDir = '提取';

  Future<bool> isComplianceAcknowledged() async =>
      (await _shell.value(kComplianceKey)) != null;

  Future<void> acknowledgeCompliance({required DateTime at}) => _shell.put(
        kComplianceKey,
        at.toIso8601String(),
        nowMs: at.millisecondsSinceEpoch,
      );

  /// 解析分享文本 → ResolvedMeta 列表（多行多链接逐条拆；单链接多 P/合集由
  /// `resolveAll` 拆成条目集——开发裁决 2026-10-19「歌曲合计拆分成多个单独的歌曲」；
  /// ≤5s 逐条=adapter 时限，flat 枚举不逐页取详情）。
  /// 登录态在池 → 解析携 Cookie（音质枚举随登录态真实变化，REQ-EXT-01）。
  Future<List<ResolvedMeta>> parseLinkText(String linkText) async {
    final useCookies = await _resolveLoginCookies();
    final metas = <ResolvedMeta>[];
    for (final line in linkText.split(RegExp(r'\s+'))) {
      if (extractFirstUrl(line) == null) {
        continue;
      }
      metas.addAll(await _down.resolveAll(line,
          cookiesRefKey: useCookies ? kCookieKey : null));
    }
    return metas;
  }

  /// 入队（合规/重复双门禁；返回 (任务行, isDup)）。
  ///
  /// dup=终态行（UI「这首歌已在曲库中」+重新提取/跳过）。
  /// 内容可选面（REQ-EXT，2026-10-24）：`withText`=字幕→LRC；`withVideo`=
  /// 视频落盘不入库（Android 形态无此选项）。登录 Cookie 在池自动随任务。
  Future<(ExtractTask, bool)> enqueue(
    ResolvedMeta meta, {
    required TaskQuality quality,
    bool withLyrics = false,
    bool withText = false,
    bool withVideo = false,
    required int nowMs,
  }) async {
    if (!await isComplianceAcknowledged()) {
      throw StateError('compliance not acknowledged'); // 门禁 RED（引导页）
    }
    final useCookies = await _resolveLoginCookies();
    final (task, isNew) = await _extract.createOrGet(
      sourceType: meta.sourceType,
      sourceId: meta.sourceId,
      url: meta.url,
      quality: quality,
      cookiesUsed: useCookies,
      nowMs: nowMs,
    );
    if (!isNew) {
      switch (task.status) {
        case ExtractTaskStatus.registered:
          // 库内已有同源 → dup 终态（行不被覆盖；REQ-EXT-06）
          return (await _markDupTask(task.id), true);
        case ExtractTaskStatus.dup:
          return (await _getTask(task.id), true); // 仍终态（或由 reEnqueue 显式重跑）
        default:
          break; // failed/paused/resolved → 继续（可能跳回 resolved 重跑）
      }
    }
    {
      final live = await (_db.select(_db.tracks)
            ..where((t) =>
                t.sourceType.equals(meta.sourceType) &
                t.sourceId.equals(meta.sourceId) &
                t.deletedAt.isNull()))
          .getSingleOrNull();
      if (live != null) {
        return (await _markDupTask(task.id), true);
      }
    }
    await _extract.updateTask(task.id,
        status: ExtractTaskStatus.resolved,
        title: meta.title,
        uploader: meta.uploader,
        durationMs: meta.durationMs,
        errorCode: null);
    if (withLyrics) {
      _lyricsWanted[task.id] = true; // EXT-08 注册后跳入 lyrics 排队
    }
    if (withText) {
      _textWanted[task.id] = true; // 字幕→LRC（注册后侧队列）
    }
    if (withVideo) {
      _videoWanted[task.id] = true; // 视频落盘不入库（下载分支路由）
    }
    if ((meta.coverUrl ?? '').isNotEmpty) {
      _taskCoverUrl[task.id] = meta.coverUrl!; // D12-4③ 拆分段封面源
    }
    _pump();
    return (await _getTask(task.id), false);
  }

  /// 重新提取（dup/failed 行复位重跑；REQ-EXT-06 分支）。
  Future<ExtractTask> reEnqueue(int taskId) async {
    await _extract.updateTask(taskId,
        status: ExtractTaskStatus.resolved, errorCode: null, progressPct: 0.0);
    _pump();
    return _getTask(taskId);
  }

  /// 快捷入队（2026-10-25 交互重构：点击=瞬间入队，元数据由队列消费端补全）。
  ///
  /// 此前快捷提取先同步跑一次 yt-dlp 解析（2-8s 无反馈）才入队——现在：
  /// * B 站视频 URL → 本地派生 sourceId（零网络）→ 立即建行 + `_pump()`，
  ///   标题/时长可用搜索结果预填（[title]/[durationMs]）；解析并入消费端；
  /// * 非 B 站形态（b23.tv 短链）→ 回退旧路径（解析后入队，≤5s）。
  Future<(ExtractTask, bool)> enqueueUrl(
    String rawUrl, {
    required TaskQuality quality,
    bool withLyrics = false,
    bool withText = false,
    bool withVideo = false,
    String? title,
    int? durationMs,
    required int nowMs,
  }) async {
    if (!await isComplianceAcknowledged()) {
      throw StateError('compliance not acknowledged');
    }
    final useCookies = await _resolveLoginCookies();
    final sourceId = bilibiliSourceIdOf(rawUrl);
    if (sourceId == null) {
      // 短链/异构形态：先解析再入队（旧行为）
      final metas =
          await _down.resolveAll(rawUrl, cookiesRefKey: useCookies ? kCookieKey : null);
      (ExtractTask, bool)? first;
      for (final m in metas) {
        first = await enqueue(m,
            quality: quality,
            withLyrics: withLyrics,
            withText: withText,
            withVideo: withVideo,
            nowMs: nowMs);
      }
      return first ?? (throw FormatException(msg.noContentInLink));
    }
    final url = extractFirstUrl(rawUrl) ?? rawUrl;
    final (task, isNew) = await _extract.createOrGet(
      sourceType: 'bilibili',
      sourceId: sourceId,
      url: url,
      quality: quality,
      cookiesUsed: useCookies,
      nowMs: nowMs,
    );
    if (!isNew) {
      switch (task.status) {
        case ExtractTaskStatus.registered:
          return (await _markDupTask(task.id), true);
        case ExtractTaskStatus.dup:
          return (await _getTask(task.id), true);
        default:
          break;
      }
    }
    {
      final live = await (_db.select(_db.tracks)
            ..where((t) =>
                t.sourceType.equals('bilibili') &
                t.sourceId.equals(sourceId) &
                t.deletedAt.isNull()))
          .getSingleOrNull();
      if (live != null) {
        return (await _markDupTask(task.id), true);
      }
    }
    await _extract.updateTask(task.id,
        status: ExtractTaskStatus.resolved,
        title: title,
        errorCode: null);
    if (withLyrics) {
      _lyricsWanted[task.id] = true;
    }
    if (withText) {
      _textWanted[task.id] = true;
    }
    if (withVideo) {
      _videoWanted[task.id] = true;
    }
    _pump();
    return (await _getTask(task.id), false);
  }

  /// 启动续泵（T9B 拆分收口增量，2026-10-19 实证归因：泵只在 enqueue/reEnqueue
  /// 起步，重启后 resolved 队列遗留无人处理）。合规未确认=不泵（与 enqueue 门禁
  /// 一致）；泵=串行处理登记遗留 resolved 行（EXT-04 语义延续）。
  Future<void> resumeQueued() async {
    if (!await isComplianceAcknowledged()) {
      return;
    }
    _pump();
  }

  /// skip dup（本行终态；dup 已是终态=noop，幂等）。
  Future<void> skipDup(int taskId) async {
    final row = await _getTask(taskId);
    if (row.status != ExtractTaskStatus.registered) {
      return; // dup 行本身即终态
    }
  }

  Future<ExtractTask> _getTask(int id) =>
      (_db.select(_db.extractTasks)..where((t) => t.id.equals(id))).getSingle();

  Future<ExtractTask> _markDupTask(int id) async {
    await _extract.updateTask(id,
        status: ExtractTaskStatus.dup, errorCode: ExtractErrorCode.dup);
    return (_db.select(_db.extractTasks)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// 勾选「同时生成歌词」在会话内持账（schema 无列）。
  final Map<int, bool> _lyricsWanted = {};

  /// 勾选「提取字幕文本」会话内持账（注册后侧队列；schema 无列）。
  final Map<int, bool> _textWanted = {};

  /// 勾选「保存视频文件」会话内持账（下载分支路由；schema 无列）。
  final Map<int, bool> _videoWanted = {};

  // ── 字幕侧队列（不占下载泵；串行） ───────────────────────
  final List<_SubsJob> _subsQueue = [];
  bool _subsRunning = false;

  void _scheduleSubs(ExtractTask task, String audioPath) {
    if (subtitles == null) {
      return;
    }
    _subsQueue.add(_SubsJob(task, audioPath));
    if (!_subsRunning) {
      _subsRunning = true;
      unawaited(_drainSubs());
    }
  }

  Future<void> _drainSubs() async {
    while (_subsQueue.isNotEmpty) {
      final job = _subsQueue.removeAt(0);
      try {
        await _runSubsJob(job);
      } catch (e) {
        // 侧队列永不崩：字幕失败=无文本（不回滚音频注册）；但必须给用户
        // 诚实反馈（此前完全静默=「文字提取能力缺失」的体感来源之一）。
        _emit(job.task.id, ExtractTaskStatus.registered,
            msg.subtitleExtractFailed(
                e is Exception ? e.toString() : msg.unknownError));
      }
    }
    _subsRunning = false;
  }

  Future<void> _runSubsJob(_SubsJob job) async {
    final sub = subtitles;
    if (sub == null) {
      return;
    }
    final staging = Directory(
        '${await stagingRoot()}/subs_${job.task.sourceId}');
    await staging.create(recursive: true);
    try {
      final useCookies = await _resolveLoginCookies();
      final lrc = await sub.fetchLrcText(
        url: job.task.url,
        workDir: staging.path,
        cookiesRefKey: useCookies ? kCookieKey : null,
      );
      if (lrc == null || lrc.trim().isEmpty) {
        // 无字幕（诚实静默产物面，但事件面给人话：AI 字幕需登录是常态原因）
        _emit(job.task.id, ExtractTaskStatus.registered,
            msg.noSubtitleAvailable);
        return;
      }
      final roots = await _lib.rootsSnapshot();
      if (roots.isEmpty) {
        _emit(job.task.id, ExtractTaskStatus.registered,
            msg.subtitleNotSavedNoRepo);
        return;
      }
      final segs = _taskSegments[job.task.id];
      if (segs != null && segs.isNotEmpty) {
        // 拆分任务：全视频 LRC → 按段窗口平移，一段一 LRC（对齐拆分曲）。
        for (final seg in segs) {
          final segLrc = shiftLrc(lrc, seg.startMs, seg.endMs);
          if (segLrc.trim().isEmpty) {
            continue; // 该段窗口内无字幕行=诚实跳过
          }
          await _writeSegmentLrc(roots, seg.audioPath, segLrc, seg.trackId,
              job.task.id);
        }
        _emit(job.task.id, ExtractTaskStatus.registered,
            msg.subtitleSplitSaved(segs.length));
        return;
      }
      // 整轨任务：音频同目录 .lrc（歌词域文件约定，REQ-LYR-03）。
      final relBase =
          job.audioPath.replaceAll('\\', '/').split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
      final rel = '$kExtractRelDir/$relBase.lrc';
      final absPath =
          '${roots.first.path.replaceAll('\\', '/')}/$rel';
      await File(absPath).writeAsString(lrc, flush: true);
      // 查轨行（sourceId 反查）→ lyrics_meta 落账（type=lrc，播放页即读）。
      final track = await (_db.select(_db.tracks)
            ..where((t) =>
                t.sourceType.equals(job.task.sourceType) &
                t.sourceId.equals(job.task.sourceId) &
                t.deletedAt.isNull()))
          .getSingleOrNull();
      if (track != null) {
        await _lyrics.upsertMeta(
          trackId: track.id,
          type: LyricsSourceType.lrc,
          lrcPath: rel,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
      _emit(job.task.id, ExtractTaskStatus.registered,
          msg.subtitleSaved('$relBase.lrc'));
    } finally {
      try {
        await staging.delete(recursive: true);
      } on Exception {
        // OS 临时策略回收兜底
      }
    }
  }

  /// 段 LRC 落账（拆分任务字幕链）：段音频同目录 .lrc + lyrics_meta 对段轨。
  Future<void> _writeSegmentLrc(
    List<RepositoryRoot> roots,
    String segAudioPath,
    String lrc,
    int trackId,
    int taskId,
  ) async {
    final relBase = segAudioPath
        .replaceAll('\\', '/')
        .split('/')
        .last
        .replaceAll(RegExp(r'\.[^.]+$'), '');
    final rel = '$kExtractRelDir/$relBase.lrc';
    final absPath = '${roots.first.path.replaceAll('\\', '/')}/$rel';
    await File(absPath).writeAsString(lrc, flush: true);
    await _lyrics.upsertMeta(
      trackId: trackId,
      type: LyricsSourceType.lrc,
      lrcPath: rel,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ── 串行任务泵 ───────────────────────────────────────────

  bool _pumping = false;
  TaskHandle? _currentHandle;
  int? _currentTaskId;
  int _lastPct = 0;
  String? _lastStagedPath;

  void _pump() {
    if (_pumping) {
      return;
    }
    _pumping = true;
    unawaited(_runLoop());
  }

  Future<void> _runLoop() async {
    _pumping = true;
    try {
      while (_pumping) {
        // 拆分语义（2026-10-19）：resolved 可为多条（多 P/合集一次入队 N 条）——
        // 单任务时代的 getSingleOrNull 会被 ≥2 行炸泵（Too many elements 实录）。
        // 取 id 最小的一条；limit(1) 由库侧保证行数，泵=严格串行。
        final rows = await (_db.select(_db.extractTasks)
              ..where((t) => t.status.equalsValue(ExtractTaskStatus.resolved))
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(1))
            .get();
        final next = rows.isEmpty ? null : rows.first;
        if (next == null) {
          break;
        }
        try {
          await _executeTask(next);
        } catch (e) {
          // 泵循环永不崩（§4.3 无泄漏默认）：终态 FAILED(disk)+staging 清理。
          await _executeTaskSafeFailure(next);
        }
      }
    } finally {
      _pumping = false;
      _currentTaskId = null;
    }
  }

  /// 泵兜底终态（§4.3 无泄漏默认）：FAILED(disk)+产物目录清除（无半成品）。
  Future<void> _executeTaskSafeFailure(ExtractTask task) async {
    try {
      final staging =
          Directory('${await stagingRoot()}/${task.sourceId}');
      if (staging.existsSync()) {
        await staging.delete(recursive: true);
      }
    } on Exception {
      // 占用兜底=下次重试前再清
    }
    await _extract.updateTask(task.id,
        status: ExtractTaskStatus.failed, errorCode: ExtractErrorCode.disk);
    _emit(task.id, ExtractTaskStatus.failed, msg.extractTerminated);
    _currentTaskId = null;
  }

  Future<void> _executeTask(ExtractTask task) async {
    _currentTaskId = task.id;
    final wantVideo = _videoWanted.remove(task.id) == true;

    // ① 目标仓库（默认第一仓库 + 提取/ 子目录；无仓库=配置缺失，不是存储故障
    //    ——独立错误类：重试无意义，UI 引导先添加仓库）。
    final roots = await _lib.rootsSnapshot();
    if (roots.isEmpty) {
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.failed, errorCode: ExtractErrorCode.noRepo);
      _emit(task.id, ExtractTaskStatus.failed, msg.noRepoConfigured);
      return;
    }
    final repo = roots.first;
    final targetDir =
        Directory('${repo.path.replaceAll('\\', '/')}/$kExtractRelDir');
    await targetDir.create(recursive: true);

    // staging 目录=确定性路径（<tmp>/ia_extract/<sourceId>/）——pause 保留 .part，
    // resume/重试自动 --continue 续传；终态 registered/取消/最终失败时清理。
    final stagingBase = Directory(await stagingRoot());
    await stagingBase.create(recursive: true);
    final stagingDir = Directory('${stagingBase.path}/${task.sourceId}');
    await stagingDir.create(recursive: true);

    // ② downloading（进度 0；事件=状态流）。
    await _extract.updateTask(task.id,
        status: ExtractTaskStatus.downloading, progressPct: 0.0);
    _emit(task.id, ExtractTaskStatus.downloading);

    final plan = DownloadPlan(
      sourceId: task.sourceId,
      url: task.url,
      quality: _qualityOf(task.quality),
      outputDir: stagingDir.path,
      cookiesRefKey: task.cookiesUsed ? kCookieKey : null,
      audioOnly: !wantVideo, // REQ-EXT 内容可选：视频=完整封装不入库
    );
    final handle = _down.download(plan);
    _currentHandle = handle;
    final terminal = await _awaitTerminal(handle, task.id);
    _currentHandle = null;
    final finalPath = _lastStagedPath;
    _lastStagedPath = null;

    // ③ 终态路由（§4.2 + §4.3）
    if (terminal == _Terminal.paused || terminal == _Terminal.failed) {
      final row =
          await (_db.select(_db.extractTasks)..where((t) => t.id.equals(task.id)))
              .getSingleOrNull();
      if (row == null) {
        // 行已被 cancelTask 删除（取消语义）：不重试、不复活
        _currentTaskId = null;
        return;
      }
      final klass = _classifyLastDetail();
      if (terminal == _Terminal.failed &&
          klass == DownloadFailureClass.network &&
          row.retryCount < 3) {
        final delayMs = const [1000, 4000, 16000][row.retryCount.clamp(0, 2)];
        await Future<void>.delayed(Duration(milliseconds: delayMs));
        await _extract.updateTask(task.id,
            status: ExtractTaskStatus.resolved, errorCode: null);
        _currentTaskId = null;
        return; // 泵循环自然取回（staging 目录与 .part 保留=断点续传）
      }
      if (terminal == _Terminal.failed) {
        final human = _human(klass);
        final suffix = _humanDetailSuffix();
        await _extract.updateTask(task.id,
            status: ExtractTaskStatus.failed, errorCode: _errCode(klass));
        _emit(task.id, ExtractTaskStatus.failed,
            suffix == null ? human : '$human$suffix');
      } else {
        await _extract.updateTask(task.id,
            status: ExtractTaskStatus.paused, progressPct: _lastPct.toDouble());
        _emit(task.id, ExtractTaskStatus.paused, msg.downloadPaused);
      }
      if (terminal == _Terminal.failed) {
        // FAILED(network) 入清单，手动重试无遗留半成品（§4.3 分片清理）
        try {
          await stagingDir.delete(recursive: true);
        } on Exception {
          // 占用=下次重试前再清（同类兜底）
        }
      }
      _currentTaskId = null;
      return;
    }

    if (terminal == _Terminal.done &&
        (finalPath == null || !File(finalPath).existsSync())) {
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.failed,
          errorCode: ExtractErrorCode.transcode);
      _emit(task.id, ExtractTaskStatus.failed, msg.transcodeFailed);
      _currentTaskId = null;
      return;
    }

    // ③.5 视频分支（REQ-EXT 内容可选面）：产物落 仓库/提取/视频/，不入曲库。
    if (wantVideo) {
      final videoDir = Directory('${targetDir.path}/视频');
      try {
        await videoDir.create(recursive: true);
      } on FileSystemException {
        await _extract.updateTask(task.id,
            status: ExtractTaskStatus.failed, errorCode: ExtractErrorCode.disk);
        _emit(task.id, ExtractTaskStatus.failed, msg.videoDirNotWritable);
        _currentTaskId = null;
        return;
      }
      final moved = await _moveIntoRepo(finalPath!, videoDir, task);
      if (moved == null) {
        await _extract.updateTask(task.id,
            status: ExtractTaskStatus.failed, errorCode: ExtractErrorCode.disk);
        _emit(task.id, ExtractTaskStatus.failed, msg.videoMoveFailed);
      } else {
        await _extract.updateTask(task.id,
            status: ExtractTaskStatus.registered, outputRelPath: moved);
        _emit(task.id, ExtractTaskStatus.registered, msg.videoSavedNote);
      }
      try {
        await stagingDir.delete(recursive: true);
      } on Exception {
        // 占用兜底
      }
      _currentTaskId = null;
      return;
    }

    // ⓪ 未定源任务兜底（title 空=入队时无元数据）：解析补全标题/时长/UP主，
    // 合集条目拆行（与 parseLinkText 同构——消费端承担解析，入队零等待）。
    if (task.title == null || (task.title?.isEmpty ?? true)) {
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.downloading, progressPct: 0.0);
      _emit(task.id, ExtractTaskStatus.downloading, msg.parsingLink);
      final useCookies = await _resolveLoginCookies();
      final List<ResolvedMeta> metas;
      try {
        metas = await _down.resolveAll(task.url,
            cookiesRefKey: useCookies ? kCookieKey : null);
      } on Exception {
        await _extract.updateTask(task.id,
            status: ExtractTaskStatus.failed,
            errorCode: ExtractErrorCode.network);
        _emit(task.id, ExtractTaskStatus.failed, msg.linkParseDead);
        _currentTaskId = null;
        return;
      }
      if (metas.isEmpty) {
        await _extract.updateTask(task.id,
            status: ExtractTaskStatus.failed,
            errorCode: ExtractErrorCode.network);
        _emit(task.id, ExtractTaskStatus.failed, msg.linkParseNoContent);
        _currentTaskId = null;
        return;
      }
      // D12-4③：封面源入账（单视频有值；多 P 条目 null=跳过）。
      final cu = metas.first.coverUrl;
      if (cu != null && cu.isNotEmpty) {
        _taskCoverUrl[task.id] = cu;
      }
      // 合集拆行：第 2..N 条建任务（继承音质与内容选项）。
      final nowMs0 = DateTime.now().millisecondsSinceEpoch;
      for (final extra in metas.skip(1)) {
        final (sib, _) = await _extract.createOrGet(
          sourceType: extra.sourceType,
          sourceId: extra.sourceId,
          url: extra.url,
          quality: task.quality,
          cookiesUsed: task.cookiesUsed,
          nowMs: nowMs0,
        );
        if (sib.status == ExtractTaskStatus.registered) {
          continue; // 已入库=dup 终态，不重置
        }
        await _extract.updateTask(sib.id,
            status: ExtractTaskStatus.resolved,
            title: extra.title,
            uploader: extra.uploader,
            durationMs: extra.durationMs,
            errorCode: null);
        if (_lyricsWanted[task.id] == true) {
          _lyricsWanted[sib.id] = true;
        }
        if (_textWanted[task.id] == true) {
          _textWanted[sib.id] = true;
        }
        if (_videoWanted[task.id] == true) {
          _videoWanted[sib.id] = true;
        }
      }
      final first = metas.first;
      await _extract.updateTask(task.id,
          title: first.title,
          uploader: first.uploader,
          durationMs: first.durationMs);
      task = await _getTask(task.id);
    }

    // ③.6 歌曲合集拆分判定（2026-10-25 需求）：时长 >5 分钟 → 静音分析
    // （+标题《》歌单匹配命名）→ 多曲入库。桌面形态（ffmpeg 在位）限定。
    List<SplitSegment> splitPlan = const [];
    if (!wantVideo && Platform.isWindows) {
      await _extract.updateTask(task.id, status: ExtractTaskStatus.transcoding);
      _emit(task.id, ExtractTaskStatus.transcoding, msg.analyzingAudio);
      splitPlan = await detectSplit(
        audioPath: finalPath!,
        durationMs: task.durationMs ?? 0,
        videoTitle: task.title,
      );
    }

    // ③.7 拆分路径：单曲合集 → N 首独立曲目（一段一注册；歌词/字幕按段补全）。
    if (splitPlan.length >= 2) {
      await _executeSplit(task, finalPath!, targetDir, splitPlan);
      return;
    }

    // ④ TRANSCODING（yt-dlp -x 内联转码到此为止=语义标记态）。
    await _extract.updateTask(task.id, status: ExtractTaskStatus.transcoding);
    _emit(task.id, ExtractTaskStatus.transcoding);

    // ④.5 产物迁移：私有 staging → 仓库/提取/（PRD §3 保存位置；名=UP主 - 歌名）。
    final movedPath = await _moveIntoRepo(finalPath!, targetDir, task);
    if (movedPath == null) {
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.failed,
          errorCode: ExtractErrorCode.disk);
      _emit(task.id, ExtractTaskStatus.failed, msg.audioMoveFailed);
      _currentTaskId = null;
      return;
    }

    // ⑤ REGISTERED 事务（失败→quarantine 隔离，库不动）。
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final trackId = await _register(task, movedPath, repo, nowMs);
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.registered, outputRelPath: movedPath);
      _events.add(ExtractRegistered(task.id, trackId, task.title ?? ''));
      _emit(task.id, ExtractTaskStatus.registered);

      if (_textWanted.remove(task.id) == true) {
        // REQ-EXT 内容可选「文字」：字幕→LRC（侧队列，不占下载泵）。
        _scheduleSubs(task, movedPath);
      }

      if (_lyricsWanted.remove(task.id) == true) {
        // T9C（2026-10-19 裁决）：歌词联动不再被 ASR 模型在位门控——
        // LRCLIB 优先真取；modelId 仅在真有 present 模型时随行（ASR 兜底
        // 运行时=T10/RV-C 挂账，装配后如实记录）。
        final modelId = await _presentModelId();
        await _lyrics.schedule(trackId, modelId: modelId, nowMs: nowMs);
        lyrics.enqueue(trackId);
      }
    } catch (e) {
      await _quarantine(movedPath);
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.failed,
          errorCode: ExtractErrorCode.transcode);
      _emit(task.id, ExtractTaskStatus.failed, msg.registerFailedIsolated);
    } finally {
      try {
        await stagingDir.delete(recursive: true); // 待清理终态即清理（§4.3）
      } on Exception {
        // 目录被占用=下次同名任务复用 temp（名称唯一）
      }
      _currentTaskId = null;
    }
  }

  // ── 合集拆分（2026-10-25 需求：一段一曲 + 标题/封面/歌词自动补全）──

  /// 段注册账本（字幕偏移链：taskId → 段轨信息）。
  final Map<int, List<({int trackId, String audioPath, int startMs, int endMs})>>
      _taskSegments = {};

  /// 封面源账本（D12-4③：taskId → B 站视频封面 URL；拆分段补齐用）。
  final Map<int, String> _taskCoverUrl = {};

  /// 一次性字节下载（封面；UA 诚实；失败=null 不冒泡）。
  Future<List<int>?> _downloadBytes(String url) async {
    final client = HttpClient()
      ..findProxy = HttpClient.findProxyFromEnvironment
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final rq = await client.getUrl(Uri.parse(url))
        ..headers.set(HttpHeaders.userAgentHeader,
            'iA-Music/0.1 (https://github.com/HardStone/iA-Music)');
      final rs = await rq.close();
      if (rs.statusCode != 200) {
        return null;
      }
      final out = <int>[];
      await for (final chunk in rs) {
        out.addAll(chunk);
      }
      return out.isEmpty ? null : out;
    } on Exception {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// 拆分执行：切分 → 逐段迁入仓库 → 逐段注册 → 歌词/字幕按段补全。
  /// 任一段切分失败=诚实回退整轨（不留半套产物）。
  Future<void> _executeSplit(ExtractTask task, String stagedPath,
      Directory targetDir, List<SplitSegment> plan) async {
    final repo = (await _lib.rootsSnapshot()).first;
    final n = plan.length;
    final baseTitle = (task.title ?? '').isEmpty ? task.sourceId : task.title!;
    final uploader = (task.uploader ?? '').isEmpty ? '未知UP主' : task.uploader!;

    // ① 切分到 staging（-c copy；失败→回退整轨注册）。
    final segFiles = await splitAudio(
      audioPath: stagedPath,
      outputDir: File(stagedPath).parent.path,
      segments: plan,
      baseName: 'seg_${task.sourceId}',
    );
    if (segFiles.length != n) {
      _emit(task.id, ExtractTaskStatus.transcoding, msg.splitFailedWhole);
      await _registerWholeAfterSplitAbort(task, stagedPath, targetDir, repo);
      return;
    }

    // ② 逐段迁移+注册（真实用户可见进度：段粒度）。
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final registered =
        <({int trackId, String audioPath, int startMs, int endMs})>[];
    String? firstRelPath;
    try {
      for (var i = 0; i < n; i++) {
        final seg = plan[i];
        final segTitle = seg.title ?? '$baseTitle ${i + 1}/$n';
        final moved = await _moveFileInto(
          segFiles[i].path,
          targetDir,
          '${_sanitizeName(uploader)} - ${_sanitizeName(segTitle)}.mp3',
        );
        if (moved == null) {
          throw const FileSystemException('segment move failed');
        }
        firstRelPath ??= moved;
        final trackId = await _register(
          task,
          moved,
          repo,
          nowMs,
          sourceIdOverride: '${task.sourceId}#p${i + 1}',
          titleOverride: segTitle,
          durationMsOverride: seg.durationMs,
        );
        registered.add((
          trackId: trackId,
          audioPath: moved,
          startMs: seg.startMs,
          endMs: seg.endMs,
        ));
        _events.add(ExtractRegistered(task.id, trackId, segTitle));
        _emit(task.id, ExtractTaskStatus.transcoding,
            msg.splitProgress(i + 1, n, segTitle));
        unawaited(_extract.updateTask(
            task.id, progressPct: (i + 1) / n * 100));
        _events.add(ExtractProgress(task.id, (i + 1) / n * 100));
      }

      // ③ 任务终态=registered（一行任务对应 N 首曲目；output=首段）。
      // D12-4③：段封面补齐——B 站视频封面下载一次 → 各段 sibling
      // `<段音频名>.cover.jpg`（与 CoverChain fetched 档命名天然衔接）。
      final coverUrl = _taskCoverUrl[task.id];
      if (coverUrl != null) {
        final bytes = await _downloadBytes(coverUrl);
        if (bytes != null) {
          for (final seg in registered) {
            final base = seg.audioPath.replaceAll(RegExp(r'\.[^.]+$'), '');
            try {
              File('$base.cover.jpg').writeAsBytesSync(bytes, flush: true);
            } catch (_) {
              // 单段封面写失败不阻断（其余段继续；封面链后续可在线兜底）。
            }
          }
        }
      }
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.registered, outputRelPath: firstRelPath);
      _taskSegments[task.id] = registered;
      _taskCoverUrl.remove(task.id);
      _emit(task.id, ExtractTaskStatus.registered, msg.splitDone(n));

      // ④ 每段歌词（LRCLIB 按段曲名匹配）+ 字幕文本按段偏移。
      if (_lyricsWanted.remove(task.id) == true) {
        final modelId = await _presentModelId();
        for (final seg in registered) {
          await _lyrics.schedule(seg.trackId,
              modelId: modelId, nowMs: nowMs);
          lyrics.enqueue(seg.trackId);
        }
      }
      if (_textWanted.remove(task.id) == true) {
        _scheduleSubs(task, registered.first.audioPath);
      }
      // 完整合集文件不再保留（拆分产物已替代，防曲库重复内容）。
      try {
        await File(stagedPath).delete();
      } on Exception {
        // staging 目录终态统一清理
      }
    } catch (e) {
      // 半套产物=quarantine 已迁段；任务失败（诚实：拆分中断不留脏库）
      for (final seg in registered) {
        await _quarantine(seg.audioPath);
      }
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.failed,
          errorCode: ExtractErrorCode.transcode);
      _emit(task.id, ExtractTaskStatus.failed, msg.splitRegisterFailed);
    } finally {
      try {
        await Directory(File(stagedPath).parent.path).delete(recursive: true);
      } on Exception {
        // 目录被占用=OS 临时策略回收兜底
      }
      _currentTaskId = null;
    }
  }

  /// 拆分分析失败后的整轨回退注册（沿用单轨路径语义）。
  Future<void> _registerWholeAfterSplitAbort(
      ExtractTask task, String stagedPath, Directory targetDir, RepositoryRoot repo) async {
    final movedPath = await _moveIntoRepo(stagedPath, targetDir, task);
    if (movedPath == null) {
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.failed, errorCode: ExtractErrorCode.disk);
      _emit(task.id, ExtractTaskStatus.failed, msg.audioMoveFailed);
      _currentTaskId = null;
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final trackId = await _register(task, movedPath, repo, nowMs);
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.registered, outputRelPath: movedPath);
      _events.add(ExtractRegistered(task.id, trackId, task.title ?? ''));
      _emit(task.id, ExtractTaskStatus.registered, msg.noSongBoundary);
      if (_textWanted.remove(task.id) == true) {
        _scheduleSubs(task, movedPath);
      }
      if (_lyricsWanted.remove(task.id) == true) {
        final modelId = await _presentModelId();
        await _lyrics.schedule(trackId, modelId: modelId, nowMs: nowMs);
        lyrics.enqueue(trackId);
      }
    } catch (e) {
      await _quarantine(movedPath);
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.failed,
          errorCode: ExtractErrorCode.transcode);
      _emit(task.id, ExtractTaskStatus.failed, msg.registerFailedIsolated);
    } finally {
      try {
        await Directory(File(stagedPath).parent.path).delete(recursive: true);
      } on Exception {
        // 目录被占用=OS 临时策略回收兜底
      }
      _currentTaskId = null;
    }
  }

  Future<_Terminal> _awaitTerminal(TaskHandle handle, int taskId) {
    final c = Completer<_Terminal>();
    late final StreamSubscription<TaskEvent> sub;
    sub = _down.stream.listen((ev) {
      if (ev is TaskProgress) {
        _lastPct = ev.percent.round();
        unawaited(
            _extract.updateTask(taskId, progressPct: ev.percent));
        if (!_events.isClosed) {
          _events.add(ExtractProgress(taskId, ev.percent));
        }
      } else if (ev is TaskStaged) {
        _lastStagedPath = ev.filePath;
        unawaited(sub.cancel());
        if (!c.isCompleted) {
          c.complete(_Terminal.done);
        }
      } else if (ev is TaskPaused) {
        _lastDetail = null;
        unawaited(sub.cancel());
        if (!c.isCompleted) {
          c.complete(_Terminal.paused);
        }
      } else if (ev is TaskFailed) {
        _lastDetail = ev.detail;
        unawaited(sub.cancel());
        if (!c.isCompleted) {
          c.complete(_Terminal.failed);
        }
      }
    });
    return c.future;
  }

  String? _lastDetail;

  DownloadFailureClass _classifyLastDetail() {
    final d = (_lastDetail ?? '').toLowerCase();
    if (d.contains('auth') || d.contains('需要登录') || d.contains('login')) {
      return DownloadFailureClass.auth;
    }
    if (d.contains('disk') || d.contains('space')) {
      return DownloadFailureClass.disk;
    }
    return DownloadFailureClass.network;
  }

  ExtractErrorCode _errCode(DownloadFailureClass k) {
    switch (k) {
      case DownloadFailureClass.auth:
        return ExtractErrorCode.auth;
      case DownloadFailureClass.disk:
        return ExtractErrorCode.disk;
      case DownloadFailureClass.unsupported:
        return ExtractErrorCode.transcode; // 格式/内容/工具链受限 → 最贴近终态码
      case DownloadFailureClass.network:
        return ExtractErrorCode.network;
    }
  }

  String _human(DownloadFailureClass k) {
    switch (k) {
      case DownloadFailureClass.auth:
        return msg.failureAuth;
      case DownloadFailureClass.disk:
        return msg.failureDisk;
      case DownloadFailureClass.unsupported:
        return msg.failureUnsupported;
      case DownloadFailureClass.network:
        return msg.failureNetwork;
    }
  }

  /// 真实错误行 → 人话附件（此前进程 stderr 的唯一诊断信息在 UI 层完全丢失）。
  String? _humanDetailSuffix() {
    final d = _lastDetail;
    if (d == null) {
      return null;
    }
    final i = d.indexOf('ERROR:');
    final err = i >= 0 ? d.substring(i) : null;
    if (err == null || err.trim().isEmpty) {
      return null;
    }
    final oneLine = err.replaceAll('\n', ' ').trim();
    return oneLine.length > 160
        ? '（${oneLine.substring(0, 160)}…）'
        : '（$oneLine）';
  }

  Future<String?> _presentModelId() async {
    final rows = await (_db.select(_db.modelRegistry)).get();
    for (final r in rows) {
      if (r.status == ModelStatus.present) {
        return r.modelId;
      }
    }
    return null;
  }

  /// 产物迁移：staging → 仓库/提取/UP主 - 歌名.mp3（PRD §3 文件命名；
  /// 合规文件名净化 + 冲突消歧 -2/-3）。
  Future<String?> _moveIntoRepo(
    String stagedPath,
    Directory targetDir,
    ExtractTask task,
  ) async {
    final rawTitle = (task.title ?? '').isEmpty
        ? stagedPath.split(Platform.pathSeparator).last.split('.').first
        : task.title!;
    final rawUploader = (task.uploader ?? '').isEmpty
        ? '未知UP主'
        : task.uploader!;
    final ext = stagedPath.split(Platform.pathSeparator).last.split('.').last;
    final base =
        '${_sanitizeName(rawUploader)} - ${_sanitizeName(rawTitle)}.$ext';
    return _moveFileInto(stagedPath, targetDir, base);
  }

  /// 段/整轨统一迁移面（base 已含扩展名；rename 失败→跨卷复制+删除）。
  Future<String?> _moveFileInto(
    String stagedPath,
    Directory targetDir,
    String base,
  ) async {
    var candidate = base;
    var n = 1;
    while (File('${targetDir.path}/$candidate').existsSync()) {
      n++;
      final dot = base.lastIndexOf('.');
      candidate = dot < 0
          ? '$base-$n'
          : '${base.substring(0, dot)}-$n${base.substring(dot)}';
    }
    try {
      final dst = '${targetDir.path}/$candidate'.replaceAll('\\', '/');
      await File(stagedPath).rename(dst);
      return dst;
    } on FileSystemException {
      // 跨卷 rename → 复制+删除（staging=系统临时盘 vs 仓库自定义盘）
      try {
        final dst = '${targetDir.path}/$candidate'.replaceAll('\\', '/');
        await File(stagedPath).copy(dst);
        await File(stagedPath).delete();
        return dst;
      } on Exception {
        return null;
      }
    }
  }

  /// 合规文件名（去「」【】书名号与合集前缀占位 + Windows 保留字符替换）。
  static String _sanitizeName(String raw) {
    var s = raw
        .replaceAll(RegExp(r'《|》|「|」|【|】'), '')
        .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
        .trim();
    return s.isEmpty ? '未命名' : s;
  }

  /// 注册入库（事务：字典 upsert + 单件 track + FTS —— 复用批插 internals）。
  /// 拆分段经 [sourceIdOverride]/[titleOverride]/[durationMsOverride] 覆盖：
  /// -c copy 段文件的内嵌标签仍是整视频标题/时长，不能作为段元数据。
  Future<int> _register(
    ExtractTask task,
    String finalPath,
    RepositoryRoot repo,
    int nowMs, {
    String? sourceIdOverride,
    String? titleOverride,
    int? durationMsOverride,
  }) async {
    final meta = await (MetadataAdapter().read(finalPath));
    final bytes = await File(finalPath).readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final st = await File(finalPath).stat();
    // 产物名以两种分隔符归一（rename 返回值均为正斜杠统一化路径）。
    final fileName =
        finalPath.split(Platform.pathSeparator).last.split('/').last;
    final rel = '$kExtractRelDir/$fileName';

    final ids = await _lib.insertTrackBatch([
      ScannedTrackInput(
        rootId: repo.id,
        relPath: rel,
        mtime: st.modified.millisecondsSinceEpoch,
        fileSize: st.size,
        contentHash: hash,
        nowMs: nowMs,
        title: titleOverride ??
            (meta.title.isEmpty
                ? task.title ?? fileName.split('.').first
                : meta.title),
        artistDisplay: meta.artistDisplay.isEmpty
            ? (titleOverride != null ? task.uploader : meta.artistDisplay)
            : meta.artistDisplay,
        durationMs: durationMsOverride ??
            (meta.durationMs > 0 ? meta.durationMs : task.durationMs),
        format: AudioFormatSpec.mp3,
        sampleRate: meta.sampleRate,
      ),
    ]);
    // source 列补写（批插不填 → 单 update；=库里 source 双保险的种子）
    final trackId = ids.single;
    await (_db.update(_db.tracks)..where((t) => t.id.equals(trackId))).write(
      TracksCompanion(
        sourceType: Value(task.sourceType),
        sourceId: Value(sourceIdOverride ?? task.sourceId),
      ),
    );
    return trackId;
  }

  /// 注册失败隔离（§3.2 不变量：不影响曲库）。
  Future<void> _quarantine(String filePath) async {
    try {
      final dir = await _quarantineBase();
      final name = filePath.split(Platform.pathSeparator).last;
      await File(filePath).rename('${dir.path}/$name');
    } on Exception {
      // 磁盘锁=保留原位（staging 目录下）；快照记录
    }
  }

  /// 用户暂停（进行中的任务）。
  Future<void> pauseCurrent() async {
    final h = _currentHandle;
    if (h != null) {
      await _down.pause(h);
    }
  }

  /// 用户取消（§4.3 资源释放：进程 kill + 分片清理；行删除=队列历史可清）。
  Future<void> cancelTask(int taskId) async {
    final row = await _getTask(taskId);
    if (_currentTaskId == taskId) {
      final h = _currentHandle;
      if (h != null) {
        await _down.cancel(h); // 进程树 kill
      }
      await _cleanupStaging(row.sourceId); // .part/.ytdl 清理（无半成品遗留）
    }
    unawaited((_db.delete(_db.extractTasks)..where((t) => t.id.equals(taskId)))
        .go());
  }

  Future<void> _cleanupStaging(String sourceId) async {
    final dir =
        Directory('${await stagingRoot()}/$sourceId');
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } on Exception {
        // OS 临时策略回收兜底
      }
    }
  }

  void _onDownEvent(TaskEvent ev) {} // 消费在 _awaitTerminal 订阅；未做全局观察

  /// quarantine 根（T9A 平台修正：systemTemp 在 Android 不可写）。
  Future<Directory> _quarantineBase() async {
    final base = Directory(await _quarantineTempRoot());
    await base.create(recursive: true);
    return base.createTemp('ia_quarantine');
  }

  Future<String> _quarantineTempRoot() async {
    if (Platform.isAndroid) {
      final t = await getTemporaryDirectory();
      return t.path;
    }
    return Directory.systemTemp.path;
  }

  void _emit(int taskId, ExtractTaskStatus s, [String? message]) {
    if (!_events.isClosed) {
      _events.add(ExtractStateChanged(taskId, s, message: message));
    }
  }

  /// 会话终了：杀当前进程；任务行留存（下次会话可手动重试，§4.3 无残留半成品）。
  Future<void> dispose() async {
    await _sub.cancel();
    final h = _currentHandle;
    if (h != null) {
      await _down.cancel(h);
    }
    await _events.close();
  }
}
