# 决策记录 DEC-008：阶段 1 技术选型拍板（§3.Z 四项裁决点）

- **ID**：DEC-008
- **日期**：2026-10-17（拍板问答轮，question 工具）
- **发起人**：opencode（agent）；**答复人**：Hardstone（开发者）
- **关联**：`TECH-SELECTION-iA-Music.md` §3.Z；`ADR-0001-build-1-tech-selection.md`；`DEC-007`（团队适配输入）

## 1. 裁决结果

| # | 议题 | 开发者选择 | 影响 |
|---|---|---|---|
| ① | R1 Android 下载引擎许可 | **MIT 版**（ffmpegkit-maintained/yt-dlp-android，Chaquopy 嵌 CPython） | 接受「yt-dlp 更新随库发版节奏」；GPL 版（yausername/youtubedl-android）落选，不采用进程隔离等变通 |
| ② | R2 百度网盘通道 | **彻底移除候选**（产品需求层面放弃） | 通道池收缩为 WebDAV/OneDrive/Google Drive/GitHub；冻结基线 7 处修订（见 §2）；百度控制台实测（原工作单 ISS-02/ISS-102）取消 |
| ③ | 音频引擎路线 | **先 PoC 再定**（mpv_audio_kit 0.5.1 为首选试验，Android 真机 PoC 不达标即切双引擎） | 增 TECH-03 行动项：「mpv_audio_kit Android 后台保活+软件 EQ+≥30min 长稳」；双引擎（just_audio+audio_service / media_kit 系）确认为已证实回退线 |
| ④ | 分发与最低版本 | **按默认建议锁定** | Android 8.0+ / Windows 10+ x64 / Ubuntu 22.04+ · Debian 12+；Linux 打包 AppImage + deb；桌面 ffmpeg 分发采用 LGPL 构建（当前 gyan GPL 构建仅探查用） |

## 2. 由②触发的冻结基线修订（DEC-008 决议，同一日执行）

| 文档 | 修订点 |
|---|---|
| `_02_feature_spec/_01_human_prd/overview_prd.md` | v1.2.1→**v1.3.0**；「通道」行通道池去百度；决策日志范围 DEC-001~008 |
| `_02_feature_spec/_01_human_prd/features/sync_prd.md` | v1.0.0→**v1.1.0**；§3.1 授权登录百度行删除；§3.2 重数据通道枚举、REQ-SYNC-01、§5 Empty 通道卡去百度；风险登记 R2 标记裁决关闭；来源注记补 DEC-008 |
| `_02_feature_spec/_02_vibe_spec/sync_vibe_spec.md` | ChannelCardList cards 数组移除 baidu 项（带注释溯源） |
| `_02_feature_spec/_04_prototype_wireframe/main_prototype.md` | §5.9 mermaid 通道卡节点、ASCII 空态线框去百度 |
| `_02_feature_spec/_03_prototype_html/main_prototype.html` | 同步 Empty 态通道数组移除百度项 |
| `_00_project_foundation/_02_dictionary/_02_project_word.dict.yaml` | 「同步通道」术语 desc 去百度（术语仍 19 个，仅释义收敛） |
| `_01_product_vision/_02_phased_roadmap/iA-Music_phased_plan.md` | FEAT-SYNC-01 行去百度（保留原文痕迹式注记） |

- 统计口径不变：REQ 仍 63（REQ-SYNC-01 范围缩窄非删除）、Gherkin 场景/TEST 计数不变、术语 19 不变。
- 历史文档（DEC-001/002/003、PROBE-SHEET R2、PHASE-0-ACCEPTANCE ISS-02、FREEZE-SIGNOFF）按「历史保留原文」原则不改；后续引用以 DEC-008 为准。

## 3. 遗留工作单（真机项，ISS-101 保留）

- R1：Android 嵌入引擎（MIT 版 AAR 集成）真机验证——负责人：开发者（设备）；agent 回填结论。
- R3：SenseVoice arm64 RTF/峰值内存真机计时——负责人：开发者；桌面 RTF 因 Python 3.14 无轮子后置。
- ③：mpv_audio_kit Android PoC（后台/EQ/长稳）——负责人：开发者；不达标回退线已声明（双引擎）。
