/// Dart FFI bindings for the Chromaprint audio fingerprinting library.
///
/// Chromaprint is the core component of the AcoustID project. It takes
/// raw audio data (16-bit signed integers) and produces compact fingerprints
/// that can be used to identify audio recordings.
///
/// Basic usage:
/// ```dart
/// final cp = Chromaprint();
/// cp.start(44100, 1); // 44.1kHz mono
/// cp.feed(audioData);
/// cp.finish();
/// final fingerprint = cp.getFingerprint();
/// print('Fingerprint: $fingerprint');
/// cp.dispose();
/// ```
library;

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'chromaprint_bindings_generated.dart';

/// Fingerprinting algorithms supported by Chromaprint.
///
/// The default algorithm ([defaultAlgorithm]) is recommended for general use.
enum ChromaprintAlgorithm {
  test1(0),
  test2(1),
  test3(2),
  test4(3),
  test5(4);

  /// The integer value as defined in the C API.
  final int value;
  const ChromaprintAlgorithm(this.value);

  /// The default algorithm used by Chromaprint (test2).
  static const defaultAlgorithm = test2;
}

/// Exception thrown when a Chromaprint C API call fails.
///
/// Most chromaprint functions return 1 on success and 0 on error.
/// When a function returns 0, this exception is thrown with a description
/// of the failed operation.
class ChromaprintException implements Exception {
  /// A human-readable description of the error.
  final String message;

  /// Creates a [ChromaprintException] with the given [message].
  const ChromaprintException(this.message);

  @override
  String toString() => 'ChromaprintException: $message';
}

void _check(int result, String operation) {
  if (result == 0) {
    throw ChromaprintException('$operation failed');
  }
}

const String _libName = 'chromaprint';

/// Opens the chromaprint shared library.
///
/// Tries the bundled plugin library first (works in Flutter apps where the
/// native library is compiled into the plugin). Falls back to the system
/// library for standalone Dart usage on desktop Linux.
ffi.DynamicLibrary _openLibrary() {
  if (Platform.isLinux || Platform.isAndroid) {
    // 1. Bundled plugin library (Flutter app)
    try {
      return ffi.DynamicLibrary.open('lib$_libName.so');
    } catch (_) {}
    // 2. System library (standalone Dart on desktop)
    try {
      return ffi.DynamicLibrary.open('lib$_libName.so.1');
    } catch (_) {}
    throw StateError(
      'Could not find libchromaprint. '
      'In a Flutter app, ensure the plugin is listed in pubspec.yaml. '
      'For standalone Dart, install the system library '
      '(e.g. libchromaprint-dev on Debian/Ubuntu, chromaprint on Arch Linux).',
    );
  }
  if (Platform.isIOS || Platform.isMacOS) {
    // On iOS and macOS, the native code is statically linked into the
    // app binary by CocoaPods. Use DynamicLibrary.process() to access
    // the exported symbols directly from the global symbol table.
    return ffi.DynamicLibrary.process();
  }
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError(
    'Unsupported platform: ${Platform.operatingSystem}',
  );
}

/// The bindings to the native chromaprint functions.
final ChromaprintBindings _bindings = ChromaprintBindings(_openLibrary());

/// The result of decoding a compressed fingerprint.
class DecodedFingerprint {
  /// The raw fingerprint as a list of 32-bit unsigned integers.
  final List<int> rawFingerprint;

  /// The algorithm that was used to generate the fingerprint.
  final ChromaprintAlgorithm algorithm;

  /// Creates a [DecodedFingerprint] with the given [rawFingerprint] data
  /// and [algorithm].
  DecodedFingerprint(this.rawFingerprint, this.algorithm);
}

