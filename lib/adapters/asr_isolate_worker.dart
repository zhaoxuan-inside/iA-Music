/// ASR 专用长驻 worker isolate（2026-10-25 性能修复）。
///
/// 根因：SenseVoice FFI 推理此前在主 isolate 同步执行（一首歌几十秒起），
/// UI 全程冻结 → Windows「未响应」/安卓 ANR；叠加启动 resumeQueued 复活
/// 批量提取任务（每 withLyrics 任务一次推理）即「总是未响应」。
///
/// 协议（主 → worker）：`(seq, 'probe', modelDir)` 探测识别器可用性；
/// `(seq, 'run', modelDir, wavPath)` 执行。worker 内完成 wav 读取、识别器
/// 缓存（按 modelDir，模型秒级加载跨曲复用）、推理与临时件清理。
/// 回复（worker → 主）：`(seq, payload)`——probe 回 bool，run 回 tokens|null
/// （失败=null，asr_unavailable 语义，不冒泡）。
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:ia_music/adapters/asr_adapter.dart' show AsrToken;
import 'package:ia_music/adapters/asr_native.dart';

final class AsrIsolateWorker {
  AsrIsolateWorker._();

  static final AsrIsolateWorker instance = AsrIsolateWorker._();

  SendPort? _send;
  final Map<int, Completer<Object?>> _pending = {};
  int _seq = 0;

  Future<SendPort> _ensure() async {
    final existing = _send;
    if (existing != null) {
      return existing;
    }
    final ready = Completer<SendPort>();
    final port = ReceivePort();
    await Isolate.spawn(
      _workerMain,
      port.sendPort,
      debugName: 'ia_asr_worker',
    );
    port.listen((msg) {
      if (msg is SendPort) {
        if (!ready.isCompleted) {
          ready.complete(msg);
        }
        return;
      }
      if (msg is (int, Object?)) {
        _pending.remove(msg.$1)?.complete(msg.$2);
      }
    });
    return ready.future;
  }

  /// 识别器可用性（DLL/模型齐否；worker 内缓存识别器，probe 即预热）。
  Future<bool> nativeAvailable(String modelDir) async {
    final send = await _ensure();
    final seq = ++_seq;
    final completer = Completer<Object?>();
    _pending[seq] = completer;
    send.send((seq, 'probe', modelDir));
    return await completer.future == true;
  }

  /// 主线程只传路径；推理全程在 worker（UI 零阻塞）。
  Future<List<AsrToken>?> transcribe({
    required String modelDir,
    required String wavPath,
  }) async {
    final send = await _ensure();
    final seq = ++_seq;
    final completer = Completer<Object?>();
    _pending[seq] = completer;
    send.send((seq, 'run', modelDir, wavPath));
    final r = await completer.future;
    return r is List<AsrToken> ? r : null;
  }

  static void _workerMain(SendPort main) {
    final port = ReceivePort();
    main.send(port.sendPort);
    final cache = <String, AsrNativeRecognizer?>{};
    AsrNativeRecognizer? recognizerOf(String modelDir) {
      if (cache.containsKey(modelDir)) {
        return cache[modelDir];
      }
      final rec = AsrNativeRecognizer.create(modelDir);
      cache[modelDir] = rec;
      return rec;
    }

    port.listen((msg) {
      final record = msg as (int, String, String, String?);
      final seq = record.$1;
      switch (record.$2) {
        case 'probe':
          main.send((seq, recognizerOf(record.$3) != null));
        case 'run':
          final wavPath = record.$4!;
          try {
            final rec = recognizerOf(record.$3);
            if (rec == null) {
              main.send((seq, null));
            } else {
              final samples = AsrNativeRecognizer.readWav16kMono(wavPath);
              if (samples == null) {
                main.send((seq, null));
              } else {
                final tokens = rec.transcribeSamples(samples);
                main.send((seq, tokens.isEmpty ? null : tokens));
              }
            }
          } catch (_) {
            main.send((seq, null)); // 推理异常=不可用语义，不冒泡不重试
          } finally {
            try {
              final f = File(wavPath);
              if (f.existsSync()) {
                f.deleteSync();
                final dir = f.parent;
                if (dir.listSync().isEmpty) {
                  dir.deleteSync();
                }
              }
            } on Exception {
              // 临时件 OS 回收
            }
          }
      }
    });
  }
}
