/// 展示格式化（时间等）。
library;

import 'package:ia_music/l10n/s.dart';

/// mm:ss（小时曲超 60 分钟自然展示 m 累计，如 75:20）。
String iaMmss(int ms) {
  final total = (ms / 1000).round();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// 时刻 HH:mm（历史行播放时刻；Unix ms）。
String iaHHmm(int unixMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(unixMs);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// 播放量（B 站式 12.3万；英文 UI 记 12.3M/1.2B）。
String iaPlayCount(int? n) {
  if (n == null) return '';
  final en = msg.localeName.startsWith('en');
  if (n >= 100000000) {
    return '${(n / 100000000).toStringAsFixed(1)}${en ? 'B' : '亿'}';
  }
  if (n >= 10000) {
    return '${(n / 10000).toStringAsFixed(1)}${en ? 'M' : '万'}';
  }
  return '$n';
}
