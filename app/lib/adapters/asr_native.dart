/// AsrNative —— sherpa-onnx C API 的 Dart FFI 直调（2026-10-25 应用内集成）。
///
/// 分发形态：`sherpa-onnx-c-api.dll` + `onnxruntime*.dll` 随应用目录分发
/// （无 Python 依赖——此前子进程脚本形态退役为 fallback）。
/// 结构体转写自 sherpa-onnx v2.0.0 `c-api.h`（字段顺序=内存布局；
/// 仅访问 Result 前段字段，尾部字段不涉及偏移）。
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'package:ia_music/adapters/asr_adapter.dart' show AsrToken;

// ── C 结构体转写（c-api.h v2.0.0）────────────────────────────

final class _SherpaOnnxFeatureConfig extends Struct {
  @Int32()
  external int sampleRate;
  @Int32()
  external int featureDim;
}

final class _TransducerCfg extends Struct {
  external Pointer<Utf8> encoder;
  external Pointer<Utf8> decoder;
  external Pointer<Utf8> joiner;
}

final class _ParaformerCfg extends Struct {
  external Pointer<Utf8> model;
}

final class _NemoCtcCfg extends Struct {
  external Pointer<Utf8> model;
}

final class _WhisperCfg extends Struct {
  external Pointer<Utf8> encoder;
  external Pointer<Utf8> decoder;
  external Pointer<Utf8> language;
  external Pointer<Utf8> task;
  @Int32()
  external int tailPaddings;
  @Int32()
  external int enableTokenTimestamps;
  @Int32()
  external int enableSegmentTimestamps;
}

final class _TdnnCfg extends Struct {
  external Pointer<Utf8> model;
}

final class _SenseVoiceCfg extends Struct {
  external Pointer<Utf8> model;
  external Pointer<Utf8> language;
  @Int32()
  external int useItn;
}

final class _MoonshineCfg extends Struct {
  external Pointer<Utf8> preprocessor;
  external Pointer<Utf8> encoder;
  external Pointer<Utf8> uncachedDecoder;
  external Pointer<Utf8> cachedDecoder;
  external Pointer<Utf8> mergedDecoder;
}

final class _FireRedAsrCfg extends Struct {
  external Pointer<Utf8> encoder;
  external Pointer<Utf8> decoder;
}

final class _DolphinCfg extends Struct {
  external Pointer<Utf8> model;
}

final class _ZipformerCtcCfg extends Struct {
  external Pointer<Utf8> model;
}

final class _CanaryCfg extends Struct {
  external Pointer<Utf8> encoder;
  external Pointer<Utf8> decoder;
  external Pointer<Utf8> srcLang;
  external Pointer<Utf8> tgtLang;
  @Int32()
  external int usePnc;
}

final class _WenetCtcCfg extends Struct {
  external Pointer<Utf8> model;
}

final class _OmnilingualCfg extends Struct {
  external Pointer<Utf8> model;
}

final class _MedAsrCfg extends Struct {
  external Pointer<Utf8> model;
}

final class _FunAsrNanoCfg extends Struct {
  external Pointer<Utf8> encoderAdaptor;
  external Pointer<Utf8> llm;
  external Pointer<Utf8> embedding;
  external Pointer<Utf8> tokenizer;
  external Pointer<Utf8> systemPrompt;
  external Pointer<Utf8> userPrompt;
  @Int32()
  external int maxNewTokens;
  @Float()
  external double temperature;
  @Float()
  external double topP;
  @Int32()
  external int seed;
  external Pointer<Utf8> language;
  @Int32()
  external int itn;
  external Pointer<Utf8> hotwords;
}

final class _FireRedCtcCfg extends Struct {
  external Pointer<Utf8> model;
}

final class _Qwen3AsrCfg extends Struct {
  external Pointer<Utf8> convFrontend;
  external Pointer<Utf8> encoder;
  external Pointer<Utf8> decoder;
  external Pointer<Utf8> tokenizer;
  @Int32()
  external int maxTotalLen;
  @Int32()
  external int maxNewTokens;
  @Float()
  external double temperature;
  @Float()
  external double topP;
  @Int32()
  external int seed;
  external Pointer<Utf8> hotwords;
}

