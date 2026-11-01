/// WS6 同步域 —— Google Drive 通道适配器（Drive v3；REQ-SYNC-01/02/03/06）。
///
/// * [GoogleDriveAdapter] 以 `dart:io` HttpClient 直连 Drive v3
///   （https://www.googleapis.com/drive/v3 + upload 端点
///   https://www.googleapis.com/upload/drive/v3）实现 `SyncChannelPort`
///   全部五方法（DEC-010：无 mock/替身）。
/// * 凭据：[ChannelConfig.credentialsRefKey] 指向 SecureStore 的 JSON
///   `{"clientId":"...","refreshToken":"...","accessToken":"...","expiresAt":ms}`
///   （accessToken 可缺省，与 OneDriveAdapter 同形态）；构造注入 credentials
///   读取器与 credentialsWriter 回写器，凭据值不落日志（C50）。
/// * OAuth 设备码流（懒触发，scope=drive.file）：任何请求无可用 token 或遇
///   401 → 先用 refresh_token 换新；失败则发起设备码会话
///   （POST oauth2.googleapis.com/device/code）并后台轮询 token 端点直到
///   成功/过期，成功自动回写 SecureStore。**授权需用户交互**，不做浏览器内嵌
///   （docs/DELIVERY-NOTES①）：未授权时 testConnection 返回
///   `需要在浏览器完成设备授权：{verification_uri}，代码 {user_code}`，
///   其余方法抛 [ChannelAuthFailedException]（同人话文案）。
/// * 资源模型：Drive 无路径 —— 用「按名查找父目录链」：根=用户主目录
///   （spaces=drive，'root' 别名；不用 appDataFolder——需 files 权限口径）。
///   `q=name='X' and mimeType='application/vnd.google-apps.folder' and
///   '{parentId}' in parents and trashed=false` 逐级解析/逐级建目录；文件按
///   (parent, name) 定位。注意 Drive 允许同名条目：查找取首个命中。
/// * 上传：先按 (parent,name) 定位——命中 → media PATCH 覆盖内容（语义对齐
///   WebDAV PUT）；未命中 → multipart 创建（name+parents 元数据同请求）。
///   大文件不用 resumable 会话（docs/DELIVERY-NOTES②）——按 ChunkPlan 切片逐传
///   `{name}.part-N`，每片成功即 TransferCheckpointSaved（断点凭据）；全部
///   完成后按序回读拼接、传终文件、内部 DELETE 分片（Port 红线：无删除语义，
///   DELETE 仅 adapter 自用清理）。
/// * diff 语义与 WebDavAdapter 完全一致：递归远端目录树 → ManifestEntry
///   （relPath 相对 remoteDir；updatedAtMs=modifiedTime ISO8601 → epoch ms；
///   hash=null）；`.part-N` 中断残留分片过滤；remoteDir 目录不存在=从未同步
///   （全部本地进 toUpload）。时间戳仲裁归 SyncEngine，adapter 只报告。
/// * 错误映射（_classify）：401 → auth（Drive 的 403 多为限流/配额，归
///   network 并在人话文案区分）；5xx/Socket/Timeout/其余 → network。
///   事件面（putFile）一律以 TransferFailed 事件收尾不抛；非事件面
///   （diff/getFile/listRemote）抛契约异常（NetworkLostException /
///   ChannelAuthFailedException / DiskFullException），不吞异常不留痕。
/// * docs/DELIVERY-NOTES（后续迭代输入）：
///   ① 设备码授权不做浏览器内嵌/WebView——用户在系统浏览器打开
///      verification_uri（Google 返回 verification_url，缺省
///      https://google.com/device）输入 user_code；适配器侧后台轮询自动完成
///      令牌回写。真服务联调需 Google Cloud OAuth 客户端（类型=TV 和受限输入
///      设备，启用 device flow）+ OAuth 同意屏配置 scope=drive.file。
///   ② 官方建议 simple/multipart ≤5MB（超限未实测；5,120GB 为端点上限）——
///      本 adapter 分片钳到 4MB 保守上限；终文件拼接后仍走 multipart，超限
///      失败 → TransferFailed 留痕（如遇阻可切 resumable uploadType）。
///   ③ 设备码流/Drive 端点未经真服务联调（无法真测，见报告）；人工验证步骤：
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

/// Drive v3 根地址（元数据/查询）。
const String _kDriveBase = 'https://www.googleapis.com/drive/v3';

