/// 封面主色提取（D12-6 延续 DEC-011 D11-3；重写版）。
/// 48px 降采样 + 24 色相桶 × 3 明度桶饱和度加权投票；灰图/坏图 → null。
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

Future<Color?> extractCoverSeedFromBytes(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes,
        targetWidth: 48, targetHeight: 48);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final ByteData? data;
    try {
      data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
      codec.dispose();
    }
    if (data == null) return null;
    return _dominant(data);
  } catch (_) {
    return null;
  }
}

Future<Color?> extractCoverSeedFromPath(String path) async {
  try {
    return await extractCoverSeedFromBytes(await File(path).readAsBytes());
  } catch (_) {
    return null;
  }
}

Color? _dominant(ByteData data) {
  const hueBins = 24;
  const lBins = 3;
  final votes = List.filled(hueBins * lBins, 0.0);
  final counts = List.filled(hueBins * lBins, 0);
  final rSum = List.filled(hueBins * lBins, 0);
  final gSum = List.filled(hueBins * lBins, 0);
  final bSum = List.filled(hueBins * lBins, 0);
  final bytes =
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  for (var i = 0; i + 3 < bytes.length; i += 4) {
    if (bytes[i + 3] < 128) continue;
    final r = bytes[i];
    final g = bytes[i + 1];
    final b = bytes[i + 2];
    final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
    final l = hsl.lightness;
    final s = hsl.saturation;
    if (l < 0.10 || l > 0.92 || s < 0.15) continue;
    final hueBin = (hsl.hue / 360 * hueBins).floor().clamp(0, hueBins - 1);
    final lBin = l < 0.33 ? 0 : (l < 0.66 ? 1 : 2);
    final idx = hueBin * lBins + lBin;
    votes[idx] += s;
    counts[idx] += 1;
    rSum[idx] += r;
    gSum[idx] += g;
    bSum[idx] += b;
  }
  var best = -1;
  var bestVotes = 0.0;
  for (var i = 0; i < votes.length; i++) {
    if (votes[i] > bestVotes) {
      bestVotes = votes[i];
      best = i;
    }
  }
  if (best < 0 || counts[best] < 6) return null;
  final n = counts[best];
  return Color.fromARGB(
    255,
    (rSum[best] / n).round().clamp(0, 255),
    (gSum[best] / n).round().clamp(0, 255),
    (bSum[best] / n).round().clamp(0, 255),
  );
}
