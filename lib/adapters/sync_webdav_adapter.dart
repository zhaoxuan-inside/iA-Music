/// WS6 同步域 —— WebDAV 通道适配器（ADR-0001 R2：MVP 激活通道；REQ-SYNC-01/02/05/06）。
///
/// * [WebDavAdapter] 以 `webdav_client_plus`（真实 WebDAV 协议客户端，纯 Dart）
///   实现 `SyncChannelPort` 全部五个方法（DEC-010：无 mock/替身；S8 同步链路
///   真服务联调用 `test/sync/webdav_fixture_server.dart` 本地真协议夹具）。
/// * 凭据：[ChannelConfig.credentialsRefKey] 是 SecureStore 键——本 adapter 不直接
///   管凭据，构造注入 `Future<String?> Function(String refKey)` 读取器取口令/令牌；
///   凭据值不落日志、不落库（C50）。
/// * 通道上下文：契约的 diff/putFile/getFile/listRemote 不携 [ChannelConfig]，
///   由调用方（SyncEngine）构造时或经 [bind] 绑定当前通道后再调用；未绑定即调用
///   属编程错误（StateError，不映射人话文案）。
/// * 错误映射（本文件 `_classify`）：HTTP 401/403 → auth；HTTP 507 → disk；
///   5xx/Socket/Timeout/其余 → network（detail 带原异常串）。事件面方法
///   （putFile）一律以 TransferFailed 事件收尾不抛；非事件面方法（diff/getFile/
///   listRemote）抛契约异常（NetworkLostException / ChannelAuthFailedException /
///   DiskFullException），不吞异常不留痕。
/// * 分块断点（C36 自研叠加）：[putFile] 的 chunked 非空时按 ChunkPlan 切片，
///   逐片写 `<remotePath>.part-N` 临时块文件（父目录由包内 write 自带 MKCOL 建
///   出），每片成功 yield TransferCheckpointSaved + TransferProgress；全部完成
///   后按序回读拼接写终文件、删除全部分片，yield TransferDone。块间响应注入的
///   cancelled 回调（C38：协作式取消，响应点=块边界）→ TransferPaused('user')。
///   ChunkPlan.concurrency 当前实现按串行处理（保证 chunkIndex 单调，Engine 层
///   用多文件并行兑现并发度）。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:contracts/contracts.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

/// 连接/请求超时口径（15s；包支持 WebdavOptions 超时参数，直接传入）。
const Duration _kTimeout = Duration(seconds: 15);

/// ChunkPlan.chunkSizeBytes 非法（<=0）时的兜底分片大小（与契约默认一致：8 MiB）。
const int _kDefaultChunkBytes = 8 * 1024 * 1024;

/// `.part-N` 临时分片名后缀（diff 遍历时过滤：上传中断残留的分片不是同步实体）。
final RegExp _kPartSuffix = RegExp(r'\.part-\d+$');

/// SyncChannelPort 的 WebDAV 实现。
final class WebDavAdapter implements SyncChannelPort {
  /// [credentials]=SecureStore 读取器注入（凭据本体不进本类）；[cancelled]=块边界
  /// 协作式取消探针（可选，默认 null=不可取消）；[config]=初始通道（可后经
  /// [bind] 绑定/更换；私有字段经 private named parameter 对外仍叫 credentials/
  /// cancelled/config）。
  WebDavAdapter({required this._credentials, this._cancelled, this._config});

  /// SecureStore 读取器（凭据本体只在此出入）。
  final Future<String?> Function(String refKey) _credentials;

  /// 块边界协作式取消探针（可选；默认 null=不可取消）。
  final bool Function()? _cancelled;

  ChannelConfig? _config;

  /// 绑定/切换当前通道（SyncEngine 换通道或凭据轮换后重绑；diff/putFile 等
  /// 契约方法不携 cfg，通道上下文由此注入）。
  void bind(ChannelConfig cfg) => _config = cfg;

  ChannelConfig get _cfg {
    final cfg = _config;
    if (cfg == null) {
      throw StateError('WebDavAdapter 未绑定通道配置：先调用 bind(cfg) 再执行同步操作');
    }
    return cfg;
  }

