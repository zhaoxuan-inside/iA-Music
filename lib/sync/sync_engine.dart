/// 同步引擎（WS6/FEAT-SYNC-01 · REQ-SYNC-01..08）。
///
/// 设计口径（sync_prd + DETAILED-DESIGN §3.3/§4.1 + TASK-S8）：
/// * **七态状态机**：IDLE→DEBOUNCE(30s)→PREPARE→TRANSFERRING→(IDLE|PAUSED|
///   NEEDS_REAUTH|SUSPENDED_DISK)；逐态迁移与详设 §4.1 表一致。
/// * **远端布局**（`<remoteDir>/`）：`manifest.json`（relKey→hash/size/updatedAt）、
///   `library.json`（轻数据：track 元数据/歌单/红心/历史）、`tombstones.json`、
///   `audio/<rootBase>/<relPath>`（音频本体；分块断点在 adapter）。
/// * **跨端身份**：track=`<rootBasename>/<relPath>`（+contentHash 复核）；
///   playlist=uuid（schema v3 回填）；history=(relKey, playedAt)。
/// * **冲突**：记录级 last-writer-wins by updatedAt，败者→conflict_copies；
///   歌单文档=last-writer-wins 整体替换（增删随文档传播）；删除只走墓碑。
/// * **红线**：本地数据无损；删除仅传播记录；**远端文件永不因子端删除被删**
///   （SyncChannelPort 无 delete 语义）；凭据只经 SecureStore 引用键。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:contracts/contracts.dart';
import 'package:drift/drift.dart';

import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';

/// 引擎状态（详设 §4.1 七态）。
enum SyncEngineState {
  idle,
  debounce,
  prepare,
  transferring,
  paused,
  needsReauth,
  suspendedDisk,
}

/// 同步触发方式。
enum SyncTrigger { autoDebounce, manual }

/// 同步事件（状态迁移/进度/终态摘要；UI 同步中心消费）。
sealed class SyncEvent {
  const SyncEvent();
}

final class SyncStateChanged extends SyncEvent {
  const SyncStateChanged(this.state, {this.reason});
  final SyncEngineState state;
  final String? reason; // paused/needsReauth 人话原因
}

final class SyncProgressEvent extends SyncEvent {
  const SyncProgressEvent(this.relPath, this.sentBytes, this.totalBytes);
  final String relPath;
  final int sentBytes;
  final int totalBytes;
}

/// 终态摘要（REQ-SYNC-07：成功 N/失败 M 人话面数据）。
class SyncSummary {
  SyncSummary({
    required this.startedAt,
    required this.completedAt,
    this.uploaded = 0,
    this.downloaded = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.tombstonesPushed = 0,
    this.applied,
  });

  final int startedAt;
  int completedAt;
  int uploaded;
  int downloaded;
  int failed;
  int conflicts;
  int tombstonesPushed;

  /// 中断原因（null=完整跑完）。
  String? applied;

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt,
        'completedAt': completedAt,
        'uploaded': uploaded,
        'downloaded': downloaded,
        'failed': failed,
        'conflicts': conflicts,
        'tombstonesPushed': tombstonesPushed,
        'applied': applied,
      };

  static SyncSummary fromJson(Map<String, dynamic> j) => SyncSummary(
        startedAt: (j['startedAt'] as num?)?.toInt() ?? 0,
        completedAt: (j['completedAt'] as num?)?.toInt() ?? 0,
        uploaded: (j['uploaded'] as num?)?.toInt() ?? 0,
        downloaded: (j['downloaded'] as num?)?.toInt() ?? 0,
        failed: (j['failed'] as num?)?.toInt() ?? 0,
        conflicts: (j['conflicts'] as num?)?.toInt() ?? 0,
        tombstonesPushed: (j['tombstonesPushed'] as num?)?.toInt() ?? 0,
        applied: j['applied'] as String?,
      );
}

// ── 轻数据 JSON 文档（远端 library.json/tombstones.json 载荷） ──

final class SyncTrackMeta {
  SyncTrackMeta({
    required this.relKey,
    required this.updatedAt,
    this.hash,
    this.title,
    this.artist,
    this.album,
    this.durationMs,
    this.fileSize,
    this.sourceType,
    this.sourceId,
  });

