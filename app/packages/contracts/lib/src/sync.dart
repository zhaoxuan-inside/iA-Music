/// SyncChannelPort —— 同步通道契约（MVP=WebDAV 完整实现；GitHub=轻数据；C 红线全集）。
///
/// **硬性红线**：
/// * 本 Port **不存在 delete 语义**——删除只传播记录（墓碑），远端文件永不因子端删除而被删。
/// * 本地数据无损（RED LINE）；断网=暂停（NetworkLostException 语义），不主动重传。
/// * 凭据只经 [ChannelConfig.credentialsRefKey]（SecureStore 键引用；不入 DB/日志）。
library;

import 'dart:typed_data';

import 'shared.dart';

enum ChannelType { webdav, onedrive, gdrive, github }

/// GitHub 为轻数据型（REQ-SYNC-08）：音频上传调用由调用方对该类型直接禁用。
final class ChannelConfig {
  const ChannelConfig({
    required this.type,
    required this.baseUrl,
    this.remoteDir = 'iA-Music/',
    this.username,
    required this.credentialsRefKey,
  });

  final ChannelType type;
  final String baseUrl;
  final String remoteDir;
  final String? username;

  /// SecureStore key（凭据本体不进本结构）。
  final String credentialsRefKey;
}

/// 连接测试（REQ-SYNC-01）：失败必须带可直接展示的人话 reason。
final class TestResult {
  const TestResult({required this.ok, this.reason});
  final bool ok;

  /// 人话失败原因（如『地址不可达』『凭据被拒』）；ok=true 时为 null。
  final String? reason;
}

/// 本地清单条目。
final class ManifestEntry {
  const ManifestEntry({required this.relPath, required this.updatedAtMs, this.hash});

  final String relPath;
  final int updatedAtMs;
  final String? hash;
}

/// 本地实体（轻数据 JSON 清单/墓碑比较输入）。
class LocalManifest {
  LocalManifest({required this.entries});
  final List<ManifestEntry> entries;
}

/// 远端差异（PREPARE 阶段产物；调用方据此按态迁移）。
final class RemoteDiff {
  const RemoteDiff({
    required this.toUpload,
    required this.toDownload,
    required this.conflicts,
  });

  final List<ManifestEntry> toUpload;
  final List<ManifestEntry> toDownload;

  /// 双端均更新于上次同步点之后——由调用方做 last-writer-wins + 冲突副本。
  final List<ManifestEntry> conflicts;
}

enum TransferError { network, auth, disk }

sealed class TransferEvent {
  const TransferEvent();
}

final class TransferProgress extends TransferEvent {
  const TransferProgress(this.relPath, this.sentBytes, this.totalBytes);
  final String relPath;
  final int sentBytes;
  final int totalBytes;
}

/// 分块检查点落盘（断点续传凭据；调用方持久化 chunkIndex）。
final class TransferCheckpointSaved extends TransferEvent {
  const TransferCheckpointSaved(this.relPath, this.chunkIndex);
  final String relPath;
  final int chunkIndex;
}

final class TransferPaused extends TransferEvent {
  const TransferPaused(this.relPath, this.reason);
  final String relPath;
  final String reason;
}

final class TransferDone extends TransferEvent {
  const TransferDone(this.relPath);
  final String relPath;
}

final class TransferFailed extends TransferEvent {
  const TransferFailed(this.relPath, this.code, {this.detail});
  final String relPath;
  final TransferError code;
  final String? detail;
}

abstract class SyncChannelPort {
  /// 配置校验（REQ-SYNC-01：测试通过才可保存——调用方 UI 圈定）。
  Future<TestResult> testConnection(ChannelConfig cfg);

  /// PREPARE：远端清单 vs 本地清单（+墓碑时间戳比较由 SyncEngine 域内执行）。
  Future<RemoteDiff> diff(String remoteDir, LocalManifest local);

  /// 上传单文件（[chunked] 非空=分块断点；暂停=TaskPaused+checkpoint 已存）。
  Stream<TransferEvent> putFile(String remotePath, Uint8List bytes, {ChunkPlan? chunked});

  /// 下载（Range 续传由实现内部处理）；远端不存在 → null。
  Future<Uint8List?> getFile(String remotePath);

  /// 只读列远端目录（用于通道健康/容量展示；**无删除方法**）。
  Future<List<String>> listRemote(String remoteDir);
}
