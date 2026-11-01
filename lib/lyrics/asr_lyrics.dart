/// ASR token 时间轴 → LRC 歌词成形（纯函数，单测覆盖）。
///
/// * 特殊标签 token（SenseVoice 的 `<|zh|>`/`<|HAPPY|>` 等事件/语种标记）剔除；
/// * 行切分：标点（，。！？；、,.!?）收行；行超 [maxLineChars] 字在最近
///   token 后强制断；行首时间=行首 token 时间；
/// * 连续相同标点/纯标点行丢弃；空白行丢弃。
library;

import 'package:ia_music/adapters/asr_adapter.dart';

const int maxLineChars = 14;

/// 成形产物：LRC 正文 + 纯文本（无时间轴，展示/检索用）。
final class AsrLyrics {
  const AsrLyrics(this.lrc, this.plainText);
  final String lrc;
  final String plainText;
}

/// SenseVoice 特殊标记 token（`<|...|>` 形态）。
bool _isSpecialToken(String w) =>
    w.startsWith('<|') && w.endsWith('|>') || w.startsWith('<') && w.endsWith('>');

bool _isPunct(String w) => '，。！？；、,.!?…'.contains(w);

AsrLyrics asrTokensToLyrics(List<AsrToken> tokens, {int maxChars = maxLineChars}) {
  final clean = tokens.where((t) {
    final w = t.text.trim();
    return w.isNotEmpty && !_isSpecialToken(w);
  }).toList();
  if (clean.isEmpty) {
    return const AsrLyrics('', '');
  }

  final lines = <({int startMs, String text})>[];
  final buf = StringBuffer();
  int? lineStart;
  var chars = 0;

  void flush() {
    final text = buf.toString().trim();
    if (text.isNotEmpty && RegExp(r'[\u4e00-\u9fff\w]').hasMatch(text)) {
      lines.add((startMs: lineStart ?? 0, text: text));
    }
    buf.clear();
    lineStart = null;
    chars = 0;
  }

  for (final t in clean) {
    final w = t.text;
    if (_isPunct(w)) {
      if (buf.isNotEmpty) {
        flush(); // 标点只触发断行，不进行文本（LRC 行干净）
      }
      continue;
    }
    if (buf.isNotEmpty && chars + w.length > maxChars) {
      flush(); // 写前预判：长 token 在行尾处溢出（13字+3字token=16>14）
    }
    lineStart ??= t.tMs;
    buf.write(w);
    chars += w.length;
  }
  flush();

  final lrc = [
    for (final l in lines)
      '[${_mmssxx(l.startMs)}]${l.text}',
  ].join('\n');
  final plain = [
    for (final l in lines) l.text,
  ].join('\n');
  return AsrLyrics(lrc, plain);
}

String _mmssxx(int ms) {
  final m = (ms ~/ 60000).toString().padLeft(2, '0');
  final s = ((ms ~/ 1000) % 60).toString().padLeft(2, '0');
  final xx = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
  return '$m:$s.$xx';
}
