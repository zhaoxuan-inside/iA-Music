/// 共享 UI 组件导出桶：21 处引用零改动的稳定门面。
///
/// 实现按职责拆在同目录（route/hub_scaffold/rows/letter_rail/wp_menu/
/// wp_toast/empty_state/wp_switch/format）；新代码可按需精确 import，
/// 既有代码继续走本桶。
library;

export 'empty_state.dart';
export 'format.dart';
export 'hub_scaffold.dart';
export 'letter_rail.dart';
export 'route.dart';
export 'rows.dart';
export 'wp_menu.dart';
export 'wp_switch.dart';
export 'wp_toast.dart';
