/// 架构守卫测试——分层 import 规则的机器强制（v2 宪章第一条；永不被删）。
///
/// 规则（docs/ARCHITECTURE.md）：
/// * ui        → 只准 import state / domain / app(theme) / flutter / riverpod / l10n
/// * state     → 禁 import adapters / data（组合根在 app/）
/// * services  → 禁 import adapters / ui / state / flutter
/// * data      → 禁 import adapters / services / ui / state
/// * adapters  → 禁 import services / data / ui / state（叶子实现，只依赖 domain）
/// * domain    → 禁 import lib 内其它层与 Flutter（纯 Dart）
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _lib = 'lib';

/// 每层 → 禁止的 import 前缀（相对 lib/ 的目录或 package: 名）。
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

void main() {
  test('分层 import 规则', () {
    final violations = <String>[];
    for (final layer in _forbidden.keys) {
      final dir = Directory('$_lib/${layer.split('/')[1]}');
      if (!dir.existsSync()) {
        continue;
      }
      for (final file in dir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) {
          continue;
        }
        final content = file.readAsLinesSync();
        for (final line in content) {
          final m = _importRe.firstMatch(line);
          if (m == null) {
            continue;
          }
          final uri = m.group(1)!;
          for (final bad in _forbidden[layer]!) {
            final hit = uri.startsWith(bad) ||
                (uri.startsWith('package:ia_music/') &&
                    'lib/${uri.substring('package:ia_music/'.length)}'.startsWith(bad));
            if (hit) {
              violations.add('${file.path}: $uri (禁止 import $bad)');
            }
          }
        }
      }
    }
    expect(violations, isEmpty, reason: '分层规则被破坏：\n${violations.join('\n')}');
  });
}