/// High-level Dart wrapper around the Chromaprint C library.
///
/// Use this class to generate audio fingerprints from raw PCM data.
///
/// The typical workflow is:
/// 1. Create a [Chromaprint] instance
/// 2. Call [start] with the audio format parameters
/// 3. Call [feed] one or more times with raw PCM samples
/// 4. Call [finish] to complete the fingerprint
/// 5. Call [getFingerprint] to retrieve the result
/// 6. Call [dispose] to free native resources
///
/// Audio data must be 16-bit signed integers in native byte order.
/// For stereo audio, channels are interleaved.
///
/// A [Finalizer] is attached to ensure the native context is freed even if
/// [dispose] is never called. However, explicit [dispose] is still recommended
/// for deterministic resource release.
class Chromaprint {
  static final _finalizer =
      Finalizer<ffi.Pointer<ChromaprintContext>>(_nativeFree);

  static void _nativeFree(ffi.Pointer<ChromaprintContext> ptr) {
    _bindings.chromaprint_free(ptr);
  }

  ffi.Pointer<ChromaprintContext>? _ctx;
  bool _disposed = false;

  /// Creates a new Chromaprint fingerprinter.
  ///
  /// [algorithm] specifies the fingerprinting algorithm to use.
  /// Defaults to [ChromaprintAlgorithm.defaultAlgorithm].
  ///
  /// Throws [ChromaprintException] if the context cannot be created.
  Chromaprint({ChromaprintAlgorithm algorithm = ChromaprintAlgorithm.defaultAlgorithm}) {
    _ctx = _bindings.chromaprint_new(algorithm.value);
    if (_ctx == ffi.nullptr) {
      throw const ChromaprintException('Failed to create chromaprint context');
    }
    _finalizer.attach(this, _ctx!, detach: this);
  }

  ffi.Pointer<ChromaprintContext> get _context {
    if (_disposed || _ctx == null) {
      throw StateError('Chromaprint instance has been disposed');
    }
    return _ctx!;
  }

  /// Returns the algorithm used by this instance.
  ChromaprintAlgorithm get algorithm {
    final value = _bindings.chromaprint_get_algorithm(_context);
    return ChromaprintAlgorithm.values.firstWhere(
      (a) => a.value == value,
      orElse: () => ChromaprintAlgorithm.defaultAlgorithm,
    );
  }

  /// Returns the sample rate configured after [start] was called.
  int get sampleRate => _bindings.chromaprint_get_sample_rate(_context);

  /// Returns the number of channels configured after [start] was called.
  int get numChannels => _bindings.chromaprint_get_num_channels(_context);

  /// Returns the item duration in samples.
  int get itemDuration => _bindings.chromaprint_get_item_duration(_context);

  /// Returns the item duration in milliseconds.
  int get itemDurationMs =>
      _bindings.chromaprint_get_item_duration_ms(_context);

  /// Returns the delay in samples.
  int get delay => _bindings.chromaprint_get_delay(_context);

  /// Returns the delay in milliseconds.
  int get delayMs => _bindings.chromaprint_get_delay_ms(_context);