final class _CohereCfg extends Struct {
  external Pointer<Utf8> encoder;
  external Pointer<Utf8> decoder;
  external Pointer<Utf8> language;
  @Int32()
  external int usePunct;
  @Int32()
  external int useItn;
}

final class _OfflineModelConfig extends Struct {
  external _TransducerCfg transducer;
  external _ParaformerCfg paraformer;
  external _NemoCtcCfg nemoCtc;
  external _WhisperCfg whisper;
  external _TdnnCfg tdnn;
  external Pointer<Utf8> tokens;
  @Int32()
  external int numThreads;
  @Int32()
  external int debug;
  external Pointer<Utf8> provider;
  external Pointer<Utf8> modelType;
  external Pointer<Utf8> modelingUnit;
  external Pointer<Utf8> bpeVocab;
  external Pointer<Utf8> telespeechCtc;
  external _SenseVoiceCfg senseVoice;
  external _MoonshineCfg moonshine;
  external _FireRedAsrCfg fireRedAsr;
  external _DolphinCfg dolphin;
  external _ZipformerCtcCfg zipformerCtc;
  external _CanaryCfg canary;
  external _WenetCtcCfg wenetCtc;
  external _OmnilingualCfg omnilingual;
  external _MedAsrCfg medasr;
  external _FunAsrNanoCfg funasrNano;
  external _FireRedCtcCfg fireRedAsrCtc;
  external _Qwen3AsrCfg qwen3Asr;
  external _CohereCfg cohereTranscribe;
}

final class _OfflineLmConfig extends Struct {
  external Pointer<Utf8> model;
  @Float()
  external double scale;
}

final class _HomophoneReplacerCfg extends Struct {
  external Pointer<Utf8> dictDir;
  external Pointer<Utf8> lexicon;
  external Pointer<Utf8> ruleFsts;
  external Pointer<Utf8> graph;
  @Int32()
  external int maxActive;
}

final class _CtcFstDecoderCfg extends Struct {
  external Pointer<Utf8> graph;
  @Int32()
  external int maxActive;
}

final class _OfflineRecognizerConfig extends Struct {
  external _SherpaOnnxFeatureConfig featConfig;
  external _OfflineModelConfig modelConfig;
  external _OfflineLmConfig lmConfig;
  external Pointer<Utf8> decodingMethod;
  @Int32()
  external int maxActivePaths;
  external Pointer<Utf8> hotwordsFile;
  @Float()
  external double hotwordsScore;
  external Pointer<Utf8> ruleFsts;
  external Pointer<Utf8> ruleFars;
  @Float()
  external double blankPenalty;
  external _HomophoneReplacerCfg hr;
  external _CtcFstDecoderCfg ctcFstDecoderConfig;
}

/// Result 前段（text..lang；尾部字段不访问）。
final class _OfflineRecognizerResult extends Struct {
  external Pointer<Utf8> text;
  external Pointer<Float> timestamps;
  @Int32()
  external int count;
  external Pointer<Utf8> tokens;
  external Pointer<Pointer<Utf8>> tokensArr;
  external Pointer<Utf8> json;
  external Pointer<Utf8> lang;
}

// ── 符号绑定 ───────────────────────────────────────────────

typedef _CreateOfflineRecognizerC = Pointer<Void> Function(
  Pointer<_OfflineRecognizerConfig>,
);
typedef _CreateOfflineRecognizerDart = Pointer<Void> Function(
  Pointer<_OfflineRecognizerConfig>,
);
typedef _CreateStreamC = Pointer<Void> Function(Pointer<Void>);
typedef _CreateStreamDart = Pointer<Void> Function(Pointer<Void>);
typedef _AcceptWaveformC = Void Function(
  Pointer<Void>,
  Int32,
  Pointer<Float>,
  Int32,
);
typedef _AcceptWaveformDart = void Function(
  Pointer<Void>,
  int,
  Pointer<Float>,
  int,
);
typedef _DecodeStreamC = Void Function(Pointer<Void>, Pointer<Void>);
typedef _DecodeStreamDart = void Function(Pointer<Void>, Pointer<Void>);
typedef _GetResultC = Pointer<_OfflineRecognizerResult> Function(Pointer<Void>);
typedef _GetResultDart = Pointer<_OfflineRecognizerResult> Function(
  Pointer<Void>,
);
typedef _VoidFnC = Void Function(Pointer<Void>);
typedef _VoidFnDart = void Function(Pointer<Void>);
typedef _DestroyResultC = Void Function(Pointer<_OfflineRecognizerResult>);
typedef _DestroyResultDart = void Function(Pointer<_OfflineRecognizerResult>);

