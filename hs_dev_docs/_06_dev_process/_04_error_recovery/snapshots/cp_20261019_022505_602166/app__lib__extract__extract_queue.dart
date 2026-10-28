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
import 'package:ia_music/adapters/downloader_adapter.dart';
import 'package:ia_music/adapters/metadata_adapter.dart';
import 'package:ia_music/data/daos.dart';
import 'package:drift/drift.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';

sealed class ExtractQueueEvent {
  const ExtractQueueEvent(this.taskId);
  final int taskId;
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
  ExtractQueue({required IaDatabase db, required DownloaderPort downloader})
      : _db = db,
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

  /// 解析分享文本 → ResolvedMeta 列表（多行多链接逐条拆；≤5s 逐条=adapter 时限）。
  Future<List<ResolvedMeta>> parseLinkText(String linkText) async {
    final metas = <ResolvedMeta>[];
    for (final line in linkText.split(RegExp(r'\s+'))) {
      if (extractFirstUrl(line) == null) {
        continue;
      }
      metas.add(await _down.resolve(line));
    }
    return metas;
  }

  /// 入队（合规/重复双门禁；返回 (任务行, isDup)）。
  ///
  /// dup=终态行（UI「这首歌已在曲库中」+重新提取/跳过）。
  Future<(ExtractTask, bool)> enqueue(
    ResolvedMeta meta, {
    required TaskQuality quality,
    bool withLyrics = false,
    required int nowMs,
  }) async {
    if (!await isComplianceAcknowledged()) {
      throw StateError('compliance not acknowledged'); // 门禁 RED（引导页）
    }
    final (task, isNew) = await _extract.createOrGet(
      sourceType: meta.sourceType,
      sourceId: meta.sourceId,
      url: meta.url,
      quality: quality,
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
        final next = await (_db.select(_db.extractTasks)
              ..where((t) => t.status.equalsValue(ExtractTaskStatus.resolved))
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .getSingleOrNull();
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
          Directory('${Directory.systemTemp.path}/ia_extract/${task.sourceId}');
      if (staging.existsSync()) {
        await staging.delete(recursive: true);
      }
    } on Exception {
      // 占用兜底=下次重试前再清
    }
    await _extract.updateTask(task.id,
        status: ExtractTaskStatus.failed, errorCode: ExtractErrorCode.disk);
    _emit(task.id, ExtractTaskStatus.failed, '提取执行失败，任务已终止');
    _currentTaskId = null;
  }

  Future<void> _executeTask(ExtractTask task) async {
    _currentTaskId = task.id;

    // ① 目标仓库（默认第一仓库 + 提取/ 子目录；无仓库=磁盘/配置面失败）。
    final roots = await _lib.rootsSnapshot();
    if (roots.isEmpty) {
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.failed, errorCode: ExtractErrorCode.disk);
      _emit(task.id, ExtractTaskStatus.failed, '尚未配置音乐仓库，请先在「我的」添加仓库');
      return;
    }
    final repo = roots.first;
    final targetDir =
        Directory('${repo.path.replaceAll('\\', '/')}/$kExtractRelDir');
    await targetDir.create(recursive: true);

    // staging 目录=确定性路径（<tmp>/ia_extract/<sourceId>/）——pause 保留 .part，
    // resume/重试自动 --continue 续传；终态 registered/取消/最终失败时清理。
    final stagingBase =
        Directory('${Directory.systemTemp.path}/ia_extract');
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
        await _extract.updateTask(task.id,
            status: ExtractTaskStatus.failed, errorCode: _errCode(klass));
        _emit(task.id, ExtractTaskStatus.failed, _human(klass));
      } else {
        await _extract.updateTask(task.id,
            status: ExtractTaskStatus.paused, progressPct: _lastPct.toDouble());
        _emit(task.id, ExtractTaskStatus.paused, '下载中断，已暂停，联网后自动继续');
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
      _emit(task.id, ExtractTaskStatus.failed, '产物转码失败');
      _currentTaskId = null;
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
      _emit(task.id, ExtractTaskStatus.failed, '产物迁移失败：目标目录不可写');
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

      if (_lyricsWanted.remove(task.id) == true) {
        final modelId = await _presentModelId();
        if (modelId != null) {
          await _lyrics.schedule(trackId, modelId: modelId, nowMs: nowMs);
        }
      }
    } catch (e) {
      await _quarantine(movedPath);
      await _extract.updateTask(task.id,
          status: ExtractTaskStatus.failed,
          errorCode: ExtractErrorCode.transcode);
      _emit(task.id, ExtractTaskStatus.failed, '注册失败：产物已隔离，不影响曲库');
    } finally {
      try {
        await stagingDir.delete(recursive: true); // 待清理终态即清理（§4.3）
      } on Exception {
        // 目录被占用=下次同名任务复用 temp（名称唯一）
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
      case DownloadFailureClass.network:
        return ExtractErrorCode.network;
    }
  }

  String _human(DownloadFailureClass k) {
    switch (k) {
      case DownloadFailureClass.auth:
        return 'B 站登录状态过期，请重新扫码';
      case DownloadFailureClass.disk:
        return '存储空间不足，请清理后重试';
      case DownloadFailureClass.network:
        return '网络连接中断，任务已暂停，本地数据不受影响';
    }
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
    final ext =
        stagedPath.split(Platform.pathSeparator).last.split('.').last;
    final rawTitle = (task.title ?? '').isEmpty
        ? stagedPath.split(Platform.pathSeparator).last.split('.').first
        : task.title!;
    final rawUploader = (task.uploader ?? '').isEmpty
        ? '未知UP主'
        : task.uploader!;
    final base =
        '${_sanitizeName(rawUploader)} - ${_sanitizeName(rawTitle)}';
    var candidate = '$base.$ext';
    var n = 1;
    while (File(candidate).existsSync()) {
      n++;
      candidate = '$base-$n.$ext';
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
  Future<int> _register(
    ExtractTask task,
    String finalPath,
    RepositoryRoot repo,
    int nowMs,
  ) async {
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
        title: meta.title.isEmpty
            ? task.title ?? fileName.split('.').first
            : meta.title,
        artistDisplay:
            meta.artistDisplay.isEmpty ? task.uploader : meta.artistDisplay,
        durationMs: meta.durationMs > 0 ? meta.durationMs : task.durationMs,
        format: AudioFormatSpec.mp3,
        sampleRate: meta.sampleRate,
      ),
    ]);
    // source 列补写（批插不填 → 单 update；=库里 source 双保险的种子）
    final trackId = ids.single;
    await (_db.update(_db.tracks)..where((t) => t.id.equals(trackId))).write(
      TracksCompanion(
        sourceType: Value(task.sourceType),
        sourceId: Value(task.sourceId),
      ),
    );
    return trackId;
  }

  /// 注册失败隔离（§3.2 不变量：不影响曲库）。
  Future<void> _quarantine(String filePath) async {
    try {
      final dir = await Directory.systemTemp.createTemp('ia_quarantine');
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
        Directory('${Directory.systemTemp.path}/ia_extract/$sourceId');
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } on Exception {
        // OS 临时策略回收兜底
      }
    }
  }

  void _onDownEvent(TaskEvent ev) {} // 消费在 _awaitTerminal 订阅；未做全局观察

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