  /// Sets an option on the context.
  ///
  /// Currently supported options:
  /// - `silence_threshold`: Threshold for detecting silence (0-32767).
  ///
  /// Must be called before [start].
  void setOption(String name, int value) {
    final namePtr = name.toNativeUtf8();
    try {
      _check(
        _bindings.chromaprint_set_option(_context, namePtr.cast(), value),
        'setOption',
      );
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Starts the fingerprinting process.
  ///
  /// [sampleRate] is the audio sample rate in Hz (e.g. 44100).
  /// [numChannels] is the number of audio channels (1 for mono, 2 for stereo).
  void start(int sampleRate, int numChannels) {
    _check(
      _bindings.chromaprint_start(_context, sampleRate, numChannels),
      'start',
    );
  }

  /// Feeds audio data to the fingerprinter.
  ///
  /// [data] must be 16-bit signed integer samples in native byte order.
  /// For stereo audio, channels are interleaved (L, R, L, R, ...).
  /// The size is measured in samples (not bytes).
  void feed(Int16List data) {
    final dataPtr = calloc<ffi.Int16>(data.length);
    try {
      dataPtr.asTypedList(data.length).setAll(0, data);
      _check(
        _bindings.chromaprint_feed(_context, dataPtr, data.length),
        'feed',
      );
    } finally {
      calloc.free(dataPtr);
    }
  }

  /// Feeds raw pointer audio data to the fingerprinter.
  ///
  /// Use this when you already have audio data in a native buffer
  /// (e.g. from another FFI call). The size is measured in samples.
  void feedRaw(ffi.Pointer<ffi.Int16> data, int size) {
    _check(
      _bindings.chromaprint_feed(_context, data, size),
      'feed',
    );
  }

  /// Finishes the fingerprinting process.
  ///
  /// Must be called after all audio data has been fed.
  void finish() {
    _check(
      _bindings.chromaprint_finish(_context),
      'finish',
    );
  }

  /// Clears the current fingerprint data.
  ///
  /// After calling this, you can call [start] again to process new audio
  /// without creating a new [Chromaprint] instance.
  void clearFingerprint() {
    _check(
      _bindings.chromaprint_clear_fingerprint(_context),
      'clearFingerprint',
    );
  }

  /// Returns the compressed fingerprint as a base64-encoded string.
  ///
  /// Must be called after [finish].
  String getFingerprint() {
    final fpPtr = calloc<ffi.Pointer<ffi.Char>>();
    try {
      _check(
        _bindings.chromaprint_get_fingerprint(_context, fpPtr),
        'getFingerprint',
      );
      return fpPtr.value.cast<Utf8>().toDartString();
    } finally {
      if (fpPtr.value != ffi.nullptr) {
        _bindings.chromaprint_dealloc(fpPtr.value.cast());
      }
      calloc.free(fpPtr);
    }
  }

  /// Returns the raw fingerprint as a list of 32-bit unsigned integers.
  ///
  /// Must be called after [finish].
  List<int> getRawFingerprint() {
    final fpPtr = calloc<ffi.Pointer<ffi.Uint32>>();
    final sizePtr = calloc<ffi.Int>();
    try {
      _check(
        _bindings.chromaprint_get_raw_fingerprint(_context, fpPtr, sizePtr),
        'getRawFingerprint',
      );
      final size = sizePtr.value;
      return fpPtr.value.asTypedList(size).toList();
    } finally {
      if (fpPtr.value != ffi.nullptr) {
        _bindings.chromaprint_dealloc(fpPtr.value.cast());
      }
      calloc.free(fpPtr);
      calloc.free(sizePtr);
    }
  }

  /// Returns the number of elements in the raw fingerprint.
  ///
  /// Must be called after [finish].
  int getRawFingerprintSize() {
    final sizePtr = calloc<ffi.Int>();
    try {
      _check(
        _bindings.chromaprint_get_raw_fingerprint_size(_context, sizePtr),
        'getRawFingerprintSize',
      );
      return sizePtr.value;
    } finally {
      calloc.free(sizePtr);
    }
  }

  /// Returns a 32-bit hash of the fingerprint.
  ///
  /// Must be called after [finish].
  int getFingerprintHash() {
    final hashPtr = calloc<ffi.Uint32>();
    try {
      _check(
        _bindings.chromaprint_get_fingerprint_hash(_context, hashPtr),
        'getFingerprintHash',
      );
      return hashPtr.value;
    } finally {
      calloc.free(hashPtr);
    }
  }

  /// Releases the native chromaprint context.
  ///
  /// After calling this, the instance cannot be used anymore.
  void dispose() {
    if (!_disposed && _ctx != null) {
      _finalizer.detach(this);
      _bindings.chromaprint_free(_ctx!);
      _ctx = null;
      _disposed = true;
    }
  }

  @override
  String toString() => 'Chromaprint(algorithm: $algorithm, disposed: $_disposed)';
}

/// Returns the version string of the chromaprint library.
String getVersion() {
  final versionPtr = _bindings.chromaprint_get_version();
  return versionPtr.cast<Utf8>().toDartString();
}

/// Encodes a raw fingerprint to a compressed format.
///
/// [rawFingerprint] is the raw fingerprint data as 32-bit unsigned integers.
/// [algorithm] is the algorithm that was used to generate the fingerprint.
/// [base64] if true, the result is base64-encoded.
///
/// Returns the encoded fingerprint as a string.
String encodeFingerprint(
  List<int> rawFingerprint,
  ChromaprintAlgorithm algorithm, {
  bool base64 = true,
}) {
  final fpPtr = calloc<ffi.Uint32>(rawFingerprint.length);
  final encodedPtr = calloc<ffi.Pointer<ffi.Char>>();
  final encodedSizePtr = calloc<ffi.Int>();
  try {
    for (var i = 0; i < rawFingerprint.length; i++) {
      fpPtr[i] = rawFingerprint[i];
    }
    _check(
      _bindings.chromaprint_encode_fingerprint(
        fpPtr,
        rawFingerprint.length,
        algorithm.value,
        encodedPtr,
        encodedSizePtr,
        base64 ? 1 : 0,
      ),
      'encodeFingerprint',
    );
    return encodedPtr.value.cast<Utf8>().toDartString();
  } finally {
    if (encodedPtr.value != ffi.nullptr) {
      _bindings.chromaprint_dealloc(encodedPtr.value.cast());
    }
    calloc.free(fpPtr);
    calloc.free(encodedPtr);
    calloc.free(encodedSizePtr);
  }
}

/// Decodes a compressed fingerprint.
///
/// [encoded] is the encoded fingerprint string.
/// [base64] if true, the input is base64-encoded.
///
/// Returns a [DecodedFingerprint] containing the raw data and algorithm.
DecodedFingerprint decodeFingerprint(
  String encoded, {
  bool base64 = true,
}) {
  final encodedPtr = encoded.toNativeUtf8();
  final fpPtr = calloc<ffi.Pointer<ffi.Uint32>>();
  final sizePtr = calloc<ffi.Int>();
  final algorithmPtr = calloc<ffi.Int>();
  try {
    _check(
      _bindings.chromaprint_decode_fingerprint(
        encodedPtr.cast(),
        encoded.length, // chromaprint does not accept -1 as a sentinel
        fpPtr,
        sizePtr,
        algorithmPtr,
        base64 ? 1 : 0,
      ),
      'decodeFingerprint',
    );
    final size = sizePtr.value;
    final rawFp = fpPtr.value.asTypedList(size).toList();
    final algoValue = algorithmPtr.value;
    return DecodedFingerprint(
      rawFp,
      ChromaprintAlgorithm.values.firstWhere(
        (a) => a.value == algoValue,
        orElse: () => ChromaprintAlgorithm.defaultAlgorithm,
      ),
    );
  } finally {
    if (fpPtr.value != ffi.nullptr) {
      _bindings.chromaprint_dealloc(fpPtr.value.cast());
    }
    calloc.free(encodedPtr);
    calloc.free(fpPtr);
    calloc.free(sizePtr);
    calloc.free(algorithmPtr);
  }
}

/// Computes a 32-bit hash of a raw fingerprint.
///
/// This is useful for quickly comparing fingerprints.
int hashFingerprint(List<int> rawFingerprint) {
  final fpPtr = calloc<ffi.Uint32>(rawFingerprint.length);
  final hashPtr = calloc<ffi.Uint32>();
  try {
    for (var i = 0; i < rawFingerprint.length; i++) {
      fpPtr[i] = rawFingerprint[i];
    }
    _check(
      _bindings.chromaprint_hash_fingerprint(
        fpPtr,
        rawFingerprint.length,
        hashPtr,
      ),
      'hashFingerprint',
    );
    return hashPtr.value;
  } finally {
    calloc.free(fpPtr);
    calloc.free(hashPtr);
  }
}