  @override
  Future<TestResult> testConnection(ChannelConfig cfg) async {
    if (cfg.type != ChannelType.webdav) {
      return const TestResult(
        ok: false,
        reason: '通道类型不是 WebDAV，无法用 WebDAV 方式测试连接',
      );
    }
    try {
      final client = await _open(cfg);
      await client.ping();
      // 确保 remoteDir 存在（mkdirAll 递归建目录；405=已存在 视为成功）。
      await client.mkdirAll(_dirPath(cfg.remoteDir));
      return const TestResult(ok: true);
    } on Object catch (e) {
      return TestResult(ok: false, reason: _friendlyReason(e));
    }
  }

  @override
  Future<RemoteDiff> diff(String remoteDir, LocalManifest local) async {
    final client = await _open(_cfg);
    final dir = _normalizeDir(remoteDir);
    final Map<String, int> remoteMtimes;
    try {
      remoteMtimes = await _walkRemote(client, dir);
    } on WebdavException catch (e) {
      if ((e.statusCode ?? 0) == 404) {
        // 远端目录不存在=从未同步过：全部本地进 toUpload。
        return RemoteDiff(
          toUpload: List<ManifestEntry>.of(local.entries),
          toDownload: const [],
          conflicts: const [],
        );
      }
      throw _toContractException(e);
    } on Object catch (e) {
      throw _toContractException(e);
    }

    // 求差规则（时间戳仲裁归 SyncEngine，adapter 只报告）：
    // * 远端有本地无 → toDownload；本地有远端无 → toUpload；
    // * 双侧都在且时间不同 → conflicts（Engine 做 last-writer-wins + 冲突副本）；
    // * 双侧都在且时间相同 → 视为已同步，不上报。
    final localByRel = <String, ManifestEntry>{
      for (final e in local.entries) e.relPath: e,
    };
    final toUpload = <ManifestEntry>[];
    final conflicts = <ManifestEntry>[];
    for (final e in local.entries) {
      final remoteMs = remoteMtimes[e.relPath];
      if (remoteMs == null) {
        toUpload.add(e);
      } else if (remoteMs != e.updatedAtMs) {
        // 冲突条目带本地 hash 供 Engine 做冲突副本。
        conflicts.add(e);
      }
    }
    final toDownload = <ManifestEntry>[];
    for (final entry in remoteMtimes.entries) {
      if (!localByRel.containsKey(entry.key)) {
        // 远端条目不存 hash（远端只有 mtime）。
        toDownload.add(
          ManifestEntry(relPath: entry.key, updatedAtMs: entry.value),
        );
      }
    }
    int byRel(ManifestEntry a, ManifestEntry b) =>
        a.relPath.compareTo(b.relPath);
    toUpload.sort(byRel);
    toDownload.sort(byRel);
    conflicts.sort(byRel);
    return RemoteDiff(
      toUpload: toUpload,
      toDownload: toDownload,
      conflicts: conflicts,
    );
  }

