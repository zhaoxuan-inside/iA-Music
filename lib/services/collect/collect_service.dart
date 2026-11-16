/// 收集执行服务：任务队列的真实处理（B 站 / YouTube / 直链音频）。
///
/// * 直链音频（source=direct）→ HTTP 下载到音乐目录 → 重扫入库 → 挂歌词 → done。
/// * B 站（source=bilibili）→ 视频信息 → DASH 音频流下载 → 字幕转 LRC →
///   重扫入库 → done（真实协议，端点在 collect_config）。
/// * YouTube（source=youtube）→ InnerTube 播放流解析 → 下载 → 重扫入库 → done。
/// * 三分离：这里只有真实下载与真实数据库写入，无任何预置内容。
library;

import 'dart:io';

import 'package:drift/drift.dart';

import '../../app/config/collect_config.dart';
import '../../data/database.dart';
import '../../domain/entities/track.dart';
import '../scan/scan_service.dart';
import 'bilibili_client.dart' show BiliVideoInfo, BilibiliClient;
import 'bilibili_page_meta.dart';
import 'collect_ports.dart';
import 'download_guard.dart';
import 'youtube_client.dart' show YoutubeClient;

enum CollectPhase { idle, running }

class CollectRunner {
  CollectRunner(this._db, this._scan,
      {required this.cacheDir,
      required this.bilibili,
      required this.youtube});

  final IaDatabase _db;
  final ScanService _scan;
  final String cacheDir;

  /// 平台提取端口（真实实现 = BilibiliClient / YoutubeClient；测试注入假件）。
  final BiliCollectApi bilibili;
  final YtCollectApi youtube;

  CollectPhase phase = CollectPhase.idle;

  /// 多 P 任务共享同一视频信息，避免 100 个分 P 重复请求 view 接口。
  final Map<String, BiliVideoInfo> _biliInfoCache = {};

  CollectDao get _tasks => _db.collectDao;
  PlaylistDao get _playlists => _db.playlistDao;

