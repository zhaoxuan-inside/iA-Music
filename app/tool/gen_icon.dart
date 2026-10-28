/// 一次性图标生成器（2026-10-25 · DEC-012 产品化）：
/// iA Music 启动图标——深夜近黑渐变底 + 品牌绿五柱信号条（“私人电台”）。
///
/// 纯 Dart（自带 PNG 编码器 + ICO 容器），不引第三方包：
/// * master 1024 → Android legacy 各密度（ic_launcher / ic_launcher_round）
/// * Windows app_icon.ico（256/64/48/32/16 PNG 帧）
/// 运行：dart run tool/gen_icon.dart
library;

import 'dart:io';
import 'dart:typed_data';

const _bgTop = [0x1A, 0x1B, 0x20]; // #1A1B20
const _bgBottom = [0x0F, 0x10, 0x13]; // #0F1013 画布
const _green = [0x4B, 0xE0, 0xA3]; // 品牌绿 #4BE0A3

const _size = 1024;
const _baseline = 712.0;
const _barW = 74.0;
const _centers = [252.0, 382.0, 512.0, 642.0, 772.0];
const _barH = [0.34, 0.52, 0.74, 0.54, 0.38]; // ×560
const _barA = [0.85, 0.95, 1.0, 0.95, 0.85];

/// mask: 0=square rounded-rect, 1=circle
Uint8List paintIcon(int mask) {
  final px = Uint8List(_size * _size * 4);
  final r = 224.0; // 圆角半径（22%）
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final i = (y * _size + x) * 4;
      final fx = x + 0.5, fy = y + 0.5;

      // 遮罩（几何外=透明）
      double a;
      if (mask == 1) {
        final d = _dist(fx, fy, 512, 512);
        a = d <= 512 ? 1.0 : 0.0;
      } else {
        final cx = _clamp(fx, r, _size - r), cy = _clamp(fy, r, _size - r);
        a = _dist(fx, fy, cx, cy) <= r ? 1.0 : 0.0;
      }
      if (a == 0.0) {
        px[i + 3] = 0;
        continue;
      }

      // 背景垂直渐变
      final t = fy / _size;
      var cr = _lerpInt(_bgTop[0], _bgBottom[0], t).toDouble();
      var cg = _lerpInt(_bgTop[1], _bgBottom[1], t).toDouble();
      var cb = _lerpInt(_bgTop[2], _bgBottom[2], t).toDouble();

      // 信号柱（胶囊：到中轴距离 ≤ 半宽）
      for (var b = 0; b < 5; b++) {
        final h = _barH[b] * 560;
        final top = _baseline - h;
        final nearestX = _clamp(fx, _centers[b], _centers[b]);
        final nearestY = _clamp(fy, top + _barW / 2, _baseline - _barW / 2);
        if (_dist(fx, fy, nearestX, nearestY) <= _barW / 2) {
          final ba = _barA[b];
          cr = cr * (1 - ba) + _green[0] * ba;
          cg = cg * (1 - ba) + _green[1] * ba;
          cb = cb * (1 - ba) + _green[2] * ba;
          break;
        }
      }

      px[i] = cr.round();
      px[i + 1] = cg.round();
      px[i + 2] = cb.round();
      px[i + 3] = 255;
    }
  }
  return px;
}

double _dist(double x1, double y1, double x2, double y2) =>
    _sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));

double _sqrt(double v) {
  if (v <= 0) return 0;
  var g = v;
  for (var i = 0; i < 40; i++) {
    g = (g + v / g) / 2;
  }
  return g;
}

double _clamp(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

int _lerpInt(int a, int b, double t) => (a + (b - a) * t).round();

// ── PNG 编码（RGBA8 · filter 0 · zlib）──

Uint8List encodePng(int w, int h, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // filter none
    raw.add(Uint8List.sublistView(rgba, y * w * 4, (y + 1) * w * 4));
  }
  final idat = Uint8List.fromList(ZLibEncoder(level: 9).convert(raw.takeBytes()));

  final out = BytesBuilder();
  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _chunk(out, 'IHDR', _ihdr(w, h));
  _chunk(out, 'IDAT', idat);
  _chunk(out, 'IEND', Uint8List(0));
  return out.takeBytes();
}

Uint8List _ihdr(int w, int h) {
  final b = ByteData(13);
  b.setUint32(0, w);
  b.setUint32(4, h);
  b.setUint8(8, 8); // bit depth
  b.setUint8(9, 6); // RGBA
  b.setUint8(10, 0);
  b.setUint8(11, 0);
  b.setUint8(12, 0);
  return b.buffer.asUint8List();
}