  @override
  Stream<TransferEvent> putFile(
    String remotePath,
    Uint8List bytes, {
    ChunkPlan? chunked,
  }) async* {
    final cfg = _cfg; // 未绑定通道=编程错误，直接抛（不伪装成传输失败事件）。
    try {
      final client = await _open(cfg);
      if (chunked == null) {
        // 单次全量 PUT（包内 wdWriteWithBytes 自带父目录 MKCOL）。
        await client.write(remotePath, bytes);
        yield TransferProgress(remotePath, bytes.length, bytes.length);
        yield TransferDone(remotePath);
        return;
      }

      final chunkSize = chunked.chunkSizeBytes <= 0
          ? _kDefaultChunkBytes
          : chunked.chunkSizeBytes;
      final partCount = bytes.isEmpty
          ? 0
          : (bytes.length + chunkSize - 1) ~/ chunkSize;
      final parts = <String>[
        for (var i = 0; i < partCount; i++) '$remotePath.part-$i',
      ];

      // 逐片上传：每片成功 = 一个断点检查点（chunkIndex 单调）。
      var sent = 0;
      for (var i = 0; i < partCount; i++) {
        if (_isCancelled()) {
          // 分片残留即断点凭据（Engine 重提 putFile 幂等重传全部片）。
          yield TransferPaused(remotePath, 'user');
          return;
        }
        final start = i * chunkSize;
        final end = (start + chunkSize) < bytes.length
            ? (start + chunkSize)
            : bytes.length;
        final slice = Uint8List.sublistView(bytes, start, end);
        try {
          await client.write(parts[i], slice);
        } on Object catch (e) {
          yield _failedEvent(remotePath, e);
          return;
        }
        sent += slice.length;
        yield TransferCheckpointSaved(remotePath, i);
        yield TransferProgress(remotePath, sent, bytes.length);
      }

      if (_isCancelled()) {
        yield TransferPaused(remotePath, 'user');
        return;
      }

      // 按序回读各片拼接 → 写终文件 → 清理分片（remove 对 404 视为成功）。
      final builder = BytesBuilder(copy: false);
      try {
        for (final part in parts) {
          builder.add(await client.read(part));
        }
      } on Object catch (e) {
        yield _failedEvent(remotePath, e);
        return;
      }
      final assembled = builder.takeBytes();
      if (assembled.length != bytes.length) {
        yield TransferFailed(
          remotePath,
          TransferError.network,
          detail: '分块回读长度不符：期望 ${bytes.length} 字节，实际 ${assembled.length} 字节',
        );
        return;
      }
      try {
        await client.write(remotePath, assembled);
      } on Object catch (e) {
        yield _failedEvent(remotePath, e);
        return;
      }
      try {
        for (final part in parts) {
          await client.remove(part);
        }
      } on Object catch (e) {
        // 终文件已写成功，但分片清理失败必须留痕（残留分片会被 diff 过滤，
        // 但污染远端空间）——按失败上报，Engine 重提幂等重传。
        yield _failedEvent(remotePath, e);
        return;
      }
      yield TransferDone(remotePath);
    } on Object catch (e) {
      // 覆盖 _open（凭据读取/客户端构建）等前置失败：事件面方法不抛流错误。
      yield _failedEvent(remotePath, e);
    }
  }

  @override
  Future<Uint8List?> getFile(String remotePath) async {
    final client = await _open(_cfg);
    try {
      return await client.read(remotePath);
    } on WebdavException catch (e) {
      if ((e.statusCode ?? 0) == 404) {
        return null; // 远端不存在 → null（契约口径）。
      }
      throw _toContractException(e);
    } on Object catch (e) {
      throw _toContractException(e);
    }
  }

  @override
  Future<List<String>> listRemote(String remoteDir) async {
    final client = await _open(_cfg);
    final dir = _normalizeDir(remoteDir);
    try {
      final entries = await client.readDir(dir.isEmpty ? '/' : dir);
      final names = entries.map((f) => f.name).toList()..sort();
      return names;
    } on WebdavException catch (e) {
      if ((e.statusCode ?? 0) == 404) {
        return const []; // 目录不存在按空清单处理（健康/容量展示语义）。
      }
      throw _toContractException(e);
    } on Object catch (e) {
      throw _toContractException(e);
    }
  }

  // ── 内部实现 ──────────────────────────────────────────────────────────────

  /// 按当前配置构建客户端：凭据读取器取口令/令牌；用户名+口令 → Basic，
  /// 仅令牌（无用户名）→ Bearer，均缺 → 匿名。超时 15s 走 WebdavOptions。
  Future<WebdavClient> _open(ChannelConfig cfg) async {
    final secret = await _credentials(cfg.credentialsRefKey);
    final Auth auth;
    if (cfg.username != null && secret != null) {
      auth = BasicAuth(user: cfg.username!, pwd: secret);
    } else if (cfg.username == null && secret != null) {
      auth = BearerAuth(token: secret);
    } else {
      auth = const NoAuth();
    }
    return WebdavClient(
      url: cfg.baseUrl,
      auth: auth,
      options: const WebdavOptions(
        connectTimeout: _kTimeout,
        sendTimeout: _kTimeout,
        receiveTimeout: _kTimeout,
      ),
    );
  }

  /// 递归列出远端目录下全部文件：relPath（相对 remoteDir，'/' 分隔）→ mtimeMs。
  /// 远端不存 hash；`.part-N` 中断残留分片过滤掉。
  Future<Map<String, int>> _walkRemote(WebdavClient client, String dir) async {
    final out = <String, int>{};
    Future<void> walk(String path) async {
      final entries = await client.readDir(path.isEmpty ? '/' : path);
      for (final f in entries) {
        if (f.isDir) {
          await walk(f.path);
        } else if (!_kPartSuffix.hasMatch(f.path)) {
          out[_relOf(f, dir)] = f.modified?.millisecondsSinceEpoch ?? 0;
        }
      }
    }

    await walk(dir);
    return out;
  }

