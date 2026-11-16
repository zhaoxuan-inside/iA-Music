/// B 站分 P 标题 → 歌名/歌手（纯函数，便于单测）。
library;

/// 解析「001.周杰伦-爱在西元前」「005.潘玮柏_弦子-不得不爱」这类分 P 名。
///
/// 拆不出时回退到分 P 名 + UP 主，绝不丢信息。
({String title, String artist}) parseBiliPageMeta(
  String part, {
  required String fallbackTitle,
  required String fallbackArtist,
}) {
  var s = part.trim();
  if (s.isEmpty) {
    return (title: fallbackTitle, artist: fallbackArtist);
  }
  // 去掉「001.」/「001、」编号
  s = s.replaceFirst(RegExp(r'^\d+[.、]\s*'), '');
  if (s.isEmpty) {
    return (title: fallbackTitle, artist: fallbackArtist);
  }
  // 纯数字分 P 名（如「1」）：用视频标题补齐，避免库里只显示「1」
  if (RegExp(r'^\d+$').hasMatch(s)) {
    return (title: '$fallbackTitle - $s', artist: fallbackArtist);
  }
  // 「歌手-歌名」；歌手可能用 _ 连接合作歌手
  final m = RegExp(r'^(.+?)\s*[-–—]\s*(.+)$').firstMatch(s);
  if (m == null) {
    return (title: s, artist: fallbackArtist);
  }
  final artist = m.group(1)!.trim().replaceAll('_', ' / ');
  final title = m.group(2)!.trim();
  if (artist.isEmpty || title.isEmpty) {
    return (title: s, artist: fallbackArtist);
  }
  return (title: title, artist: artist);
}