void _chunk(BytesBuilder out, String type, Uint8List data) {
  final len = ByteData(4)..setUint32(0, data.length);
  out.add(len.buffer.asUint8List());
  final typeBytes = type.codeUnits;
  out.add(typeBytes);
  out.add(data);
  final crcInput = BytesBuilder()..add(typeBytes)..add(data);
  final crc = ByteData(4)..setUint32(0, _crc32(crcInput.takeBytes()));
  out.add(crc.buffer.asUint8List());
}

List<int>? _crcCache;
List<int> get _crcTableGen => _crcCache ??= () {
      final t = List<int>.filled(256, 0);
      for (var n = 0; n < 256; n++) {
        var c = n;
        for (var k = 0; k < 8; k++) {
          c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
        }
        t[n] = c;
      }
      return t;
    }();

int _crc32(Uint8List data) {
  final t = _crcTableGen;
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc = t[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

// ── 缩放（面积平均，向下取整即可）──

Uint8List resizeRgba(Uint8List src, int srcSize, int dstSize) {
  final dst = Uint8List(dstSize * dstSize * 4);
  final ratio = srcSize / dstSize;
  for (var y = 0; y < dstSize; y++) {
    for (var x = 0; x < dstSize; x++) {
      // 目标像素覆盖的源块盒平均；步进限 ~8 采样/轴防细柱丢失。
      final x0 = (x * ratio).floor();
      final y0 = (y * ratio).floor();
      final x1 = ((x + 1) * ratio).ceil().clamp(x0 + 1, srcSize);
      final y1 = ((y + 1) * ratio).ceil().clamp(y0 + 1, srcSize);
      final stepX = ((x1 - x0) / 8).ceil().clamp(1, x1 - x0);
      final stepY = ((y1 - y0) / 8).ceil().clamp(1, y1 - y0);
      var r = 0, g = 0, b = 0, a = 0, n = 0;
      for (var sy = y0; sy < y1; sy += stepY) {
        for (var sx = x0; sx < x1; sx += stepX) {
          final i = (sy * srcSize + sx) * 4;
          r += src[i];
          g += src[i + 1];
          b += src[i + 2];
          a += src[i + 3];
          n++;
        }
      }
      final o = (y * dstSize + x) * 4;
      dst[o] = r ~/ n;
      dst[o + 1] = g ~/ n;
      dst[o + 2] = b ~/ n;
      dst[o + 3] = a ~/ n;
    }
  }
  return dst;
}

// ── ICO 容器（PNG 帧内嵌，Vista+ 支持）──

Uint8List buildIco(List<(int size, Uint8List png)> frames) {
  final out = BytesBuilder();
  final head = ByteData(6);
  head.setUint16(0, 0);
  head.setUint16(2, 1);
  head.setUint16(4, frames.length);
  out.add(head.buffer.asUint8List());
  var offset = 6 + 16 * frames.length;
  final dir = BytesBuilder();
  var data = BytesBuilder();
  for (final (size, png) in frames) {
    final e = ByteData(16);
    e.setUint8(0, size >= 256 ? 0 : size);
    e.setUint8(1, size >= 256 ? 0 : size);
    e.setUint8(2, 0);
    e.setUint8(3, 0);
    e.setUint16(4, 1); // planes
    e.setUint16(6, 32); // bpp
    e.setUint32(8, png.length);
    e.setUint32(12, offset);
    dir.add(e.buffer.asUint8List());
    data.add(png);
    offset += png.length;
  }
  out.add(dir.takeBytes());
  out.add(data.takeBytes());
  return out.takeBytes();
}

void main() {
  final square = paintIcon(0);
  final round = paintIcon(1);
  final res = 'android/app/src/main/res';
  const densities = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  for (final e in densities.entries) {
    final dir = '$res/mipmap-${e.key}';
    Directory(dir).createSync(recursive: true);
    final sq = resizeRgba(square, _size, e.value);
    final rd = resizeRgba(round, _size, e.value);
    File('$dir/ic_launcher.png').writeAsBytesSync(encodePng(e.value, e.value, sq));
    File('$dir/ic_launcher_round.png')
        .writeAsBytesSync(encodePng(e.value, e.value, rd));
    stdout.writeln('mipmap-${e.key} (${e.value}px) ✓');
  }
  // Windows ICO（256 主帧 + 小尺寸）
  final frames = <(int, Uint8List)>[
    for (final s in [256, 64, 48, 32, 16])
      (s, encodePng(s, s, resizeRgba(square, _size, s))),
  ];
  File('windows/runner/resources/app_icon.ico')
      .writeAsBytesSync(buildIco(frames));
  stdout.writeln('windows app_icon.ico ✓');
  // master 存档（设计稿参照）
  File('output/icon_master_1024.png').writeAsBytesSync(encodePng(_size, _size, square));
  stdout.writeln('output/icon_master_1024.png ✓');
}
