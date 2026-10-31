/// LibraryHub —— 仓库管理/扫描/监听协调器（S2 纵切装配点；壳层与页面共用）。
///
/// 职责：
/// * `addRepositoryAndScan`：插根行（path 唯一，重复 → StateError）→
///   挂 Watcher（先挂防竞态：扫描期到达的事件排 `_dirty` 补扫）→
///   全量扫描（ScanProgress=实时计数流；ScanDone=终态）→ 返回终态报告。
/// * `events`：扫描事件广播（ScanProgress/ScanDone 含 watcher 增量报告副本）。
/// * `rescanNow`：显式再扫（REQ-LIB-05 锚「触发下一次扫描」）。
/// * `dispose`：停全部 watcher（持有真事件流，勿泄漏）。
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:ia_music/adapters/android_downloader_adapter.dart';
import 'package:ia_music/adapters/bilibili_auth_adapter.dart';
import 'package:ia_music/adapters/bilibili_client.dart';
import 'package:ia_music/adapters/bilibili_search_adapter.dart';
import 'package:ia_music/adapters/cover_fetch_adapter.dart';
import 'package:ia_music/adapters/downloader_adapter.dart';
import 'package:ia_music/adapters/lrclib_adapter.dart';
import 'package:ia_music/adapters/netease_lyric_search.dart';
import 'package:ia_music/adapters/subtitle_adapter.dart';
import 'package:ia_music/extract/extract_queue.dart';
import 'package:ia_music/library/cover_chain.dart';
import 'package:ia_music/library/enrich_service.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/library/library_service.dart';
import 'package:ia_music/scan/root_watcher.dart';
import 'package:ia_music/scan/scan_service.dart';

final class LibraryHub {
  LibraryHub(this._db)
      : _scan = ScanService(db: _db),
        _lib = LibraryService(db: _db),
        _dao = DataAccess(_db).library {
    _events = StreamController.broadcast();
  }

  final IaDatabase _db;
  final ScanService _scan;
  final LibraryService _lib;
  final LibraryDao _dao;

  final CoverFetchAdapter _coverFetch = CoverFetchAdapter();
  late final CoverChain covers = CoverChain(data, _coverFetch);

  // ── 识别修正域（2026-10-30：本地扫描曲目歌名/歌词/封面自动修正） ──────
  final LrclibAdapter _lrclib = LrclibAdapter();
  final NetEaseLyricSearch _netease = NetEaseLyricSearch();

  /// 层级兜底（LRCLIB→网易→ASR）；tier3 委托 extract.lyrics（B 站链路全
  /// 托管，含其自身 onTrackEnriched）——两者皆 late final，首次触达均装配。
  late final EnrichService enrich = EnrichService(
    db: _db,
    lrclib: _lrclib,
    songSearch: _netease,
    asrFallback: (trackId) => extract.lyrics.runForTrack(trackId),
    onTrackEnriched: _onTrackEnriched,
  );

  /// S6 提取域（会话生命周期=壳层；串行队列+真实 Process 下载）。
  /// hasLoginCookies：B 站登录 Cookie 门（任务/解析自动携 Cookie=登录音质）。
  /// subtitles 注入共享 BilibiliClient：字幕通道二（player API 直达 CC/AI
  /// 字幕，登录态随池）——此前仅 yt-dlp 字幕面，AI 字幕能力悬空。
  late final ExtractQueue extract =
      ExtractQueue(
          db: _db,
          downloader: Platform.isAndroid
              ? AndroidDownloaderAdapter()
              : DownloaderAdapter(),
          hasLoginCookies: _hasBiliLoginCookies,
          subtitles:
              Platform.isAndroid ? null : SubtitleAdapter(bilibili: biliClient),
          onTrackEnriched: _onTrackEnriched);

  // ── B 站域（搜索/登录共用单 Cookie 池；SecureStore 唯一持久化面） ──────
  late final BilibiliClient biliClient = BilibiliClient();
  late final BilibiliSearchAdapter searchAdapter =
      BilibiliSearchAdapter(client: biliClient);
  late final BilibiliAuthAdapter authAdapter =
      BilibiliAuthAdapter(client: biliClient);

  /// 歌词反查命中改轨后：bump revision（列表刷新歌名）+ 封面按新身份重取
  /// （CoverChain 未命中不缓存 → 下次 decide 即按新歌名/歌手在线取封面）。
  void _onTrackEnriched(int trackId) {
    _bump();
    unawaited(covers.decide(trackId));
  }

