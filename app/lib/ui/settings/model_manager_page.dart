/// 歌词模型管理页（WS4/REQ-LYRAI-01：SenseVoiceSmall int8 下载/状态/删除）。
///
/// 下载源=hf-mirror（ADR-0001 R3 指定镜像；ADR-0001 版本钉死=2024-07-17 模型）。
/// 完成后写 model_registry(status=present, localPath)——ExtractQueue 的
/// `_presentModelDir()` 即刻生效，无需重启。sha256=落账真实值（DELIVERY-NOTES
/// 记录：参考校验和待发布物固定后补入）。
library;

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

const String _kOnnxUrl =
    'https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue/resolve/main/model.int8.onnx';
const String _kTokensUrl =
    'https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue/resolve/main/tokens.txt';

final class ModelManagerPage extends StatefulWidget {
  const ModelManagerPage({super.key, required this.hub});

  final LibraryHub hub;

  @override
  State<ModelManagerPage> createState() => _ModelManagerPageState();
}

class _ModelManagerPageState extends State<ModelManagerPage> {
  List<ModelRegistryData> _rows = const [];
  bool _loaded = false;
  int? _dlPct; // null=未在下载
  bool _busy = false;
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
  Future<int> _fetchToFile(HttpClient http, String url, File target,
      {required void Function(int pct) onPct}) async {
    final part = File('${target.path}.part');
    final req = await http.getUrl(Uri.parse(url));
    final resp = await req.close();
    if (resp.statusCode != 200) {
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
    if (part.existsSync()) {
      part.renameSync(target.path);
    }
    return received;
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _dlPct = 0;
    });
    final http = _http = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final dir = await _modelDir();
      dir.createSync(recursive: true);
      // tokens.txt 小文件先行（快速失败面）；onnx 大文件进度主导 UI
      await _fetchToFile(http, _kTokensUrl, File('${dir.path}/tokens.txt'),
          onPct: (_) {});
      final onnx = File('${dir.path}/model.int8.onnx');
      await _fetchToFile(http, _kOnnxUrl, onnx, onPct: (pct) {
        if (mounted) setState(() => _dlPct = pct);
      });
      final bytes = onnx.readAsBytesSync();
      final sha = sha256.convert(bytes).toString();
      await widget.hub.data.shell.upsertModel(
        kSenseVoiceModelId,
        sizeBytes: bytes.length,
        sha256: sha,
        status: ModelStatus.present,
        localPath: dir.path,
        downloadedAt: DateTime.now().millisecondsSinceEpoch,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sOf(context).modelDownloadDone)),
        );
      }
    } on Object catch (e) {
      // 半成品清理（.part 残留=下次重下续盘由 HTTP 全量覆盖；目录保留）
      debugPrint('model download failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sOf(context).modelDownloadFailed)),
        );
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
              child: Text(t.cancel)),
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
    final present = row != null &&
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
                            Icon(IaIcon.autoFix,
                                size: 22,
                                color:
                                    present ? p.accent : p.secondaryText),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                kSenseVoiceModelId,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              present
                                  ? t.modelStatusPresent
                                  : t.modelStatusAbsent,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    present ? p.accent : p.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        if (present && row.sizeBytes != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            t.modelSizeLabel(row.sizeBytes! ~/ (1024 * 1024)),
                            style: TextStyle(
                                fontSize: 12, color: p.secondaryText),
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
                                fontSize: 12, color: p.secondaryText),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (present)
                              FilledButton.tonalIcon(
                                key: const ValueKey('model_delete'),
                                onPressed:
                                    _busy ? null : () => unawaited(_delete()),
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
                      height: 1.7),
                ),
              ],
            ),
    );
  }

  String get _sourceNote =>
      'hf-mirror.com · csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue · int8 (2024-07-17)';
}
