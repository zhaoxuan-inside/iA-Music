/// 应用版本信息（与 pubspec.yaml 的 version 同步；用于设置页自证安装包）。
library;

const String kAppVersionName = '3.0.0';
const int kAppVersionCode = 14;
const String kAppEdition = 'Zune Environment';

String get kAppVersionLabel => 'v$kAppVersionName ($kAppVersionCode) · $kAppEdition';
