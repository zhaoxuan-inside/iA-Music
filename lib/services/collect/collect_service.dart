/// 收集执行服务：任务队列的真实处理（source 插件 / 直链音频）。
///
/// * 直链音频（source=direct）→ HTTP 下载到音乐目录 → 重扫入库 → done。
/// * source 插件（source=<插件 id>）→ 插件 resolve 元数据与子曲目 →
///   插件 stream 直链 → 宿主下载（带插件给的请求头）→ 插件 lyrics →
///   重扫入库 → done。平台知识 100% 在插件（docs/PLUGIN.md §3.2）；
///   宿主只做媒体 IO、多曲目拆分与数据库写入。
/// * URL 片段约定 `#ia-track=N`：多子曲目任务只提取第 N 条（1-based），
///   拆分由宿主完成，插件永远收到无片段的干净 URL。
library;

import 'dart:io';

import 'package:drift/drift.dart';

import '../../app/config/collect_config.dart';
import '../../data/database.dart';
import '../../domain/entities/track.dart';
import '../scan/scan_service.dart';
import 'download_guard.dart';
import 'source_plugins.dart';

enum CollectPhase { idle, running }

class CollectRunner {
  CollectRunner(
    this._db,
    this._scan, {
    required this.cacheDir,
    required this.sources,
    this.onTaskError,
    this.onTaskSoftError,
  });

  final IaDatabase _db;
  final ScanService _scan;
  final String cacheDir;

  /// 音频源插件门面（已启用插件枚举 + 契约调用）。
  /// null = 仅直链可用（测试/最小装配）。
  final SourcePlugins? sources;

  /// 单任务硬失败回调（错误原文+栈，供 state 层接诊断/日志追踪）。
  final void Function(String title, Object error, StackTrace? st)? onTaskError;

  /// 软失败回调（如歌词缺失——不失败任务，但原因要可见）。
  final void Function(String source, Object error)? onTaskSoftError;

  /// 运行中任务的取消请求集：UI 暂停/删除经 [cancelTask] 登记，
  /// [_process] 的检查点（下载泵回调/发布前/入库前）触发后转 paused。
  final Set<int> _cancelRequests = {};

  CollectPhase phase = CollectPhase.idle;

  /// 同一链接的 resolve 元数据缓存：多子曲目拆分后 N 个任务只解析一次。
  final Map<String, Map<String, Object?>> _metaCache = {};

  CollectDao get _tasks => _db.collectDao;
  PlaylistDao get _playlists => _db.playlistDao;

  /// 请求取消任务（运行中→检查点触发；已结束任务登记无副作用，由
  /// _process 的 finally 清除）。等待中的任务直接由 DAO 置 paused。
  void cancelTask(int id) => _cancelRequests.add(id);

  /// 处理一轮队列（顺序执行 pending 任务；重复调用安全——运行中直接返回）。
  ///
  /// 开轮先回收僵尸：App 中途死亡留下的 running 任务重置为 pending 重跑。
  /// 多曲目拆分会在处理中新增 pending 任务，所以这里循环取队首，
  /// 直到没有新的 pending；遇到「没有音乐目录」则停手，等目录就绪后再跑。
  /// 返回 (处理数, 失败数)：调用方据此记轮次汇总（记录点在 state 层）。
  Future<(int, int)> runOnce() async {
    if (phase == CollectPhase.running) {
      return (0, 0);
    }
    var processed = 0;
    var failed = 0;
    phase = CollectPhase.running;
    try {
      await _tasks.requeueRunning();
      // 两阶段管道：阶段一逐任务下载/提取落盘（文件直接发布进音乐目录，
      // 不扫描）；阶段二整轮一次批扫 + 逐任务入库记账。原每首一扫——
      // 导入 100 首歌单 = 100 次全目录 walk+diff。
      final staged = <_StagedFile>[];
      while (true) {
        final pending = await _tasks.pendingOrRunning();
        CollectTaskRow? next;
        for (final t in pending) {
          if (t.status == CollectStatusCol.pending) {
            next = t;
            break;
          }
        }
        if (next == null) {
          break;
        }
        final (cont, taskFailed, file) = await _process(
            next.id, next.source, next.url, next.title, next.artist,
            next.lyricsPath, next.playlistId);
        processed++;
        if (taskFailed) {
          failed++;
        }
        if (file != null) {
          staged.add(file);
        }
        if (!cont) {
          break;
        }
      }
      if (staged.isNotEmpty) {
        failed += await _publishStaged(staged);
      }
    } finally {
      phase = CollectPhase.idle;
    }
    return (processed, failed);
  }