  /// WebdavFile.path（base-relative 绝对形如 `/dir/sub/a.mp3`）→ 相对 [dir] 的
  /// relPath；跨域 href（完整 URL）兜底退回文件名（baseRelative 模式不应发生）。
  String _relOf(WebdavFile f, String dir) {
    var p = f.path;
    if (p.startsWith('http://') || p.startsWith('https://')) {
      return f.name;
    }
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    if (dir.isEmpty) {
      return p;
    }
    return p.startsWith('$dir/') ? p.substring(dir.length + 1) : p;
  }

  bool _isCancelled() => _cancelled?.call() ?? false;

  /// 远端目录入参规范化：去首尾 '/'；空串=根。
  String _normalizeDir(String remoteDir) {
    var dir = remoteDir.trim();
    while (dir.startsWith('/')) {
      dir = dir.substring(1);
    }
    while (dir.endsWith('/')) {
      dir = dir.substring(0, dir.length - 1);
    }
    return dir;
  }

  /// cfg.remoteDir（默认 'iA-Music/'）→ 客户端用的 base-relative 目录路径。
  String _dirPath(String remoteDir) {
    final dir = _normalizeDir(remoteDir);
    return dir.isEmpty ? '/' : '/$dir';
  }

  /// 统一错误分类：401/403 → auth；507 → disk；其余（5xx/4xx/网络/未知）→
  /// network。detail 一律带原异常串（不吞异常不留痕）。
  (TransferError, String) _classify(Object error) {
    final detail = error.toString();
    if (error is WebdavException) {
      final status = error.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return (TransferError.auth, detail);
      }
      if (status == 507) {
        return (TransferError.disk, detail);
      }
      return (TransferError.network, detail);
    }
    // DioException / SocketException / TimeoutException / HttpException / 其他
    // 一律 network 语义（超时细分只影响人话文案）。
    return (TransferError.network, detail);
  }

  bool _isTimeout(Object error) =>
      error is TimeoutException ||
      (error is DioException &&
          (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.receiveTimeout));

  /// testConnection 的人话失败原因（可直接展示；REQ-SYNC-01）。
  String _friendlyReason(Object error) {
    if (error is WebdavException) {
      final status = error.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return '凭据被拒（HTTP $status），请检查用户名与密码/令牌';
      }
      if (status == 507) {
        return '服务端存储空间不足（HTTP 507），请清理网盘空间后重试';
      }
      if (status >= 500) {
        return '服务异常（HTTP $status），请稍后重试';
      }
      return '服务拒绝了请求（HTTP $status），请检查远端目录设置';
    }
    if (_isTimeout(error)) {
      return '连接超时（15 秒无响应），请检查服务地址与网络';
    }
    return '地址不可达或服务异常，请检查服务地址与网络';
  }

  /// putFile 事件面的失败事件（不抛流错误）。
  TransferFailed _failedEvent(String relPath, Object error) {
    final (code, detail) = _classify(error);
    return TransferFailed(relPath, code, detail: detail);
  }

  /// 非事件面方法（diff/getFile/listRemote）的契约异常映射：
  /// network → NetworkLostException；auth → ChannelAuthFailedException；
  /// disk → DiskFullException。message=人话默认文案 + 技术细节
  /// （契约口径：message 面向日志可含技术细节，UI 文案按异常类型映射）。
  ContractException _toContractException(Object error) {
    final (code, detail) = _classify(error);
    switch (code) {
      case TransferError.auth:
        return ChannelAuthFailedException('授权过期或地址/凭据有误，请重新授权（$detail）');
      case TransferError.disk:
        return DiskFullException('存储空间不足，已暂停；可用空间足够后继续（$detail）');
      case TransferError.network:
        final reason = _isTimeout(error) ? '连接/请求超时（15s）' : detail;
        return NetworkLostException('网络连接中断，任务已暂停，本地数据不受影响（$reason）');
    }
  }
}
