/// Quickplay 固定项：把专辑 / 艺人 / 歌单钉到快速播放墙。
library;

enum QuickplayKind { album, artist, playlist }

class QuickplayPin {
  const QuickplayPin({
    required this.kind,
    required this.key,
    required this.title,
    required this.subtitle,
  });

  final QuickplayKind kind;

  /// album / artist 为 norm 键；playlist 为数据库 id 字符串。
  final String key;
  final String title;
  final String subtitle;

  String get id => '${kind.name}:$key';

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'key': key,
        'title': title,
        'subtitle': subtitle,
      };

  static QuickplayPin? fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'];
    final key = json['key'];
    final title = json['title'];
    if (rawKind is! String || key is! String || title is! String) {
      return null;
    }
    QuickplayKind? kind;
    for (final k in QuickplayKind.values) {
      if (k.name == rawKind) {
        kind = k;
      }
    }
    if (kind == null) {
      return null;
    }
    return QuickplayPin(
      kind: kind,
      key: key,
      title: title,
      subtitle: json['subtitle'] as String? ?? '',
    );
  }
}
