/// 展示格式化（时间等）。
library;

/// mm:ss（小时曲超 60 分钟自然展示 m 累计，如 75:20）。
String iaMmss(int ms) {
  final total = (ms / 1000).round();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// 播放量（B 站式 12.3万）。
String iaPlayCount(int? n) {
  if (n == null) return '';
  if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(1)}亿';
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
  return '$n';
}
