/// 应用信息（与 pubspec.yaml 的 version 同步；展示于「设置 · 关于」）。
library;

const String kAppName = 'iA-Music';

const String kAppTagline = '本地优先的个人音乐库——把散落的音乐收进来、看得清、听得好';

/// 版本名（语义版本）。
const String kAppVersionName = '0.0.4';

/// 版本号（安装计数，对应 pubspec 的 version: x.y.z+n）。
const int kAppVersionCode = 17;

/// 目标平台。
const String kAppPlatform = 'Android（arm64）';

String get kAppVersionLabel => 'v$kAppVersionName ($kAppVersionCode)';
