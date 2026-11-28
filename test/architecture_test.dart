/// 架构守卫测试——分层 import 规则的机器强制（v2 宪章第一条；永不被删）。
///
/// 规则（docs/ARCHITECTURE.md「分层与依赖规则」+「UI 分层」两节）：
/// * ui        → 只准 import state / domain / app(theme) / flutter / riverpod / l10n
/// * ui 内部   → layout/components/kit/motion 禁 state 与页面域；mapped 允许
///               精确 watch 单 provider；actions/routing 跳转收口；域间禁互
///               import（detail/search 双域组合容器豁免）
/// * state     → 禁 import adapters / data / inference（组合根在 app/providers.dart，
///               data 类型经组合根中继 export）
/// * services  → 禁 import adapters / ui / state / flutter
/// * data      → 禁 import adapters / services / ui / state（底层能力域）
/// * inference → 禁 import adapters / services / data / ui / state / plugins
///               （底层能力域：模型推理自包含实现，只依赖 domain）
/// * adapters  → 禁 import services / data / ui / state（叶子实现，只依赖 domain）
/// * plugins   → 禁 import services / data / ui / state（自包含沙箱子系统）
/// * domain    → 禁 import lib 内其它层与 Flutter（纯 Dart）
///
/// 匹配前先把 import URI 归一化为 lib/ 内路径：`package:ia_music/x.dart` 与
/// 相对路径 `../x.dart` 都解析成 `lib/...` 再比对——曾经相对路径
/// 完全绕过本守卫（真实违规全部走相对 import 却一直绿灯）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 页面域目录（UI 组合层，按业务域划分）。
const List<String> _uiPageDomains = [
  'lib/ui/detail/', // 曲库+歌单 双域组合容器（共享页，豁免域间禁令）
  'lib/ui/search/', // 曲库+收集 双域组合容器（共享页，豁免域间禁令）
  'lib/ui/library/',
  'lib/ui/music/',
  'lib/ui/listen/',
  'lib/ui/played/',
  'lib/ui/play/',
  'lib/ui/playing/',
  'lib/ui/playlists/',
  'lib/ui/settings/',
  'lib/ui/onboarding/',
  'lib/ui/collect/',
  'lib/ui/plugins/',
  'lib/ui/enrich/',
];

/// UI 内部分层规则（docs/ARCHITECTURE.md「UI 分层」节）：
/// * layout（页面骨架）/ components/kit（纯展示件）/ motion（动画基元）
///   禁 state 与页面域——底两层物理上拿不到数据；
/// * components/mapped（自带映射复合组件）允许精确 watch 单一 provider，
///   禁页面域；
/// * actions（跨域动作编排）禁页面域——跳转一律走 routing；
/// * routing 是唯一允许 import 页面本体的公共层。
final Map<String, List<String>> _forbidden = _buildForbidden();

Map<String, List<String>> _buildForbidden() {
  final m = <String, List<String>>{
    'lib/ui/': [
      'lib/adapters/',
      'lib/data/',
      'lib/inference/',
      'lib/plugins/',
      'lib/services/',
      'package:drift/',
      'package:sqlite3/',
    ],
    'lib/state/': [
      'lib/adapters/',
      'lib/data/',
      'lib/inference/',
      'package:drift/',
    ],
    'lib/services/': [
      'lib/adapters/',
      'lib/inference/',
      'lib/ui/',
      'lib/state/',
      'package:flutter/',
      'dart:ui',
    ],
    'lib/data/': ['lib/adapters/', 'lib/inference/', 'lib/services/', 'lib/ui/', 'lib/state/'],
    'lib/inference/': [
      'lib/adapters/',
      'lib/data/',
      'lib/plugins/',
      'lib/services/',
      'lib/state/',
      'lib/ui/',
    ],
    'lib/adapters/': ['lib/inference/', 'lib/services/', 'lib/data/', 'lib/ui/', 'lib/state/'],
    'lib/plugins/': ['lib/services/', 'lib/data/', 'lib/ui/', 'lib/state/'],
    'lib/domain/': [
      'lib/adapters/',
      'lib/data/',
      'lib/inference/',
      'lib/services/',
      'lib/state/',
      'lib/ui/',
      'lib/app/',
      'package:flutter/',
      'dart:ui',
    ],
    // UI 基础层：禁 state 与页面域
    'lib/ui/layout/': ['lib/state/', ..._uiPageDomains, 'lib/ui/actions/', 'lib/ui/routing/'],
    'lib/ui/components/kit/': ['lib/state/', ..._uiPageDomains],
    'lib/ui/motion/': ['lib/state/', ..._uiPageDomains],
    // 自带映射复合组件：允许精确 watch 单一 provider，禁页面域
    'lib/ui/components/mapped/': [..._uiPageDomains],
    // 跨域动作编排：禁页面域（跳转走 routing）
    'lib/ui/actions/': [..._uiPageDomains],
  };
  // 域间禁 import：页面域互不认识（共享组合页豁免）——跳转走 routing
  for (final d in _uiPageDomains) {
    if (d == 'lib/ui/detail/' || d == 'lib/ui/search/') {
      continue; // 双域组合容器，组合一切
    }
    m[d] = [
      for (final other in _uiPageDomains)
        if (other != d && other != 'lib/ui/detail/' && other != 'lib/ui/search/')
          other,
    ];
  }
  return m;
}

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
