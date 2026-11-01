/// MetadataPort adapter —— audio_metadata_reader 1.8.1 真解析直桥。
///
/// 纪律：
/// * 红线（REQ-LIB-03）：**绝不写回原文件**——本类只读；S2 不碰封面
///   （`getImage=false`；封面链=S5，CoverFetchPort 另路）。
/// * §3.1 禁则：解析进 Isolate（扫描不占 UI isolate）。
/// * 裸值口径：tag 缺失 → 空串（**文件名兜底责任在扫描层**=tables.dart 注释口径）。
/// * 契约口径（exceptions.dart/Port 注释）：损坏/零字节/IO/不支持扩展 →
///   `FormatException`（调用方按 skipped 计数，REQ-LIB-01；不中断流程）。
library;

import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as am;
import 'package:contracts/contracts.dart';

class MetadataAdapter implements MetadataPort {
  const MetadataAdapter();

  @override
  Future<ParsedMeta> read(String audioPath) => Isolate.run(() => parseSync(audioPath));

  /// 同步解析核心（ScanService 批量 isolate 内复用；公开而非私有——跨库可调用）。
  static ParsedMeta parseSync(String audioPath) {
    final f = File(audioPath);
    final format = _formatOf(audioPath);
    final am.AudioMetadata m;
    try {
      m = am.readMetadata(f, getImage: false);
    } on FormatException {
      rethrow;
    } catch (e) {
      // 包内两类异常（MetadataParser/NoMetadataParser/IO）→ 契约层 FormatException
      throw FormatException('unreadable audio metadata: $audioPath (${e.runtimeType})');
    }
    final st = f.statSync();
    return ParsedMeta(
      title: m.title ?? '',
      artistDisplay: m.artist ?? '',
      albumDisplay: m.album ?? '',
      durationMs: m.duration?.inMilliseconds ?? 0,
      format: format,
      fileSizeBytes: st.size,
      mtimeMs: st.modified.millisecondsSinceEpoch,
      sampleRate: m.sampleRate,
    );
  }

  static AudioFormat _formatOf(String audioPath) {
    final dot = audioPath.lastIndexOf('.');
    final ext = dot < 0 ? '' : audioPath.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'mp3' => AudioFormat.mp3,
      'flac' => AudioFormat.flac,
      'm4a' => AudioFormat.m4a,
      'ogg' => AudioFormat.ogg,
      'wav' => AudioFormat.wav,
      'ape' => AudioFormat.ape,
      _ => throw FormatException('unsupported audio extension: $audioPath'),
    };
  }
}
