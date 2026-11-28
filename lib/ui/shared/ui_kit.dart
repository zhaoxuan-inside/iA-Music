/// 共享 UI 组件导出桶：稳定的 re-export 门面。
///
/// 实现已按 UI 分层落位（layout=页面骨架 / components=页面组件 /
/// motion=交互动画基元，见 docs/ARCHITECTURE.md UI 节）；本桶只做
/// re-export——既有引用零改动，新代码建议按层精确 import。
library;

export '../components/kit/format.dart';
export '../components/kit/letter_rail.dart';
export '../components/kit/rows.dart';
export '../components/kit/wp_menu.dart';
export '../components/kit/wp_switch.dart';
export '../components/kit/wp_toast.dart';
export '../layout/empty_state.dart';
export '../layout/hub_scaffold.dart';
export '../layout/route.dart';
