/// 字母分组键：歌名/艺人名首字 → 拼音首字母大写；非字母归 '#'。
library;

import 'package:pinyin/pinyin.dart';

String letterKey(String raw) {
  final s = raw.trim();
  if (s.isEmpty) {
    return '#';
  }
  final up = s[0].toUpperCase();
  if (up.contains(RegExp('[A-Z]'))) {
    return up;
  }
  final py = PinyinHelper.getPinyinE(s[0], defPinyin: '#');
  final letter = py.isEmpty ? '#' : py[0].toUpperCase();
  return letter.contains(RegExp('[A-Z]')) ? letter : '#';
}
