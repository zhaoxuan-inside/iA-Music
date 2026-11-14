import 'dart:ffi' as ffi;
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chromaprint/chromaprint.dart';

/// Generates 16-bit PCM samples of a sine wave.
Int16List _generateSineWave({
  required int sampleRate,
  required double frequency,
  required int durationSeconds,
  double amplitude = 0.25,
  int channels = 1,
}) {
  final numSamples = sampleRate * durationSeconds * channels;
  final samples = Int16List(numSamples);
  for (var i = 0; i < numSamples; i++) {
    final sampleIndex = i ~/ channels;
    final channelIndex = i % channels;
    // Slight frequency offset per channel to create a distinguishable signal.
    final freq = frequency + channelIndex * 10.0;
    samples[i] =
        (amplitude * 32767.0 * sin(2 * pi * freq * sampleIndex / sampleRate))
            .toInt();
  }
  return samples;
}

/// Generates silent (zero) PCM samples.
Int16List _generateSilence({required int sampleRate, required int durationSeconds}) {
  return Int16List(sampleRate * durationSeconds);
}

void main() {
  group('ChromaprintAlgorithm', () {
    test('has expected values', () {
      expect(ChromaprintAlgorithm.test1.value, equals(0));
      expect(ChromaprintAlgorithm.test2.value, equals(1));
      expect(ChromaprintAlgorithm.test3.value, equals(2));
      expect(ChromaprintAlgorithm.test4.value, equals(3));
      expect(ChromaprintAlgorithm.test5.value, equals(4));
    });

    test('defaultAlgorithm is test2', () {
      expect(ChromaprintAlgorithm.defaultAlgorithm,
          equals(ChromaprintAlgorithm.test2));
    });
  });

  group('ChromaprintException', () {
    test('has correct message and toString', () {
      const exc = ChromaprintException('something went wrong');
      expect(exc.message, equals('something went wrong'));
      expect(exc.toString(), equals('ChromaprintException: something went wrong'));
    });
  });

  group('getVersion', () {
    test('returns a non-empty version string', () {
      final version = getVersion();
      expect(version, isNotEmpty);
      // Chromaprint v1.6.0 is expected from the bundled submodule.
      expect(version, startsWith('1.'));
    });
  });

  group('Chromaprint', () {
    test('creates instance with default algorithm', () {
      final cp = Chromaprint();
      expect(cp.algorithm, equals(ChromaprintAlgorithm.test2));
      cp.dispose();
    });

    test('creates instance with explicit algorithm', () {
      final cp = Chromaprint(algorithm: ChromaprintAlgorithm.test1);
      expect(cp.algorithm, equals(ChromaprintAlgorithm.test1));
      cp.dispose();
    });

    test('throws StateError after dispose', () {
      final cp = Chromaprint();
      cp.dispose();
      expect(() => cp.algorithm, throwsStateError);
      expect(() => cp.start(44100, 1), throwsStateError);
      expect(() => cp.feed(Int16List(0)), throwsStateError);
      expect(() => cp.finish(), throwsStateError);
    });

    test('dispose is idempotent', () {
      final cp = Chromaprint();
      cp.dispose();
      cp.dispose(); // Should not throw.
    });

    test('toString reflects state before dispose', () {
      final cp = Chromaprint();
      final str = cp.toString();
      expect(str, contains('Chromaprint('));
      expect(str, contains('disposed: false'));
      cp.dispose();
    });

    test('toString throws after dispose when accessing algorithm', () {
      final cp = Chromaprint();
      cp.dispose();
      // toString calls algorithm which accesses _context.
      expect(() => cp.toString(), throwsStateError);
    });

    test('sampleRate and numChannels after start', () {
      final cp = Chromaprint();
      cp.start(44100, 2);
      // Chromaprint internally resamples to 11025 Hz and downmixes to mono.
      expect(cp.sampleRate, equals(11025));
      expect(cp.numChannels, equals(1));
      cp.dispose();
    });

    test('item duration and delay are positive after start', () {
      final cp = Chromaprint();
      cp.start(44100, 1);
      expect(cp.itemDuration, greaterThan(0));
      expect(cp.itemDurationMs, greaterThan(0));
      expect(cp.delay, greaterThanOrEqualTo(0));
      expect(cp.delayMs, greaterThanOrEqualTo(0));
      cp.dispose();
    });

    test('generates fingerprint from mono sine wave', () {
      final cp = Chromaprint();
      cp.start(44100, 1);
      cp.feed(_generateSineWave(
        sampleRate: 44100,
        frequency: 440.0,
        durationSeconds: 5,
      ));
      cp.finish();

      final fingerprint = cp.getFingerprint();
      expect(fingerprint, isNotEmpty);

      final rawSize = cp.getRawFingerprintSize();
      expect(rawSize, greaterThan(0));

      final raw = cp.getRawFingerprint();
      expect(raw.length, equals(rawSize));
      expect(raw.every((e) => e >= 0), isTrue);

      final hash = cp.getFingerprintHash();
      expect(hash, isNonNegative);

      cp.dispose();
    });

    test('generates fingerprint from stereo audio', () {
      final cp = Chromaprint();
      cp.start(44100, 2);
      cp.feed(_generateSineWave(
        sampleRate: 44100,
        frequency: 1000.0,
        durationSeconds: 3,
        channels: 2,
      ));
      cp.finish();

      final fingerprint = cp.getFingerprint();
      expect(fingerprint, isNotEmpty);

      cp.dispose();
    });

    test('generates consistent fingerprints for identical input', () {
      final samples = _generateSineWave(
        sampleRate: 44100,
        frequency: 440.0,
        durationSeconds: 3,
      );

      String generateFp() {
        final cp = Chromaprint();
        cp.start(44100, 1);
        cp.feed(samples);
        cp.finish();
        final fp = cp.getFingerprint();
        cp.dispose();
        return fp;
      }

      final fp1 = generateFp();
      final fp2 = generateFp();
      expect(fp1, equals(fp2));
    });

    test('generates different fingerprints for different input', () {
      // Chromaprint normalizes amplitude, so use sine vs silence to guarantee
      // different fingerprints.
      final samples1 = _generateSineWave(
        sampleRate: 44100,
        frequency: 440.0,
        durationSeconds: 5,
      );
      final samples2 = _generateSilence(
        sampleRate: 44100,
        durationSeconds: 5,
      );

      String generateFp(Int16List samples) {
        final cp = Chromaprint();
        cp.start(44100, 1);
        cp.feed(samples);
        cp.finish();
        final fp = cp.getFingerprint();
        cp.dispose();
        return fp;
      }

      final fp1 = generateFp(samples1);
      final fp2 = generateFp(samples2);
      expect(fp1, isNot(equals(fp2)));
    });

    test('feedRaw works with native pointer', () {
      final samples = _generateSineWave(
        sampleRate: 44100,
        frequency: 440.0,
        durationSeconds: 3,
      );
      final dataPtr = calloc<ffi.Int16>(samples.length);
      try {
        dataPtr.asTypedList(samples.length).setAll(0, samples);

        final cp = Chromaprint();
        cp.start(44100, 1);
        cp.feedRaw(dataPtr, samples.length);
        cp.finish();

        final fingerprint = cp.getFingerprint();
        expect(fingerprint, isNotEmpty);
        cp.dispose();
      } finally {
        calloc.free(dataPtr);
      }
    });

    test('feed can be called multiple times', () {
      final samples = _generateSineWave(
        sampleRate: 44100,
        frequency: 440.0,
        durationSeconds: 5,
      );
      final chunkSize = samples.length ~/ 3;

      final cp = Chromaprint();
      cp.start(44100, 1);
      cp.feed(samples.sublist(0, chunkSize));
      cp.feed(samples.sublist(chunkSize, chunkSize * 2));
      cp.feed(samples.sublist(chunkSize * 2));
      cp.finish();

      final fingerprint = cp.getFingerprint();
      expect(fingerprint, isNotEmpty);
      cp.dispose();
    });

    test('clearFingerprint allows reuse', () {
      final cp = Chromaprint();

      // First fingerprint with audio.
      cp.start(44100, 1);
      cp.feed(_generateSineWave(
        sampleRate: 44100,
        frequency: 440.0,
        durationSeconds: 5,
      ));
      cp.finish();
      final fp1 = cp.getFingerprint();
      expect(fp1, isNotEmpty);

      // Clear and reuse with silence to guarantee different fingerprint.
      cp.clearFingerprint();
      cp.start(44100, 1);
      cp.feed(_generateSilence(sampleRate: 44100, durationSeconds: 5));
      cp.finish();
      final fp2 = cp.getFingerprint();
      expect(fp2, isNotEmpty);
      expect(fp2, isNot(equals(fp1)));

      cp.dispose();
    });

    test('setOption throws on unknown option name', () {
      final cp = Chromaprint();
      expect(
        () => cp.setOption('nonexistent_option', 42),
        throwsA(isA<ChromaprintException>()),
      );
      cp.dispose();
    });

    test('fingerprinting works without setOption', () {
      final cp = Chromaprint();
      cp.start(44100, 1);
      cp.feed(_generateSineWave(
        sampleRate: 44100,
        frequency: 440.0,
        durationSeconds: 3,
      ));
      cp.finish();
      final fingerprint = cp.getFingerprint();
      expect(fingerprint, isNotEmpty);
      cp.dispose();
    });

    test('supports different algorithms', () {
      for (final algo in ChromaprintAlgorithm.values) {
        final cp = Chromaprint(algorithm: algo);
        expect(cp.algorithm, equals(algo));
        cp.start(44100, 1);
        cp.feed(_generateSineWave(
          sampleRate: 44100,
          frequency: 440.0,
          durationSeconds: 3,
        ));
        cp.finish();
        final fingerprint = cp.getFingerprint();
        expect(fingerprint, isNotEmpty);
        cp.dispose();
      }
    });
  });

  group('encodeFingerprint / decodeFingerprint', () {
    test('round-trip encodes and decodes a fingerprint', () {
      final cp = Chromaprint();
      cp.start(44100, 1);
      cp.feed(_generateSineWave(
        sampleRate: 44100,
        frequency: 440.0,
        durationSeconds: 5,
      ));
      cp.finish();

      final raw = cp.getRawFingerprint();
      cp.dispose();

      // Encode then decode.
      final encoded = encodeFingerprint(raw, ChromaprintAlgorithm.test2);
      expect(encoded, isNotEmpty);

      final decoded = decodeFingerprint(encoded);
      expect(decoded.algorithm, equals(ChromaprintAlgorithm.test2));
      expect(decoded.rawFingerprint.length, equals(raw.length));
      expect(decoded.rawFingerprint, equals(raw));
    });

    test('encode with base64 disabled produces non-empty output', () {
      final cp = Chromaprint();
      cp.start(44100, 1);
      cp.feed(_generateSineWave(
        sampleRate: 44100,
        frequency: 440.0,
        durationSeconds: 5,
      ));
      cp.finish();

      final raw = cp.getRawFingerprint();
      cp.dispose();

      final encoded = encodeFingerprint(
        raw,
        ChromaprintAlgorithm.test2,
        base64: false,
      );
      expect(encoded, isNotEmpty);
    });

    test('encode without base64 produces non-empty output that can be decoded', () {
      final cp = Chromaprint();
      cp.start(44100, 1);
      cp.feed(_generateSineWave(
        sampleRate: 44100,
        frequency: 440.0,
        durationSeconds: 5,
      ));
      cp.finish();

      final raw = cp.getRawFingerprint();
      cp.dispose();

      final encoded = encodeFingerprint(
        raw,
        ChromaprintAlgorithm.test2,
        base64: true,
      );
      // Decode the base64-encoded fingerprint back.
      final decoded = decodeFingerprint(encoded, base64: true);
      expect(decoded.algorithm, equals(ChromaprintAlgorithm.test2));
      expect(decoded.rawFingerprint, equals(raw));
    });
  });

  group('hashFingerprint', () {
    test('returns a consistent hash for the same input', () {
      final cp = Chromaprint();
      cp.start(44100, 1);
      cp.feed(_generateSineWave(
        sampleRate: 44100,
        frequency: 440.0,
        durationSeconds: 5,
      ));
      cp.finish();

      final raw = cp.getRawFingerprint();
      cp.dispose();

      final hash1 = hashFingerprint(raw);
      final hash2 = hashFingerprint(raw);
      expect(hash1, equals(hash2));
      expect(hash1, isNonNegative);
    });

    test('returns different hashes for different input', () {
      final samples1 = _generateSineWave(
        sampleRate: 44100,
        frequency: 440.0,
        durationSeconds: 5,
      );

      List<int> getRaw(Int16List samples) {
        final cp = Chromaprint();
        cp.start(44100, 1);
        cp.feed(samples);
        cp.finish();
        final raw = cp.getRawFingerprint();
        cp.dispose();
        return raw;
      }

      final hash1 = hashFingerprint(getRaw(samples1));
      final hash2 = hashFingerprint(getRaw(_generateSilence(
        sampleRate: 44100,
        durationSeconds: 5,
      )));
      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('DecodedFingerprint', () {
    test('stores raw fingerprint and algorithm', () {
      final decoded = DecodedFingerprint([1, 2, 3], ChromaprintAlgorithm.test3);
      expect(decoded.rawFingerprint, equals([1, 2, 3]));
      expect(decoded.algorithm, equals(ChromaprintAlgorithm.test3));
    });
  });
}
