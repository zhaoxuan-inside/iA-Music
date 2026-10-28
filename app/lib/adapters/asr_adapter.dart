/// AsrAdapter —— SenseVoice 本地 ASR（2026-10-25 应用内集成）。
///
/// 优先路径：**原生 FFI 直调**（`sherpa-onnx-c-api.dll` 随应用分发，
/// [AsrNativeRecognizer]；无 Python 依赖）。DLL/模型缺件时回落开发态
/// Python 子进程脚本（`py -3.14 tool/asr_sensevoice.py`）——两者输出
/// 同构 token 时间轴。任一环缺失 → null（调用方记 asr_unavailable）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:ia_music/adapters/asr_isolate_worker.dart';
import 'package:ia_music/adapters/downloader_adapter.dart' show kFfmpegDir;

/// ASR 原始时间轴 token。
final class AsrToken {
  const AsrToken(this.tMs, this.text);
  final int tMs;
  final String text;
}

/// 本地 ASR 接口（原生/脚本双形态；契约 AsrPort=isolate 常驻形态留待对接）。
abstract class LocalAsrPort {
  Future<List<AsrToken>?> transcribe({
    required String modelDir,
    required String audioPath,
  });
}

final class AsrAdapter implements LocalAsrPort {
  const AsrAdapter();

  /// 开发态脚本解析（发行位=exe 旁 tool/；env 覆盖）。
  static String? resolveScript() {
    final env = Platform.environment['IA_ASR_SCRIPT'];
    if (env != null && env.isNotEmpty && File(env).existsSync()) {
      return env;
    }
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir/tool/asr_sensevoice.py',
      '$exeDir/asr_sensevoice.py',
      // 开发态：build/windows/x64/runner/{Debug|Release}/ → app/tool/
      '$exeDir/../../../../tool/asr_sensevoice.py',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) {
        return c;
      }
    }
    return null;
  }

  @override
  Future<List<AsrToken>?> transcribe({
    required String modelDir,
    required String audioPath,
  }) async {
    // 推理在长驻 worker isolate（2026-10-25 性能修复：主线程同步 FFI 推理
    // 冻结 UI 数十秒——Windows「未响应」/安卓 ANR 的根因）。主线程只传路径。
    if (!await AsrIsolateWorker.instance.nativeAvailable(modelDir)) {
      return _transcribeViaScript(modelDir: modelDir, audioPath: audioPath);
    }
    final wav = await _toWav16kMono(audioPath);
    if (wav == null) {
      return null;
    }
    return AsrIsolateWorker.instance.transcribe(
      modelDir: modelDir,
      wavPath: wav,
    );
  }

  /// 任意音频 → 16k mono pcm_s16le wav（ffmpeg；产物=临时目录）。
  static Future<String?> _toWav16kMono(String audioPath) async {
    final ffmpeg = '${kFfmpegDir.replaceAll('\\', '/')}/ffmpeg.exe';
    if (!File(ffmpeg).existsSync()) {
      return null;
    }
    final dir = Directory.systemTemp.createTempSync('ia_asr');
    final out = '${dir.path}/a.wav';
    final r = await Process.run(ffmpeg, [
      '-hide_banner', '-nostats', '-y',
      '-i', audioPath,
      '-ac', '1', '-ar', '16000',
      '-c:a', 'pcm_s16le', out,
    ]);
    if (r.exitCode != 0 || !File(out).existsSync()) {
      return null;
    }
    return out;
  }

  /// 开发态 fallback：Python 子进程脚本（py -3.14；裸 py=freethreaded 无包）。
  Future<List<AsrToken>?> _transcribeViaScript({
    required String modelDir,
    required String audioPath,
  }) async {
    final script = resolveScript();
    if (script == null) {
      return null;
    }
    try {
      final r = await Process.run(
        'py',
        ['-3.14', script, '--model-dir', modelDir, '--audio', audioPath,
         '--ffmpeg', kFfmpegDir],
        environment: {
          ...Platform.environment,
          'PYTHONIOENCODING': 'utf-8',
        },
        stdoutEncoding: utf8,
      );
      if (r.exitCode != 0) {
        return null;
      }
      final lines = (r.stdout as String)
          .split('\n')
          .where((l) => l.trim().startsWith('{'))
          .toList();
      if (lines.isEmpty) {
        return null;
      }
      final j = jsonDecode(lines.last) as Map<String, dynamic>;
      if (j['error'] != null) {
        return null;
      }
      final raw = (j['tokens'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m.cast<Object?, Object?>()))
          .toList();
      if (raw.isEmpty) {
        return null;
      }
      return [
        for (final m in raw)
          AsrToken((m['t'] as num?)?.toInt() ?? 0, '${m['w'] ?? ''}'),
      ];
    } on Exception {
      return null;
    }
  }
}
