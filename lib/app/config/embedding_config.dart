/// 音频嵌入向量配置（模型工件来源与哈希锚见 native/PROVENANCE.md）。
///
/// 模型文件管理归 data 层（ModelStore：在线下载/校验/落盘/登记），
/// inference 模块只负责推理——本文件是两侧共用的唯一事实源。
library;

/// 嵌入模型标识——track_vectors.model 落账值 + model_files 登记主键；
/// 换模型只改这里，旧向量按本列过滤出池重算，模型文件按本 id 落盘。
const String kEmbeddingModel = 'yamnet-1024-v1';

/// 嵌入维度（YAMNet penultimate 层）。
const int kEmbeddingDim = 1024;

/// 单曲解码/推理时长上限（秒）——最坏情况耗时封顶；均值画像取前段
/// 足够稳定，与指纹链的 110s 截断同思路。
const int kEmbeddingMaxSeconds = 120;

/// 模型下载源（TF-Hub 官方 lite 转换版的镜像直链；可被 settings KV
/// [kEmbeddingModelUrlKey] 覆盖为自建源——插件市场同款惯例）。
const String kEmbeddingModelUrl =
    'https://hf-mirror.com/thelou1s/yamnet/resolve/main/lite-model_yamnet_tflite_1.tflite';

/// 下载源覆盖键（settings KV；空串/缺省 = 用 [kEmbeddingModelUrl]）。
const String kEmbeddingModelUrlKey = 'models.yamnet.url';

/// 内容完整性锚——下载后逐字节 sha256 校验，不符判伪源拒收
/// （native/PROVENANCE.md 同源记录）。
const String kEmbeddingModelSha256 =
    '141fba1cdaae842c816f28edc4937e8b4f0af4c8df21862ccc6b52dc567993c3';

/// 预期字节数——长度不符直接判废（不等哈希算完）。
const int kEmbeddingModelBytes = 16096668;
