/// WS6 同步域 —— OneDrive 通道适配器（Microsoft Graph v1.0；REQ-SYNC-01/02/03/06）。
///
/// * [OneDriveAdapter] 以 `dart:io` HttpClient 直连 Microsoft Graph v1.0
///   （https://graph.microsoft.com/v1.0）实现 `SyncChannelPort` 全部五方法
///   （DEC-010：无 mock/替身）。
/// * 凭据：[ChannelConfig.credentialsRefKey] 指向 SecureStore 的 JSON
///   `{"clientId":"...","refreshToken":"...","accessToken":"...","expiresAt":ms}`
///   （accessToken 可缺省）；本 adapter 不直接管 SecureStore——构造注入
///   credentials 读取器与 credentialsWriter 回写器，凭据值不落日志（C50）。
/// * OAuth 设备码流（懒触发）：任何请求无可用 token 或遇 401 → 先用
///   refresh_token 换新；失败则发起设备码会话（POST devicecode）并后台轮询
///   token 端点直到成功/过期，成功自动回写 SecureStore。**授权需用户交互**，
///   不做浏览器内嵌（docs/DELIVERY-NOTES①）：未授权时 testConnection 返回
///   `需要在浏览器完成设备授权：{verification_uri}，代码 {user_code}`，
///   其余方法抛 [ChannelAuthFailedException]（同人话文案）。
/// * 端点映射（remoteDir 为根 item）：GET /me/drive/root:/{path}（元数据/
///   存在性）；GET /me/drive/root:/{path}:/children（列目录，@odata.nextLink
///   分页）；PUT /me/drive/root:/{path}:/content（简单上传）；GET :/content
///   （下载）；DELETE /me/drive/root:/{path}（仅分片清理自用——Graph DELETE
///   不被 SyncChannelPort 暴露，Port 红线：无删除语义）。
/// * 大文件（>4MB 简单上传阈值）：不用 Graph upload session（docs/DELIVERY-NOTES②）
///   ——按 ChunkPlan 切片（有效分片钳到 4MB 内）逐 PUT `{path}.part-N`，每片
///   成功即 TransferCheckpointSaved（断点凭据）；全部完成后按序回读拼接、
///   简单 PUT 终文件、逐 DELETE 分片。PUT 覆盖已有文件（语义同 WebDAV PUT）。
///   ChunkPlan.concurrency 按串行处理（chunkIndex 单调；并发度由 Engine 层
///   多文件并行兑现，与 WebDavAdapter 口径一致）。
/// * diff 语义与 WebDavAdapter 完全一致：递归远端目录树 → ManifestEntry
///   （relPath 相对 remoteDir；updatedAtMs=fileSystemInfo.lastModifiedDateTime
///   → epoch ms；hash=null）；`.part-N` 中断残留分片过滤；远端目录不存在=
///   从未同步（全部本地进 toUpload）。时间戳仲裁归 SyncEngine，adapter 只报告。
/// * 错误映射（_classify）：401/403 → auth；507 → disk；5xx/413/Socket/
///   Timeout/其余 → network。事件面（putFile）一律以 TransferFailed 事件收尾
///   不抛；非事件面（diff/getFile/listRemote）抛契约异常（NetworkLostException
///   / ChannelAuthFailedException / DiskFullException），不吞异常不留痕。
/// * docs/DELIVERY-NOTES（后续迭代输入）：
///   ① 设备码授权不做浏览器内嵌/WebView——用户在系统浏览器打开
///      verification_uri 输入 user_code；适配器侧后台轮询自动完成令牌回写，
///      授权成功后重试即恢复。真服务联调需 Azure 应用注册（Public client，
///      启用设备码流）取得 clientId 写入 SecureStore 凭据 JSON 后进行。
///   ② 简单 PUT 当前文档上限 250MB（4MB 为历史阈值，本 adapter 保守按 4MB
///      钳分片大小）；终文件拼接后仍走简单 PUT，超限 413 → TransferFailed。
///   ③ 设备码流/Graph 端点未经真服务联调（无法真测，见报告）；人工验证步骤：
///      配置通道 → testConnection 返回授权提示（uri+代码）→ 浏览器完成授权
///      → 稍候重试 testConnection 应 ok:true 且 SecureStore 凭据已含
///      accessToken/expiresAt。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, HttpException, HttpHeaders, SocketException;
import 'dart:typed_data';

