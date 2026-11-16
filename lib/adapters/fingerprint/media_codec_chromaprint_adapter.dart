/// FingerprintPort 实现——Android MediaCodec 解码 + chromaprint FFI。
///
/// 无 mpv、无 ffmpeg：系统 MediaCodec 解出 16-bit PCM（源采样率/声道），
/// Dart 侧下混/重采样到 mono/11025/s16，再交给 chromaprint。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:chromaprint/chromaprint.dart' as cp;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/ports/fingerprint_port.dart';

class MediaCodecChromaprintAdapter implements FingerprintPort {
  MediaCodecChromaprintAdapter();

  static const MethodChannel _channel =
      MethodChannel('ia_music/fingerprint');
  static const int _tapRate = 11025;
  static const int _maxSeconds = 110;

  @override
  Future<AudioFingerprint?> fingerprint(String path,
      {required int durationMs}) async {
    final chromaprint = cp.Chromaprint();
    File? pcmFile;
    try {
      final dir = await getTemporaryDirectory();
      pcmFile = File(
          '${dir.path}/fp_${DateTime.now().microsecondsSinceEpoch}.s16le');
      final seconds = durationMs > 0
          ? (durationMs / 1000).ceil().clamp(1, _maxSeconds)
          : _maxSeconds;

      final info = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'decodePcm',
        {
          'path': path,
          'outPath': pcmFile.path,
          'maxSeconds': seconds,
        },
      );
      if (info == null) {
        return null;
      }
      final sr = (info['sampleRate'] as num?)?.toInt() ?? 0;
      final ch = (info['channels'] as num?)?.toInt() ?? 0;
      if (sr <= 0 || ch <= 0) {
        return null;
      }
      final bytes = await pcmFile.readAsBytes();
      if (bytes.length < 2) {
        return null;
      }
      final mono = _toMono11025(bytes, sr, ch);
      if (mono.isEmpty) {
        return null;
      }

      chromaprint.start(_tapRate, 1);
      const chunk = 8192;
      for (var off = 0; off < mono.length; off += chunk) {
        final end = (off + chunk) < mono.length ? off + chunk : mono.length;
        chromaprint.feed(Int16List.sublistView(mono, off, end));
      }
      chromaprint.finish();
      final fp = chromaprint.getFingerprint();
      if (fp.isEmpty) {
        return null;
      }
      return AudioFingerprint(
        fingerprint: fp,
        durationMs: durationMs > 0 ? durationMs : 0,
      );
    } on Object {
      return null;
    } finally {
      chromaprint.dispose();
      try {
        await pcmFile?.delete();
      } on Object {
        // 临时文件清理容错
      }
    }
  }

  /// 源 PCM（16-bit, sr, ch）→ mono 11025 s16（线性插值）。
  Int16List _toMono11025(Uint8List bytes, int sr, int ch) {
    final data = bytes.buffer
        .asInt16List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 2);
    final frames = data.length ~/ ch;
    if (frames <= 0) {
      return Int16List(0);
    }
    final outLen =
        ((frames * _tapRate) / sr).floor().clamp(0, _tapRate * _maxSeconds);
    final out = Int16List(outLen);
    for (var i = 0; i < outLen; i++) {
      final pos = i * sr / _tapRate;
      final i0 = pos.floor().clamp(0, frames - 1);
      final i1 = (i0 + 1).clamp(0, frames - 1);
      final frac = pos - i0;
      var sum = 0.0;
      for (var c = 0; c < ch; c++) {
        final s0 = data[i0 * ch + c];
        final s1 = data[i1 * ch + c];
        sum += s0 + (s1 - s0) * frac;
      }
      out[i] = (sum / ch).round().clamp(-32768, 32767);
    }
    return out;
  }
}
