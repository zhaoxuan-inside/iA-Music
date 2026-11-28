/// 音频嵌入向量契约——「哪首歌听起来像这首」的声学画像。
/// 与指纹（识别：这是哪首歌）互补不互替；向量必须绑定模型版本才有意义。
library;

/// 一首曲目的整曲嵌入（帧均值 + L2 归一化后的单向量）。
class AudioEmbedding {
  const AudioEmbedding({
    required this.model,
    required this.dim,
    required this.vector,
  });

  /// 模型标识（yamnet-1024-v1…）——入库时作为 track_vectors.model 落账。
  final String model;
  final int dim;

  /// 已 L2 归一化：相似度 = 点积，无需再算模长。
  final List<double> vector;
}

/// 设备端音频嵌入，两级失败语义（与指纹的「一律 null」不同——嵌入的
/// 单曲失败必须可重试，不能陪葬整个端口）：
/// * 返回 null —— 端口级不可用（原生侧未注册/模型加载失败）：调用方
///   会话级禁用，不消耗重试计数。
/// * 抛错 —— 曲目级失败（解码失败/文件不可读）：调用方按曲目记账重试。
abstract class EmbeddingPort {
  Future<AudioEmbedding?> embed(String path, {required int durationMs});
}
