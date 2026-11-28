/// 应用信息（展示于「设置 · 关于」）。
///
/// 版本不再手写同步：曾在这里维护 kAppVersionName/kAppVersionCode，与
/// pubspec 的 version 双头更新，v0.0.5 起连续 13 个发版只动了 pubspec，
/// 关于页长期显示着 v0.0.4。现改为运行时读安装包元数据（package_info_plus，
/// 即 pubspec version 的构建产物 versionName/versionCode），pubspec 是
/// 唯一事实源，发版只改一处。
library;

const String kAppName = 'iA-Music';

const String kAppTagline = '让散落的歌，被看见、被听见';

/// 目标平台。
const String kAppPlatform = 'Android（arm64）';
