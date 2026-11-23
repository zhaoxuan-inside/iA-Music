/// 架构守卫测试——分层 import 规则的机器强制（v2 宪章第一条；永不被删）。
///
/// 规则（docs/ARCHITECTURE.md）：
/// * ui        → 只准 import state / domain / app(theme) / flutter / riverpod / l10n
/// * state     → 禁 import adapters / data（组合根在 app/providers.dart，
///               data 类型经组合根中继 export）
/// * services  → 禁 import adapters / ui / state / flutter
/// * data      → 禁 import adapters / services / ui / state
/// * adapters  → 禁 import services / data / ui / state（叶子实现，只依赖 domain）
/// * plugins   → 禁 import services / data / ui / state（自包含沙箱子系统）
/// * domain    → 禁 import lib 内其它层与 Flutter（纯 Dart）
///
/// 匹配前先把 import URI 归一化为 lib/ 内路径：`package:ia_music/x.dart` 与
/// 相对路径 `../adapters/x.dart` 都解析成 `lib/...` 再比对——曾经相对路径
/// 完全绕过本守卫（真实违规全部走相对 import 却一直绿灯）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 每层 → 禁止的 import 前缀（归一化后的 lib/ 路径或外部 package:/dart: 名）。
const Map<String, List<String>> _forbidden = {
  'lib/ui/': [
    'lib/adapters/',
    'lib/data/',
    'package:drift/',
    'package:sqlite3/',
  ],
  'lib/state/': ['lib/adapters/', 'lib/data/', 'package:drift/'],
  'lib/services/': [
    'lib/adapters/',
    'lib/ui/',
    'lib/state/',
    'package:flutter/',
    'dart:ui',
  ],
  'lib/data/': ['lib/adapters/', 'lib/services/', 'lib/ui/', 'lib/state/'],
  'lib/adapters/': ['lib/services/', 'lib/data/', 'lib/ui/', 'lib/state/'],
  'lib/plugins/': ['lib/services/', 'lib/data/', 'lib/ui/', 'lib/state/'],
  'lib/domain/': [
    'lib/adapters/',
    'lib/data/',
    'lib/services/',
    'lib/state/',
    'lib/ui/',
    'lib/app/',
    'package:flutter/',
    'dart:ui',
  ],
};

/// import/export 指令提取。
final RegExp _importRe = RegExp(r'''^\s*(?:import|export|part(?: of)?)\s+['"]([^'"]+)['"]''', multiLine: true);

/// import URI → 归一化路径。
///
/// * `package:ia_music/x` → `lib/x`；其余 `package:`/`dart:` 原样返回
///   （外部包禁令如 `package:drift/` 仍按前缀比对）。
/// * 相对路径按所在文件目录解析 `.`/`..`，落回 lib/ 内路径。
String _normalize(String filePath, String uri) {
  if (uri.startsWith('package:ia_music/')) {
    return 'lib/${uri.substring('package:ia_music/'.length)}';
  }
  if (uri.startsWith('package:') || uri.startsWith('dart:')) {
    return uri;
  }
  final base = filePath.split('/')..removeLast();
  final parts = <String>[];
  for (final seg in uri.split('/')) {
    if (seg == '..') {
      if (parts.isNotEmpty) {
        parts.removeLast();
      }
    } else if (seg != '.') {
      parts.add(seg);
    }
  }
  return [...base, ...parts].join('/');
}

void main() {
  test('分层 import 规则', () {
    final violations = <String>[];
    for (final layer in _forbidden.keys) {
      final dir = Directory(layer);
      if (!dir.existsSync()) {
        continue;
      }
      for (final file in dir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) {
          continue;
        }
        // Windows 下 listSync 返回反斜杠路径，统一成正斜杠再解析。
        final path = file.path.replaceAll(r'\', '/');
        for (final line in file.readAsLinesSync()) {
          final m = _importRe.firstMatch(line);
          if (m == null) {
            continue;
          }
          final uri = _normalize(path, m.group(1)!);
          for (final bad in _forbidden[layer]!) {
            if (uri.startsWith(bad)) {
              violations.add('$path: ${m.group(1)} (禁止 import $bad)');
            }
          }
        }
      }
    }
    expect(violations, isEmpty, reason: '分层规则被破坏：\n${violations.join('\n')}');
  });
}