  /// 阶段一：下载/提取（文件发布进音乐目录即返回）；扫描与入库记账
  /// 延后到 [_publishStaged] 轮末批扫。
  /// 返回 (是否继续轮询, 是否失败, 已下载待入库)。
  Future<(bool, bool, _StagedFile?)> _process(
    int id,
    String source,
    String url,
    String title,
    String artist,
    String? lyricsPath,
    int? playlistId,
  ) async {
    await _tasks.setStatus(id, CollectStatusCol.running);
    try {
      _ensureNotCancelled(id);
      final root = await _firstRoot();
      if (root == null) {
        // 未配置音乐目录：回 pending，等目录就绪后重跑（本轮回调停止，避免空转）。
        await _tasks.setStatus(id, CollectStatusCol.pending);
        return (false, false, null);
      }
      final (filePath, _, lrc) = switch (source) {
        'direct' => await _downloadDirect(id, url, title, artist, root.path),
        _ => await _extractViaPlugin(
            id, source, url, title, artist, root.path, playlistId),
      };
      _ensureNotCancelled(id);
      if (filePath == null) {
        // 防御路径：下载/提取管道已改为失败即抛，到这里说明有未覆盖的空洞。
        throw Exception('提取未产出音频文件：$url');
      }
      return (
        true,
        false,
        _StagedFile(
          taskId: id,
          rootId: root.id,
          rootPath: root.path,
          filePath: filePath,
          lrcPath: lrc ?? lyricsPath,
          playlistId: playlistId,
          title: title,
        ),
      );
    } on CollectCancelledException {
      // 运行中暂停/删除：转 paused（不重跑、不算失败、不上报），残留清理
      await cleanupTaskTmp(cacheDir, id);
      await _tasks.setStatus(id, CollectStatusCol.paused);
      return (true, false, null);
    } on Object catch (e, st) {
      // 失败原因必须可见：错误原文落任务行（UI 可读）+ 回调上抛（state 层
      // 接诊断/日志追踪）——曾经的裸 catch 让所有提取失败无声蒸发。
      await cleanupTaskTmp(cacheDir, id);
      await _tasks.setStatus(id, CollectStatusCol.failed,
          errorText: _errorText(e));
      onTaskError?.call(title, e, st);
      return (true, true, null);
    } finally {
      _cancelRequests.remove(id);
    }
  }

  /// 阶段二：整轮一次批扫（每个涉及的音乐目录一次）+ 逐任务入库记账。
  /// 单任务记账失败不影响其余（失败原文落任务行 + 回调上报，与阶段一同口径）。
  Future<int> _publishStaged(List<_StagedFile> staged) async {
    var failed = 0;
    final roots = <int, String>{
      for (final s in staged) s.rootId: s.rootPath,
    };
    for (final e in roots.entries) {
      await _scan.scanRoot(e.key, e.value);
    }
    for (final s in staged) {
      try {
        final track = await _trackByPath(s.filePath);
        if (track == null) {
          throw Exception('入库扫描未找到文件：${s.filePath}');
        }
        // 歌词：提取期拉到的 LRC 优先；GitHub 拉取随带的其次
        if (s.lrcPath != null) {
          await _db.lyricsDao.upsert(
            track.id,
            LyricsMetaCompanion.insert(
              trackId: Value(track.id),
              kind: const Value('online'),
              lrcPath: Value(s.lrcPath),
            ),
          );
        }
        // 归歌单
        if (s.playlistId != null) {
          await _playlists.addTrack(s.playlistId!, track.id);
          await _playlists.decrementPending(s.playlistId!);
        }
        await _tasks.setStatus(s.taskId, CollectStatusCol.done,
            filePath: s.filePath);
      } on Object catch (e, st) {
        failed++;
        await _tasks.setStatus(s.taskId, CollectStatusCol.failed,
            errorText: _errorText(e));
        onTaskError?.call(s.title, e, st);
      }
    }
    return failed;
  }