  /// 处理一轮队列（顺序执行 pending 任务；重复调用安全——运行中直接返回）。
  ///
  /// 开轮先回收僵尸：App 中途死亡留下的 running 任务重置为 pending 重跑。
  /// 多 P 拆分会在处理中新增 pending 任务，所以这里循环取队首，
  /// 直到没有新的 pending；遇到「没有音乐目录」则停手，等目录就绪后再跑。
  Future<void> runOnce() async {
    if (phase == CollectPhase.running) {
      return;
    }
    phase = CollectPhase.running;
    try {
      await _tasks.requeueRunning();
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
        final cont = await _process(next.id, next.source, next.url, next.title,
            next.artist, next.lyricsPath, next.playlistId);
        if (!cont) {
          break;
        }
      }
    } finally {
      phase = CollectPhase.idle;
    }
  }

  Future<bool> _process(
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
      final root = await _firstRoot();
      if (root == null) {
        // 未配置音乐目录：回 pending，等目录就绪后重跑（本轮回调停止，避免空转）。
        await _tasks.setStatus(id, CollectStatusCol.pending);
        return false;
      }
      final (filePath, meta, lrc) = switch (source) {
        'bilibili' => await _extractBilibili(
            id, url, title, artist, root.path, playlistId),
        'youtube' => await _extractYoutube(id, url, title, artist, root.path),
        'direct' => await _downloadDirect(id, url, title, artist, root.path),
        _ => throw Exception('未知来源：$source'),
      };
      if (filePath == null) {
        await _tasks.setStatus(id, CollectStatusCol.failed);
        return true;
      }
      // 增量重扫：真实入库（复用扫描链路，音乐目录为根）
      await _scan.scanRoot(root.id, root.path);
      final track = await _trackByPath(filePath);
      if (track == null) {
        await _tasks.setStatus(id, CollectStatusCol.failed);
        return true;
      }
      // 歌词：提取期拉到的 LRC 优先；GitHub 拉取随带的其次
      final lrcPath = lrc ?? lyricsPath;
      if (lrcPath != null) {
        await _db.lyricsDao.upsert(
          track.id,
          LyricsMetaCompanion.insert(
            trackId: Value(track.id),
            kind: const Value('online'),
            lrcPath: Value(lrcPath),
          ),
        );
      }
      // 归歌单
      if (playlistId != null) {
        await _playlists.addTrack(playlistId, track.id);
        final pl = await (_db.select(_db.playlists)
              ..where((x) => x.id.equals(playlistId)))
            .getSingleOrNull();
        if (pl != null && pl.pending > 0) {
          await (_db.update(_db.playlists)..where((x) => x.id.equals(playlistId)))
              .write(PlaylistsCompanion(pending: Value(pl.pending - 1)));
        }
      }
      await _tasks.setStatus(id, CollectStatusCol.done, filePath: filePath);
      return true;
    } on Object {
      await _tasks.setStatus(id, CollectStatusCol.failed);
      return true;
    }
  }

  /// ── B 站提取 ──────────────────────────────────────────────────────

  Future<(String?, ({String title, String artist}), String?)> _extractBilibili(
      int taskId,
      String url,
      String title,
      String artist,
      String rootDir,
      int? playlistId) async {
    final bvid = BilibiliClient.bvidFrom(url);
    if (bvid == null) {
      throw Exception('不是有效的 B 站视频链接：$url');
    }
    await _tasks.setProgress(taskId, 5);
    final info =
        _biliInfoCache[bvid] ?? await bilibili.videoInfo(bvid);
    _biliInfoCache[bvid] = info;
    final pages = info.pages;
    final requestedPage = _biliPage(url);
    final isMulti = pages.length > 1;

    // 不带 p 参数（或只有 p=1 的分享链接）的多 P 视频：自动按 P 拆分，每 P 一首。
    // 原任务重定向到 P1，其余 P 入队；本轮 runOnce 会继续处理新增任务。
    // 只有明确带 p>=2 时才视为「只提取这一 P」。
    if (isMulti && (requestedPage == null || requestedPage <= 1)) {
      final firstMeta = parseBiliPageMeta(pages.first.part,
          fallbackTitle: info.title, fallbackArtist: info.owner);
      try {
        await _tasks.retarget(taskId,
            url: _withBiliPage(url, 1),
            title: firstMeta.title,
            artist: firstMeta.artist);
      } on Object {
        // 唯一键冲突等：保留原任务，继续按 P1 提取。
      }
      for (var i = 1; i < pages.length; i++) {
        final meta = parseBiliPageMeta(pages[i].part,
            fallbackTitle: info.title, fallbackArtist: info.owner);
        await _tasks.enqueue(
          'bilibili',
          _withBiliPage(url, i + 1),
          title: meta.title,
          artist: meta.artist,
          playlistId: playlistId,
        );
      }
    }

    final selected = pages.isEmpty
        ? null
        : pages[(requestedPage == null
                ? 0
                : (requestedPage - 1).clamp(0, pages.length - 1))
            .toInt()];
    final cid = selected?.cid ?? info.cid;
    final pageMeta = isMulti && selected != null
        ? parseBiliPageMeta(selected.part,
            fallbackTitle: info.title, fallbackArtist: info.owner)
        : null;
    final useTitle =
        pageMeta?.title ?? (title.isNotEmpty ? title : info.title);
    final useArtist =
        pageMeta?.artist ?? (artist.isNotEmpty ? artist : info.owner);

    await _tasks.setProgress(taskId, 12);
    final stream = await bilibili.audioStream(bvid, info.aid ?? '', cid);
    await _tasks.setProgress(taskId, 20);
    final safe = _fileName(useArtist, useTitle, stream.ext, taskId);
    final target = '$rootDir${Platform.pathSeparator}$safe';
    // 先下到应用私有缓存（必然可写），再发布进音乐目录——
    // 共享存储里可能有异主文件（重装后旧 uid 残留），直接写会挂死。
    final tmp = '$cacheDir/dl_bili_$taskId.${stream.ext}';
    await bilibili.downloadAudio(stream, tmp,
        onProgress: (received, total) =>
            _tasks.setProgress(taskId, 20 + (received / total * 65).floor()));
    final filePath = await _publish(tmp, target);
    // 字幕 → LRC（落到音频同目录同名）；限时 15s——字幕缺失/挂流不阻断提取
    String? lrcPath;
    try {
      final subs = await bilibili.subtitles(info.aid, cid)
          .timeout(const Duration(seconds: 15));
      for (final s in subs) {
        final lrc = await bilibili.subtitleLrc(s.url)
            .timeout(const Duration(seconds: 15));
        if (lrc != null) {
          final dot = filePath.lastIndexOf('.');
          final lrcTarget = dot > 0
              ? '${filePath.substring(0, dot)}.lrc'
              : '$filePath.lrc';
          final lrcTmp = '$cacheDir/lrc_bili_$taskId.lrc';
          await File(lrcTmp).writeAsString(lrc, flush: true);
          lrcPath = await _publish(lrcTmp, lrcTarget);
          break;
        }
      }
    } on Object {
      // 字幕缺失不阻断提取
    }
    await _tasks.setProgress(taskId, 90);
    return (filePath, (title: useTitle, artist: useArtist), lrcPath);
  }

  /// URL 里的 p 参数（1-based；没有则 null）。
  int? _biliPage(String url) {
    final uri = Uri.tryParse(url);
    final raw = uri?.queryParameters['p'];
    return raw == null ? null : int.tryParse(raw);
  }

  /// 给 B 站 URL 写入/替换 p 参数，保留其他查询参数。
  String _withBiliPage(String url, int page) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return '$url${url.contains('?') ? '&' : '?'}p=$page';
    }
    final params = Map<String, String>.from(uri.queryParameters);
    params['p'] = '$page';
    return uri.replace(queryParameters: params).toString();
  }

  /// ── YouTube 提取 ─────────────────────────────────────────────────

  Future<(String?, ({String title, String artist}), String?)> _extractYoutube(
      int taskId, String url, String title, String artist, String rootDir) async {
    final videoId = YoutubeClient.videoIdFrom(url);
    if (videoId == null) {
      throw Exception('不是有效的 YouTube 链接：$url');
    }
    await _tasks.setProgress(taskId, 10);
    final (details, stream) = await youtube.resolveAudio(videoId);
    final useTitle = title.isNotEmpty
        ? title
        : (details['title'] as String? ?? videoId);
    final useArtist = artist.isNotEmpty
        ? artist
        : ((details['author'] as String? ?? '')
                .replaceAll(RegExp(r' - Topic$'), ''))
            .trim();
    await _tasks.setProgress(taskId, 18);
    final safe = _fileName(useArtist, useTitle, stream.ext, taskId);
    final target = '$rootDir${Platform.pathSeparator}$safe';
    final tmp = '$cacheDir/dl_yt_$taskId.${stream.ext}';
    await youtube.downloadAudio(stream, tmp, onProgress: (received, total) {
      _tasks.setProgress(taskId, 18 + (received / total * 70).floor());
    });
    final filePath = await _publish(tmp, target);
    await _tasks.setProgress(taskId, 90);
    return (filePath, (title: useTitle, artist: useArtist), null);
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
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) {
        client.close();
        return (null, (title: title, artist: artist), null);
      }
      final total = res.contentLength;
      final sink = File(tmp).openWrite();
      await pumpDownload(
        source: res,
        sink: sink,
        onChunk: (r) async {
          if (total > 0) {
            await _tasks.setProgress(taskId, (r / total * 90).floor());
          }
        },
      );
      await sink.flush();
      await sink.close();
      client.close();
      final filePath = await _publish(tmp, target);
      await _tasks.setProgress(taskId, 95);
      return (filePath, (title: title, artist: artist), null);
    } on Object {
      return (null, (title: title, artist: artist), null);
    }
  }

  /// 发布：私有缓存 → 音乐目录。
  ///
  /// 共享存储里可能残留异主文件（App 重装后旧 uid 拥有的同名件）：
  /// 直接写会在 FUSE 层挂死——先删（自己写的能删），删不掉换唯一名。
  /// 跨卷 rename 失败（EXDEV）回退 copy。
  Future<String> _publish(String tmpPath, String target) async {
    final t = File(target);
    if (t.existsSync()) {
      try {
        t.deleteSync();
      } on Object {
        final dot = target.lastIndexOf('.');
        final alt = dot > 0
            ? '${target.substring(0, dot)}-${DateTime.now().millisecondsSinceEpoch}${target.substring(dot)}'
            : '$target-${DateTime.now().millisecondsSinceEpoch}';
        return _publish(tmpPath, alt);
      }
    }
    final src = File(tmpPath);
    try {
      return (await src.rename(target)).path;
    } on Object {
      await src.copy(target);
      await src.delete();
      return target;
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

