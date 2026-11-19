/// 歌名归一化（纯函数，isolate 安全）：
/// 从标签或文件名推导出干净的歌名，必要时顺带推断歌手。
///
/// 规则（按序）：
/// 1. 去扩展名后取基名
/// 2. 去前导曲号——数字后必须跟分隔符或空白才算曲号（「16月6日」不动）
/// 3. 「歌手 - 歌名」拆分（带空格分隔）：任一侧等于已知歌手则取另一侧；
///    歌手未知时按首个分隔符拆（左=歌手 右=歌名），仅当两侧都非空
/// 4. 「歌名-歌手」拆分（无空格连字符，恰一个「-」）：歌手已知时等于
///    歌手的一侧剥离；未知时右=歌手（记得-林俊杰 → 记得 / 林俊杰）
/// 5. 去装饰段：【…】恒去；(…) / […] 含媒体关键词才去（Official/MV/Live…）
/// 6. 空白折叠；结果为空回退输入
library;

class NormalizedTitle {
  const NormalizedTitle({required this.title, this.artist});

  final String title;

  /// 仅当从文件名/标签推断出新歌手时非空（不覆盖已有歌手标签）。
  final String? artist;
}

const List<String> _mediaKeywords = [
  'official', 'mv', 'audio', 'video', 'live', 'hd', '4k', '8k', 'remaster',
  'remastered', 'lyrics', '歌词', '歌词版', '字幕', '完整版', '高清', '纯音乐', '伴奏', 'instrumental', '现场',
];

const List<String> _separators = [' - ', ' — ', ' – ', ' _ ', '_-_', ' -_', '_- '];

NormalizedTitle normalizeTitle(
    {required String raw, String? artistTag, String? fileName}) {
  var source = raw.trim();
  final fromFile = source.isEmpty;
  if (fromFile) {
    var base = (fileName ?? '').trim();
    final dot = base.lastIndexOf('.');
    if (dot > 0) {
      base = base.substring(0, dot);
    }
    source = base;
  }

  var artist = artistTag?.trim() ?? '';
  final hadArtistTag = artist.isNotEmpty;

  // 去前导曲号：数字后必须跟分隔符（01- / 01_ / 01.）或空白，
  // 否则不是曲号——「16月6日」的 16 是歌名的一部分。
  source = source.replaceFirst(
      RegExp(r'^\s*(?:\d{1,3}\s*[-._)\]]+\s*|\d{1,3}\s+(?=\S))'), '');

  // 「歌手 - 歌名」拆分
  for (final sep in _separators) {
    final idx = source.indexOf(sep);
    if (idx <= 0 || idx + sep.length >= source.length) {
      continue;
    }
    final left = source.substring(0, idx).trim();
    final right = source.substring(idx + sep.length).trim();
    if (left.isEmpty || right.isEmpty) {
      continue;
    }
    if (artist.isNotEmpty) {
      final l = left.toLowerCase();
      final r = right.toLowerCase();
      final a = artist.toLowerCase();
      if (l == a) {
        source = right;
        break;
      }
      if (r == a) {
        source = left;
        break;
      }
    } else if (artist.isEmpty) {
      // 歌手未知：按文件名惯例 左=歌手 右=歌名
      artist = left;
      source = right;
      break;
    }
  }

  // 「歌名-歌手」拆分（无空格连字符）：文件名惯例歌名在前。
  // 仅当恰好一个连字符且两侧非空时启用；右段纯数字或过长不视作歌手。
  if (RegExp(r'[-–—]').allMatches(source).length == 1) {
    final m = RegExp(r'^(.+?)\s*[-–—]\s*(.+)$').firstMatch(source);
    if (m != null) {
      final left = m.group(1)!.trim();
      final right = m.group(2)!.trim();
      final a = artist.toLowerCase();
      if (artist.isNotEmpty) {
        // 歌手已知：等于歌手的一侧剥离
        if (right.toLowerCase() == a && left.isNotEmpty) {
          source = left;
        } else if (left.toLowerCase() == a && right.isNotEmpty) {
          source = right;
        }
      } else if (left.isNotEmpty &&
          right.isNotEmpty &&
          right.length <= 12 &&
          !RegExp(r'^\d+$').hasMatch(right)) {
        artist = right;
        source = left;
      }
    }
  }

  // 去装饰段：【…】恒去；(…) / […] 含媒体关键词才去
  source = source
      .replaceAll(RegExp('【[^】]*】'), '')
      .replaceAllMapped(RegExp(r'\[[^\]]*\]'), (m) {
        final inner = m.group(0)!.substring(1, m.group(0)!.length - 1).toLowerCase();
        return _mediaKeywords.any(inner.contains) ? '' : m.group(0)!;
      })
      .replaceAllMapped(RegExp(r'\([^)]*\)'), (m) {
        final inner = m.group(0)!.substring(1, m.group(0)!.length - 1).toLowerCase();
        return _mediaKeywords.any(inner.contains) ? '' : m.group(0)!;
      });

  // 尾部残留分隔符与空白折叠
  source = source
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[\s\-_.]+$'), '')
      .trim();

  if (source.isEmpty && fileName != null && fileName.trim().isNotEmpty) {
    var base = fileName.trim();
    final dot = base.lastIndexOf('.');
    if (dot > 0) {
      base = base.substring(0, dot);
    }
    final stripped = base
        .replaceFirst(
            RegExp(r'^\s*(?:\d{1,3}\s*[-._)\]]+\s*|\d{1,3}\s+(?=\S))'), '')
        .trim();
    // 纯数字文件名（01.wav/06.mp3）去掉曲号后会空；
    // 此时保留原数字，别把可用信息变成「未知歌曲」。
    source = stripped.isEmpty ? base.trim() : stripped;
  }
  if (source.isEmpty) {
    source = '未知歌曲';
  }

  return NormalizedTitle(
      title: source,
      artist: (!hadArtistTag && artist.isNotEmpty) ? artist : null);
}
