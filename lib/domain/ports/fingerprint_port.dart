/// 音频指纹端口——真·内容识别（不依赖任何文字线索）。
/// 实现：mpv 解码（任意格式）→ chromaprint FFI 计算指纹。
library;

class AudioFingerprint {
  const AudioFingerprint({required this.fingerprint, required this.durationMs});

  /// 压缩指纹（base64，AcoustID /v2/lookup 直接可用）。
  final String fingerprint;

  /// 音频总时长（毫秒，AcoustID 查询必填）。
  final int durationMs;
}

abstract class FingerprintPort {
  /// 对 [path] 计算 chromaprint 指纹。[durationMs] 为音频总时长（已知时传入，
  /// 用于判定采集完成）。原生库缺失/解码失败 → null（调用方回退文字链）。
  Future<AudioFingerprint?> fingerprint(String path, {required int durationMs});
}