/// Drive v3 上传端点（media/multipart PUT/POST/PATCH）。
const String _kDriveUploadBase = 'https://www.googleapis.com/upload/drive/v3';

/// 设备码流端点。
const String _kDeviceCodeUrl = 'https://oauth2.googleapis.com/device/code';
const String _kTokenUrl = 'https://oauth2.googleapis.com/token';

/// OAuth scope（drive.file：仅本应用创建的文件可见可写）。
const String _kScope = 'https://www.googleapis.com/auth/drive.file';

/// Drive 文件夹 MIME。
const String _kFolderMime = 'application/vnd.google-apps.folder';

/// verification_uri 兜底（Google 文档口径）。
const String _kFallbackVerificationUri = 'https://google.com/device';

/// ChunkPlan.chunkSizeBytes 非法（<=0）时的兜底分片大小（契约默认 8 MiB）。
const int _kDefaultChunkBytes = 8 * 1024 * 1024;

/// 分片/单请求保守上限（官方建议 simple/multipart ≤5MB，取 4MB 含
/// multipart 边界/header 余量）。
const int _kMaxPartBytes = 4 * 1024 * 1024;

/// token 到期提前量（60s 网络余量）。
const int _kExpirySkewMs = 60 * 1000;

/// `.part-N` 临时分片名后缀（diff 遍历过滤：上传中断残留的分片不是同步实体）。
final RegExp _kPartSuffix = RegExp(r'\.part-\d+$');

/// SecureStore 凭据 JSON 形态（与 OneDriveAdapter 同形态）。
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

/// Drive 非 2xx 响应异常（status 供分类；code/message 取自错误体）。
final class _DriveException implements Exception {
  const _DriveException(this.status, this.code, this.message);

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

/// 以 Drive 错误体抛 [_DriveException]（[what] 为无错误体时的兜底描述）。
Never _throwDrive(_Resp res, String what) {
  final err = _jsonMap(res.body)['error'];
  final code = err is Map<String, dynamic> ? err['status'] : null;
  final message = err is Map<String, dynamic> ? err['message'] : null;
  throw _DriveException(
    res.status,
    code is String ? code : '',
    message is String && message.isNotEmpty ? message : what,
  );
}

/// base + path + 查询参数组装 URL（参数值经 Uri 百分号编码）。
Uri _uri(String base, String path, Map<String, String>? params) {
  final parsed = Uri.parse('$base/$path');
  return params == null ? parsed : parsed.replace(queryParameters: params);
}

/// Drive q 语法的字符串转义（\ 与 ' 需反斜杠转义）。
String _escapeQ(String value) =>
    value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

/// modifiedTime（ISO8601 UTC）→ epoch ms；缺省 0。
int _modifiedMs(Map<String, dynamic> item) {
  final modified = item['modifiedTime'];
  if (modified is! String || modified.isEmpty) {
    return 0;
  }
  try {
    return DateTime.parse(modified).millisecondsSinceEpoch;
  } on FormatException {
    return 0;
  }
}

/// SyncChannelPort 的 Google Drive（v3）实现。
final class GoogleDriveAdapter implements SyncChannelPort {
  /// [credentials]=SecureStore 读取器注入（凭据本体不进本类）；[credentialsWriter]=
  /// SecureStore 回写器（设备码流/refresh 换发新凭据后持久化）；[cancelled]=块
  /// 边界协作式取消探针（可选，默认 null=不可取消）；[config]=初始通道（可后经
  /// [bind] 绑定/更换；私有字段经 private named parameter 对外仍叫
  /// credentials/credentialsWriter/cancelled/config）。
  GoogleDriveAdapter({
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
      throw StateError('GoogleDriveAdapter 未绑定通道配置：先调用 bind(cfg) 再执行同步操作');
    }
    return cfg;
  }