  Future<bool> _hasBiliLoginCookies() async {
    await biliClient.ensureBootstrapped();
    return biliClient.hasLoginCookie;
  }

  /// 数据门面直通（S3 播放域/设置清空等页面级消费；DAO 聚合一次性注入）。
  /// 单例：此前每次访问都新建 DataAccess/DAO 实例（无谓 churn，且页面间
  /// 拿到不同实例让 identity 判断失效）。
  late final DataAccess _data = DataAccess(_db);
  DataAccess get data => _data;

  /// 页面/壳层装配访问器（hub=组合根；持有 DAO 与域服务）。
  LibraryDao get dao => _dao;
  LibraryService get library => _lib;

  /// 页面快照取数（edit/remove/scan 后由 revisions 事件驱动重取）。
  Future<List<RepositoryRoot>> rootsSnapshot() => _dao.rootsSnapshot();
  Future<List<Track>> trackRowsSnapshot(LibSort sort) => _dao.liveTracksOnce(sort);

  late final StreamController<ScanEvent> _events;
  Stream<ScanEvent> get events => _events.stream;

  /// 页面刷新事件源（revision：任何库态变化自增）——ake watch 流替代形态，
  /// 实测 FakeAsync 下 drift watch 流与运行时副作用互相拖挂（scan 挂死已
  /// 实证）——页面一律「revision 事件 → Future 重取快照」消费数据。
  final StreamController<int> _revisions = StreamController.broadcast();
  int _revCounter = 0;
  Stream<int> get revisions => _revisions.stream;

  /// 扫描进度 bump 节流（进度事件=每处理一个文件一条——万曲库扫描期间
  /// 每次 bump 都引发全列表重查；终态/其他域 bump 不节流）。
  static const _progressBumpIntervalMs = 250;
  int _lastProgressBumpMs = -_progressBumpIntervalMs;

  void _bump() {
    _revCounter++;
    if (!_revisions.isClosed) {
      _revisions.add(_revCounter);
    }
  }

