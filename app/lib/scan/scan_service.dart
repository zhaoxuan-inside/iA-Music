/// ScanService —— DETAILED-DESIGN §3.1 扫描六联（REQ-LIB-01..07 + REQ-ONB-02）。
///
/// 语义锚：§6.2 样例 1 —— Report.total=有效入架数、skipped=损坏/零字节计数；
/// 错误实现（坏文件计 0 total / 跳过中断流程）自动判败。
///
/// 纪律（§3.1 + §6.2）：
/// * **真实计数红线**：total=实际有效音频数（禁「看起来正常」跳表损坏件）。
/// * 批 200/事务：字典 upsert + tracks 核心插入 + FTS 拼音列**同一批事务**（D9-1）。
/// * 不占 UI isolate：tag 解析+stat+hash 整批进单 Isolate。
/// * 同一 root 并发一次（§3.1 任务锁；二次调用=程序级拒绝 StateError）。
/// * 全轮 diff：DB 有而盘无 → `missing_at`（REQ-LIB-05 灰显；文件放回→恢复）；
///   盘上回归的同路径**软删行** → 复活（UNIQUE(root,rel_path) 锚定同一条记录）。
/// * hash=整文件 SHA-256（S2 实现口径；spec「范围=音频帧」差异 → ISS-504 登记，
///   分发期裁决；S2 内修改类断言（DoD3）依赖「编辑不写文件」红线，两口径等价）。
/// * Sync 指向：content_hash 变更检测输入（S6 消费）。
library;

import 'dart:io';
import 'dart:isolate';

import 'package:contracts/contracts.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:drift/drift.dart';
import 'package:ia_music/adapters/metadata_adapter.dart';
import 'package:ia_music/data/daos.dart';
import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';

/// 扫描模式：full=全量重解析；incremental=盘对库 diff（mtime/size 未变→跳解析）。
enum ScanMode { full, incremental }

sealed class ScanEvent {}

/// 过程事件（每批 flush 后抛出；UI 进度条消费）。
final class ScanProgress extends ScanEvent {
  ScanProgress({required this.processed, required this.admitted, required this.skipped});

  final int processed;
  final int admitted;
  final int skipped;
}

/// 终结事件（§6.2 断言载体）。
final class ScanDone extends ScanEvent {
  ScanDone(this.report);

  final ScanReport report;
}

/// 真实计数红线载体。
final class ScanReport {
  const ScanReport({
    required this.total,
    required this.skipped,
    required this.added,
    required this.updated,
    required this.missing,
    required this.skippedPaths,
  });

  /// 本轮有效音频总数（=新增 + 既有可用）。
  final int total;

  /// 损坏/零字节/不可解析（跳过计数，不中断）。
  final int skipped;

  /// 新入库数（含软删同路径复活重入架）。
  final int added;

  /// 变化 touch（mtime/size/hash 变化 → updated_at 刷新）。
  final int updated;

  /// 盘上消失 → missing_at（REQ-LIB-05）。
  final int missing;

  /// skipped 具名清单（evidence/UI 排查用）。
  final List<String> skippedPaths;
}

/// Port 依赖口径：批解析在 isolate 内复用 adapter 的**同步核心**
/// （`MetadataAdapter.parseSync`——与 MetadataPort.read 同一真解析，
///  后者=Isolate.run(parseSync)，契约面保留给提取域等单件消费方）。
class ScanService {
  ScanService({required IaDatabase db})
      : _db = db,
        _dao = DataAccess(db).library;

  static const int kBatchSize = 200; // §3.1 批 200/事务

  static final RegExp _audioExt = RegExp(r'\.(mp3|flac|m4a|ogg|wav|ape)$', caseSensitive: false);

  final IaDatabase _db;
  final LibraryDao _dao;

  static final Set<int> _busyRoots = {};

  /// 六扩展白名单（§3.1 扫描入库边界）。
  static bool isAudioEntry(String path) => _audioExt.hasMatch(path);

