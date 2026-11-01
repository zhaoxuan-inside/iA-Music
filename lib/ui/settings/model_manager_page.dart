/// 歌词模型管理页（WS4/REQ-LYRAI-01：SenseVoiceSmall int8 下载/状态/删除）。
///
/// 下载源=ModelScope 优先，Hugging Face 作为回退；版本钉死=2024-07-17 模型。
/// 完成后写 model_registry(status=present, localPath)——ExtractQueue 的
/// `_presentModelDir()` 即刻生效，无需重启。sha256=落账真实值（docs/DELIVERY-NOTES
/// 记录：下载完成前对两个文件进行固定 SHA-256 校验）。
library;

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' show Digest, sha256;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ia_music/data/ia_database.dart';
import 'package:ia_music/data/tables.dart';
import 'package:ia_music/l10n/s.dart';
import 'package:ia_music/library/library_hub.dart';
import 'package:ia_music/ui/theme/ia_icons.dart';
import 'package:ia_music/ui/theme/ia_theme.dart';

/// 模型标识（=ASR 链路 `_presentModelDir` 匹配的 'sensevoice' 家族）。
const String kSenseVoiceModelId = 'sensevoice-int8-20240717';
const String _kOnnxSha256 =
    'c71f0ce00bec95b07744e116345e33d8cbbe08cef896382cf907bf4b51a2cd51';
const String _kTokensSha256 =
    'f449eb28dc567533d7fa59be34e2abca8784f771850c78a47fb731a31429a1dc';

// ModelScope is the preferred distribution channel for mainland users.  The
// repository below contains the sherpa-compatible SenseVoice files (the
// official iic/SenseVoiceSmall repository contains the original export and
// cannot be loaded directly by sherpa-onnx).
const List<String> _kOnnxUrls = [
  'https://www.modelscope.cn/models/xiaohaoxin/sherpa-onnx-sense-voice-small/resolve/master/model.int8.onnx',
  'https://modelscope.cn/models/xiaohaoxin/sherpa-onnx-sense-voice-small/resolve/master/model.int8.onnx',
  'https://huggingface.co/nocmt/SenseVoiceSmall-INT8-ONNX/resolve/main/model.int8.onnx',
  'https://hf-mirror.com/nocmt/SenseVoiceSmall-INT8-ONNX/resolve/main/model.int8.onnx',
];
const List<String> _kTokensUrls = [
  'https://www.modelscope.cn/models/xiaohaoxin/sherpa-onnx-sense-voice-small/resolve/master/tokens.txt',
  'https://modelscope.cn/models/xiaohaoxin/sherpa-onnx-sense-voice-small/resolve/master/tokens.txt',
  'https://huggingface.co/nocmt/SenseVoiceSmall-INT8-ONNX/resolve/main/tokens.txt',
  'https://hf-mirror.com/nocmt/SenseVoiceSmall-INT8-ONNX/resolve/main/tokens.txt',
];

final class ModelManagerPage extends StatefulWidget {
  const ModelManagerPage({super.key, required this.hub});

  final LibraryHub hub;

  @override
  State<ModelManagerPage> createState() => _ModelManagerPageState();
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

class _ModelManagerPageState extends State<ModelManagerPage> {
  List<ModelRegistryData> _rows = const [];
  bool _loaded = false;
  int? _dlPct; // null=未在下载
  bool _busy = false;
  bool _cancelRequested = false;
  HttpClient? _http;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _http?.close();
    super.dispose();
  }

  Future<void> _reload() async {
    final rows = await widget.hub.data.shell.modelsAll();
    if (mounted) {
      setState(() {
        _rows = rows;
        _loaded = true;
      });
    }
  }

  ModelRegistryData? get _senseVoice {
    for (final r in _rows) {
      if (r.modelId.contains('sensevoice')) return r;
    }
    return null;
  }