  void _bumpThrottled() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProgressBumpMs < _progressBumpIntervalMs) {
      return;
    }
    _lastProgressBumpMs = now;
    _bump();
  }

  /// T9B（IMPL-S6 §8.7）事件域接线（2026-10-19）：提取注册 = 库态变化 →
  /// revision bump → 曲库快照重取。热刷新缺口实证：100 分 P 全量跑完后，
  /// 曲库热读仍停在 2 首（事件域原只挂 scan/edit/remove），冷启动才全真 100 首。
  /// 调用点=main 装配（extract 为 late final，构造期不可订阅）。
  void wireExtractRevisionToRevisions() {
    extract.events.listen((ev) {
      if (ev is ExtractRegistered) {
        _bump();
      }
    });
  }

  final Map<int, RootWatcher> _watchers = {};
  final Map<int, StreamSubscription<ScanReport>> _watcherSubs = {};

  /// 挂 watcher 并常驻接线（REQ-LIB-02 入库即见）：增量终态与全量终态同流 +
  /// 新增轨自动入队识别修正。订阅随 hub 生命周期（dispose 统一停）——
  /// 此前挂在 addRepositoryAndScan 内、初始全量扫描完即 cancel，此后
  /// watcher 增量报告无人消费（实证缺口，一并修复）。
  Future<void> _attachWatcher(int rootId, String path) async {
    final watcher = RootWatcher(
      db: _db,
      scanService: _scan,
      rootId: rootId,
      rootPath: path,
    );
    _watchers[rootId] = watcher;
    _watcherSubs[rootId] = watcher.reports.listen((r) {
      if (!_events.isClosed) {
        _events.add(ScanDone(r)); // 增量终态与全量终态同流
      }
      enrich.enqueueAll(r.addedTrackIds);
      _bump();
    });
    await watcher.start();
  }

  /// 启动重挂（2026-10-30 补缺口：_watchers 会话级，重启后既有根不再监听）：
  /// 逐根重建 watcher + **增量补扫**——应用关闭期间盘上新增/变更的文件由
  /// 枚举 diff 入库（addedTrackIds 自动入队识别修正）。
  Future<void> attachWatchers() async {
    final roots = await _dao.rootsSnapshot();
    for (final r in roots) {
      if (_watchers.containsKey(r.id)) {
        continue;
      }
      try {
        await _attachWatcher(r.id, r.path);
        await _runFullScan(r.id, incremental: true);
      } catch (_) {
        // 根目录盘上消失等装配异常：不阻塞其余根（下次 rescan 可恢复）。
      }
    }
  }

  /// 添加仓库并全量扫描（REQ-LIB-01）。
  Future<ScanReport> addRepositoryAndScan(
    String path, {
    void Function(int processed, int admitted, int skipped)? onProgress,
  }) async {
    final existed = await (_db.select(_db.repositoryRoots)
          ..where((r) => r.path.equals(path)))
        .getSingleOrNull();
    if (existed != null) {
      throw StateError('repository already exists: $path');
    }
    final rootId = await _db.into(_db.repositoryRoots).insert(
          RepositoryRootsCompanion.insert(
            path: path,
            mode: RepositoryMode.directory,
            addedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );

    // watcher 先挂（扫描与其后变更的竞态统一由 RootWatcher._dirty 补扫）；
    await _attachWatcher(rootId, path);
    return _runFullScan(rootId, onProgress: onProgress);
  }

  /// 显式全量再扫（REQ-LIB-05「触发下一次扫描」锚位）。
  Future<ScanReport> rescanNow({required int rootId, ScanMode mode = ScanMode.full}) async {
    return _runFullScan(rootId);
  }

  /// 编辑标题（页面入口：域服务 + revision 递增）。
  Future<void> editTrackTitle(int trackId, String newTitle, {required int nowMs}) async {
    await _lib.editTrackTitle(trackId, newTitle, nowMs: nowMs);
    _bump();
  }

  /// 移除（页面入口：域服务 + revision 递增）。
  Future<void> removeTrack(int trackId, {required int nowMs}) async {
    await _lib.removeTrack(trackId, nowMs: nowMs);
    _bump();
  }

  /// 仓库移除（WS2/REQ-ONB-04）：停 watcher → 根内软删+根行删除 → bump。
  /// 音频文件本体不动（总览删除策略红线）。
  Future<void> removeRepository(int rootId, {required int nowMs}) async {
    await _watchers[rootId]?.stop();
    _watchers.remove(rootId);
    await _watcherSubs[rootId]?.cancel();
    _watcherSubs.remove(rootId);
    await _dao.removeRoot(rootId, nowMs);
    _bump();
  }

  /// 手动识别修正（设置页每根按钮）：根内全部活轨入队，返回排队数。
  Future<int> enrichRoot(int rootId) async {
    final rows = await (_db.select(_db.tracks)
          ..where((t) => t.rootId.equals(rootId) & t.deletedAt.isNull()))
        .get();
    enrich.enqueueAll(rows.map((r) => r.id));
    return rows.length;
  }

  /// 扫描事件桥（默认 full；启动补扫=incremental）：进度回调 + 事件广播 +
  /// revision 递增 + **新增轨入队识别修正**（终态返回）。
  Future<ScanReport> _runFullScan(
    int rootId, {
    bool incremental = false,
    void Function(int processed, int admitted, int skipped)? onProgress,
  }) async {
    final events = await _scan
        .scan(rootId: rootId, mode: incremental ? ScanMode.incremental : ScanMode.full)
        .toList();
    final done = events.whereType<ScanDone>().last;
    enrich.enqueueAll(done.report.addedTrackIds);
    for (final e in events) {
      if (!_events.isClosed) {
        _events.add(e);
      }
      // 进度事件节流 bump（终态必 bump=列表最终一致）；实时计数仍全量广播。
      if (e is ScanProgress) {
        _bumpThrottled();
      } else {
        _bump();
      }
      if (e is ScanProgress && onProgress != null) {
        onProgress(e.processed, e.admitted, e.skipped);
      }
    }
    return done.report;
  }

  Future<void> dispose() async {
    await extract.dispose();
    _coverFetch.close();
    _lrclib.close();
    _netease.dispose();
    enrich.dispose();
    biliClient.dispose();
    for (final w in _watchers.values) {
      await w.stop();
    }
    _watchers.clear();
    for (final s in _watcherSubs.values) {
      await s.cancel();
    }
    _watcherSubs.clear();
    await _events.close();
    await _revisions.close();
  }
}
