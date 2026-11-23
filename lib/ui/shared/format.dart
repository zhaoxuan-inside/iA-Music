/// 展示格式化：时长（原 7 处手写 `sec ~/ 60` 收口）。
library;

/// 毫秒 → m:ss（如 3:07）。
String formatDuration(int ms) {
  final sec = (ms / 1000).round();
  return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
}
