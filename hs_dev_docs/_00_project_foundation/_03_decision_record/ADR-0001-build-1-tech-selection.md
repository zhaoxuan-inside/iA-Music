# ADR-0001：BUILD 阶段 1 技术选型与实施约束

- **ID**：ADR-0001
- **状态**：Accepted（2026-10-17，开发者在 DEC-007 + DEC-008 拍板确认）
- **关联**：`TECH-SELECTION-iA-Music.md`（§1 约束 C01–C67 / §3 候选矩阵 / §5 实施约束）；`DEC-007-tech-selection-inputs.md`；`DEC-008-tech-selection-decisions.md`；`PHASE-1-ACCEPTANCE-iA-Music.md`

## 1. 决策

本项目采用以下技术基线（置顶执行契约，阶段 2+ 架构/契约以本 ADR 为准）：

| 域 | 选择 |
|---|---|
| 跨端栈 | **Flutter（Dart）**，一套代码三端（Android/Windows/Linux） |
| 音频引擎 | **mpv_audio_kit 0.5.1 首选试验**（三端单引擎；Android 后台+EQ+长稳真机 PoC 待过）；**回退线＝双引擎**（Android: just_audio+audio_service；桌面: media_kit+smtc_windows+audio_service_mpris） |
| R1 提取/下载 | **Android：ffmpegkit-maintained/yt-dlp-android（MIT）**；**桌面：捆绑 yt-dlp 二进制 + LGPL 构建 ffmpeg** + Process spawn；登录态 Cookie 支撑 B 站高音质（匿名实测仅 64k 音轨） |
| R2 同步 | **MVP 激活通道＝WebDAV**（webdav_client_plus）；其余通道池 OneDrive/Google Drive（可选实现）+ GitHub（轻数据）；**百度网盘彻底移除**（DEC-008） |
| R3 ASR | **sherpa_onnx Dart 1.13.8+ + SenseVoiceSmall int8（2024-07-17 模型）**，经 hf-mirror 镜像下载 + sha256 校验；isolate+分块承载暂停/取消 |
| 存储检索 | **drift + sqlite3（bundled，FTS5）+ drift_flutter**；拼音检索以 FTS5 辅助列实现；audio_metadata_reader 读元数据/封面 |
| 封面在线源 | **MusicBrainz CAA 主源 → iTunes Search 兜底**；只补缺不覆盖 |
| 分发 | AAB + per-ABI splits（Android 8.0+）；Windows 10+ x64；**Ubuntu 22.04+/Debian 12+，AppImage+deb**；依赖全开源免费（必要付费先请示） |

## 2. 理由（摘要）

- 团队适配基准 Flutter（DEC-007 D7-1），候选矩阵中其余栈未显示显著更优（TECH-SELECTION §3.A）；
- 音频单引擎可满足 EQ/媒体会话三端需求，因包较新（2026-03 首版）按开发者裁决 ③ 先 PoC；
- R1 许可优先：MIT 干净适配项目 MIT 许可与未来开源；yt-dlp 引擎行为已桌面实测（EXP-001）；
- 百度通道与「开源免费 + 自有服务端零」以及 2026 目录限制叠加不符合 MVP（开发者裁决 ② 移除）；
- SenseVoice 离线中文 RTF 证据充分（最差 0.436@A55 单线程）且模型镜像通路已实测（EXP-002）；
- drift+sqlite3 bundled 满足 FTS5/迁移/bundled 三端；sqlite3_flutter_libs 已 EOL 故弃用。

## 3. 后果与风险

- 真机未知项（R1 Android 嵌入 / R3 arm64 RTF / 音频 PoC）按工作单保留，负责人=开发者，结论回填后复核本 ADR（不改基线结论则仅补证据）；
- mpv_audio_kit PoC 不达标→切换双引擎，桌面 EQ 缺口将以「软件 EQ 自实现 or 显式不支持提示」在阶段 2 处理；
- ffmpeg LGPL 构建分发时履行「许可文本+源码链接」义务（TECH-04）；
- 落选方案（KMP/Tauri/MAUI/Qt、media_kit 单引擎、百度通道、whisper 系）不得混入执行契约。