  void _ensureNotCancelled(int id) {
    if (_cancelRequests.contains(id)) {
      throw const CollectCancelledException();
    }
  }

  /// ── source 插件提取（通用管道） ────────────────────────────────────

  Future<(String?, ({String title, String artist}), String?)> _extractViaPlugin(
      int taskId,
      String source,
      String url,
      String title,
      String artist,
      String rootDir,
      int? playlistId) async {
    final plugins = sources;
    if (plugins == null) {
      throw Exception('来源插件未安装或未启用：$source');
    }
    final handle = await plugins.byId(source) ??
        // 清单旧别名/插件换名兜底：按 URL 让插件重新认领一次
        (await plugins.routeUrl(url) == null
            ? null
            : await plugins.byId((await plugins.routeUrl(url))!));
    if (handle == null) {
      throw Exception('来源插件未安装或未启用：$source');
    }
    final baseUrl = _baseUrl(url);
    final pin = _trackPin(url);

    await _tasks.setProgress(taskId, 5);
    final meta = _metaCache[baseUrl] ?? await _resolveWithRetry(handle, baseUrl);
    _metaCache[baseUrl] = meta;
    final tracks = (meta['tracks'] as List<Object?>? ?? const [])
        .whereType<Map>()
        .map((m) => m.cast<String, Object?>())
        .toList(growable: false);
    if (tracks.isEmpty) {
      throw Exception('插件未返回可提取曲目');
    }

    // 多曲目拆分：未 pin 且多于一条 → 当前任务重定向到首曲，其余入队。
    // 插件永远收到无片段的干净 URL；片段只由宿主读写。
    if (tracks.length > 1 && pin == null) {
      final first = tracks.first;
      try {
        await _tasks.retarget(taskId,
            url: _withTrack(baseUrl, 1),
            title: '${first['title'] ?? ''}',
            artist: '${first['artist'] ?? ''}');
      } on CollectCancelledException {
        rethrow;
      } on Object {
        // 唯一键冲突等：保留原任务，继续按首曲提取。
      }
      for (var i = 1; i < tracks.length; i++) {
        final t = tracks[i];
        await _tasks.enqueue(
          source,
          _withTrack(baseUrl, i + 1),
          title: '${t['title'] ?? ''}',
          artist: '${t['artist'] ?? ''}',
          playlistId: playlistId,
        );
      }
    }

    final track = tracks[pin == null ? 0 : (pin - 1).clamp(0, tracks.length - 1)]
        .cast<String, Object?>();
    final trackId = '${track['id'] ?? ''}';
    if (trackId.isEmpty) {
      throw Exception('插件子曲目缺少 id');
    }
    final useTitle = title.isNotEmpty ? title : ('${track['title'] ?? ''}');
    final useArtist = artist.isNotEmpty ? artist : ('${track['artist'] ?? ''}');

    await _tasks.setProgress(taskId, 12);
    final stream = await handle.stream(trackId) ??
        (throw Exception('插件未返回音频直链'));
    final streamUrl = '${stream['url'] ?? ''}';
    if (streamUrl.isEmpty) {
      throw Exception('插件音频直链为空');
    }
    final ext = ('${stream['ext'] ?? ''}').isEmpty
        ? 'audio'
        : ('${stream['ext']}').toLowerCase();
    final headers =
        (stream['headers'] as Map<Object?, Object?>? ?? const {}).cast<String, String>();

    await _tasks.setProgress(taskId, 20);
    final safe = _fileName(useArtist, useTitle, ext, taskId);
    final target = '$rootDir${Platform.pathSeparator}$safe';
    // 先下到应用私有缓存（必然可写），再发布进音乐目录——
    // 共享存储里可能有异主文件（重装后旧 uid 残留），直接写会挂死。
    final tmp = '$cacheDir/dl_${source}_$taskId.$ext';
    await _downloadStreamWithRetry(
        handle, trackId, streamUrl, headers, taskId, tmp,
        onProgress: (received, total) {
      if (total > 0) {
        _tasks.setProgress(taskId, 20 + (received / total * 65).floor());
      }
    });
    final filePath = await _publish(tmp, target);

    // 歌词（插件把字幕/歌词转成文本返回；缺失/挂流不阻断提取）
    String? lrcPath;
    try {
      final lrc = await (handle.lyrics(trackId).timeout(const Duration(seconds: 20)));
      final text = lrc == null
          ? null
          : ((lrc['synced'] as String?) ?? (lrc['plain'] as String?));
      if (text != null && text.trim().isNotEmpty) {
        final dot = filePath.lastIndexOf('.');
        final lrcTarget = dot > 0
            ? '${filePath.substring(0, dot)}.lrc'
            : '$filePath.lrc';
        final lrcTmp = '$cacheDir/lrc_${source}_$taskId.lrc';
        await File(lrcTmp).writeAsString(text, flush: true);
        // 旁车歌词不覆盖不换名：目标已有 .lrc（用户自己的或上轮的）一律
        // 保留丢 tmp——覆盖毁用户歌词，换名破坏「同名 .lrc」配对约定。
        final lrcFile = File(lrcTarget);
        if (lrcFile.existsSync()) {
          try {
            File(lrcTmp).deleteSync();
          } on Object {
            // 残留 tmp 无碍
          }
          lrcPath = lrcTarget;
        } else {
          lrcPath = await _publish(lrcTmp, lrcTarget);
        }
      }
    } on CollectCancelledException {
      rethrow;
    } on Object catch (e) {
      // 歌词缺失不阻断提取——但失败原因要可见（软失败，进日志追踪；
      // 插件超时/异常与「真没歌词」由此可区分）。
      onTaskSoftError?.call('提取歌词 · $useTitle', e);
    }
    await _tasks.setProgress(taskId, 90);
    return (filePath, (title: useTitle, artist: useArtist), lrcPath);
  }

