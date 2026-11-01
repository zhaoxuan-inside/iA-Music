/// GitHub 同步通道（WS6/REQ-SYNC-01/02/08：**轻数据 only**——不存音频）。
///
/// REST Contents API（api.github.com）：
/// * baseUrl 形态=`https://github.com/{owner}/{repo}`（私有仓库 + PAT）；
/// * token 经 cfg.credentialsRefKey → SecureStore 读取（C50：凭据唯一出入点）；
/// * diff/putFile/getFile/listRemote 全走 contents API（GET/PUT，sha 乐观锁）；
/// * `supportsAudio=false`：音频开关在 UI+逻辑双侧禁用（REQ-SYNC-08）。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:contracts/contracts.dart';

/// GitHub Contents API 适配器。
final class GitHubAdapter implements SyncChannelPort {
  GitHubAdapter({required this._credentials, this._config});

  final Future<String?> Function(String refKey) _credentials;
  final ChannelConfig? _config;
  HttpClient? _http;

  static const _timeout = Duration(seconds: 15);

  HttpClient get _client => _http ??= HttpClient()
    ..connectionTimeout = _timeout
    ..findProxy = HttpClient.findProxyFromEnvironment;

  /// 音频支持=否（REQ-SYNC-08：GitHub 仓库限制；UI+逻辑双侧禁用）。
  static const bool supportsAudio = false;

  ({String owner, String repo}) _repoOf(String baseUrl) {
    final clean = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final parts = clean.split('/');
    if (parts.length < 2) {
      throw ChannelAuthFailedException('仓库地址无效：应为 https://github.com/{owner}/{repo}');
    }
    return (owner: parts[parts.length - 2], repo: parts.last);
  }

  Future<String> _token(ChannelConfig cfg) async {
    final token = await _credentials(cfg.credentialsRefKey);
    if (token == null || token.isEmpty) {
      throw ChannelAuthFailedException('未配置访问 Token（GitHub 需要仓库级 PAT）');
    }
    return token;
  }