  final String relKey;
  final int updatedAt;
  final String? hash;
  final String? title;
  final String? artist;
  final String? album;
  final int? durationMs;
  final int? fileSize;
  final String? sourceType;
  final String? sourceId;

  Map<String, dynamic> toJson() => {
        'relKey': relKey,
        'updatedAt': updatedAt,
        if (hash != null) 'hash': hash,
        if (title != null) 'title': title,
        if (artist != null) 'artist': artist,
        if (album != null) 'album': album,
        if (durationMs != null) 'durationMs': durationMs,
        if (fileSize != null) 'fileSize': fileSize,
        if (sourceType != null) 'sourceType': sourceType,
        if (sourceId != null) 'sourceId': sourceId,
      };

  static SyncTrackMeta fromJson(Map<String, dynamic> j) => SyncTrackMeta(
        relKey: j['relKey'] as String,
        updatedAt: (j['updatedAt'] as num).toInt(),
        hash: j['hash'] as String?,
        title: j['title'] as String?,
        artist: j['artist'] as String?,
        album: j['album'] as String?,
        durationMs: (j['durationMs'] as num?)?.toInt(),
        fileSize: (j['fileSize'] as num?)?.toInt(),
        sourceType: j['sourceType'] as String?,
        sourceId: j['sourceId'] as String?,
      );
}

final class SyncPlaylistDoc {
  SyncPlaylistDoc({
    required this.uuid,
    required this.name,
    required this.kind,
    required this.updatedAt,
    required this.deletedAt,
    required this.items,
  });

  final String uuid;
  final String name;
  final String kind; // system_favorite / user
  final int updatedAt;
  final int? deletedAt; // 墓碑传播后的软删时间（对端可读）

  /// 条目=有序 relKey（position 由序承担）。
  final List<String> items;

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'name': name,
        'kind': kind,
        'updatedAt': updatedAt,
        if (deletedAt != null) 'deletedAt': deletedAt,
        'items': items,
      };

  static SyncPlaylistDoc fromJson(Map<String, dynamic> j) => SyncPlaylistDoc(
        uuid: j['uuid'] as String,
        name: j['name'] as String? ?? '',
        kind: j['kind'] as String? ?? 'user',
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
        deletedAt: (j['deletedAt'] as num?)?.toInt(),
        items: [for (final i in (j['items'] as List? ?? const [])) i as String],
      );
}

final class SyncHistoryEntry {
  SyncHistoryEntry({required this.relKey, required this.playedAt, this.completed = true});
  final String relKey;
  final int playedAt;
  final bool completed;

  Map<String, dynamic> toJson() =>
      {'relKey': relKey, 'playedAt': playedAt, 'completed': completed};

  static SyncHistoryEntry fromJson(Map<String, dynamic> j) => SyncHistoryEntry(
        relKey: j['relKey'] as String,
        playedAt: (j['playedAt'] as num).toInt(),
        completed: (j['completed'] as bool?) ?? true,
      );
}

final class SyncLibraryDoc {
  SyncLibraryDoc({
    required this.tracks,
    required this.playlists,
    required this.history,
  });

  final List<SyncTrackMeta> tracks;
  final List<SyncPlaylistDoc> playlists;
  final List<SyncHistoryEntry> history;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'tracks': [for (final t in tracks) t.toJson()],
        'playlists': [for (final p in playlists) p.toJson()],
        'history': [for (final h in history) h.toJson()],
      };

  static SyncLibraryDoc fromJson(Map<String, dynamic> j) => SyncLibraryDoc(
        tracks: [
          for (final t in (j['tracks'] as List? ?? const []))
            SyncTrackMeta.fromJson(t as Map<String, dynamic>)
        ],
        playlists: [
          for (final p in (j['playlists'] as List? ?? const []))
            SyncPlaylistDoc.fromJson(p as Map<String, dynamic>)
        ],
        history: [
          for (final h in (j['history'] as List? ?? const []))
            SyncHistoryEntry.fromJson(h as Map<String, dynamic>)
        ],
      );
}

/// 墓碑远端记录（跨端身份=relKey/uuid，非本地 id）。
final class SyncTombstone {
  SyncTombstone({
    required this.kind,
    required this.identity,
    required this.deletedAt,
  });
  final String kind; // track/playlist/playlist_item/few_watch/lyrics_meta
  final String identity; // track=relKey；playlist=uuid；playlist_item=uuid|relKey
  final int deletedAt;

