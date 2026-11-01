/// AsrPort —— 歌词 ASR 契约（R3；sherpa_onnx + SenseVoiceSmall int8，ADR-0001）。
///
/// 约束（DETAILED-DESIGN §3.4/§4.3）：
/// * isolate 内加载与转写（UI isolate 禁入）。
/// * 输入 16k 单声道 wav（转码由调用方负责）。
/// * 取消响应=块边界（C38）。
/// * `segments` 为空 = 纯音乐/无人声（REQ-LYRAI-05）：**不生成空文件**；
///   提交空结果由歌词域抛 `AsrNoVoiceException`。
library;

import 'shared.dart';

/// 转写进度（0..100）。
final class AsrProgress {
  const AsrProgress(this.percent);
  final double percent;
}

abstract class AsrHandle {
  /// 驱动进度流（实现 isolate → 调用方 UI）。
  Stream<AsrProgress> get progress;

  Future<AsrResult> get result;

  /// 协作取消：块边界生效；取消后 result=cancelled（segments 空，isCancelled=true）。
  void requestCancel();
}

final class AsrSegment {
  const AsrSegment({required this.startMs, required this.endMs, required this.text});

  final int startMs;
  final int endMs;
  final String text;
}

final class AsrResult {
  const AsrResult({required this.segments, this.isCancelled = false});

  final List<AsrSegment> segments;
  final bool isCancelled;

  /// 纯音乐判定（segments 空且未取消）。
  bool get isNoVoice => segments.isEmpty && !isCancelled;
}

abstract class AsrPort {
  /// `model_registry.status==present` 且 sha256 已验（§1.2）。
  Future<bool> isReady();

  /// isolate 内加载；校验失败 → `ModelInvalidException`。
  Future<void> prepare(String modelPath);

  /// 转写（wavPath=16k mono wav；token 可空）。
  AsrHandle transcribe(String wavPath, {CancelToken? token});

  /// 全净释放（模型内存/isolate；完全退出时长驻可释放）。
  Future<void> unload();
}