import 'package:contracts/contracts.dart';

/// 请求超时口径（15s/请求，与 WebDavAdapter 一致）。
const Duration _kTimeout = Duration(seconds: 15);

/// Microsoft Graph v1.0 根地址。
const String _kGraphBase = 'https://graph.microsoft.com/v1.0';

/// 设备码流端点（AAD v2 公共端点，common 租户）。
const String _kDeviceCodeUrl =
    'https://login.microsoftonline.com/common/oauth2/v2.0/devicecode';
const String _kTokenUrl =
    'https://login.microsoftonline.com/common/oauth2/v2.0/token';

/// OAuth scope（文件读写 + 离线刷新）。
const String _kScope = 'Files.ReadWrite offline_access';

/// ChunkPlan.chunkSizeBytes 非法（<=0）时的兜底分片大小（契约默认 8 MiB）。
const int _kDefaultChunkBytes = 8 * 1024 * 1024;

/// 分片/单请求保守上限：简单 PUT 的历史阈值 4MB（当前文档 250MB；保守钳制
/// 兼容中间层限制，代价只是检查点更密）。
const int _kMaxPartBytes = 4 * 1024 * 1024;

/// token 到期提前量（60s 网络余量）。
const int _kExpirySkewMs = 60 * 1000;

/// `.part-N` 临时分片名后缀（diff 遍历过滤：上传中断残留的分片不是同步实体）。
final RegExp _kPartSuffix = RegExp(r'\.part-\d+$');

/// SecureStore 凭据 JSON 形态（clientId/refreshToken/accessToken/expiresAt）。
final class _Creds {
  _Creds({
    required this.clientId,
    this.refreshToken,
    this.accessToken,
    this.expiresAtMs,
  });

  final String clientId;
  final String? refreshToken;
  final String? accessToken;

  /// accessToken 到期时刻（epoch ms；null=未知 → 视为过期走刷新）。
  final int? expiresAtMs;

  static _Creds? parse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final clientId = decoded['clientId'];
      if (clientId is! String || clientId.isEmpty) {
        return null;
      }
      return _Creds(
        clientId: clientId,
        refreshToken: decoded['refreshToken'] is String
            ? decoded['refreshToken'] as String
            : null,
        accessToken: decoded['accessToken'] is String
            ? decoded['accessToken'] as String
            : null,
        expiresAtMs: decoded['expiresAt'] is int
            ? decoded['expiresAt'] as int
            : null,
      );
    } on Object {
      return null; // 凭据 JSON 损坏 → 视同未配置（走设备码流重新授权）。
    }
  }

  bool get hasFreshToken {
    final token = accessToken;
    final expiresAt = expiresAtMs;
    return token != null &&
        token.isNotEmpty &&
        expiresAt != null &&
        DateTime.now().millisecondsSinceEpoch < expiresAt - _kExpirySkewMs;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'clientId': clientId,
    if (refreshToken != null) 'refreshToken': refreshToken,
    if (accessToken != null) 'accessToken': accessToken,
    if (expiresAtMs != null) 'expiresAt': expiresAtMs,
  };
}

/// token 端点成功响应（access_token/expires_in/refresh_token）。
final class _TokenResponse {
  const _TokenResponse({
    required this.accessToken,
    required this.expiresInSec,
    this.refreshToken,
  });

  final String accessToken;
  final int expiresInSec;
  final String? refreshToken;

  static _TokenResponse? parse(Uint8List body) {
    final map = _jsonMap(body);
    final accessToken = map['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      return null;
    }
    final expiresIn = map['expires_in'];
    final refreshToken = map['refresh_token'];
    return _TokenResponse(
      accessToken: accessToken,
      expiresInSec: expiresIn is num ? expiresIn.toInt() : 3600,
      refreshToken: refreshToken is String ? refreshToken : null,
    );
  }
}