  Map<String, dynamic> toJson() =>
      {'kind': kind, 'identity': identity, 'deletedAt': deletedAt};

  static SyncTombstone fromJson(Map<String, dynamic> j) => SyncTombstone(
        kind: j['kind'] as String,
        identity: j['identity'] as String,
        deletedAt: (j['deletedAt'] as num).toInt(),
      );
}

/// 同步引擎。
final class SyncEngine {
  SyncEngine({
    required IaDatabase db,
    required this.port,
    this.remoteDir = 'iA-Music/',
    this.audioChunk = const ChunkPlan(),
  }) : _db = db {
    _data = DataAccess(db);
  }

  final IaDatabase _db;
  late final DataAccess _data;
  final SyncChannelPort port;
  final String remoteDir;
  final ChunkPlan audioChunk;

  static const debounceMs = 30000; // REQ-SYNC-02：变更后 30s 防抖

  SyncEngineState _state = SyncEngineState.idle;
  Timer? _debounceTimer;
  bool _running = false;
  final _events = StreamController<SyncEvent>.broadcast();
  Stream<SyncEvent> get events => _events.stream;
  SyncEngineState get state => _state;

  void _setState(SyncEngineState s, {String? reason}) {
    _state = s;
    if (!_events.isClosed) {
      _events.add(SyncStateChanged(s, reason: reason));
    }
  }

  /// 本地变更喂点（服务域写入后回调；30s 防抖 REQ-SYNC-02）。
  void notifyLocalChange() {
    if (_running || _state == SyncEngineState.transferring) {
      return;
    }
    _debounceTimer?.cancel();
    _setState(SyncEngineState.debounce);
    _debounceTimer = Timer(const Duration(milliseconds: debounceMs), () {
      unawaited(run(SyncTrigger.autoDebounce));
    });
  }

  /// 立即同步（REQ-SYNC-07 手动面）。
  Future<SyncSummary> run(SyncTrigger trigger) async {
    _debounceTimer?.cancel();
    if (_running) {
      return SyncSummary(startedAt: 0, completedAt: _nowMs(), applied: 'already-running');
    }
    _running = true;
    final summary = SyncSummary(startedAt: _nowMs(), completedAt: 0);
    final channel = await _data.sync.currentChannel();
    if (channel == null) {
      summary.applied = 'no-channel';
      _setState(SyncEngineState.idle);
      _running = false;
      return summary;
    }
    try {
      // PREPARE：本地装配 ↔ 远端清单（REQ-SYNC-01 前置=通道已测存）
      _setState(SyncEngineState.prepare);
      final localDoc = await _buildLocalDoc();
      final localManifest = LocalManifest(entries: [
        for (final t in localDoc.tracks)
          if (t.hash != null)
            ManifestEntry(relPath: t.relKey, updatedAtMs: t.updatedAt, hash: t.hash),
      ]);
      // 音频差集的权威来源=manifest.json（远端清单只含音频 relKey；
      // 通道目录里的引擎 json 不进 diff 命名空间）。
      final remoteManifest = await _getJson('manifest.json');
      final remoteEntries = <String, ManifestEntry>{
        for (final e in (remoteManifest['entries'] as List? ?? const []))
          ((e as Map<String, dynamic>)['relPath'] as String): ManifestEntry(
            relPath: e['relPath'] as String,
            updatedAtMs: (e['updatedAtMs'] as num?)?.toInt() ?? 0,
            hash: e['hash'] as String?,
          ),
      };
      // port.diff=契约 PREPARE 面（通道实链路演练；决策以 manifest 为准）。
      await port.diff(remoteDir, localManifest);
      final localSet = <String>{for (final e in localManifest.entries) e.relPath};

      // 远端库快照（PREPARE 期取——本端 push 在 merge 前会覆盖远端，
// 必须先取快照再推）。
      final remoteLibraryRaw = await _getJson('library.json');
      // TRANSFERRING
      _setState(SyncEngineState.transferring);
      await _pushLibrary(localDoc);
      summary.uploaded++;

      // 音频上传：本地有+远端无（新入库/提取产物）
      for (final relKey in localSet.difference(remoteEntries.keys.toSet())) {
        final file = await _resolveLocalAudio(relKey);
        if (file == null || !file.existsSync()) {
          continue;
        }
        final ok = await _putAudio(file, relKey, summary);
        if (ok) {
          summary.uploaded++;
        } else {
          summary.failed++;
        }
      }

      // 音频下载：远端有+本地无（REQ-SYNC-03：另一端下载后可直接播放）
      final imported = <String>[];
      for (final relKey in remoteEntries.keys.toSet().difference(localSet)) {
        final bytes = await port.getFile(_rp('audio/$relKey'));
        if (bytes != null) {
          final saved = await _saveAudioFile(relKey, bytes);
          if (saved != null) {
            imported.add(saved);
            summary.downloaded++;
          }
        } else {
          summary.failed++;
        }
      }

      // 轻数据合并（REQ-SYNC-02/04/05；含墓碑双向传播）
      summary.conflicts += await _mergeRemoteLibrary(localDoc, remoteLibraryRaw);
      await _pushManifest(localManifest, summary);

      // 终态：摘要落库（REQ-SYNC-07）
      summary.completedAt = _nowMs();
      await _data.sync.upsertLastSync(
        channelId: channel.id,
        pendingUp: summary.uploaded,
        pendingDown: summary.downloaded,
        summaryJson: jsonEncode(summary.toJson()),
        lastStartedAt: summary.startedAt,
        nowMs: _nowMs(),
      );
      _setState(SyncEngineState.idle);
      if (imported.isNotEmpty && _onFilesImported != null) {
        await _onFilesImported!(imported);
      }
    } on NetworkLostException catch (e) {
      // REQ-SYNC-06：断网=暂停明示原因；本地无损
      summary.applied = 'paused';
      summary.completedAt = _nowMs();
      _setState(SyncEngineState.paused, reason: e.message);
    } on ChannelAuthFailedException catch (e) {
      summary.applied = 'reauth';
      summary.completedAt = _nowMs();
      _setState(SyncEngineState.needsReauth, reason: e.message);
    } on DiskFullException catch (e) {
      summary.applied = 'disk';
      summary.completedAt = _nowMs();
      _setState(SyncEngineState.suspendedDisk, reason: e.message);
    } finally {
      _running = false;
      if (!_events.isClosed) {
        _events.add(SyncProgressEvent('', 0, 0)); // 终态信号占位（UI 刷新）
      }
    }
    return summary;
  }