/// 加载随包分发的 sherpa-onnx C 库（exe 同目录优先；PATH 兜底）。
DynamicLibrary? _loadSherpaLib({String? dllDir}) {
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final candidates = [
    if (dllDir != null) '$dllDir/sherpa-onnx-c-api.dll',
    '$exeDir/sherpa-onnx-c-api.dll',
    '$exeDir/lib/sherpa-onnx-c-api.dll',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) {
      // 劫持防御（本机实证）：c-api.dll 的依赖 onnxruntime.dll 按默认搜索
      // 序会被 System32 残留的旧版（1.17，API 17 < 需求 28）抢占。先按全路径
      // 加载同目录的 onnxruntime.dll 注册进进程，同名的后续加载即复用。
      final ort = '${File(c).parent.path}/onnxruntime.dll';
      if (File(ort).existsSync()) {
        try {
          DynamicLibrary.open(ort);
        } on ArgumentError {
          // sherpa 自带的 ort 缺失时回落默认搜索（打包完整性由随包保证）
        }
      }
      return DynamicLibrary.open(c);
    }
  }
  try {
    return DynamicLibrary.open('sherpa-onnx-c-api.dll');
  } on ArgumentError {
    return null;
  }
}

/// 原生 SenseVoice 转写器（一次加载常驻；线程安全由库内会话隔离）。
final class AsrNativeRecognizer {
  AsrNativeRecognizer._(
    this._rec,
    this._createStream,
    this._accept,
    this._decode,
    this._getResult,
    this._destroyStream,
    this._destroyRec,
    this._destroyResult,
  );

  static DynamicLibrary? _cachedLib;

  /// 模型目录 → 识别器（dll/模型缺件 → null=诚实降级到脚本 fallback）。
  static AsrNativeRecognizer? create(String modelDir, {String? dllDir}) {
    final lib = _cachedLib ??= _loadSherpaLib(dllDir: dllDir);
    if (lib == null) {
      return null;
    }
    final model = '$modelDir/model.int8.onnx';
    final tokens = '$modelDir/tokens.txt';
    if (!File(model).existsSync() || !File(tokens).existsSync()) {
      return null;
    }
    final cfg = calloc<_OfflineRecognizerConfig>();
    try {
      cfg.ref.featConfig.sampleRate = 16000;
      cfg.ref.featConfig.featureDim = 80;
      cfg.ref.modelConfig.tokens = tokens.toNativeUtf8();
      cfg.ref.modelConfig.numThreads = 2;
      cfg.ref.modelConfig.provider = 'cpu'.toNativeUtf8();
      cfg.ref.modelConfig.senseVoice.model = model.toNativeUtf8();
      cfg.ref.modelConfig.senseVoice.language = 'auto'.toNativeUtf8();
      cfg.ref.modelConfig.senseVoice.useItn = 1;
      cfg.ref.decodingMethod = 'greedy_search'.toNativeUtf8();
      final create = lib
          .lookupFunction<
            _CreateOfflineRecognizerC,
            _CreateOfflineRecognizerDart
          >('SherpaOnnxCreateOfflineRecognizer');
      final rec = create(cfg);
      if (rec == nullptr) {
        return null;
      }
      return AsrNativeRecognizer._(
        rec,
        lib.lookupFunction<_CreateStreamC, _CreateStreamDart>(
          'SherpaOnnxCreateOfflineStream',
        ),
        lib.lookupFunction<_AcceptWaveformC, _AcceptWaveformDart>(
          'SherpaOnnxAcceptWaveformOffline',
        ),
        lib.lookupFunction<_DecodeStreamC, _DecodeStreamDart>(
          'SherpaOnnxDecodeOfflineStream',
        ),
        lib.lookupFunction<_GetResultC, _GetResultDart>(
          'SherpaOnnxGetOfflineStreamResult',
        ),
        lib.lookupFunction<_VoidFnC, _VoidFnDart>(
          'SherpaOnnxDestroyOfflineStream',
        ),
        lib.lookupFunction<_VoidFnC, _VoidFnDart>(
          'SherpaOnnxDestroyOfflineRecognizer',
        ),
        lib.lookupFunction<_DestroyResultC, _DestroyResultDart>(
          'SherpaOnnxDestroyOfflineRecognizerResult',
        ),
      );
    } finally {
      calloc.free(cfg);
    }
  }

