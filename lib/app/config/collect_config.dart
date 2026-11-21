/// 收集域配置：平台 API 端点 / 客户端语境 / 预置目录 / 命名规则。
///
/// 三分离：端点与常量只活在本文件；服务层按需引用，禁止在业务代码里散落 URL。
/// 这里只有配置，没有任何预置内容数据。
library;

/// Android 预置候选目录（存在才可选；真实扫描入库走 ScanService）。
const List<String> kPresetMusicDirs = [
  '/storage/emulated/0/Music',
  '/storage/emulated/0/Download',
];

/// 目录浏览器起点（Android 共享存储根）。
const String kDirectoryBrowserRoot = '/storage/emulated/0';

/// 下载文件命名：'{artist} - {title}.{ext}'（artist 为空时 '{title}.{ext}'）。
const String kDownloadNamePattern = '@artist - @title';

