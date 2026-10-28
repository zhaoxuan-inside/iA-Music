// 一次性取证脚本（S8 性能排障）：统计曲库规模与各表行数。
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.open(
      r'C:\Users\hardstone\AppData\Roaming\com.hardstone\ia_music\ia_music.db');
  for (final t in [
    'tracks',
    'albums',
    'artists',
    'repository_roots',
    'extract_tasks',
    'lyrics_meta',
    'play_history',
  ]) {
    final n =
        db.select('SELECT COUNT(*) AS n FROM $t').first['n'] as int;
    stdout.writeln('$t=$n');
  }
  db.select("SELECT status, COUNT(*) AS n FROM extract_tasks GROUP BY status").forEach((r) => stdout.writeln('task_${r['status']}=${r['n']}'));
  db.close();
}