  /// URL 片段 pin 约定（`#ia-track=N`）的构造/解析统一在 collect_config，
  /// 这里只留薄委托——state 层勾选入队共用同一写入点。
  int? _trackPin(String url) => trackPinOf(url);

  String _baseUrl(String url) => trackBaseUrl(url);

  String _withTrack(String baseUrl, int n) => trackPinUrl(baseUrl, n);

  /// 插件元数据解析（失败短重试一次）：resolve 是提取链路的第一段网络触达，
  /// 设备 DNS/网络瞬态抖动（Wi-Fi↔蜂窝切换的「Failed host lookup」）会把
  /// 整个任务直接打失败——与下载重取直链（_downloadStreamWithRetry）同口径
  /// 重试一次。重试前留 1s 恢复窗口：系统对解析失败有短暂负缓存，立即重试
  /// 大概率撞同一状态。
  Future<Map<String, Object?>> _resolveWithRetry(
      SourcePluginHandle handle, String baseUrl) async {
    try {
      return await handle.resolve(baseUrl) ??
          (throw Exception('插件未返回元数据'));
    } on Object {
      await Future<void>.delayed(const Duration(seconds: 1));
      return await handle.resolve(baseUrl) ??
          (throw Exception('插件未返回元数据（重试）'));
    }
  }

