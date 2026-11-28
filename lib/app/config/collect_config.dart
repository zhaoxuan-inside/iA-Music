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

/// ── 子曲目 pin 约定（宿主专用，插件永远收到无片段的干净 URL） ──────────
///
/// URL 片段 `#ia-track=N`：多子曲目任务只提取第 N 条（1-based）。唯一写入点
/// 在这里——collect_service 的拆分与 state 层的勾选入队共用同一构造/解析。

/// 给干净 URL 追加第 [n] 条（1-based）子曲目 pin 片段。
String trackPinUrl(String baseUrl, int n) => '$baseUrl#ia-track=$n';

/// 解析 URL 片段 `#ia-track=N` → N（1-based；没有则 null）。
int? trackPinOf(String url) {
  final m = RegExp(r'#ia-track=(\d+)').firstMatch(url);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// 剥掉 pin 片段（以及任何其它片段）后的干净 URL。
String trackBaseUrl(String url) => url.split('#').first;