  Future<Map<String, dynamic>> _api(
    Uri uri, {
    required String token,
    String method = 'GET',
    Object? body,
  }) async {
    final req = await _client.openUrl(method, uri);
    req.headers.set('Authorization', 'Bearer $token');
    req.headers.set('Accept', 'application/vnd.github+json');
    req.headers.set('X-GitHub-Api-Version', '2022-11-28');
    req.followRedirects = true;
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final resp = await req.close().timeout(_timeout);
    final text = await utf8.decodeStream(resp);
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw ChannelAuthFailedException('GitHub Token 无效或权限不足（${resp.statusCode}）');
    }
    if (resp.statusCode >= 400) {
      throw NetworkLostException(
          'GitHub API 失败（${resp.statusCode}）${text.length > 120 ? '：${text.substring(0, 120)}' : ''}');
    }
    if (text.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  String _contentsUrl(ChannelConfig cfg, String path) {
    final r = _repoOf(cfg.baseUrl);
    final cleanPath = path.replaceAll(RegExp(r'^/+'), '');
    return 'https://api.github.com/repos/${r.owner}/${r.repo}/contents/$cleanPath';
  }

  @override
  Future<TestResult> testConnection(ChannelConfig cfg) async {
    try {
      final token = await _token(cfg);
      final r = _repoOf(cfg.baseUrl);
      await _api(
        Uri.parse('https://api.github.com/repos/${r.owner}/${r.repo}'),
        token: token,
      );
      return const TestResult(ok: true);
    } on ContractException catch (e) {
      return TestResult(ok: false, reason: e.message);
    } on SocketException {
      return const TestResult(ok: false, reason: '网络不可达：请检查网络连接');
    } on TimeoutException {
      return const TestResult(ok: false, reason: '连接超时：请检查网络后重试');
    }
  }

  @override
  Future<RemoteDiff> diff(String remoteDir, LocalManifest local) async {
    final cfg = _requireCfg;
    final remoteEntries = <ManifestEntry>[];
    await _collectDir(cfg, remoteDir, remoteEntries);
    final remoteByName = {for (final e in remoteEntries) e.relPath: e};
    final localByName = {for (final e in local.entries) e.relPath: e};
    final toUpload = <ManifestEntry>[];
    final toDownload = <ManifestEntry>[];
    final conflicts = <ManifestEntry>[];
    for (final e in local.entries) {
      final remote = remoteByName[e.relPath];
      if (remote == null) {
        toUpload.add(e);
      } else if (remote.updatedAtMs != e.updatedAtMs) {
        conflicts.add(e); // 双侧同键不同时间——Engine last-writer-wins
      }
    }
    for (final e in remoteEntries) {
      if (!localByName.containsKey(e.relPath)) {
        toDownload.add(e);
      }
    }
    return RemoteDiff(
        toUpload: toUpload, toDownload: toDownload, conflicts: conflicts);
  }

  final List<(ChannelConfig, String)> _cfgStack = [];

  ChannelConfig get _requireCfg {
    if (_cfgStack.isEmpty) {
      final bound = _config;
      if (bound == null) {
        throw StateError('GitHubAdapter: 构造传入 config 或先 attachConfig');
      }
      return bound;
    }
    return _cfgStack.last.$1;
  }

  /// 递归列目录（目录树=GitHub tree API 单调用更快；此处 contents API 逐级）。
  Future<void> _collectDir(
      ChannelConfig cfg, String dir, List<ManifestEntry> out) async {
    final token = await _token(cfg);
    final r = _repoOf(cfg.baseUrl);
    final cleanDir = dir.replaceAll(RegExp(r'^/+'), '');
    final uri =
        Uri.parse('https://api.github.com/repos/${r.owner}/${r.repo}/contents/$cleanDir');
    final Map<String, dynamic> resp;
    try {
      resp = await _api(uri, token: token);
    } on NetworkLostException {
      return; // 目录不存在（首次同步）=空清单
    }
    final items = resp['items'] as List?;
    if (items == null) {
      return;
    }
    for (final raw in items) {
      final f = raw as Map<String, dynamic>;
      final type = f['type'] as String?;
      final path = f['path'] as String? ?? '';
      if (type == 'dir') {
        await _collectDir(cfg, '$path/', out);
      } else if (type == 'file') {
        final size = (f['size'] as num?)?.toInt() ?? 0;
        out.add(ManifestEntry(
          relPath: path.replaceFirst(RegExp('^$cleanDir/'), ''),
          updatedAtMs: _shaMs(f['sha'] as String?),
          hash: size > 0 ? 'gh:${f['sha']}' : null,
        ));
      }
    }
  }

  /// GitHub contents 无 mtime——用 blob sha 哈希前缀派生稳定"版本时间"
  /// （同内容=同值；Engine 只比较相等性，单调性由内容哈希保证）。
  int _shaMs(String? sha) {
    if (sha == null || sha.length < 8) {
      return 0;
    }
    return int.parse(sha.substring(0, 8), radix: 16);
  }

  @override
  Stream<TransferEvent> putFile(
      String remotePath, Uint8List bytes, {ChunkPlan? chunked}) async* {
    final cfg = _requireCfg;
    final token = await _token(cfg);
    final path = '${cfg.remoteDir}/$remotePath'.replaceAll(RegExp(r'^/+'), '');
    try {
      // 既有 sha（乐观锁：不存在=新建）
      String? existingSha;
      try {
        final meta = await _api(
          Uri.parse(_contentsUrl(cfg, path)),
          token: token,
        );
        existingSha = meta['sha'] as String?;
      } on NetworkLostException {
        existingSha = null; // 404=新建
      }
      final resp = await _api(
        Uri.parse(_contentsUrl(cfg, path)),
        token: token,
        method: 'PUT',
        body: {
          'message': 'iA-Music sync: $remotePath',
          'content': base64Encode(bytes),
          'sha': ?existingSha,
        },
      );
      if (resp.isEmpty) {
        yield TransferFailed(remotePath, TransferError.network,
            detail: 'empty commit response');
      } else {
        yield TransferProgress(remotePath, bytes.length, bytes.length);
        yield TransferDone(remotePath);
      }
    } on ContractException catch (e) {
      yield TransferFailed(remotePath,
          e is ChannelAuthFailedException ? TransferError.auth : TransferError.network,
          detail: e.message);
    } on SocketException catch (e) {
      yield TransferFailed(remotePath, TransferError.network, detail: '$e');
    } on TimeoutException {
      yield TransferFailed(remotePath, TransferError.network, detail: 'timeout');
    }
  }

  @override
  Future<Uint8List?> getFile(String remotePath) async {
    final cfg = _requireCfg;
    final token = await _token(cfg);
    final path =
        '${cfg.remoteDir}/$remotePath'.replaceAll(RegExp(r'^/+'), '');
    try {
      final meta = await _api(Uri.parse(_contentsUrl(cfg, path)), token: token);
      final content = meta['content'] as String?;
      if (content == null) {
        return null;
      }
      return base64Decode(content.replaceAll('\n', ''));
    } on NetworkLostException {
      return null; // 404/不存在
    }
  }

  @override
  Future<List<String>> listRemote(String remoteDir) async {
    final cfg = _requireCfg;
    final token = await _token(cfg);
    final cleanDir = remoteDir.replaceAll(RegExp(r'^/+'), '');
    final r = _repoOf(cfg.baseUrl);
    try {
      final resp = await _api(
        Uri.parse(
            'https://api.github.com/repos/${r.owner}/${r.repo}/contents/$cleanDir'),
        token: token,
      );
      final items = resp['items'] as List? ?? const [];
      return [
        for (final raw in items)
          ((raw as Map<String, dynamic>)['name'] as String? ?? ''),
      ]..removeWhere((n) => n.isEmpty);
    } on NetworkLostException {
      return const [];
    }
  }

  /// 通道装配缝：SyncService 在每次同步前 push cfg（有状态面最小化）。
  void attachConfig(ChannelConfig cfg) => _cfgStack.add((cfg, ''));
  void detachConfig() {
    if (_cfgStack.isNotEmpty) {
      _cfgStack.removeLast();
    }
  }

  void close() {
    _http?.close();
    _http = null;
  }
}