  /// 插件音频下载（失败重取一次直链）：部分上游 CDN 节点拒绝无 Range 的
  /// 裸 GET（B 站 upos 实证 403）——重取 playurl 会重新分配节点，通常可下。
  /// 取消异常原样上抛不重试；重试前清残留半截 tmp。
  Future<void> _downloadStreamWithRetry(
      SourcePluginHandle handle,
      String trackId,
      String streamUrl,
      Map<String, String> headers,
      int taskId,
      String tmp,
      {required void Function(int received, int total) onProgress}) async {
    try {
      await _downloadTo(streamUrl, headers, tmp,
          onProgress: onProgress, cancelled: () => _cancelRequests.contains(taskId));
    } on CollectCancelledException {
      rethrow;
    } on Object {
      final retry = await handle.stream(trackId) ??
          (throw Exception('插件未返回音频直链（重试）'));
      final retryUrl = '${retry['url'] ?? ''}';
      if (retryUrl.isEmpty) {
        throw Exception('插件音频直链为空（重试）');
      }
      final retryHeaders =
          (retry['headers'] as Map<Object?, Object?>? ?? const {})
              .cast<String, String>();
      await cleanupTaskTmp(cacheDir, taskId);
      await _downloadTo(retryUrl, retryHeaders, tmp,
          onProgress: onProgress,
          cancelled: () => _cancelRequests.contains(taskId));
    }
  }

  /// ── 直链下载 ─────────────────────────────────────────────────────

  Future<(String?, ({String title, String artist}), String?)> _downloadDirect(
      int taskId, String url, String title, String artist, String rootDir) async {
    final ext = url.contains('.') && url.lastIndexOf('.') > url.lastIndexOf('/')
        ? url.substring(url.lastIndexOf('.') + 1).split('?').first.toLowerCase()
        : 'audio';
    final safe = _fileName(artist, title, ext, taskId);
    final target = '$rootDir${Platform.pathSeparator}$safe';
    final tmp = '$cacheDir/dl_direct_$taskId.$ext';
    // 不吞异常：HTTP 状态码/停滞看门狗/磁盘 IO 的真实原因冒泡到
    // _process 的失败记录点（曾经在这里换成 null filePath，失败无声）。
    await _downloadTo(url, const {}, tmp,
        onProgress: (r, total) {
          if (total > 0) {
            _tasks.setProgress(taskId, (r / total * 90).floor());
          }
        },
        cancelled: () => _cancelRequests.contains(taskId));
    final filePath = await _publish(tmp, target);
    await _tasks.setProgress(taskId, 95);
    return (filePath, (title: title, artist: artist), null);
  }