  Future<Directory> _modelDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/models/sensevoice');
  }

  /// 流式下载单文件（.part → 原名）；返回落盘字节数。
  Future<int> _fetchToFile(
    HttpClient http,
    List<String> urls,
    File target, {
    required void Function(int pct) onPct,
  }) async {
    Object? lastError;
    for (final url in urls) {
      try {
        return await _fetchToFileFromUrl(http, url, target, onPct: onPct);
      } on Object catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? HttpException('no model download URL configured');
  }

  Future<int> _fetchToFileFromUrl(
    HttpClient http,
    String url,
    File target, {
    required void Function(int pct) onPct,
  }) async {
    final part = File('${target.path}.part');
    final req = await http.getUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.userAgentHeader, 'iA-Music/1.1');
    final resp = await req.close();
    if (resp.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${resp.statusCode} for $url');
    }
    final total = resp.contentLength;
    final sink = part.openWrite();
    var received = 0;
    var lastPct = -10;
    try {
      await for (final chunk in resp) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          final pct = (received * 100 / total).round();
          if (pct - lastPct >= 2) {
            lastPct = pct;
            onPct(pct);
          }
        }
      }
    } finally {
      await sink.close();
    }
    if (target.existsSync()) {
      target.deleteSync();
    }
    if (part.existsSync()) {
      part.renameSync(target.path);
    }
    return received;
  }

  Future<String> _sha256File(File file) async {
    final result = _DigestSink();
    final input = sha256.startChunkedConversion(result);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return result.value.toString();
  }

  Future<void> _download() async {
    if (_busy) return;
    _cancelRequested = false;
    setState(() {
      _busy = true;
      _dlPct = 0;
    });
    final http = _http = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    Directory? dir;
    try {
      dir = await _modelDir();
      dir.createSync(recursive: true);
      // tokens.txt 小文件先行（快速失败面）；onnx 大文件进度主导 UI
      await _fetchToFile(
        http,
        _kTokensUrls,
        File('${dir.path}/tokens.txt'),
        onPct: (_) {},
      );
      final onnx = File('${dir.path}/model.int8.onnx');
      await _fetchToFile(
        http,
        _kOnnxUrls,
        onnx,
        onPct: (pct) {
          if (mounted) setState(() => _dlPct = pct);
        },
      );
      final tokens = File('${dir.path}/tokens.txt');
      final tokensSha = await _sha256File(tokens);
      if (tokensSha != _kTokensSha256) {
        throw const FormatException('tokens.txt 校验失败');
      }
      final sha = await _sha256File(onnx);
      if (sha != _kOnnxSha256) {
        throw const FormatException('model.int8.onnx 校验失败');
      }
      await widget.hub.data.shell.upsertModel(
        kSenseVoiceModelId,
        sizeBytes: await onnx.length(),
        sha256: sha,
        status: ModelStatus.present,
        localPath: dir.path,
        downloadedAt: DateTime.now().millisecondsSinceEpoch,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(sOf(context).modelDownloadDone)));
      }
    } on Object catch (e) {
      debugPrint('model download failed: $e');
      // 下载未完成或校验失败的文件不能被后续启动误认为可用模型。
      if (dir != null) {
        for (final name in [
          'tokens.txt',
          'tokens.txt.part',
          'model.int8.onnx',
          'model.int8.onnx.part',
        ]) {
          try {
            final f = File('${dir.path}/$name');
            if (f.existsSync()) f.deleteSync();
          } on FileSystemException {
            // 清理失败不影响下次下载重试。
          }
        }
      }
      if (mounted) {
        if (!_cancelRequested) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sOf(context).modelDownloadFailed)),
          );
        }
      }
    } finally {
      http.close();
      _http = null;
      if (mounted) {
        setState(() {
          _busy = false;
          _dlPct = null;
        });
      }
      await _reload();
    }
  }

  void _cancelDownload() {
    if (!_busy) return;
    _cancelRequested = true;
    _http?.close(force: true);
  }

  Future<void> _delete() async {
    final t = sOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.modelDelete),
        content: Text(t.modelDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            key: const ValueKey('model_delete_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.modelDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final row = _senseVoice;
    final dirPath = row?.localPath;
    await widget.hub.data.shell.deleteModel(kSenseVoiceModelId);
    if (dirPath != null && dirPath.isNotEmpty) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        try {
          await dir.delete(recursive: true);
        } on FileSystemException {
          // 目录占用（推理中）——注册行已删，物理清理下次重装兜底
        }
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(sOf(context).modelDeleted)));
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ia;
    final t = sOf(context);
    final row = _senseVoice;
    final present =
        row != null &&
        row.status == ModelStatus.present &&
        (row.localPath ?? '').isNotEmpty &&
        Directory(row.localPath!).existsSync();
    return Scaffold(
      key: const ValueKey('model_manager_page'),
      appBar: AppBar(title: Text(t.modelManagerTitle)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              IaIcon.autoFix,
                              size: 22,
                              color: present ? p.accent : p.secondaryText,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                kSenseVoiceModelId,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              present
                                  ? t.modelStatusPresent
                                  : t.modelStatusAbsent,
                              style: TextStyle(
                                fontSize: 12,
                                color: present ? p.accent : p.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        if (present && row.sizeBytes != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            t.modelSizeLabel(row.sizeBytes! ~/ (1024 * 1024)),
                            style: TextStyle(
                              fontSize: 12,
                              color: p.secondaryText,
                            ),
                          ),
                        ],
                        if (_dlPct != null) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            key: const ValueKey('model_progress'),
                            value: _dlPct! / 100,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.modelDownloading(_dlPct!),
                            style: TextStyle(
                              fontSize: 12,
                              color: p.secondaryText,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_busy)
                              TextButton(
                                key: const ValueKey('model_cancel'),
                                onPressed: _cancelDownload,
                                child: Text(t.cancel),
                              )
                            else if (present)
                              FilledButton.tonalIcon(
                                key: const ValueKey('model_delete'),
                                onPressed: _busy
                                    ? null
                                    : () => unawaited(_delete()),
                                icon: Icon(IaIcon.delete),
                                label: Text(t.modelDelete),
                              )
                            else
                              FilledButton.icon(
                                key: const ValueKey('model_download'),
                                onPressed: _busy || _dlPct != null
                                    ? null
                                    : () => unawaited(_download()),
                                icon: Icon(IaIcon.download),
                                label: Text(t.modelDownload),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _sourceNote,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.secondaryText,
                    height: 1.7,
                  ),
                ),
              ],
            ),
    );
  }

  String get _sourceNote =>
      '魔塔社区 · xiaohaoxin/sherpa-onnx-sense-voice-small · int8';
}
