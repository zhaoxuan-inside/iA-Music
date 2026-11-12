/// 歌词领域模型与 LRC 解析/成形（纯 Dart 纯函数；全仓唯一一份）。
library;

/// 一行歌词：时间戳 + 文本。
class LyricLine {
  const LyricLine({required this.tMs, required this.text});

  final int tMs;
  final String text;

  bool get isBlank => text.trim().isEmpty;
}

/// 整篇歌词（已按时间升序）。
class LyricDoc {
  const LyricDoc({required this.lines, required this.sourceKind});

  final List<LyricLine> lines;
  final LyricSourceKind sourceKind;

  bool get isEmpty => lines.isEmpty;

  /// 二分定位：播放到 [tMs] 时应高亮的行号；无命中（含空文档）返回 null。
  int? lineIndexAt(int tMs) {
    var lo = 0;
    var hi = lines.length - 1;
    var hit = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].tMs <= tMs) {
        hit = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return hit < 0 ? null : hit;
  }
}

enum LyricSourceKind { none, sidecar, embedded, online, pasted }

final RegExp _stamp = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final RegExp _metaTag = RegExp(r'^\[(ti|ar|al|by|offset|length|re|ve):(.*)\]$', caseSensitive: false);

/// 解析 LRC 文本。容忍多时间戳行与 `[mm:ss]` 无厘头行；失败返回空文档。
LyricDoc parseLrc(String raw, {LyricSourceKind kind = LyricSourceKind.none}) {
  final out = <LyricLine>[];
  var offsetMs = 0;
  for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
    final meta = _metaTag.firstMatch(rawLine.trim());
    if (meta != null) {
      if (meta.group(1)!.toLowerCase() == 'offset') {
        offsetMs = int.tryParse(meta.group(2)!.trim()) ?? 0;
      }
      continue;
    }
    final stamps = _stamp.allMatches(rawLine).toList();
    if (stamps.isEmpty) {
      continue;
    }
    final text = rawLine.substring(stamps.last.end).trim();
    for (final m in stamps) {
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final fracRaw = m.group(3) ?? '0';
      final frac = int.parse(fracRaw.padRight(3, '0').substring(0, 3));
      out.add(LyricLine(tMs: min * 60000 + sec * 1000 + frac - offsetMs, text: text));
    }
  }
  out.sort((a, b) => a.tMs.compareTo(b.tMs));
  return LyricDoc(lines: out, sourceKind: kind);
}

/// 成形为标准 LRC 文本（供落盘；[offsetMs] 作用于时间轴，正=整体延后）。
String formatLrc(List<LyricLine> lines, {int offsetMs = 0}) {
  final buf = StringBuffer();
  if (offsetMs != 0) {
    buf.writeln('[offset:$offsetMs]');
  }
  for (final l in lines) {
    buf.writeln('[${_stamp2(l.tMs + offsetMs)}]${l.text}');
  }
  return buf.toString();
}

String _stamp2(int tMs) {
  final m = (tMs ~/ 60000).toString().padLeft(2, '0');
  final s = ((tMs % 60000) ~/ 1000).toString().padLeft(2, '0');
  final cs = ((tMs % 1000) ~/ 10).toString().padLeft(2, '0');
  return '$m:$s.$cs';
}

/// 判定一篇 LRC 是否逐行同步（≥60% 行带有效时间轴且非纯空行）。
bool looksSynced(LyricDoc doc) {
  if (doc.lines.isEmpty) {
    return false;
  }
  final withText = doc.lines.where((l) => !l.isBlank).length;
  return withText >= doc.lines.length * 0.6 && doc.lines.length >= 4;
}

/// 歌词决议结果（正文 + 生效偏移；偏移在渲染期应用）。
class LyricsResult {
  const LyricsResult({required this.doc, required this.offsetMs});

  final LyricDoc doc;
  final int offsetMs;
}