  /// 宿主侧媒体 IO：HTTP 下载到临时文件（停滞看门狗 + 进度 + 取消令牌）。
  Future<void> _downloadTo(
      String url, Map<String, String> headers, String filePath,
      {void Function(int received, int total)? onProgress,
      bool Function()? cancelled}) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      headers.forEach((k, v) => req.headers.set(k, v));
      // 部分 CDN 节点拒绝无 Range 的裸 GET（B 站 upos 实证 403）
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
      final res = await req.close();
      if (res.statusCode != 200 && res.statusCode != 206) {
        throw Exception('音频流下载失败：HTTP ${res.statusCode}');
      }
      final total = res.contentLength > 0 ? res.contentLength : 0;
      final sink = File(filePath).openWrite();
      try {
        await pumpDownload(
          source: res,
          sink: sink,
          onChunk: (r) async => onProgress?.call(r, total),
          cancelled: cancelled,
        );
      } finally {
        await sink.flush();
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  /// 发布：私有缓存 → 音乐目录。**永不覆盖既有文件**。
  ///
  /// 同名在库区是高频真实场景（不同源同曲/不同版本），覆盖等于毁掉用户
  /// 自己的文件；FUSE 异主残留（重装后旧 uid 拥有的同名件，直接写会在
  /// FUSE 层挂死）同样以换名绕开——冲突路径永不再写。
  /// * 目标不存在 → rename 发布（EXDEV 回退 copy）。
  /// * 目标存在且字节相同 → 去重：丢 tmp 复用既有路径（重复任务不产生
  ///   第二个文件，入库后也不产生重复曲目行）。
  /// * 目标存在且内容不同 → 时间戳唯一名（递归防撞）。
  Future<String> _publish(String tmpPath, String target) async {
    final t = File(target);
    if (t.existsSync()) {
      if (await _sameBytes(tmpPath, target)) {
        // 同内容去重：既有文件为准，tmp 丢弃（删不掉由 cleanupTaskTmp 兜底）
        try {
          File(tmpPath).deleteSync();
        } on Object {
          // 残留 tmp 无碍正确性
        }
        return target;
      }
      final dot = target.lastIndexOf('.');
      final alt = dot > 0
          ? '${target.substring(0, dot)}-${DateTime.now().millisecondsSinceEpoch}${target.substring(dot)}'
          : '$target-${DateTime.now().millisecondsSinceEpoch}';
      return _publish(tmpPath, alt);
    }
    final src = File(tmpPath);
    try {
      return (await src.rename(target)).path;
    } on Object {
      try {
        await src.copy(target);
        await src.delete();
        return target;
      } on Object {
        // copy 也被拒（分区存储 EPERM——需「所有文件访问」/磁盘满）：
        // 半截 target 是自己刚写的，清掉避免残留垃圾，错误原文上抛。
        try {
          if (t.existsSync()) {
            t.deleteSync();
          }
        } on Object {
          // 删不掉就留着（错误原文已随任务失败可见）
        }
        rethrow;
      }
    }
  }

  /// 字节级等同判断（先比长度，再分块流比对；只在发布冲突时触发）。
  /// 任一侧读失败（异主残留不可读等）→ 视为不同——换名发布，不赌权限。
  Future<bool> _sameBytes(String a, String b) async {
    const chunkSize = 1 << 20;
    RandomAccessFile? fa;
    RandomAccessFile? fb;
    try {
      final fileA = File(a);
      final fileB = File(b);
      if (fileA.lengthSync() != fileB.lengthSync()) {
        return false;
      }
      fa = fileA.openSync();
      fb = fileB.openSync();
      while (true) {
        final ca = await fa.read(chunkSize);
        final cb = await fb.read(chunkSize);
        if (ca.length != cb.length) {
          return false;
        }
        for (var i = 0; i < ca.length; i++) {
          if (ca[i] != cb[i]) {
            return false;
          }
        }
        if (ca.length < chunkSize) {
          return true;
        }
      }
    } on Object {
      return false;
    } finally {
      fa?.closeSync();
      fb?.closeSync();
    }
  }

  /// 下载文件名：'{artist} - {title}.{ext}'（artist 为空则 '{title}.{ext}'）。
  String _fileName(String artist, String title, String ext, int taskId) {
    var name = kDownloadNamePattern
        .replaceAll('@artist', artist.trim())
        .replaceAll('@title', title.trim());
    if (artist.trim().isEmpty) {
      name = title.trim();
    }
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (name.isEmpty) {
      name = 'collect-$taskId';
    }
    return '$name.$ext';
  }

  /// 任务行落库的错误原文（截断防超长栈/URL 撑爆行显示）。
  String _errorText(Object e) {
    final s = '$e';
    return s.length <= 400 ? s : '${s.substring(0, 400)}…';
  }

  Future<RepositoryRoot?> _firstRoot() async {
    final roots = await _db.libraryDao.allRoots();
    return roots.isEmpty ? null : roots.first;
  }

  Future<Track?> _trackByPath(String path) async {
    final rows =
        await (_db.select(_db.tracks)..where((t) => t.path.equals(path))).get();
    return rows.isEmpty
        ? null
        : _db.libraryDao.trackById(rows.first.id);
  }
}

/// 本轮已下载（文件已发布进音乐目录）、待批扫入库的任务（阶段二最小集）。
class _StagedFile {
  const _StagedFile({
    required this.taskId,
    required this.rootId,
    required this.rootPath,
    required this.filePath,
    required this.lrcPath,
    required this.playlistId,
    required this.title,
  });

  final int taskId;
  final int rootId;
  final String rootPath;
  final String filePath;
  final String? lrcPath;
  final int? playlistId;
  final String title;
}