  Stream<ScanEvent> scan({
    required int rootId,
    ScanMode mode = ScanMode.full,
  }) async* {
    if (_busyRoots.contains(rootId)) {
      throw StateError('scan already running for rootId=$rootId'); // §3.1 任务锁
    }
    _busyRoots.add(rootId);
    try {
      final root = await (_db.select(_db.repositoryRoots)
            ..where((r) => r.id.equals(rootId)))
          .getSingleOrNull();
      if (root == null) {
        throw StateError('repository root not found: $rootId');
      }
      final dir = Directory(root.path);
      if (!dir.existsSync()) {
        throw StateError('scan root missing on disk: ${root.path}');
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final existing = {for (final t in await _dao.rowsByRoot(rootId)) t.relPath: t};
      final seen = <String>{};

      var admitted = 0;
      var skipped = 0;
      var added = 0;
      var updated = 0;
      var processed = 0;
      final skippedPaths = <String>[];
      final pending = <String>[]; // 本 flush 批的相对路径

      Future<void> flush() async {
        if (pending.isEmpty) {
          return;
        }
        // 单 isolate 批：tag 解析（裸值）+ stat + 整文件 sha256（不占 UI isolate）
        final batch = pending.toList();
        final outs = await _runParseChunk(root.path, batch);
        pending.clear();

        final inserts = <ScannedTrackInput>[];
        for (final out in outs) {
          if (out.error != null) {
            skipped++;
            skippedPaths.add(out.relPath);
            continue;
          }
          final meta = out.meta!;
          final title = meta.title.isEmpty ? _titleFromRel(out.relPath) : meta.title;
          final artist = meta.artistDisplay.isEmpty ? null : meta.artistDisplay;
          final album = meta.albumDisplay.isEmpty ? null : meta.albumDisplay;
          final durationMs = meta.durationMs > 0 ? meta.durationMs : null;
          final spec = AudioFormatSpec.values.byName(meta.format.name);

          final row = existing[out.relPath];
          if (row == null) {
            inserts.add(ScannedTrackInput(
              rootId: rootId,
              relPath: out.relPath,
              mtime: meta.mtimeMs,
              fileSize: meta.fileSizeBytes,
              contentHash: out.hash,
              nowMs: nowMs,
              title: title,
              artistDisplay: artist,
              albumDisplay: album,
              durationMs: durationMs,
              format: spec,
              sampleRate: meta.sampleRate,
            ));
            added++;
            admitted++;
            continue;
          }
          if (row.deletedAt != null) {
            // 同路径回归 + 曾软删 → 复活（清软删位 + 元数据刷新 + FTS 同事务）
            await _dao.reviveTrack(
              row.id,
              mtime: meta.mtimeMs,
              fileSize: meta.fileSizeBytes,
              contentHash: out.hash,
              nowMs: nowMs,
              title: title,
              artist: artist,
              album: album,
              durationMs: durationMs,
            );
            added++;
            admitted++;
            continue;
          }
          if (row.deletedAt == null && row.missingAt != null) {
            // 缺失恢复（REQ-LIB-05「放回→恢复」）：文件回归即清 missing_at
            await _dao.markPresent(row.id, nowMs);
          }
          final changed = row.mtime != meta.mtimeMs ||
              row.fileSize != meta.fileSizeBytes ||
              row.contentHash != out.hash;
          if (changed) {
            await _dao.touchTrackOnRescan(
              row.id,
              changed: true,
              mtime: meta.mtimeMs,
              fileSize: meta.fileSizeBytes,
              contentHash: out.hash,
              nowMs: nowMs,
            );
            updated++;
          }
          final displayChanged = row.title != title ||
              row.artistDisplay != artist ||
              row.albumDisplay != album ||
              row.durationMs != durationMs;
          if (displayChanged) {
            await _dao.reconcileTrackMeta(
              row.id,
              title: title,
              artist: artist,
              album: album,
              durationMs: durationMs,
              nowMs: nowMs,
            );
          }
          admitted++;
        }
        if (inserts.isNotEmpty) {
          await _dao.insertTrackBatch(inserts); // ≤200=批 200/事务
        }
      }

      await for (final ent in dir.list(recursive: true, followLinks: false)) {
        if (ent is! File || !isAudioEntry(ent.path)) {
          continue;
        }
        final relPath = _relPathOf(root.path, ent.absolute.path);
        seen.add(relPath);

        if (mode == ScanMode.incremental) {
          final st = await ent.stat();
          final row = existing[relPath];
          if (row != null &&
              row.deletedAt == null &&
              row.mtime == st.modified.millisecondsSinceEpoch &&
              row.fileSize == st.size) {
            // 增量快路径：未变→不解析（mtime 变更才刷 updated_at，REQ-LIB-02）
            admitted++;
            processed++;
            continue;
          }
        }

        pending.add(relPath);
        processed++;
        if (pending.length >= kBatchSize) {
          await flush();
          yield ScanProgress(processed: processed, admitted: admitted, skipped: skipped);
        }
      }
      await flush();
      yield ScanProgress(processed: processed, admitted: admitted, skipped: skipped);

      // 全轮 diff：DB 有而盘无 → missing_at（REQ-LIB-05；文件放回 → 恢复路径见下轮扫描）
      final goneRel = existing.keys.where((k) => !seen.contains(k)).toList();
      var missing = 0;
      if (goneRel.isNotEmpty) {
        final goneRows = await (_db.select(_db.tracks)
              ..where((t) => t.rootId.equals(rootId) & t.relPath.isIn(goneRel)))
            .get();
        for (final g in goneRows) {
          if (g.deletedAt == null) {
            await _dao.markMissing(g.id, nowMs);
            missing++;
          }
        }
      }

      yield ScanDone(ScanReport(
        total: admitted,
        skipped: skipped,
        added: added,
        updated: updated,
        missing: missing,
        skippedPaths: List.unmodifiable(skippedPaths),
      ));
    } finally {
      _busyRoots.remove(rootId);
    }
  }

  /// 批 isolate 调用壳（**静态上下文**：Isolate.run 闭包只捕获可发送 locals；
  /// 实例方法闭包会隐式传染 `this._db` → send 失败——已实证）。
  static Future<List<ParseOut>> _runParseChunk(String root, List<String> paths) =>
      Isolate.run(() => _parseChunk(root: root, relPaths: paths));

  /// 归一 POSIX 分隔的根相对路径（§1.2 rel_path 跨平台稳定）。
  static String _relPathOf(String rootPath, String absPath) {
    final root = rootPath.replaceAll('\\', '/');
    final path = absPath.replaceAll('\\', '/');
    var rel = path.startsWith(root) ? path.substring(root.length) : path;
    while (rel.startsWith('/')) {
      rel = rel.substring(1);
    }
    return rel;
  }

  /// 文件名兜底标题（tables.dart 注释口径：标签缺失→由扫描以文件名填充）。
  static String _titleFromRel(String relPath) {
    final name = relPath.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? name : name.substring(0, dot);
  }
}

/// isolate 批解析单件（无平台对象；records/class 皆 sendable）。
final class ParseOut {
  const ParseOut({
    required this.relPath,
    required this.hash,
    this.error,
    this.meta,
  });

  final String relPath;

  /// 整文件 SHA-256（解析失败时为空串占位——失败件不更新任何库行）。
  final String hash;
  final String? error;
  final ParsedMeta? meta;
}

/// 批解析（§3.1 禁则：不占 UI isolate）——逐件真读：tag 裸值 + 大小/mtimes + sha256。
/// 损坏/零字节/消失 → [ParseOut.error]（调用方 skipped 计数，REQ-LIB-01 不中断）。
List<ParseOut> _parseChunk({required String root, required List<String> relPaths}) {
  final outs = <ParseOut>[];
  for (final rel in relPaths) {
    final abs = '${root.replaceAll('\\', '/')}/$rel';
    try {
      final f = File(abs);
      final hash = sha256.convert(f.readAsBytesSync()).toString();
      final meta = MetadataAdapter.parseSync(abs); // 内含 stat（size/mtime）
      outs.add(ParseOut(relPath: rel, hash: hash, meta: meta));
    } catch (e) {
      outs.add(ParseOut(relPath: rel, hash: '', error: e.toString()));
    }
  }
  return outs;
}
