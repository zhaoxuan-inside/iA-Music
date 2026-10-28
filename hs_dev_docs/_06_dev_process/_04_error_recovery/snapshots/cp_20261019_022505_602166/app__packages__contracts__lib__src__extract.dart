/// DownloaderPort —— 提取下载契约（R1）。
///
/// 双态实现：
/// * 桌面：`Process`（yt-dlp + LGPL ffmpeg 捆绑，DEC-008 ④）
/// * Android：MIT 版 yt-dlp-android AAR（RV-B 前置验证）
///
/// 纪律（EXP-001）：`--print` 隐含 simulate —— resolve 路径必须加 `--no-simulate` 类
/// 补偿参数或改走独立输出通道；实现方负责该纪律，调用方无感知。
///
/// 重试上限（DETAILED-DESIGN §4.3）：网络级指数退避 ≤3 次/任务；`auth` 不自动重试；
/// 取消=进程 kill+分片清理，无半成品遗留。
library;


/// 音质枚举（§5.2 唯一事实源；匿名可用域依登录态划定——EXP-001：匿名仅 64k 实测）。
enum Quality { k64, k128, k192, hires }

/// 失败码（§4.2 任务机结局；UI 文案由调用方 map）。
enum DownloadError { network, auth, disk, transcode, duplicate }

/// `resolve(url)` 的产物（≤5s 承诺，REQ-EXT-01）。
final class ResolvedMeta {
  const ResolvedMeta({
    required this.sourceType,
    required this.sourceId,
    required this.url,
    required this.title,
    required this.uploader,
    required this.durationMs,
    required this.qualities,
    this.coverUrl,
  });

  /// 目前恒为 `bilibili`（通道收敛后预留）。
  final String sourceType;
  final String sourceId;
  final String url;
  final String title;
  final String uploader;
  final int durationMs;

  /// 登录态可用的音质（含 `quality` 说明）。
  final List<Quality> qualities;

  /// 解析卡封面地址（S6 契约增量：解析结果展示封面，REQ-EXT-01）。
  final String? coverUrl;
}

/// 下载计划（cookies 只传 SecureStore 键引用，**不传值**——C50）。
final class DownloadPlan {
  const DownloadPlan({
    required this.sourceId,
    required this.url,
    required this.quality,
    required this.outputDir,
    this.cookiesRefKey,
  });

  final String sourceId;
  final String url;
  final Quality quality;

  /// 应用私有目录（产物先落私有，注册入库由调用方事务负责，§3.2 不变量）。
  final String outputDir;

  /// SecureStore key（登录高音质时必填；实现读取后不得留存/落日志）。
  final String? cookiesRefKey;
}

/// 任务句柄（同一 plan 重复提交 → `DuplicateSourceException` 由实现判断或调用方预检）。
final class TaskHandle {
  const TaskHandle(this.id);
  final int id;
}

sealed class TaskEvent {
  const TaskEvent();
}

final class TaskProgress extends TaskEvent {
  const TaskProgress(this.percent, {this.speedBps});
  /// 0..100
  final double percent;
  final int? speedBps;
}

/// 下载产物就绪（转码前）。
final class TaskStaged extends TaskEvent {
  const TaskStaged(this.filePath);
  final String filePath;
}

final class TaskPaused extends TaskEvent {
  const TaskPaused(this.reason);
  final String reason;
}

final class TaskResumed extends TaskEvent {
  const TaskResumed();
}

final class TaskFailed extends TaskEvent {
  const TaskFailed(this.code, {this.detail});
  final DownloadError code;
  final String? detail;
}

abstract class DownloaderPort {
  /// 解析分享文本中的链接（调用方负责拆分多行多链接；REQ-EXT-01 ≤5s）。
  Future<ResolvedMeta> resolve(String sharedUrl);

  /// 启动下载；事件经 [stream]（含 progress|staged|paused|resumed|failed）。
  TaskHandle download(DownloadPlan plan);

  /// 事件流（所有活动任务共用；事件携 [TaskHandle] 语境由调用方绑定任务行）。
  Stream<TaskEvent> get stream;

  Future<void> pause(TaskHandle handle);

  /// 恢复=断点续传（分片级）。
  Future<void> resume(TaskHandle handle);

  /// 取消（进程 kill + 分片清理；终态 FAILED(network|…) 由调用方记录）。
  Future<void> cancel(TaskHandle handle);
}