/// 进行中的设备码授权会话（后台轮询所需的最小状态）。
final class _DeviceSession {
  _DeviceSession({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.interval,
    required this.expiresAt,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  Duration interval;
  final DateTime expiresAt;
}

/// 设备码待授权信号（内部控制流）：由 testConnection 转人话 reason，
/// 其余方法经 _classify 映射为 auth 契约异常。
final class _DeviceAuthPending implements Exception {
  const _DeviceAuthPending(this.verificationUri, this.userCode);

  final String verificationUri;
  final String userCode;

  /// 人话授权提示（REQ-SYNC-01 口径）。
  String get prompt => '需要在浏览器完成设备授权：$verificationUri，代码 $userCode';
}

/// Graph 非 2xx 响应异常（status 供分类；code/message 取自错误体）。
final class _GraphException implements Exception {
  const _GraphException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  @override
  String toString() =>
      'HTTP $status${code.isEmpty ? '' : ' $code'} $message'.trim();
}

/// HTTP 响应最小记录。
typedef _Resp = ({int status, Uint8List body});

/// JSON 体安全解析（非 JSON/非对象 → 空 map，调用方按缺字段处理）。
Map<String, dynamic> _jsonMap(Uint8List body) {
  if (body.isEmpty) {
    return const <String, dynamic>{};
  }
  try {
    final decoded = jsonDecode(utf8.decode(body));
    return decoded is Map<String, dynamic>
        ? decoded
        : const <String, dynamic>{};
  } on Object {
    return const <String, dynamic>{};
  }
}

/// 以 Graph 错误体抛 [_GraphException]（[what] 为无错误体时的兜底描述）。
Never _throwGraph(_Resp res, String what) {
  final err = _jsonMap(res.body)['error'];
  final code = err is Map<String, dynamic> ? err['code'] : null;
  final message = err is Map<String, dynamic> ? err['message'] : null;
  throw _GraphException(
    res.status,
    code is String ? code : '',
    message is String && message.isNotEmpty ? message : what,
  );
}

/// path（'/' 分隔）逐段百分号编码后拼接（Graph 寻址用 ':' 不受影响）。
String _encodedPath(String path) => path
    .split('/')
    .where((s) => s.isNotEmpty)
    .map(Uri.encodeComponent)
    .join('/');

/// item 元数据/删除 URL：'' → /me/drive/root；非空 → /me/drive/root:/{path}。
Uri _itemUrl(String path) {
  final segs = _encodedPath(path);
  if (segs.isEmpty) {
    return Uri.parse('$_kGraphBase/me/drive/root');
  }
  return Uri.parse('$_kGraphBase/me/drive/root:/$segs');
}

/// 列目录 URL：'' → /me/drive/root/children；非空 → /me/drive/root:/{path}:/children。
Uri _childrenUrl(String path) {
  final segs = _encodedPath(path);
  if (segs.isEmpty) {
    return Uri.parse('$_kGraphBase/me/drive/root/children');
  }
  return Uri.parse('$_kGraphBase/me/drive/root:/$segs:/children');
}

/// 上传/下载 URL：/me/drive/root:/{path}:/content。
Uri _contentUrl(String path) =>
    Uri.parse('$_kGraphBase/me/drive/root:/${_encodedPath(path)}:/content');

/// fileSystemInfo.lastModifiedDateTime（ISO8601 UTC）→ epoch ms；缺省 0。
int _lastModifiedMs(Map<String, dynamic> item) {
  final fs = item['fileSystemInfo'];
  final lastModified = fs is Map<String, dynamic>
      ? fs['lastModifiedDateTime']
      : null;
  if (lastModified is! String || lastModified.isEmpty) {
    return 0;
  }
  try {
    return DateTime.parse(lastModified).millisecondsSinceEpoch;
  } on FormatException {
    return 0;
  }
}

/// SyncChannelPort 的 OneDrive（Microsoft Graph v1.0）实现。
final class OneDriveAdapter implements SyncChannelPort {
  /// [credentials]=SecureStore 读取器注入（凭据本体不进本类）；[credentialsWriter]=
  /// SecureStore 回写器（设备码流/refresh 换发新凭据后持久化）；[cancelled]=块
  /// 边界协作式取消探针（可选，默认 null=不可取消）；[config]=初始通道（可后经
  /// [bind] 绑定/更换；私有字段经 private named parameter 对外仍叫
  /// credentials/credentialsWriter/cancelled/config）。
  OneDriveAdapter({
    required this._credentials,
    required this._credentialsWriter,
    this._cancelled,
    this._config,
  });

  /// SecureStore 读取器（凭据本体只在此出入）。
  final Future<String?> Function(String refKey) _credentials;

  /// SecureStore 回写器（设备码流/刷新成功后持久化新凭据 JSON）。
  final Future<void> Function(String refKey, String value) _credentialsWriter;

  /// 块边界协作式取消探针（可选；默认 null=不可取消）。
  final bool Function()? _cancelled;

  ChannelConfig? _config;

  final HttpClient _http = HttpClient()
    ..findProxy = HttpClient.findProxyFromEnvironment
    ..connectionTimeout = _kTimeout;

  /// refKey → 可用 access token（进程内缓存；401 时失效重取）。
  final Map<String, String> _tokenCache = <String, String>{};

  /// refKey → 进行中的设备码会话（未授权前重复调用复用同一 user_code）。
  final Map<String, _DeviceSession> _pendingAuth = <String, _DeviceSession>{};

  /// 绑定/切换当前通道（与 WebDavAdapter 同口径：契约方法不携 cfg）。
  void bind(ChannelConfig cfg) => _config = cfg;

  ChannelConfig get _cfg {
    final cfg = _config;
    if (cfg == null) {
      throw StateError('OneDriveAdapter 未绑定通道配置：先调用 bind(cfg) 再执行同步操作');
    }
    return cfg;
  }

  @override
  Future<TestResult> testConnection(ChannelConfig cfg) async {
    if (cfg.type != ChannelType.onedrive) {
      return const TestResult(
        ok: false,
        reason: '通道类型不是 OneDrive，无法用 Microsoft Graph 方式测试连接',
      );
    }
    try {
      final dir = _normalize(cfg.remoteDir);
      final res = await _graph('GET', _itemUrl(dir), cfg.credentialsRefKey);
      if (res.status == 404) {
        // 远端目录不存在=从未同步过：建目录后视为通过（与 WebDAV mkdirAll 口径一致）。
        await _mkdirAll(dir, cfg.credentialsRefKey);
      } else if (res.status != 200) {
        _throwGraph(res, '访问 OneDrive 失败');
      }
      return const TestResult(ok: true);
    } on _DeviceAuthPending catch (pending) {
      return TestResult(ok: false, reason: pending.prompt);
    } on Object catch (e) {
      return TestResult(ok: false, reason: _friendlyReason(e));
    }
  }

  @override
  Future<RemoteDiff> diff(String remoteDir, LocalManifest local) async {
    final cfg = _cfg;
    final dir = _normalize(remoteDir);
    final Map<String, int> remoteMtimes;
    try {
      remoteMtimes = await _walkRemote(dir, cfg.credentialsRefKey);
    } on _GraphException catch (e) {
      if (e.status == 404) {
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

    // 求差规则（与 WebDavAdapter 一致）：
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
        conflicts.add(e);
      }
    }
    final toDownload = <ManifestEntry>[];
    for (final entry in remoteMtimes.entries) {
      if (!localByRel.containsKey(entry.key)) {
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
      // 父目录链确保存在（Graph 路径寻址 PUT 不会自动建父目录）。
      await _mkdirAll(_parentDirOf(remotePath), cfg.credentialsRefKey);
      if (chunked == null) {
        await _putContent(remotePath, bytes, cfg.credentialsRefKey);
        yield TransferProgress(remotePath, bytes.length, bytes.length);
        yield TransferDone(remotePath);
        return;
      }

      final chunkSize = _effectiveChunk(chunked.chunkSizeBytes);
      final partCount = bytes.isEmpty
          ? 0
          : (bytes.length + chunkSize - 1) ~/ chunkSize;

      // 逐片上传 .part-N：每片成功 = 一个断点检查点（chunkIndex 单调）。
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
          await _putContent(
            '$remotePath.part-$i',
            slice,
            cfg.credentialsRefKey,
          );
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

      // 按序回读各片拼接 → 简单 PUT 终文件 → 逐 DELETE 分片（Port 无 delete，
      // 仅 adapter 内部自用清理）。
      final builder = BytesBuilder(copy: false);
      for (var i = 0; i < partCount; i++) {
        final Uint8List? data;
        try {
          data = await _getContent(
            '$remotePath.part-$i',
            cfg.credentialsRefKey,
          );
        } on Object catch (e) {
          yield _failedEvent(remotePath, e);
          return;
        }
        if (data == null) {
          yield TransferFailed(
            remotePath,
            TransferError.network,
            detail: '分块回读缺失：$remotePath.part-$i',
          );
          return;
        }
        builder.add(data);
      }
      final assembled = builder.takeBytes();
      if (assembled.length != bytes.length) {
        yield TransferFailed(
          remotePath,
          TransferError.network,
          detail:
              '分块回读长度不符：期望 ${bytes.length} 字节，'
              '实际 ${assembled.length} 字节',
        );
        return;
      }
      try {
        await _putContent(remotePath, assembled, cfg.credentialsRefKey);
      } on Object catch (e) {
        yield _failedEvent(remotePath, e);
        return;
      }
      for (var i = 0; i < partCount; i++) {
        try {
          await _deleteItem('$remotePath.part-$i', cfg.credentialsRefKey);
        } on Object catch (e) {
          // 终文件已写成功，但分片清理失败必须留痕（残留分片会被 diff 过滤，
          // 但污染远端空间）——按失败上报，Engine 重提幂等重传。
          yield _failedEvent(remotePath, e);
          return;
        }
      }
      yield TransferDone(remotePath);
    } on Object catch (e) {
      // 覆盖 _cfg（未绑定）/凭据读取/mkdir 等前置失败：事件面方法不抛流错误。
      yield _failedEvent(remotePath, e);
    }
  }

  @override
  Future<Uint8List?> getFile(String remotePath) async {
    final cfg = _cfg;
    try {
      return await _getContent(remotePath, cfg.credentialsRefKey);
    } on Object catch (e) {
      throw _toContractException(e);
    }
  }

  @override
  Future<List<String>> listRemote(String remoteDir) async {
    final cfg = _cfg;
    final dir = _normalize(remoteDir);
    try {
      final children = await _listChildren(dir, cfg.credentialsRefKey);
      final names =
          children.map((item) => item['name']).whereType<String>().toList()
            ..sort();
      return names;
    } on _GraphException catch (e) {
      if (e.status == 404) {
        return const []; // 目录不存在按空清单处理（健康/容量展示语义）。
      }
      throw _toContractException(e);
    } on Object catch (e) {
      throw _toContractException(e);
    }
  }

  // ── 授权（设备码流，懒触发）────────────────────────────────────────────

  /// 取可用 access token：缓存 → SecureStore 新鲜 token → refresh_token 换新
  /// → 设备码流（发起会话 + 后台轮询，立即抛待授权信号）。
  Future<String> _ensureAuthorized(String refKey) async {
    final cached = _tokenCache[refKey];
    if (cached != null) {
      return cached;
    }
    final creds = _Creds.parse(await _credentials(refKey));
    if (creds == null) {
      throw const ChannelAuthFailedException(
        'OneDrive 凭据未配置（SecureStore 无 clientId），请先完成通道配置',
      );
    }
    if (creds.hasFreshToken) {
      return _tokenCache[refKey] = creds.accessToken!;
    }
    final pending = _pendingAuth[refKey];
    if (pending != null) {
      if (DateTime.now().isBefore(pending.expiresAt)) {
        throw _DeviceAuthPending(pending.verificationUri, pending.userCode);
      }
      _pendingAuth.remove(refKey);
    }
    if (creds.refreshToken != null && creds.refreshToken!.isNotEmpty) {
      final refreshed = await _refreshToken(creds);
      if (refreshed != null) {
        await _persistCreds(
          refKey,
          creds.clientId,
          creds.refreshToken,
          refreshed,
        );
        return _tokenCache[refKey] = refreshed.accessToken;
      }
    }
    final session = await _startDeviceCode(creds.clientId);
    _pendingAuth[refKey] = session;
    unawaited(_pollDeviceAuth(refKey, creds.clientId, session));
    throw _DeviceAuthPending(session.verificationUri, session.userCode);
  }

  /// refresh_token 换新；确定性失败（invalid_grant 等）返回 null 走设备码流，
  /// 网络/超时类瞬时错误原样抛（调用方按 network 映射）。
  Future<_TokenResponse?> _refreshToken(_Creds creds) async {
    final res = await _send(
      'POST',
      Uri.parse(_kTokenUrl),
      form: <String, String>{
        'grant_type': 'refresh_token',
        'client_id': creds.clientId,
        'refresh_token': creds.refreshToken!,
      },
    );
    if (res.status == 200) {
      return _TokenResponse.parse(res.body);
    }
    return null;
  }

  /// 发起设备码会话：POST devicecode（client_id + scope）→ device_code/
  /// user_code/verification_uri/interval/expires_in。
  Future<_DeviceSession> _startDeviceCode(String clientId) async {
    final res = await _send(
      'POST',
      Uri.parse(_kDeviceCodeUrl),
      form: <String, String>{'client_id': clientId, 'scope': _kScope},
    );
    if (res.status != 200) {
      throw ChannelAuthFailedException(
        '设备码会话发起失败（HTTP ${res.status}），请检查应用 clientId 配置',
      );
    }
    final map = _jsonMap(res.body);
    final deviceCode = map['device_code'];
    final userCode = map['user_code'];
    final verificationUri = map['verification_uri'] is String
        ? map['verification_uri'] as String
        : 'https://microsoft.com/devicelogin';
    if (deviceCode is! String || userCode is! String) {
      throw const ChannelAuthFailedException('设备码会话响应不完整，请稍后重试');
    }
    final interval = map['interval'];
    final expiresIn = map['expires_in'];
    return _DeviceSession(
      deviceCode: deviceCode,
      userCode: userCode,
      verificationUri: verificationUri,
      interval: Duration(seconds: interval is num ? interval.toInt() : 5),
      expiresAt: DateTime.now().add(
        Duration(seconds: expiresIn is num ? expiresIn.toInt() : 900),
      ),
    );
  }

  /// 后台轮询设备码会话直到成功/过期：成功 → 回写 SecureStore；过期/被拒 →
  /// 只清会话（下次请求重新发起）。取消探针命中即停（C38）。
  Future<void> _pollDeviceAuth(
    String refKey,
    String clientId,
    _DeviceSession session,
  ) async {
    var interval = session.interval;
    while (DateTime.now().isBefore(session.expiresAt)) {
      if (_isCancelled()) {
        _clearPending(refKey, session);
        return;
      }
      await Future<void>.delayed(interval);
      final _Resp res;
      try {
        res = await _send(
          'POST',
          Uri.parse(_kTokenUrl),
          form: <String, String>{
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            'client_id': clientId,
            'device_code': session.deviceCode,
          },
        );
      } on Object {
        continue; // 网络抖动：按 interval 继续轮询直到过期。
      }
      if (res.status == 200) {
        final token = _TokenResponse.parse(res.body);
        if (token != null) {
          await _persistCreds(refKey, clientId, null, token);
        }
        _clearPending(refKey, session);
        return;
      }
      final error = _jsonMap(res.body)['error'];
      if (error == 'authorization_pending') {
        continue;
      }
      if (error == 'slow_down') {
        interval += const Duration(seconds: 5);
        continue;
      }
      // expired_token / authorization_declined / bad_verification_code / 其他。
      _clearPending(refKey, session);
      return;
    }
    _clearPending(refKey, session);
  }

  /// 合并回写 SecureStore（保留旧 refreshToken；新 expiresAt=now+expires_in）。
  /// 回写失败不抛（后台轮询无人接错）：返回 false，下次请求重新校验/授权。
  Future<bool> _persistCreds(
    String refKey,
    String clientId,
    String? oldRefreshToken,
    _TokenResponse token,
  ) async {
    final merged = _Creds(
      clientId: clientId,
      refreshToken: token.refreshToken ?? oldRefreshToken,
      accessToken: token.accessToken,
      expiresAtMs:
          DateTime.now().millisecondsSinceEpoch + token.expiresInSec * 1000,
    );
    try {
      await _credentialsWriter(refKey, jsonEncode(merged.toJson()));
      return true;
    } on Object {
      return false;
    }
  }

  void _clearPending(String refKey, _DeviceSession session) {
    // identical 防误清：期间若已发起新会话，旧轮询不得清除新会话。
    if (identical(_pendingAuth[refKey], session)) {
      _pendingAuth.remove(refKey);
    }
  }

  // ── Graph 访问 ──────────────────────────────────────────────────────────

  /// 带授权的 Graph 请求：取 token → 发请求；遇 401 失效缓存重取一次再试
  /// （重取触发 refresh/设备码流；仍 401 → _GraphException → auth 映射）。
  Future<_Resp> _graph(
    String method,
    Uri url,
    String refKey, {
    String? contentType,
    List<int>? body,
  }) async {
    var token = await _ensureAuthorized(refKey);
    var res = await _send(
      method,
      url,
      token: token,
      contentType: contentType,
      body: body,
    );
    if (res.status == 401) {
      _tokenCache.remove(refKey);
      token = await _ensureAuthorized(refKey);
      res = await _send(
        method,
        url,
        token: token,
        contentType: contentType,
        body: body,
      );
    }
    return res;
  }

  /// 原始 HTTP（15s 超时；form → urlencoded；body → octet-stream/json）。
  Future<_Resp> _send(
    String method,
    Uri url, {
    String? token,
    String? contentType,
    List<int>? body,
    Map<String, String>? form,
  }) async {
    if (form != null) {
      contentType = 'application/x-www-form-urlencoded';
      body = Uri(queryParameters: form).query.codeUnits;
    }
    final request = await _http.openUrl(method, url).timeout(_kTimeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (contentType != null) {
      request.headers.set(HttpHeaders.contentTypeHeader, contentType);
    }
    if (body != null) {
      request.headers.contentLength = body.length;
      request.add(body);
    }
    final response = await request.close().timeout(_kTimeout);
    final builder = BytesBuilder(copy: false);
    final drained = await response
        .fold<BytesBuilder>(builder, (b, chunk) => b..add(chunk))
        .then((b) => b.takeBytes())
        .timeout(_kTimeout);
    return (status: response.statusCode, body: drained);
  }

  /// 递归列出远端目录树：relPath（相对 dir，'/' 分隔）→ updatedAtMs；
  /// `.part-N` 中断残留分片过滤。目录不存在（404）原样上抛由调用方定夺。
  Future<Map<String, int>> _walkRemote(String dir, String refKey) async {
    final out = <String, int>{};
    Future<void> walk(String path, String rel) async {
      final children = await _listChildren(path, refKey);
      for (final item in children) {
        final name = item['name'];
        if (name is! String || name.isEmpty) {
          continue;
        }
        final childPath = path.isEmpty ? name : '$path/$name';
        final childRel = rel.isEmpty ? name : '$rel/$name';
        if (item['folder'] != null) {
          await walk(childPath, childRel);
        } else if (!_kPartSuffix.hasMatch(childRel)) {
          out[childRel] = _lastModifiedMs(item);
        }
      }
    }

    await walk(dir, '');
    return out;
  }

  /// 列目录（@odata.nextLink 分页）；404 抛 _GraphException 由调用方定夺。
  Future<List<Map<String, dynamic>>> _listChildren(
    String path,
    String refKey,
  ) async {
    final items = <Map<String, dynamic>>[];
    var url = _childrenUrl(path);
    while (true) {
      final res = await _graph('GET', url, refKey);
      if (res.status != 200) {
        _throwGraph(res, '列远端目录失败');
      }
      final map = _jsonMap(res.body);
      final value = map['value'];
      if (value is List) {
        items.addAll(value.whereType<Map<String, dynamic>>());
      }
      final next = map['@odata.nextLink'];
      if (next is! String || next.isEmpty) {
        break;
      }
      url = Uri.parse(next); // nextLink 为服务端拼好的绝对 URL，直接沿用。
    }
    return items;
  }

  /// 确保远端目录链存在（逐级 GET 元数据，缺则 POST children 建目录；
  /// 409 nameAlreadyExists 视为已存在）。
  Future<void> _mkdirAll(String dir, String refKey) async {
    final segs = dir.split('/').where((s) => s.isNotEmpty).toList();
    var parent = '';
    for (final seg in segs) {
      final path = parent.isEmpty ? seg : '$parent/$seg';
      final probe = await _graph('GET', _itemUrl(path), refKey);
      if (probe.status == 404) {
        final created = await _graph(
          'POST',
          _childrenUrl(parent),
          refKey,
          contentType: 'application/json',
          body: utf8.encode(jsonEncode({'name': seg, 'folder': const {}})),
        );
        if (created.status != 200 &&
            created.status != 201 &&
            created.status != 409) {
          _throwGraph(created, '创建远端目录失败：$path');
        }
      } else if (probe.status != 200) {
        _throwGraph(probe, '查询远端目录失败：$path');
      }
      parent = path;
    }
  }

  /// 简单 PUT :/content（≤4MB 口径；覆盖已有文件；201/200=成功）。
  Future<void> _putContent(String path, Uint8List bytes, String refKey) async {
    final res = await _graph(
      'PUT',
      _contentUrl(path),
      refKey,
      contentType: 'application/octet-stream',
      body: bytes,
    );
    if (res.status != 200 && res.status != 201) {
      _throwGraph(res, '上传失败：$path');
    }
  }

  /// GET :/content；404 → null（远端不存在，契约口径）。
  Future<Uint8List?> _getContent(String path, String refKey) async {
    final res = await _graph('GET', _contentUrl(path), refKey);
    if (res.status == 404) {
      return null;
    }
    if (res.status != 200 && res.status != 206) {
      _throwGraph(res, '下载失败：$path');
    }
    return res.body;
  }

  /// DELETE 条目——仅供分片清理内部使用（Port 无 delete 语义，不对外暴露）。
  Future<void> _deleteItem(String path, String refKey) async {
    final res = await _graph('DELETE', _itemUrl(path), refKey);
    if (res.status == 404) {
      return; // 已不存在视为成功（幂等清理）。
    }
    if (res.status != 200 && res.status != 202 && res.status != 204) {
      _throwGraph(res, '清理分片失败：$path');
    }
  }

  // ── 通用小件 ────────────────────────────────────────────────────────────

  /// 分片大小：ChunkPlan 值（<=0 → 契约默认 8 MiB）钳到 4MB 上限内。
  int _effectiveChunk(int planChunk) {
    final size = planChunk <= 0 ? _kDefaultChunkBytes : planChunk;
    return size > _kMaxPartBytes ? _kMaxPartBytes : size;
  }

  bool _isCancelled() => _cancelled?.call() ?? false;

  /// 远端目录/路径入参规范化：去首尾 '/'；空串=根。
  String _normalize(String path) {
    var p = path.trim();
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  /// 父目录（无 '/' → ''=根）。
  String _parentDirOf(String remotePath) {
    final p = _normalize(remotePath);
    final i = p.lastIndexOf('/');
    return i < 0 ? '' : p.substring(0, i);
  }

  bool _isTimeout(Object error) => error is TimeoutException;

  /// 网络层异常（Socket/HTTP）统一 network 语义（分类里兜底，这里供人话文案）。
  bool _isNetworkLevel(Object error) =>
      error is SocketException || error is HttpException;

  /// 统一错误分类：401/403 → auth；507 → disk；413/5xx/网络/未知 → network。
  (TransferError, String) _classify(Object error) {
    final detail = error.toString();
    if (error is _GraphException) {
      final status = error.status;
      if (status == 401 || status == 403) {
        return (TransferError.auth, detail);
      }
      if (status == 507) {
        return (TransferError.disk, detail);
      }
      return (TransferError.network, detail);
    }
    if (error is _DeviceAuthPending) {
      return (TransferError.auth, error.prompt);
    }
    if (error is ChannelAuthFailedException) {
      return (TransferError.auth, error.message);
    }
    return (TransferError.network, detail);
  }

  /// testConnection 的人话失败原因（可直接展示；REQ-SYNC-01）。
  String _friendlyReason(Object error) {
    if (error is ContractException) {
      return error.message; // 已是人话（如凭据未配置/会话发起失败）。
    }
    if (error is _DeviceAuthPending) {
      return error.prompt;
    }
    if (error is _GraphException) {
      final status = error.status;
      if (status == 401 || status == 403) {
        return '授权被拒（HTTP $status），请重新完成设备授权';
      }
      if (status == 507) {
        return 'OneDrive 存储空间不足（HTTP 507），请清理空间后重试';
      }
      if (status == 413) {
        return '单请求超过上传上限（4MB），请改用分块上传';
      }
      if (status >= 500) {
        return 'Microsoft Graph 服务异常（HTTP $status），请稍后重试';
      }
      return '服务拒绝了请求（HTTP $status），请检查远端目录设置';
    }
    if (_isTimeout(error)) {
      return '连接超时（15 秒无响应），请检查网络';
    }
    if (_isNetworkLevel(error)) {
      return '网络连接失败，请检查网络后重试';
    }
    return '网络不可达或服务异常，请检查网络后重试';
  }

  /// putFile 事件面的失败事件（不抛流错误）。
  TransferFailed _failedEvent(String relPath, Object error) {
    final (code, detail) = _classify(error);
    return TransferFailed(relPath, code, detail: detail);
  }

  /// 非事件面方法（diff/getFile/listRemote）的契约异常映射（WebDAV 同口径）：
  /// network → NetworkLostException；auth → ChannelAuthFailedException；
  /// disk → DiskFullException。message=人话默认文案 + 技术细节。
  ContractException _toContractException(Object error) {
    if (error is ContractException) {
      return error;
    }
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
