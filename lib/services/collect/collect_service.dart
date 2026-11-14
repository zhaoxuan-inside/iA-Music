/// 收集执行服务：GitHub 歌单任务队列的真实处理。
///
/// * 直链音频（source=direct 且 URL 可下载）→ HTTP 下载到音乐目录根 →
///   触发该目录增量重扫（真实入库）→ 挂歌词 + 归歌单 → done。
/// * 平台页面（bilibili/youtube 等）→ blocked（待二期提取引擎接 yt-dlp）。
/// * 三分离：这里只有真实下载与真实数据库写入，无任何预置内容。
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../data/database.dart';
import '../../domain/entities/track.dart';
import '../../data/daos/collect_dao.dart';
import '../scan/scan_service.dart';

enum CollectPhase { idle, running }

class CollectRunner {
  CollectRunner(this._db, this._scan, {required this.cacheDir});

  final IaDatabase _db;
  final ScanService _scan;
  final String cacheDir;

  CollectPhase phase = CollectPhase.idle;

  CollectDao get _tasks => _db.collectDao;
  PlaylistDao get _playlists => _db.playlistDao;

  /// 处理一轮队列（顺序执行 pending 任务；重复调用安全——运行中直接返回）。
  Future<void> runOnce() async {
    if (phase == CollectPhase.running) {
      return;
    }
    phase = CollectPhase.running;
    try {
      final pending = await _tasks.pendingOrRunning();
      for (final t in pending) {
        if (t.status == CollectStatusCol.running) {
          continue;
        }
        await _process(t.id, t.source, t.url, t.title, t.artist, t.lyricsPath,
            t.playlistId);
      }
    } finally {
      phase = CollectPhase.idle;
    }
  }

  Future<void> _process(
    int id,
    String source,
    String url,
    String title,
    String artist,
    String? lyricsPath,
    int? playlistId,
  ) async {
    if (source != 'direct') {
      // 平台页面：待二期提取引擎（yt-dlp）接入；保持可见、明确 blocked。
      await _tasks.setStatus(id, CollectStatusCol.blocked);
      return;
    }
    final root = await _firstRoot();
    if (root == null) {
      // 未配置音乐目录：保持 pending，等目录就绪后重跑。
      return;
    }
    await _tasks.setStatus(id, CollectStatusCol.running);
    try {
      final filePath = '${root.path}/$title-$artist-${id.hashCode}.audio';
      final ok = await _download(url, filePath, id);
      if (!ok) {
        await _tasks.setStatus(id, CollectStatusCol.failed);
        return;
      }
      // 增量重扫：真实入库（复用扫描链路，音乐目录为根）
      await _scan.scanRoot(root.id, root.path);
      // 关联歌词（拉取时已落盘）
      if (lyricsPath != null) {
        final track = await _trackByPath(filePath);
        if (track != null) {
          await _db.lyricsDao.upsert(
            track.id,
            LyricsMetaCompanion.insert(
              trackId: Value(track.id),
              kind: const Value('online'),
              lrcPath: Value(lyricsPath),
            ),
          );
        }
      }
      // 归歌单
      if (playlistId != null) {
        final track = await _trackByPath(filePath);
        if (track != null) {
          await _playlists.addTrack(playlistId, track.id);
          final pl = await (_db.select(_db.playlists)
                ..where((x) => x.id.equals(playlistId)))
              .getSingleOrNull();
          if (pl != null && pl.pending > 0) {
            await (_db.update(_db.playlists)..where((x) => x.id.equals(playlistId)))
                .write(PlaylistsCompanion(pending: Value(pl.pending - 1)));
          }
        }
      }
      await _tasks.setStatus(id, CollectStatusCol.done, filePath: filePath);
    } on Object {
      await _tasks.setStatus(id, CollectStatusCol.failed);
    }
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

  /// HTTP 下载到 [filePath]，进度回写任务表。
  Future<bool> _download(String url, String filePath, int taskId) async {
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) {
        client.close();
        return false;
      }
      final total = res.contentLength;
      final sink = File(filePath).openWrite();
      var received = 0;
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          await _tasks.setProgress(taskId, (received / total * 90).floor());
        }
      }
      await sink.flush();
      await sink.close();
      client.close();
      await _tasks.setProgress(taskId, 100);
      return true;
    } on Object {
      return false;
    }
  }
}
