# 入库二进制来源档案

宪章要求：原生二进制/模型资产入库必须在 PR 说明里给出理由与 SHA-256；
本档案作为持久记录，发版核对以此为准。

## YAMNet 嵌入模型（不随 APK 分发，在线下载）

- **SHA-256 锚**: `141fba1cdaae842c816f28edc4937e8b4f0af4c8df21862ccc6b52dc567993c3`
  （常量 `kEmbeddingModelSha256`，lib/app/config/embedding_config.dart——
  下载后逐字节校验，不符判伪源拒收）
- **字节数**: 16,096,668（常量 `kEmbeddingModelBytes`，长度守卫先行判废）
- **来源**: TensorFlow Hub `google/lite-model/yamnet/tflite/1`（Apache-2.0），
  经 HF 镜像仓库 `thelou1s/yamnet@f321d85`（TF-Hub 工件原样镜像）取得。
- **分发方式**: **不打包进 APK**（曾打包 16MB，后改为在线下载，APK 减重 16MB）。
  首次进入向量轮时由 data 层 `ModelStore`（lib/data/models/model_store.dart）
  按配置 URL 下载到应用沙箱 `models/yamnet-1024-v1.tflite`，sha256 校验通过
  后登记 model_files 表；文件丢失自动重下（自愈）。下载源可用 settings KV
  `models.yamnet.url` 覆盖为自建直链（插件市场同款惯例）。
- **签名**: 输入 `waveform` [1,15600] float32（0.975s @16kHz 单声道）；
  输出 `Identity`×3（scores[521] / embeddings[1024] / log_mel）——
  K 原生侧按 shape 末维选 1024 的 embedding 输出，不依赖固定序号。
- **用途**: 音频嵌入向量（声音相似电台）。MediaPipe 发行版的 YAMNet 裁掉了
  embedding 输出，此工件是保留完整签名的官方 lite 转换版。