  /// 音频落盘后的导入回调（下载到本地根 → 触发增量扫描入库）。
  Future<void> Function(List<String> absolutePaths)? _onFilesImported;
  set onFilesImported(Future<void> Function(List<String>)? cb) =>
      _onFilesImported = cb;

  // ── 装配/推送面 ─────────────────────────────────────────

  Future<Map<int, RepositoryRoot>> _roots() async => {
        for (final r in await _data.library.rootsSnapshot()) r.id: r
      };

  String _rootBase(String path) =>
      path.replaceAll('\\', '/').split('/').where((s) => s.isNotEmpty).last;

  /// 本地轻数据装配（tracks 元数据/歌单[uuid]/红心/历史）。
  Future<SyncLibraryDoc> _buildLocalDoc() async {
    final roots = await _roots();
    final trackRows = await (_db.select(_db.tracks)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final tracks = <SyncTrackMeta>[];
    for (final t in trackRows) {
      final root = roots[t.rootId];
      if (root == null) {
        continue;
      }
      tracks.add(SyncTrackMeta(
        relKey: '${_rootBase(root.path)}/${t.relPath}',
        updatedAt: t.updatedAt,
        hash: t.contentHash,
        title: t.title,
        artist: t.artistDisplay,
        album: t.albumDisplay,
        durationMs: t.durationMs,
        fileSize: t.fileSize,
        sourceType: t.sourceType,
        sourceId: t.sourceId,
      ));
    }
    final playlistRows = await (_db.select(_db.playlists)
          ..where((p) => p.deletedAt.isNull()))
        .get();
    final playlists = <SyncPlaylistDoc>[];
    for (final p in playlistRows) {
      final items = <String>[];
      final browsed = await _data.playlists.browse(p.id);
      for (final (_, tr) in browsed) {
        final root = roots[tr.rootId];
        if (root != null) {
          items.add('${_rootBase(root.path)}/${tr.relPath}');
        }
      }
      playlists.add(SyncPlaylistDoc(
        uuid: p.uuid ?? '${p.id}',
        name: p.name,
        kind: p.kind.name,
        updatedAt: p.updatedAt,
        deletedAt: p.deletedAt,
        items: items,
      ));
    }
    // 历史=最近 500（cap 与本地淘汰一致；远端合并按 (relKey, playedAt) 去重）
    final histRows = await _data.history.historyPage(page: 0, pageSize: 500);
    final roots2 = await _roots();
    final trackById = {for (final t in trackRows) t.id: t};
    final history = <SyncHistoryEntry>[];
    for (final (rec, tr) in histRows) {
      final row = trackById[tr.id] ?? tr;
      final root = roots2[row.rootId];
      if (root != null) {
        history.add(SyncHistoryEntry(
          relKey: '${_rootBase(root.path)}/${row.relPath}',
          playedAt: rec.playedAt,
          completed: rec.completed,
        ));
      }
    }
    return SyncLibraryDoc(tracks: tracks, playlists: playlists, history: history);
  }

  Future<void> _pushLibrary(SyncLibraryDoc doc) async {
    await _putSmall(
        'library.json',
        Uint8List.fromList(utf8.encode(jsonEncode(doc.toJson()))));
  }

  /// 小文件写入（port.putFile=Stream 面 → 订阅至 Done/Failed 收口）。
  /// 远端路径拼装（remoteDir 前缀；契约 Port 不感知通道目录约定）。
  String _rp(String path) =>
      remoteDir.isEmpty ? path : '${remoteDir.replaceAll(RegExp(r"/+"), "")}/$path';

  Future<void> _putSmall(String remotePath, Uint8List bytes) async {
    final completer = Completer<bool>();
    final sub = port.putFile(_rp(remotePath), bytes).listen((ev) {
      switch (ev) {
        case TransferDone():
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        case TransferFailed():
        case TransferPaused():
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        default:
          break;
      }
    }, onError: (Object e) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }, onDone: () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });
    try {
      await completer.future.timeout(const Duration(minutes: 5));
    } on TimeoutException {
      // 小文件 5s 超时上限远未到——网络级挂死兜底（失败计入 failed 由调用方看）
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _pushManifest(LocalManifest local, SyncSummary summary) async {
    // 墓碑出站：pendingTombstones → 跨端身份 → 合并远端 tombstones.json
    final pending = await _data.sync.pendingTombstones(limit: 500);
    final remoteRaw = await _getJson('tombstones.json');
    final remoteTombs = <String, SyncTombstone>{};
    for (final raw in (remoteRaw['tombstones'] as List? ?? const [])) {
      final t = SyncTombstone.fromJson(raw as Map<String, dynamic>);
      remoteTombs[_tombKey(t)] = t;
    }
    final roots = await _roots();
    final cleared = <int>[];
    for (final tomb in pending) {
      final identity = await _identityOf(tomb, roots);
      if (identity == null) {
        continue; // 身份解析失败（根被移除等）——保留待下次
      }
      final st = SyncTombstone(
          kind: tomb.entityKind.name, identity: identity, deletedAt: tomb.deletedAt);
      final key = _tombKey(st);
      final old = remoteTombs[key];
      if (old == null || old.deletedAt < st.deletedAt) {
        remoteTombs[key] = st;
      }
      cleared.add(tomb.id);
    }
    summary.tombstonesPushed = cleared.length;
    await _putSmall(
        'tombstones.json',
        Uint8List.fromList(utf8.encode(jsonEncode({
          'tombstones': [for (final t in remoteTombs.values) t.toJson()],
        }))));
    if (cleared.isNotEmpty) {
      await _data.sync.markTombstoneRemoteCleared(cleared, _nowMs());
    }
    // manifest 出站（音频清单；REQ-SYNC-03 diff 底册）
    await _putSmall(
        'manifest.json',
        Uint8List.fromList(utf8.encode(jsonEncode({
          'entries': [
            for (final e in local.entries)
              {'relPath': e.relPath, 'updatedAtMs': e.updatedAtMs, 'hash': e.hash},
          ],
        }))));
  }

  String _tombKey(SyncTombstone t) => '${t.kind}|${t.identity}';

  /// 本地墓碑 → 跨端身份（track=relKey；playlist=uuid；其余按域）。
  Future<String?> _identityOf(
      Tombstone tomb, Map<int, RepositoryRoot> roots) async {
    switch (tomb.entityKind) {
      case TombstoneKind.track:
        final row = await (_db.select(_db.tracks)
              ..where((t) => t.id.equals(tomb.entityLocalId)))
            .getSingleOrNull();
        final root = row == null ? null : roots[row.rootId];
        return row == null || root == null
            ? null
            : '${_rootBase(root.path)}/${row.relPath}';
      case TombstoneKind.playlist:
        final row = await (_db.select(_db.playlists)
              ..where((p) => p.id.equals(tomb.entityLocalId)))
            .getSingleOrNull();
        return row?.uuid;
      case TombstoneKind.playlist_item:
        return null; // 条目移除随歌单文档整体替换语义传播（无独立墓碑）
      case TombstoneKind.few_watch:
        final row = await (_db.select(_db.tracks)
              ..where((t) => t.id.equals(tomb.entityLocalId)))
            .getSingleOrNull();
        final root = row == null ? null : roots[row.rootId];
        return row == null || root == null
            ? null
            : '${_rootBase(root.path)}/${row.relPath}';
      case TombstoneKind.lyrics_meta:
        return null; // 歌词随音频旁车文件走音频通道
    }
  }

  /// 远端轻数据合并（REQ-SYNC-02 下行 + REQ-SYNC-04 冲突 + 墓碑下行应用）。
  /// [remoteRaw]=PREPARE 期快照（本端 push 先于 merge，实时读会是自己的 doc）。
  Future<int> _mergeRemoteLibrary(
      SyncLibraryDoc localDoc, Map<String, dynamic> remoteRaw) async {
    var conflicts = 0;
    if (remoteRaw.isEmpty) {
      return 0;
    }
    final remoteDoc = SyncLibraryDoc.fromJson(remoteRaw);
    final roots = await _roots();

    // ① 轨元数据：relKey 命中本地（同一 rootBase+relPath）→ 远端新则回写展示字段
    await _refreshTrackCache();
    final localByKey = <String, Track>{};
    for (final t in localDoc.tracks) {
      final row = _trackByRelKey(t.relKey, roots);
      if (row != null) {
        localByKey[t.relKey] = row;
      }
    }
    for (final rt in remoteDoc.tracks) {
      final local = localByKey[rt.relKey];
      if (local == null) {
        continue; // 本地无该轨（音频未到）——待音频下载后由扫描入库
      }
      if (rt.updatedAt <= local.updatedAt) {
        continue;
      }
      // last-writer-wins：远端新=胜者；本地值保全为冲突副本（REQ-SYNC-04）
      final loser = jsonEncode({
        'title': local.title,
        'artist': local.artistDisplay,
        'album': local.albumDisplay,
        'updatedAt': local.updatedAt,
      });
      final winner = jsonEncode({
        'title': rt.title,
        'artist': rt.artist,
        'album': rt.album,
        'updatedAt': rt.updatedAt,
      });
      await _data.sync.recordConflict(
        originKind: 'track',
        originLocalId: local.id,
        winnerValueJson: winner,
        loserPayloadJson: loser,
        nowMs: _nowMs(),
      );
      conflicts++;
      await (_db.update(_db.tracks)..where((t) => t.id.equals(local.id))).write(
        TracksCompanion(
          title: rt.title == null ? const Value.absent() : Value(rt.title),
          artistDisplay:
              rt.artist == null ? const Value.absent() : Value(rt.artist),
          albumDisplay:
              rt.album == null ? const Value.absent() : Value(rt.album),
          updatedAt: Value(rt.updatedAt),
        ),
      );
    }

    // ② 歌单：uuid 键控 last-writer-wins（updatedAt；删除走 deletedAt）
    for (final rp in remoteDoc.playlists) {
      final localRows = await (_db.select(_db.playlists)
            ..where((p) => p.uuid.equals(rp.uuid)))
          .get();
      final lp = localRows.firstOrNull;
      if (lp == null) {
        // 远端新歌单（REQ-SYNC-02 下行）→ 本地重建（条目=并集骨架；曲目按 relKey 解析）
        final now = _nowMs();
        final id = await _db.into(_db.playlists).insert(
              PlaylistsCompanion.insert(
                kind:
                    rp.kind == 'system_favorite' ? PlaylistKind.system_favorite : PlaylistKind.user,
                name: rp.name,
                uuid: Value(rp.uuid),
                createdAt: now,
                updatedAt: rp.updatedAt,
              ),
            );
        await _applyPlaylistItems(id, rp.items, roots);
        continue;
      }
      if (rp.updatedAt <= lp.updatedAt) {
        continue; // 本地新或相等=本地胜（下行无操作）
      }
      if (lp.kind == PlaylistKind.system_favorite) {
        // 红心系统歌单：只并集条目，不改名/不软删
        await _applyPlaylistItems(lp.id, rp.items, roots);
        continue;
      }
      if (rp.deletedAt != null && lp.deletedAt == null) {
        // 远端删除传播（墓碑已保证；此处兜底软删）
        await _data.playlists.softDeletePlaylist(lp.id, rp.deletedAt!);
        continue;
      }
      // 名称冲突=last-writer-wins（败者保全）
      if (lp.name != rp.name) {
        await _data.sync.recordConflict(
          originKind: 'playlist',
          originLocalId: lp.id,
          winnerValueJson: jsonEncode({'name': rp.name, 'updatedAt': rp.updatedAt}),
          loserPayloadJson:
              jsonEncode({'name': lp.name, 'updatedAt': lp.updatedAt}),
          nowMs: _nowMs(),
        );
        conflicts++;
      }
      await (_db.update(_db.playlists)..where((p) => p.id.equals(lp.id))).write(
        PlaylistsCompanion(
          name: Value(rp.name),
          updatedAt: Value(rp.updatedAt),
        ),
      );
      await _applyPlaylistItems(lp.id, rp.items, roots);
    }

    // ③ 历史：按 (relKey, playedAt) 去重插入（播放记录无冲突语义）
    final localHistKeys = <String>{
      for (final h in localDoc.history) '${h.relKey}@${h.playedAt}',
    };
    final trackByRelKey = <String, Track>{};
    for (final rt in remoteDoc.tracks) {
      final t = _trackByRelKey(rt.relKey, roots);
      if (t != null) {
        trackByRelKey[rt.relKey] = t;
      }
    }
    for (final h in remoteDoc.history) {
      final key = '${h.relKey}@${h.playedAt}';
      if (localHistKeys.contains(key)) {
        continue;
      }
      final tr = trackByRelKey[h.relKey];
      if (tr == null) {
        continue;
      }
      await _data.history.record(
          trackId: tr.id,
          completed: h.completed,
          deviceId: 'sync',
          nowMs: h.playedAt);
    }

    // ④ 墓碑下行：远端删除 → 本地软删（远端文件不动——红线）
    final remoteRaw2 = await _getJson('tombstones.json');
    for (final t in remoteRaw2['tombstones'] ?? <dynamic>[]) {
      final tomb = SyncTombstone.fromJson(t as Map<String, dynamic>);
      if (tomb.kind == 'track') {
        final tr = _trackByRelKey(tomb.identity, roots);
        if (tr != null && tr.deletedAt == null) {
          await _data.library.softDeleteTrack(tr.id, tomb.deletedAt);
        }
      } else if (tomb.kind == 'playlist') {
        final rows = await (_db.select(_db.playlists)
              ..where((p) => p.uuid.equals(tomb.identity)))
            .get();
        for (final p in rows) {
          if (p.deletedAt == null && p.kind != PlaylistKind.system_favorite) {
            await _data.playlists.softDeletePlaylist(p.id, tomb.deletedAt);
          }
        }
      } else if (tomb.kind == 'few_watch') {
        final tr = _trackByRelKey(tomb.identity, roots);
        if (tr != null) {
          await _data.history.removeFewWatch(tr.id);
        }
      }
    }
    return conflicts;
  }

  /// 歌单条目**整体替换**（last-writer-wins 语义：胜者文档全量生效，
  /// 增删均随文档传播；败者已在冲突面保全）。远端未解析的 relKey 跳过
  /// （音频未到本地——待后续同步补齐）。
  Future<void> _applyPlaylistItems(
      int playlistId, List<String> items, Map<int, RepositoryRoot> roots) async {
    final resolved = <int>[];
    for (final relKey in items) {
      final tr = _trackByRelKey(relKey, roots);
      if (tr != null) {
        resolved.add(tr.id);
      }
    }
    await _data.playlists.reorder(playlistId, orderedTrackIds: resolved, nowMs: _nowMs());
    // 现有条目中不在胜者清单里的 → 移除（doc 全量语义）
    final current = await _data.playlists.browse(playlistId);
    final keep = resolved.toSet();
    for (final (_, tr) in current) {
      if (!keep.contains(tr.id)) {
        await _data.playlists.removeTrack(playlistId, tr.id);
      }
    }
  }

  /// relKey → 本地轨行（rootBase=根目录 basename 匹配；找不到=首个根兜底）。
  Track? _trackByRelKey(String relKey, Map<int, RepositoryRoot> roots) {
    final idx = relKey.indexOf('/');
    if (idx <= 0) {
      return null;
    }
    final base = relKey.substring(0, idx);
    final rel = relKey.substring(idx + 1);
    RepositoryRoot? root;
    for (final r in roots.values) {
      if (_rootBase(r.path) == base) {
        root = r;
        break;
      }
    }
    root ??= roots.values.firstOrNull;
    if (root == null) {
      return null;
    }
    return _trackCache['${root.id}|$rel'];
  }

  final Map<String, Track> _trackCache = {};

  Future<void> _refreshTrackCache() async {
    _trackCache.clear();
    final rows = await (_db.select(_db.tracks)).get();
    for (final t in rows) {
      _trackCache['${t.rootId}|${t.relPath}'] = t;
    }
  }

  /// 本地音频文件解析（relKey → 绝对路径）。
  Future<File?> _resolveLocalAudio(String relKey) async {
    await _refreshTrackCache();
    final idx = relKey.indexOf('/');
    if (idx <= 0) {
      return null;
    }
    final base = relKey.substring(0, idx);
    final rel = relKey.substring(idx + 1);
    final roots = await _roots();
    for (final r in roots.values) {
      if (_rootBase(r.path) == base) {
        return File(PlaybackPath.join(r.path, rel));
      }
    }
    return null;
  }

  /// 下载音频落盘（进首个本地根的对应相对路径；REQ-SYNC-03）。
  Future<String?> _saveAudioFile(String relKey, Uint8List bytes) async {
    final idx = relKey.indexOf('/');
    if (idx <= 0) {
      return null;
    }
    final base = relKey.substring(0, idx);
    final rel = relKey.substring(idx + 1);
    final roots = await _roots();
    if (roots.isEmpty) {
      return null;
    }
    RepositoryRoot? root;
    for (final r in roots.values) {
      if (_rootBase(r.path) == base) {
        root = r;
        break;
      }
    }
    root ??= roots.values.first;
    final f = File(PlaybackPath.join(root.path, rel));
    try {
      f.createSync(recursive: true);
      f.writeAsBytesSync(bytes, flush: true);
      return f.path;
    } on FileSystemException {
      return null; // 磁盘/权限失败计入 failed（本地无损）
    }
  }

  Future<bool> _putAudio(File file, String relPath, SyncSummary summary) async {
    final completer = Completer<bool>();
    StreamSubscription<TransferEvent>? sub;
    sub = port
        .putFile(_rp('audio/$relPath'), file.readAsBytesSync(),
            chunked: audioChunk)
        .listen((ev) {
      switch (ev) {
        case TransferProgress(:final sentBytes, :final totalBytes):
          if (!_events.isClosed) {
            _events.add(SyncProgressEvent(relPath, sentBytes, totalBytes));
          }
        case TransferCheckpointSaved():
          break;
        case TransferDone():
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        case TransferFailed(:final code, :final detail):
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          if (!_events.isClosed) {
            _events.add(SyncProgressEvent('FAILED:$relPath:$code:$detail', 0, 0));
          }
        case TransferPaused(:final reason):
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          summary.applied ??= 'paused:$reason';
      }
    }, onError: (Object e) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }, onDone: () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });
    try {
      return await completer.future.timeout(const Duration(minutes: 30));
    } on TimeoutException {
      return false;
    } finally {
      await sub.cancel();
    }
  }

  Future<Map<String, dynamic>> _getJson(String name) async {
    final bytes = await port.getFile(_rp(name));
    if (bytes == null || bytes.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await _events.close();
  }
}

/// 路径拼接（与 playback_service.joinAbs 同口径；独立避免域反向依赖）。
class PlaybackPath {
  static String join(String rootPath, String rel) {
    final dir = rootPath.replaceAll('\\', '/');
    return dir.endsWith('/') ? '$dir$rel' : '$dir/$rel';
  }
}

