/// FTS 文本规整：CJK 逐字空格分隔 + 拼音双列生成（全仓唯一一份）。
///
/// unicode61 分词器把连续汉字当一个 token，因此**写入与查询两侧**都必须
/// 先过 [ftsText] 逐字拆分；拼音列额外附加"整串粘连 token"，
/// 使 `zhoujie` 这类无分隔输入也能前缀命中。
library;

import 'package:pinyin/pinyin.dart';

final RegExp _cjk = RegExp(r'[\u3040-\u30FF\u3400-\u9FFF\uF900-\uFAFF\uAC00-\uD7AF]');
final RegExp _ws = RegExp(r'\s+');

/// 是否 CJK 字符。
bool isCjkChar(String ch) => ch.isNotEmpty && _cjk.hasMatch(ch);

/// FTS 写入/查询共用规整：小写化 + CJK 逐字空格分隔 + 空白折叠。
String ftsText(String raw) {
  final buf = StringBuffer();
  for (final ch in raw.toLowerCase().runes) {
    final c = String.fromCharCode(ch);
    if (isCjkChar(c)) {
      buf..write(c)..write(' ');
    } else if (_ws.hasMatch(c)) {
      buf.write(' ');
    } else {
      buf.write(c);
    }
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 拼音全称列：每字拼音（未知字符保留原文）+ 末尾整串粘连 token。
String pinyinFull(String raw) {
  final syllables = <String>[];
  final glued = StringBuffer();
  for (final ch in raw.trim().runes) {
    final c = String.fromCharCode(ch);
    if (isCjkChar(c)) {
      var py = '';
      try {
        py = PinyinHelper.getPinyin(c);
      } on PinyinException {
        py = c;
      }
      syllables.add(py.toLowerCase());
      glued.write(py.toLowerCase());
    } else if (!_ws.hasMatch(c)) {
      syllables.add(c.toLowerCase());
      glued.write(c.toLowerCase());
    }
  }
  if (glued.isEmpty) {
    return '';
  }
  return '${syllables.join(' ')} ${glued.toString()}';
}

/// 拼音首字母列：逐字首字母 + 粘连 token。
String pinyinInitials(String raw) {
  final parts = <String>[];
  final glued = StringBuffer();
  for (final ch in raw.trim().runes) {
    final c = String.fromCharCode(ch);
    if (!isCjkChar(c)) {
      if (!_ws.hasMatch(c)) {
        parts.add(c.toLowerCase());
        glued.write(c.toLowerCase());
      }
      continue;
    }
    var head = '';
    try {
      head = PinyinHelper.getShortPinyin(c).toLowerCase();
    } on PinyinException {
      head = c.toLowerCase();
    }
    if (head.isNotEmpty) {
      parts.add(head.substring(0, 1));
      glued.write(head.substring(0, 1));
    }
  }
  if (glued.isEmpty) {
    return '';
  }
  return '${parts.join(' ')} ${glued.toString()}';
}

/// 查询侧：把用户输入拆成 FTS MATCH 词表（每词加前缀星号，AND 连接）。
String buildFtsMatch(String query) {
  final normalized = ftsText(query);
  final tokens = normalized
      .split(' ')
      .where((t) => t.isNotEmpty)
      .map((t) => '"$t"*')
      .toList();
  return tokens.join(' ');
}

/// SQL GROUP BY 用的规整键。
String normKey(String raw) => raw.trim().toLowerCase();