  final Pointer<Void> _rec;
  final _CreateStreamDart _createStream;
  final _AcceptWaveformDart _accept;
  final _DecodeStreamDart _decode;
  final _GetResultDart _getResult;
  final _VoidFnDart _destroyStream;
  final _VoidFnDart _destroyRec;
  final _DestroyResultDart _destroyResult;

  /// 16k mono f32 样本 → token 时间轴（失败/无语音=空表）。
  List<AsrToken> transcribeSamples(Float32List samples16k) {
    final stream = _createStream(_rec);
    if (stream == nullptr) {
      return const [];
    }
    final buf = calloc<Float>(samples16k.length);
    try {
      buf.asTypedList(samples16k.length).setAll(0, samples16k);
      _accept(stream, 16000, buf, samples16k.length);
      _decode(_rec, stream);
      final r = _getResult(stream);
      if (r == nullptr) {
        return const [];
      }
      try {
        final count = r.ref.count;
        final ts = r.ref.timestamps;
        final arr = r.ref.tokensArr;
        if (count <= 0 || arr == nullptr) {
          return const [];
        }
        final out = <AsrToken>[];
        for (var i = 0; i < count; i++) {
          final p = arr[i];
          if (p == nullptr) {
            continue;
          }
          final w = p.toDartString();
          final t = (ts == nullptr) ? 0 : (ts[i] * 1000).round();
          out.add(AsrToken(t, w));
        }
        return out;
      } finally {
        _destroyResult(r);
      }
    } finally {
      calloc.free(buf);
      _destroyStream(stream);
    }
  }

  /// 任意 wav（pcm_s16le/16k/mono，ffmpeg 产物）→ f32 样本。
  static Float32List? readWav16kMono(String path) {
    final bytes = File(path).readAsBytesSync();
    if (bytes.length < 44 || bytes.length < 12) {
      return null;
    }
    // RIFF 头走查：找 fmt（校验 16k/mono/16bit）与 data chunk
    var pos = 12;
    var dataStart = -1, dataLen = -1;
    var channels = -1, rate = -1, bits = -1;
    while (pos + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      final size =
          bytes[pos + 4] |
          (bytes[pos + 5] << 8) |
          (bytes[pos + 6] << 16) |
          (bytes[pos + 7] << 24);
      if (id == 'fmt ') {
        channels = bytes[pos + 10] | (bytes[pos + 11] << 8);
        rate =
            bytes[pos + 12] |
            (bytes[pos + 13] << 8) |
            (bytes[pos + 14] << 16) |
            (bytes[pos + 15] << 24);
        bits = bytes[pos + 22] | (bytes[pos + 23] << 8);
      } else if (id == 'data') {
        dataStart = pos + 8;
        dataLen = size;
        break;
      }
      pos += 8 + size + (size.isOdd ? 1 : 0);
    }
    if (dataStart < 0 ||
        channels != 1 ||
        rate != 16000 ||
        bits != 16 ||
        dataLen <= 0) {
      return null;
    }
    final n = dataLen ~/ 2;
    final out = Float32List(n);
    final bd = ByteData.sublistView(bytes, dataStart, dataStart + dataLen);
    for (var i = 0; i < n; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  void dispose() {
    _destroyRec(_rec);
  }
}
