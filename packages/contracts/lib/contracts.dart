/// iA-Music 契约包（S0 / DETAILED-DESIGN §2.1）
///
/// 七 Port + DTO + 异常枚举 —— 实现方（adapter）与调用方（模块域）唯一契约来源。
/// 本包为纯 Dart 包（无 flutter 依赖），analyzer 编译校验即工具验证（ISS-301 口径）。
library;

export 'src/asr.dart';
export 'src/cover.dart';
export 'src/engine.dart';
export 'src/exceptions.dart';
export 'src/extract.dart';
export 'src/lyrics.dart';
export 'src/metadata.dart';
export 'src/search.dart';
export 'src/secure_store.dart';
export 'src/shared.dart';
export 'src/sync.dart';