  @override
  Future<TestResult> testConnection(ChannelConfig cfg) async {
    if (cfg.type != ChannelType.gdrive) {
      return const TestResult(
        ok: false,
        reason: '通道类型不是 Google Drive，无法用 Drive v3 方式测试连接',
      );
    }
    try {
      // 根可达性探针（'root' 别名不产生网络调用，需真实列一次）。
      final probe = await _graph(
        'GET',
        _uri(_kDriveBase, 'files', const {
          'pageSize': '1',
          'fields': 'files(id)',
          'spaces': 'drive',
        }),
        cfg.credentialsRefKey,
      );
      if (probe.status != 200) {
        _throwDrive(probe, '访问 Google Drive 失败');
      }
      // 确保 remoteDir 目录链存在（与 WebDAV mkdirAll 口径一致）。
      await _resolveDirId(
        _normalize(cfg.remoteDir),
        cfg.credentialsRefKey,
        create: true,
      );
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
    final Map<String, int> remoteMtimes;
    try {
      final rootId = await _resolveDirId(
        _normalize(remoteDir),
        cfg.credentialsRefKey,
        create: false,
      );
      remoteMtimes = await _walkRemote(rootId, cfg.credentialsRefKey);
    } on _DriveException catch (e) {
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
      final dir = _parentDirOf(remotePath);
      final name = _baseName(remotePath);
      final parentId = await _resolveDirId(
        dir,
        cfg.credentialsRefKey,
        create: true,
      );
      if (chunked == null) {
        await _uploadFile(parentId, name, bytes, cfg.credentialsRefKey);
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
          await _uploadFile(
            parentId,
            '$name.part-$i',
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

      // 按序回读各片拼接 → 传终文件 → 逐 DELETE 分片（Port 无 delete，
      // 仅 adapter 内部自用清理）。
      final builder = BytesBuilder(copy: false);
      for (var i = 0; i < partCount; i++) {
        final Uint8List? data;
        try {
          data = await _downloadByName(
            parentId,
            '$name.part-$i',
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
            detail: '分块回读缺失：$name.part-$i',
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
        await _uploadFile(parentId, name, assembled, cfg.credentialsRefKey);
      } on Object catch (e) {
        yield _failedEvent(remotePath, e);
        return;
      }
      for (var i = 0; i < partCount; i++) {
        try {
          await _deleteByName(parentId, '$name.part-$i', cfg.credentialsRefKey);
        } on Object catch (e) {
          // 终文件已传成功，但分片清理失败必须留痕（残留分片会被 diff 过滤，
          // 但污染远端空间）——按失败上报，Engine 重提幂等重传。
          yield _failedEvent(remotePath, e);
          return;
        }
      }
      yield TransferDone(remotePath);
    } on Object catch (e) {
      // 覆盖 _cfg（未绑定）/凭据读取/目录解析等前置失败：事件面方法不抛流错误。
      yield _failedEvent(remotePath, e);
    }
  }

  @override
  Future<Uint8List?> getFile(String remotePath) async {
    final cfg = _cfg;
    try {
      final parentId = await _resolveDirId(
        _parentDirOf(remotePath),
        cfg.credentialsRefKey,
        create: false,
      );
      return await _downloadByName(
        parentId,
        _baseName(remotePath),
        cfg.credentialsRefKey,
      );
    } on _DriveException catch (e) {
      if (e.status == 404) {
        return null; // 远端目录/文件不存在 → null（契约口径）。
      }
      throw _toContractException(e);
    } on Object catch (e) {
      throw _toContractException(e);
    }
  }

  @override
  Future<List<String>> listRemote(String remoteDir) async {
    final cfg = _cfg;
    try {
      final parentId = await _resolveDirId(
        _normalize(remoteDir),
        cfg.credentialsRefKey,
        create: false,
      );
      final children = await _filesList(
        "'$parentId' in parents and trashed = false",
        cfg.credentialsRefKey,
      );
      final names =
          children.map((item) => item['name']).whereType<String>().toList()
            ..sort();
      return names;
    } on _DriveException catch (e) {
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
        'Google Drive 凭据未配置（SecureStore 无 clientId），请先完成通道配置',
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

  /// 发起设备码会话：POST device/code（client_id + scope）→ device_code/
  /// user_code/verification_url/interval/expires_in。
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
        : map['verification_url'] is String
        ? map['verification_url'] as String
        : _kFallbackVerificationUri;
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
      // expired_token / access_denied / 其他确定性失败。
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

  // ── Drive v3 访问 ───────────────────────────────────────────────────────

  /// 带授权的 Drive 请求：取 token → 发请求；遇 401 失效缓存重取一次再试
  /// （重取触发 refresh/设备码流；仍 401 → _DriveException → auth 映射）。
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

  /// 按名逐级解析目录 id（Drive 无路径模型）；[create] 缺级时逐级建目录。
  /// 根 = 'root'（用户主目录别名，spaces=drive）。目录链不存在且不可建 →
  /// 抛 404 _DriveException（diff/getFile/listRemote 据此走「不存在」分支）。
  Future<String> _resolveDirId(
    String dir,
    String refKey, {
    required bool create,
  }) async {
    var parent = 'root';
    for (final seg in dir.split('/').where((s) => s.isNotEmpty)) {
      final existing = await _findFolderId(parent, seg, refKey);
      if (existing != null) {
        parent = existing;
        continue;
      }
      if (!create) {
        throw _DriveException(404, 'notFound', '远端目录不存在：$dir');
      }
      final created = await _graph(
        'POST',
        _uri(_kDriveBase, 'files', null),
        refKey,
        contentType: 'application/json; charset=UTF-8',
        body: utf8.encode(
          jsonEncode(<String, dynamic>{
            'name': seg,
            'mimeType': _kFolderMime,
            'parents': <String>[parent],
          }),
        ),
      );
      if (created.status != 200 && created.status != 201) {
        _throwDrive(created, '创建远端目录失败：$seg');
      }
      final id = _jsonMap(created.body)['id'];
      if (id is! String || id.isEmpty) {
        throw _DriveException(500, 'noId', '创建目录响应缺少 id：$seg');
      }
      parent = id;
    }
    return parent;
  }

  /// files.list（q + 分页 fields）；200 之外的任何状态原样抛（含 404）。
  Future<List<Map<String, dynamic>>> _filesList(String q, String refKey) async {
    final items = <Map<String, dynamic>>[];
    String? pageToken;
    while (true) {
      final res = await _graph(
        'GET',
        _uri(_kDriveBase, 'files', <String, String>{
          'q': q,
          'fields': 'files(id,name,mimeType,size,modifiedTime),nextPageToken',
          'pageSize': '200',
          'spaces': 'drive',
          'pageToken': ?pageToken,
        }),
        refKey,
      );
      if (res.status != 200) {
        _throwDrive(res, '查询远端目录失败');
      }
      final map = _jsonMap(res.body);
      final value = map['files'];
      if (value is List) {
        items.addAll(value.whereType<Map<String, dynamic>>());
      }
      final next = map['nextPageToken'];
      pageToken = next is String && next.isNotEmpty ? next : null;
      if (pageToken == null) {
        break;
      }
    }
    return items;
  }

  /// 按 (parent, name) 定位文件夹 id；未命中 → null。
  Future<String?> _findFolderId(
    String parentId,
    String name,
    String refKey,
  ) async {
    final items = await _filesList(
      "name = '${_escapeQ(name)}' and mimeType = '$_kFolderMime' and "
      "'$parentId' in parents and trashed = false",
      refKey,
    );
    return _firstId(items);
  }

  /// 按 (parent, name) 定位文件（非文件夹）id；未命中 → null。
  Future<String?> _findFileId(
    String parentId,
    String name,
    String refKey,
  ) async {
    final items = await _filesList(
      "name = '${_escapeQ(name)}' and '$parentId' in parents and "
      "mimeType != '$_kFolderMime' and trashed = false",
      refKey,
    );
    return _firstId(items);
  }

  String? _firstId(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final id = item['id'];
      if (id is String && id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  /// 上传（存在即覆盖，语义对齐 WebDAV PUT）：先按 (parent,name) 定位——
  /// 命中 → media PATCH 覆盖内容；未命中 → multipart 创建（name+parents）。
  Future<void> _uploadFile(
    String parentId,
    String name,
    Uint8List bytes,
    String refKey,
  ) async {
    final existing = await _findFileId(parentId, name, refKey);
    if (existing != null) {
      final res = await _graph(
        'PATCH',
        _uri(_kDriveUploadBase, 'files/$existing', const {
          'uploadType': 'media',
        }),
        refKey,
        contentType: 'application/octet-stream',
        body: bytes,
      );
      if (res.status != 200 && res.status != 201) {
        _throwDrive(res, '上传失败：$name');
      }
      return;
    }
    await _createMultipart(parentId, name, bytes, refKey);
  }

  /// multipart 创建（metadata + bytes 同请求；Google 官方建议 ≤5MB/请求，
  /// 分片大小已钳到 4MB 保守上限）。
  Future<void> _createMultipart(
    String parentId,
    String name,
    Uint8List bytes,
    String refKey,
  ) async {
    final boundary = 'ia_music_${DateTime.now().microsecondsSinceEpoch}_dart';
    final meta = jsonEncode(<String, dynamic>{
      'name': name,
      'parents': <String>[parentId],
    });
    final builder = BytesBuilder(copy: false)
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n'
          '\r\n'
          '$meta\r\n'
          '--$boundary\r\n'
          'Content-Type: application/octet-stream\r\n'
          '\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));
    final res = await _graph(
      'POST',
      _uri(_kDriveUploadBase, 'files', const {'uploadType': 'multipart'}),
      refKey,
      contentType: 'multipart/related; boundary=$boundary',
      body: builder.takeBytes(),
    );
    if (res.status != 200 && res.status != 201) {
      _throwDrive(res, '上传失败：$name');
    }
  }

  /// 按 (parent, name) 下载（files/{id}?alt=media）；目录/文件不存在 → null。
  Future<Uint8List?> _downloadByName(
    String parentId,
    String name,
    String refKey,
  ) async {
    final id = await _findFileId(parentId, name, refKey);
    if (id == null) {
      return null;
    }
    final res = await _graph(
      'GET',
      _uri(_kDriveBase, 'files/$id', const {'alt': 'media'}),
      refKey,
    );
    if (res.status == 404) {
      return null;
    }
    if (res.status != 200 && res.status != 206) {
      _throwDrive(res, '下载失败：$name');
    }
    return res.body;
  }

  /// DELETE 文件——仅供分片清理内部使用（Port 无 delete 语义，不对外暴露）。
  Future<void> _deleteByName(
    String parentId,
    String name,
    String refKey,
  ) async {
    final id = await _findFileId(parentId, name, refKey);
    if (id == null) {
      return; // 已不存在视为成功（幂等清理）。
    }
    final res = await _graph(
      'DELETE',
      _uri(_kDriveBase, 'files/$id', null),
      refKey,
    );
    if (res.status == 404) {
      return;
    }
    if (res.status != 200 && res.status != 204) {
      _throwDrive(res, '清理分片失败：$name');
    }
  }

  /// 递归列出远端目录树：relPath（相对 rootId 子树，'/' 分隔）→ updatedAtMs；
  /// `.part-N` 中断残留分片过滤。
  Future<Map<String, int>> _walkRemote(String rootId, String refKey) async {
    final out = <String, int>{};
    Future<void> walk(String parentId, String rel) async {
      final children = await _filesList(
        "'$parentId' in parents and trashed = false",
        refKey,
      );
      for (final item in children) {
        final name = item['name'];
        if (name is! String || name.isEmpty) {
          continue;
        }
        final childRel = rel.isEmpty ? name : '$rel/$name';
        if ((item['mimeType'] as String? ?? '') == _kFolderMime) {
          final id = item['id'];
          if (id is String && id.isNotEmpty) {
            await walk(id, childRel);
          }
        } else if (!_kPartSuffix.hasMatch(childRel)) {
          out[childRel] = _modifiedMs(item);
        }
      }
    }

    await walk(rootId, '');
    return out;
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

  /// 文件名（无 '/' → 整段）。
  String _baseName(String remotePath) {
    final p = _normalize(remotePath);
    final i = p.lastIndexOf('/');
    return i < 0 ? p : p.substring(i + 1);
  }

  bool _isTimeout(Object error) => error is TimeoutException;

  /// 网络层异常（Socket/HTTP）统一 network 语义（分类里兜底，这里供人话文案）。
  bool _isNetworkLevel(Object error) =>
      error is SocketException || error is HttpException;

  /// 统一错误分类：401 → auth（Drive 的 403 多为限流/配额，归 network）；
  /// 5xx/网络/未知 → network。
  (TransferError, String) _classify(Object error) {
    final detail = error.toString();
    if (error is _DriveException) {
      if (error.status == 401) {
        return (TransferError.auth, detail);
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
    if (error is _DriveException) {
      final status = error.status;
      if (status == 401) {
        return '授权被拒（HTTP 401），请重新完成设备授权';
      }
      if (status == 403) {
        return 'Google Drive 拒绝访问（HTTP 403，限流/配额/权限），请稍后重试';
      }
      if (status >= 500) {
        return 'Google Drive 服务异常（HTTP $status），请稍后重试';
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
