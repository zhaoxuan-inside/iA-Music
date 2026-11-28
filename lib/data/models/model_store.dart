/// 模型文件仓库——推理模型文件的唯一管理面（data 层文件管理域）。
///
/// 职责：在线下载（单飞防并发重下）、sha256 逐块校验、temp+rename 原子
/// 落盘、登记记账（model_files 表）、文件丢失自愈（登记在但文件没了 →
/// 重下）。inference 模块只消费 resolve 出的文件路径，不知道存储与
/// 下载的存在——模型资产管理与推理计算的分界线就在这里。
library;

import 'dart:io';

import 'package:crypto/crypto.dart';

import '../database.dart';

/// 单值 Digest 收集（crypto 流式哈希的终点；避免额外依赖 convert 包）。
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

class ModelStore {
  ModelStore(this._db, this._modelsDir) {
    _client.connectionTimeout = const Duration(seconds: 15);
  }

  final IaDatabase _db;
  final String _modelsDir;
  final HttpClient _client = HttpClient();

  /// 单飞：同模型并发 ensureReady 共享同一次下载（补全轮次触发与
  /// 手动触发撞车时不产生双份 16MB 流量）。
  final Map<String, Future<String?>> _inFlight = {};

  ModelDao get _dao => _db.modelDao;

  /// 确保模型就绪，返回文件路径；不可用（下载失败/校验不符）→ null。
  /// [onProgress] (receivedBytes, totalBytes) 下载进度上报（可选）。
  Future<String?> ensureReady({
    required String id,
    required String url,
    required String sha256,
    required int sizeBytes,
    void Function(int received, int total)? onProgress,
  }) {
    final existing = _inFlight[id];
    if (existing != null) {
      return existing;
    }
    final future = _ensureReady(
        id: id,
        url: url,
        expectedSha256: sha256,
        sizeBytes: sizeBytes,
        onProgress: onProgress);
    _inFlight[id] = future;
    future.whenComplete(() => _inFlight.remove(id));
    return future;
  }

  Future<String?> _ensureReady({
    required String id,
    required String url,
    required String expectedSha256,
    required int sizeBytes,
    void Function(int received, int total)? onProgress,
  }) async {
    // 1) 登记命中且校验锚一致且文件在 → 直接复用（零下载）
    final row = await _dao.readyModel(id);
    if (row != null &&
        row.sha256 == expectedSha256 &&
        File(row.filePath).existsSync()) {
      return row.filePath;
    }
    // 登记与文件失配（换版本/校验锚变更/文件被删）→ 清位重下（自愈）
    if (row != null) {
      await _dao.forget(id);
    }

    // 2) 下载 → 校验 → 原子落盘 → 登记
    try {
      final file = await _download(id, url, expectedSha256, sizeBytes, onProgress);
      await _dao.markReady(
          id: id,
          url: url,
          sha256: expectedSha256,
          filePath: file.path,
          sizeBytes: file.lengthSync());
      return file.path;
    } on Object {
      // 下载/校验失败：temp 已清，登记未写 → null = 本会话端口级不可用，
      // 下一轮 runOnce / 重启重试（错误原文由组合根接线层进诊断）。
      return null;
    }
  }

  /// 流式下载 + 逐块 sha256 + 长度守卫 + 原子落盘。
  Future<File> _download(
      String id,
      String url,
      String expectedSha256,
      int sizeBytes,
      void Function(int received, int total)? onProgress) async {
    final tmp = File('$_modelsDir/$id.download.tmp');
    try {
      final req = await _client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) {
        throw Exception('模型下载失败：HTTP ${res.statusCode}');
      }
      final total =
          res.contentLength > 0 ? res.contentLength : sizeBytes;
      final sink = tmp.openWrite();
      final digestSink = _DigestSink();
      final hasher = sha256.startChunkedConversion(digestSink);
      var received = 0;
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          hasher.add(chunk);
          received += chunk.length;
          if (onProgress != null) {
            onProgress(received, total);
          }
        }
        await sink.flush();
        await sink.close();
      } on Object {
        try {
          await sink.close();
        } on Object {
          // 半截文件由 finally 统一清理
        }
        rethrow;
      }
      hasher.close();

      // 双重完整性守卫：长度不符直接判废（不等哈希），哈希不符判伪源
      if (sizeBytes > 0 && received != sizeBytes) {
        throw Exception('模型字节数不符：$received ≠ $sizeBytes');
      }
      final actual = digestSink.value!.toString();
      if (actual != expectedSha256) {
        throw Exception('模型 sha256 不符：$actual');
      }

      // 原子落盘：同卷 rename（temp 与目标同目录，恒同卷）
      final target = File('$_modelsDir/$id.tflite');
      if (target.existsSync()) {
        target.deleteSync(); // 自有文件，换版本重下前覆盖
      }
      return await tmp.rename(target.path);
    } on Object {
      try {
        if (tmp.existsSync()) {
          tmp.deleteSync();
        }
      } on Object {
        // 清不掉的 temp 下次下载覆盖，无碍正确性
      }
      rethrow;
    }
  }
}
