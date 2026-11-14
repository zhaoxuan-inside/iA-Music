/// 查询 NLP：原始标题串 → 分词 → 噪声滤除 → 候选搜索词（按置信度排序）。
///
/// 纯函数 + 词表配置（kNlpNoiseKeywords/kNlpSourceHints），isolate 安全。
library;

import '../../app/config/nlp_config.dart';

class QueryNlp {
  const QueryNlp();

  /// 分词：按分隔符与括号段切开，保留 CJK 连续段与字母数字连续段。
  List<String> tokenize(String raw) {
    final cleaned = raw
        .replaceAll(RegExp('【[^】]*】'), ' ')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[-_–—.]+'), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// token 是否为噪声：纯数字 / 命中噪声词 / 来源站特征 / 扩展名。
  bool isNoise(String token) {
    final t = token.toLowerCase();
    if (t.isEmpty) {
      return true;
    }
    if (kNlpIsNumericToken(t)) {
      return true;
    }
    for (final k in kNlpNoiseKeywords) {
      if (t.contains(k)) {
        return true;
      }
    }
    for (final s in kNlpSourceHints) {
      if (t.contains(s)) {
        return true;
      }
    }
    if (t.endsWith('.mp3') ||
        t.endsWith('.flac') ||
        t.endsWith('.m4a') ||
        t.endsWith('.wav')) {
      return true;
    }
    return false;
  }

  /// 从原始串构造候选搜索词（去噪后的 token 序列）。
  List<String> buildQueries(
      {required String rawTitle, required String fileName}) {
    final tokens = <String>[];
    for (final t in tokenize(rawTitle)) {
      tokens.add(t);
    }
    // 文件名基名补充线索（若与 raw 不同源）
    var base = fileName.trim();
    final dot = base.lastIndexOf('.');
    if (dot > 0) {
      base = base.substring(0, dot);
    }
    for (final t in tokenize(base)) {
      if (!tokens.contains(t)) {
        tokens.add(t);
      }
    }

    final clean = <String>[];
    for (final t in tokens) {
      if (!isNoise(t) && !clean.contains(t)) {
        clean.add(t);
      }
    }
    if (clean.isEmpty) {
      return const <String>[];
    }
    // 查询按置信度排序：全串 → 去尾 → 头两 → 首词
    final queries = <String>[];
    String join(List<String> part) => part.join(' ').trim();
    if (clean.length >= 3) {
      queries.add(join(clean));
    }
    if (clean.length >= 2) {
      queries.add(join(clean.sublist(0, clean.length - 1)));
    }
    queries.add(clean.first);
    if (clean.length >= 2) {
      queries.add('${clean.first} ${clean[1]}');
    }
    final out = <String>[];
    for (final q in queries) {
      if (q.length >= 2 && !out.contains(q)) {
        out.add(q);
      }
    }
    return out;
  }
}
