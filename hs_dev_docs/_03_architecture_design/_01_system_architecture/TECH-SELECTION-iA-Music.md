# iA-Music 技术选型说明（BUILD 阶段 1）

- **状态**：DRAFT — §1 约束 C01–C67；§3 候选矩阵 A–H（草案）；§5 实施约束已锁定（DEC-008）；拍板记录见 §6
- **输入基线**：阶段 0 冻结包（`PHASE-0-FREEZE-SIGNOFF-iA-Music.md`，2026-10-17 ACCEPTED）；R1–R3 探查工作单（桌面调研版；真机结论后置回填并复核本选型）
- **关联**：`PLAN-iA-Music-BUILD-1.md`；`PHASE-1-ACCEPTANCE-iA-Music.md`；`DEC-001..006`
- **更新时间**：2026-10-17
- 本清单由全库扫描生成（2026-10-17，子代理全量盘查）；基线当前**没有任何产品技术栈承诺**（除 LICENSE=MIT），一切技术候选从零比较。

## 0. 来源图例与基线状态注记

| 标签 | 路径 | 版本 |
|---|---|---|
| ROADMAP | `hs_dev_docs/_01_product_vision/_02_phased_roadmap/iA-Music_phased_plan.md` | FROZEN 2026-10-16 |
| OVERVIEW | `hs_dev_docs/_02_feature_spec/_01_human_prd/overview_prd.md` | v1.3.0（v1.2.1 + DEC-008 通道池修订） |
| PRD-ONB/NAV/LIB/PL/PLAY/LYR/LYRAI/EXT/SYNC | `hs_dev_docs/_02_feature_spec/_01_human_prd/features/*_prd.md` | v1.0.0–v1.2.1；SYNC=v1.1.0（DEC-008） |
| VIBE-*（9） | `hs_dev_docs/_02_feature_spec/_02_vibe_spec/*_vibe_spec.md` | 冻结 2026-10-17 |
| WIRE | `hs_dev_docs/_02_feature_spec/_04_prototype_wireframe/main_prototype.md` | v1.2 |
| DEC-00x | `hs_dev_docs/_06_dev_process/_03_qa_log/DEC-00x-*.md` | 2026-10-16/17 |
| DESIGN | 项目根 `DESIGN.md` | alpha |
| DICT | `hs_dev_docs/_00_project_foundation/_02_dictionary/_02_project_word.dict.yaml` | — |
| PROBE | `hs_dev_docs/_06_dev_process/PHASE-0-PROBE-SHEET-R1-R3-iA-Music.md` | 2026-10-17 |
| GOVERN | `config/governance.yaml` | v1.0 |
| LICENSE | 项目根 `LICENSE` | MIT © 2026 zhaoxuan |

注记：
- 仓库当前仅 1 个 commit（Initial commit），基线文档尚未纳入版本控制（`DESIGN.md`、`config/`、`mock/`、`hs_dev_docs/` 为 untracked）；建议开发者适时提交基线快照（agent 不代提交）。
- `android/`、`windows/`、`linux/`、`frontend/`、`apps/`、`backend/`、`packages/`、`scripts/`、`output/*`、`test/_0x` 均为**空脚手架目录**；其中与「无自有服务端、无 Web 端」基线无对应者，不构成技术需求；目录布局留待阶段 4 任务编排裁决。本清单不以其为依据。

## 1. 约束清单（TECH-01）

> 编号 C01–C67 供后续 ADR/验收交叉引用。`【待回填】`= R1–R3 真机结论出后复核。候选能力映射见 §3。

### 1.1 平台与运行环境

| # | 约束 | 来源 |
|---|---|---|
| C01 | MVP 三端（Android 64 位 / Windows / Linux）均可安装，以同一套代码运行同一曲库数据；iOS/macOS/32 位 Android 为非目标 | ROADMAP §1/§4.3；DEC-001 O2#5/#6 |
| C02 | 三端一套代码、一套技术栈、一个设计语言 | DEC-001 O2#5 |
| C03 | Linux 打包保留在 MVP；S0 需 Android/Windows 打包冒烟，S6 交付三端发布物 | ROADMAP §2/§4.1/§4.2 |
| C04 | 无管理后台、无自有服务端；设置页为用户功能（仓库管理/同步/歌词模型管理） | ROADMAP §2；OVERVIEW §5 |
| C05 | 最低 OS 版本基线未定（仅候选库内部出现 Android 7.0+ 提示）；需由 TECH-01/04 锁定 | PROBE R1；§2 留白 |
| C06 | R1/R3 复核需 Android 真机（解析成功/下载稳定/后台任务/APK 体积/RTF/峰值内存）；R2 百度控制台项已随 DEC-008 移除通道而取消 | PROBE；DEC-008 |
| C07 | 探查机环境快照（2026-10-17）：yt-dlp=未装、ffmpeg=未装、Python 3.14.5rc1、onnxruntime 1.30.0（已装） | PROBE |

### 1.2 音频播放能力

| # | 约束 | 来源 |
|---|---|---|
| C08 | 格式优先 MP3/FLAC/AAC/M4A/WAV/OGG；不支持格式 → 行内「格式不支持」（灰显，可尝试仍播放） | PRD-PLAY v1.2.1 §3.3 |
| C09 | Android 通知栏控制可用；桌面媒体键可用（后台/锁屏播放） | PRD-PLAY §3.1；REQ-PLAY-05 |
| C10 | EQ 5 段 60Hz/230Hz/910Hz/3.6kHz/14kHz、±12dB、预设 默认/流行/摇滚/古典/爵士/低音增强/自定义；设备不支持时必须显式提示「当前设备不支持音效调节」（禁静默失败） | PRD-PLAY §3.2；REQ-PLAY-07 |
| C11 | 倍速 0.5×–2×（默认 1×）；模式 ORDER/LIST_LOOP/SINGLE_LOOP/SHUFFLE（默认 LIST_LOOP）；随机池=全库−少播名单、单轮不重复、<10 首回退全库 | PRD-PLAY §3.1；VIBE-PLAY/NAV |
| C12 | 队列查看/选择/清空 + 「下一首播放」插入 | PRD-PLAY §3.3；REQ-PLAY-06 |
| C13 | 缺文件/解码失败：跳过 + 顶部 toast + 自动下一首 | REQ-PLAY-08；VIBE-PLAY |
| C14 | 无缝/淡入淡出为 Phase 2（不在 MVP） | ROADMAP §3/§5 |

### 1.3 数据与存储

| # | 约束 | 来源 |
|---|---|---|
| C15 | 物理 DB 设计（表/字段/迁移）在阶段 3 由开发者决策确认 | FREEZE §A |
| C16 | 19 术语为命名单一事实源（track/library/playlist/like/tombstone/conflict_copy/repo_relative_path/missing_file/less_play_list/lyrics_asset/lyrics_generation/shuffle_wheel/sync_channel/equalizer 等） | DICT |
| C17 | 播放历史留最新 500 条、按曲去重保留最近、播放计数 +1、一键清空 | PRD-PL §3；REQ-PL-05 |
| C18 | 歌单有序、同曲不可重复（行内提示）、名称 1–40 字、封面=前 4 首拼贴 | PRD-PL §3；VIBE-PL |
| C19 | 删除=仅解除入库记录、不物理删音频；同步删除仅传播墓碑，云端音频不自动物理删除 | OVERVIEW §5；REQ-LIB-07/REQ-SYNC-05 |
| C20 | 仓库路径须存在可读、不可重复、不可嵌套；自动扫描默认开；1 万首排序不卡顿 | PRD-LIB §3.1；REQ-LIB-01/02/06 |
| C21 | 元数据优先级：内嵌标签 > 文件名解析（「歌手 - 歌名」）> 在线补缺；编辑只改记录、不改文件 | PRD-LIB §2/§3.2；REQ-LIB-03 |
| C22 | 封面链：内嵌 > 同名图片 > 在线抓取（REQ-LIB-08）> 字母块；存 `<文件名>.cover.jpg` 于音频同目录；只补缺不覆盖；默认开；离线/无匹配静默降级，失败不阻塞扫描/播放 | PRD-LIB §3.2/§3.3；DEC-004 D4-3..6 |
| C23 | 歌词链：同目录 `.lrc` > 内嵌 USLT/LYRICS > 手动粘贴；标准 `[mm:ss.xx]` 多标签；翻译双行约定；偏移 −10~+10s 步进 0.5s；保存为同目录 .lrc、不回写音频；损坏降级纯文本视图 | PRD-LYR §3；REQ-LYR-01..04 |
| C24 | ASR 输出 LRC（行级时间戳）保存为同目录 .lrc；覆盖需确认；取消不产生半成品 | PRD-LYRAI §3；REQ-LYRAI-04 |
| C25 | 同步对象分层：轻数据（曲目记录/歌单/红心/历史/歌词文件/仓库相对路径索引）→ 全通道含 GitHub；重数据（音频本体）→ 仅文件型云盘；音频按内容哈希去重，跨端按相对路径+哈希匹配 | PRD-SYNC §3.2；DEC-002 Q4；DEC-003 ② |
| C26 | 冲突：记录级 updated_at 后写胜；败者保留为「冲突副本」可查看/可删；歌单合并=集合并集、删除按墓碑时间比较 | PRD-SYNC §3.3；VIBE-SYNC |
| C27 | 提取保存默认 `仓库/提取/`（可配）；文件名 `歌手 - 歌名.ext` 清洗（「」【】、合集前缀、非法字符）；标题=净化后视频标题、歌手=UP 主；任务历史可清 | PRD-EXT §3；VIBE-EXT |
| C28 | 扫描计数/ASR 进度必须真实（禁假骨架）；缺文件行 40% 透明度 + 「定位文件」 | VIBE-LIB/LYRAI；WIRE §5.5 |
| C29 | 本地搜索索引损坏可重建，不影响曲库/红心 | PRD-NAV §5；VIBE-NAV |
| C30 | 设置本地持久化（主题/语言等）；新设备提供「从同步恢复」捷径 | DEC-005；REQ-ONB-06/07/08 |

### 1.4 性能与质量

| # | 约束 | 来源 |
|---|---|---|
| C31 | 播放启动点击到出声 ≤300ms（普通设备） | OVERVIEW §6；REQ-PLAY-01 |
| C32 | 1 万首首扫 ≤2 分钟（SSD 参考）；增量重扫 ≤15s | OVERVIEW §6；REQ-LIB-02 |
| C33 | 1 万首搜索输入到结果 ≤300ms（本地索引） | PRD-NAV §3；REQ-NAV-04 |
| C34 | 歌词生成：中端桌面 4 分钟歌 ≤2 分钟；Android 目标 ≤2× 时长；超时需在队列标注 | OVERVIEW §6；REQ-LYRAI-02 |
| C35 | 链接解析 ≤5s 出结果卡 | REQ-EXT-01 |
| C36 | 同步：单文件 ≥100MB 断点续传；逐文件重试；变更防抖 30s 自动同步 | OVERVIEW §6；PRD-SYNC §2；REQ-SYNC-07 |
| C37 | 切歌/扫描/同步零崩溃（自用基线）；UI 与音频状态绝不可背离 | OVERVIEW §6；VIBE-PLAY |
| C38 | ASR 并发=1 串行、可暂停/取消；移动端仅前台亮屏或前台服务；桌面可后台 | PRD-LYRAI §3；VIBE-LYRAI |
| C39 | 下载串行队列、离页继续（前台服务/后台任务）、可取消、逐任务重试 | PRD-EXT §3；REQ-EXT-04 |
| C40 | 候选下载引擎 APK 增量 +50–80MB；建议 AAB + ABI 拆分 | PROBE R1 |
| C41 | 无障碍：触达 ≥44px、正文对比 ≥4.5:1、桌面键盘可达、尊重 reduced-motion 与安全区 | OVERVIEW §6；DESIGN |
| C42 | 轮盘动效契约：`transform .55s cubic-bezier(.32,.72,.28,1)`、横条 240↔174 平滑；静态卡不得模糊/缩放/透明度弱化 | DEC-006 D6-7；WIRE §5.11 |

### 1.5 网络与外部服务

| # | 约束 | 来源 |
|---|---|---|
| C43 | 网络出口仅限清单内：封面抓取、提取解析/下载、同步上传下载、ASR 模型下载、B 站扫码登录（Cookie）、云盘 OAuth；无自有服务端、无在线推荐 | OVERVIEW §1.2/§5 |
| C44 | 同步通道：WebDAV（最稳推荐）/OneDrive/Google Drive/GitHub（**百度网盘已移除，DEC-008**）；MVP 恰 1 个激活（可切换）；多通道=Phase 2 | PRD-SYNC §3.1/§3.3（v1.1.0）；REQ-SYNC-01 |
| C45 | GitHub 通道仅轻数据；音频开关强制 false 且 UI 禁用；Release 附件为「不推荐」选项 | DEC-003 ②；REQ-SYNC-08 |
| C46 | ~~百度官方限制【待回填】~~ **已随 DEC-008 移除通道而不适用**（历史调研保留：OAuth scope=basic,netdisk；`/apps/{appname}` 单目录限制等 | PROBE R2；DEC-008 |
| C47 | 提取=引擎能力制：「内嵌成熟下载引擎，覆盖其全部站点；B 站含登录态为重点保证」；其他站点未点名 | DEC-002 Q5；PRD-EXT §3 |
| C48 | 离线语义：ASR 模型下载后可离线；提取断网暂停可续；同步暂停本地数据不动；封面静默降级 | REQ-LYRAI-06；VIBE-EXT/SYNC/LIB |
| C49 | 同步双向；首次全量同步选主设备或合并（默认「合并，远程缺失项补到本地」）；远端目录默认 `iA-Music/` | PRD-SYNC §3.1/§3.3；REQ-SYNC-02 |

### 1.6 隐私与安全

| # | 约束 | 来源 |
|---|---|---|
| C50 | 无遥测、无自有服务端；数据本机留存直至用户配置同步；凭据（B 站 Cookie、云盘 Token）加密于本机安全存储 | OVERVIEW §5；FREEZE §A |
| C51 | ASR 严格纯本地：禁止上传用户音频到任何服务器 | VIBE-LYRAI；PRD-LYRAI §2 |
| C52 | 任何下载前须合规声明门禁；提取仅面向用户可合法访问内容；禁 DRM/付费墙/会员权限绕过 | REQ-ONB-03/REQ-EXT-07；VIBE-EXT |
| C53 | 凭据禁止明文落盘或上传 | VIBE-SYNC |
| C54 | 治理开关：version_control/env_and_secrets/supply_chain_security/security_privacy/agent_guardrails=on；cicd_and_artifacts/observability_telemetry/data_resilience_dr=off | GOVERN v1.0 |

### 1.7 许可与预算

| # | 约束 | 来源 |
|---|---|---|
| C55 | 单人开发；宽时间箱 3–4 月、可按阶段翻倍；熔断=砍特性不延期 | DEC-002 Q2；ROADMAP §1 |
| C56 | 仓库许可 MIT | LICENSE |
| C57 | 无付费与账号体系；数据归属=本机用户；同步通道以零成本为约束 | FREEZE §A；PRD-SYNC §2 |
| C58 | 「按『未来可能开源』标准执行（通用引导、合规姿态、完整错误文案），按单人维护成本控制」 | DEC-003 Q5 |
| C59 | 已出现潜在付费点：curl-cffi 指纹模拟 Pro（$24，仅候选 b 探查提及，未采用）；基线无依赖预算条目 | PROBE R1 |
| C60 | 分发渠道：**已锁定**（Android AAB+splits / Win10+ / Ubuntu22.04+·Debian12+，AppImage+deb，§5）；「公开发布」受 MIT 许可约束 | ROADMAP S6；DEC-008 |
| C61 | 对标边界：「对标来源（已改编，非克隆）」；禁复制豆瓣 FM 标识/专有插画/像素级布局——但 DEC-006 D6-7 又要求对开发者提供参考截图做像素级复刻；实现期设合规复核点 | DESIGN Do's/Don'ts；DEC-006 D6-7 |

### 1.8 UI 与 i18n

| # | 约束 | 来源 |
|---|---|---|
| C62 | 主题 暗（默认）/亮/跟随系统，即时生效、本地持久化；胶片帧与封面模糊底在亮主题仍为暗实体 | DEC-005；DESIGN |
| C63 | 语言 中文（默认）/英文/跟随系统；应用名与曲目自有数据不翻译；歌词生成输出语言=UI 语言 | DEC-005；DEC-006 |
| C64 | 完整 token 体系：暗底 #0A0B0D、accent #4BE0A3、heart #FF5C7A；系统字体栈 ≤2 族；全 tabular-nums；间距 4/8/12/16/24/32；首屏 accent ≤3 处；禁跨主题硬编码颜色 | DESIGN；WIRE §2 |
| C65 | 移动基线 390px；桌面窗口 ≥1024px（原型桌面基线 1280×800，内容最大 1080/1200）；仅两种形态，无响应式 Web | DESIGN；WIRE §5 |
| C66 | 11 页全需四态（空/加载/填充/异常）；禁假数据/假证言/未兑现「AI 智能推荐」文案 | DESIGN；FREEZE §B；WIRE §7 |
| C67 | 轮盘页契约：5 槽位、仅上滑切歌（禁下滑/点击）、播完自动上转、左缘出血、分层仅渐进旋转+z 序、亮主题专属控件配色 | DEC-006 D6-7；WIRE §5.11 |

## 2. 基线留白（阶段 1 需裁决）

1. 跨端技术栈（语言/框架/UI 工具包）——目标三端一套代码，基线未点名任何候选
2. 各端音频引擎（含桌面方案；MediaSession/前台服务实现）
3. R1 下载引擎嵌入路径（yt-dlp 封装 vs NewPipe Extractor vs B 站原生 API；更新维护、APK 体积、登录态）
4. ~~R2 百度适配~~ **已裁决：移除通道（DEC-008 ②），控制台实测取消**
5. R3 ASR 引擎与模型（sherpa-onnx vs whisper.cpp；模型族/尺寸；arm64 RTF/峰值内存实测；模型下载镜像策略）
6. 存储引擎与 schema（物理设计阶段 3 决策，但选型需锁定 DB/检索技术）
7. 封面在线源提供商（基线仅规定「按歌手/专辑/歌名匹配」，未点名 API）
8. 最低 OS 版本/兼容矩阵（Android API、Windows 版本、Linux 发行版与包格式）
9. 分发与打包（商店 vs 侧载、AAB/splits、安装器、签名）
10. 依赖许可与费用政策（$24 级付费点、商业编解码许可）
11. B 站登录实现（应用内扫码；Cookie 加密机制细化）
12. 轻数据同步序列化格式（JSON/文件布局/版本化）与冲突时钟偏差策略
13. 断点续播（曲内位置持久化）——基线未规定；若需要回产品补充
14. 蓝牙/音频焦点/hi-res/位完美/启动时延/内存/能耗预算——基线未设数值（R3 仅要求峰值内存测量）
15. 随机算法细节、搜索索引实现（仅锁定语义与时延预算）

## 3. 候选能力映射（TECH-02）— 草案完成（2026-10-17）

> 证据基准日 2026-10-17（网络调研，来源随文注）；团队适配基准＝Flutter/Dart（DEC-007 D7-1）。「结论」为候选倾向；**四项裁决点已于当日经 DEC-008 拍板落定**（见各表注记与 §6）。

### 3.A 跨端应用栈

| 候选 | 三端成熟度 | 媒体/原生嵌入 | 打包/体积 | 许可 | 关键代价 | 结论 |
|---|---|---|---|---|---|---|
| **Flutter 3.47** | Win/Linux 官方 Supported 层（CI 实测）；Android API 24–37（flutter.dev/reference/supported-platforms，2026-09-22） | 插件 MethodChannel + FFI hooks；现成音频栈（EQ/媒体键/通知） | AAB/splits；Linux snap/deb/flatpak | BSD-3（依赖 MIT/BSD） | Impeller 桌面回归（#169423/#180831 未关）；桌面插件缝隙 | **首选** |
| KMP+CMP 1.12.2 | CMP Desktop production-ready；仅 64 位（JetBrains 文档） | Android 原生 Kotlin 零桥接（yt-dlp/ASR 直接依赖） | jpackage+Conveyor；JVM 随包 | Apache-2.0；桌面绑 VLC 涉 GPL-3.0 | 桌面无官方音频层（vlcj GPL / 早期 mediamp）；生态较小 | 备选（Android 嵌入优势） |
| Tauri 2.12 | Android 稳定但 Webview API 有缺口 | **Android sidecar 官方不支持**（tauri#9774）；MediaSession 缺 → 只能自写 Kotlin 插件 | AppImage/deb/rpm；需 WebView2 | MIT/Apache-2.0 | 后台音频/原生嵌入均需大量自研 | 否决为首选 |
| .NET MAUI | Linux 仅 Avalonia Preview 1（2026-03-16）未 GA | 绑定库可行 | Linux 不可交付 | MIT | Linux 未 GA | 否决 |
| Qt 6.12 | 三端官方 | JNI/C++ 直接嵌入 | CMake/androiddeployqt | LGPL-3.0/GPL/商业 | OSS 无 LTS 补丁、约半年强制升级；合规义务 | 技术可行，成本最高 |

团队适配与迁移/退出成本：开发者 Flutter 熟练（DEC-007）为最高权重；其余候选须「显著更优」才可反转（当前证据不支持）。若极端情况切换，Dart 侧状态/模型层可保留、UI 层重写为大头（已知代价）。

### 3.B 音频引擎（Flutter）

| 候选 | EQ 5 段（C10） | 后台/通知（C09） | 桌面媒体键（C09） | gapless（Phase 2） | 维护/许可 | 结论 |
|---|---|---|---|---|---|---|
| **mpv_audio_kit 0.5.1（单引擎三端）** | 软件 EQ（设备无关，可达标） | 内建媒体会话 | 内建 SMTC/MPRIS | setGapless+prefetch | 新包（2026-03 首版）；BSD-3 | **首选试验 → DEC-008 ③ 裁决：先真机 PoC 再定**（后台保活+EQ+≥30min 长稳；不达标切双引擎） |
| 双引擎：Android just_audio+audio_service；桌面 media_kit+smtc_windows+audio_service_mpris | Android 仅设备提供频段（须实现「不支持→显式提示」）；桌面无 EQ（缺口） | just_audio 生态成熟（ExoPlayer+通知） | 已证实可行（mpris 0.2.1 / smtc 1.1.0） | 桌面实验性 | 活跃；MIT | **回退线（DEC-008 ③ 声明）**：PoC 不达标即取本线 |
| media_kit 单引擎 | 无官方 EQ（#205/#600 hack 不稳） | 无内建，需 audio_service 桥（#913） | 无内建 | mpv prefetch | 限维护（#1337） | 不作基线 |
| flutter_soloud 5.2.1 | 有软件 EQ | 无媒体会话 | 无 | 有 | 活跃 | 不推荐为主体 |

体积参考：mpv_audio_kit ~8–9MB/平台；「启动 ≤300ms」（C31）无公开基准（未证实）→ 纳入 PoC 实测项。

### 3.C R1 提取/下载引擎

| 候选（Android） | 许可（关键） | 能力/维护 | 代价 | 结论 |
|---|---|---|---|---|
| ffmpegkit-maintained/yt-dlp-android 2.0.2 | **MIT** | CPython 3.13 进程内；库内不可更新 yt-dlp | AAR 60–80MB；免 curl-cffi（B 站可配 Cookie）；arm64+x86_64 | **已锁定（DEC-008 ①）**：MIT 版采用；yt-dlp 更新随库发版（B 站适配失效时快速小版本） |
| yausername/youtubedl-android 0.18.1 | **GPL-3.0** | 生态最稳；库内可更新 yt-dlp | **GPL 传染**（MIT 项目分发需换 GPL 或进程隔离） | **落选（DEC-008 ①）**：GPL 传染与项目 MIT/未来开源冲突；不采用进程隔离变通 |
| NewPipe Extractor | GPL-3.0 | 仅解析、无下载器 | 同上 | 不作主选 |
| flutter_ytdlp_plugin | — | Android only、仅解析、+25MB | 不满足下载 | 不可用 |

桌面路线：捆绑 yt-dlp 二进制（17MiB，Unlicense）+ ffmpeg（**选 LGPL 构建**，禁 `--enable-gpl/nonfree`；随包体积 +70–100MB 量级，未证实）+ Process spawn/JSON 流式解析；Flutter 案例：yt_dlp_gui / ardl / TubeVault。
存储/登录态：Android 10+ 下载落应用私有目录 + MediaStore/SAF 导出（youtubedl-android#174）；B 站登录用 `--cookies`（Netscape 格式），Cookie 加密存储（C50）。

### 3.D R2 同步适配

| 通道 | Dart 生态（2026-10） | 断点续传 | 授权 | 结论 |
|---|---|---|---|---|
| **WebDAV** | webdav_client_plus 2.0.0（活跃，BSD-3） | 下载 Range✓ / 上传需自研分块+清单重试 | Basic/Digest | **MVP 默认通道** |
| OneDrive | 无官方 Dart 包 → microsoft_graph_api 自适配 | createUploadSession✓ | OAuth（设备码/loopback） | 备选（可选实现） |
| Google Drive | google_sign_in_all_platforms 2.0.3（社区） | 官方支持（细节未证实） | OAuth loopback | 备选 |
| 百度网盘 | 无 Dart SDK → REST 手写 | 官方分片✓ | OAuth；2026-06-03 后应用限 `/apps/{appname}`（C46） | **已移除（DEC-008 ② 裁决）：产品需求层面放弃，不计入通道池；控制台实测取消** |
| GitHub | git2dart 0.5.6 / REST | >100MB 拒收 | PAT | 仅轻数据（C45） |

通用：桌面 OAuth 用 flutter_web_auth_2（loopback；flutter_appauth 无桌面）；设备码流备选；凭据 flutter_secure_storage（Win=Credential Manager+AES-GCM；Linux=libsecret 需 keyring；Android=Keystore，建议 allowBackup=false）。
代价：WebDAV 上传续传无标准（HTTP resumable upload 仍为 draft）→ 自研分块；每增一个通道即一层适配成本（MVP 恰 1 个激活，C44）。

### 3.E R3 ASR

| 项 | 选择 | 证据/代价 |
|---|---|---|
| 引擎 | **sherpa_onnx Dart 1.13.8**（官方 k2-fsa；Android arm64/Win/Linux；Apache-2.0；per-ABI 分包） | 纯 Dart FFI；同步 decode → isolate+分块实现暂停/取消（C38）；pub 未 verified（供应链小风险） |
| 模型 | **SenseVoiceSmall int8 2024-07-17**（默认；带 ITN 标点）；备选 Paraformer zh small（下载 74MB）；Whisper tiny 补充多语 | 最差 RTF 0.436（RK3588 A55 单线程）→ 4 分钟歌 ≈105s，「≤2× 时长」有余量（C34）；桌面 x86 0.07–0.13 |
| 模型下载 | hf-mirror 镜像通路已验证（EXP-002：239MB≈2 分钟）；background_downloader 断点 + sha256 校验 | 首载 5–17.5s（旧机）→ 建议常驻/前台服务、大核优先（C38） |
| 备选引擎 | whisper.cpp 封装（whisper_ggml 2.8.1：Android✓/桌面仅 x64） | Android 有 51× 慢的第三方基准（单一证据，谨慎采信）；中文口碑弱于 SenseVoice → 不作首选 |
| 桌面预检 | 模型已就绪（EXP-002）；本机 Python 3.14 无 sherpa 轮子 → RTF 计时后置（以真机为主） | 复测可另装 cp312/313（需请示） |

### 3.F 存储与检索

| 项 | 选择 | 证据/代价 |
|---|---|---|
| DB | **drift 2.35.2 + sqlite3 3.7.1（hooks 打包）+ drift_flutter 0.3.1**（MIT） | 三端+迁移+**FTS5 内建**；**弃 sqlite3_flutter_libs（0.6.0+eol）**；需 Dart ≥3.10 |
| 全文/拼音索引 | FTS5 于「标题+歌手+专辑」辅助表 + `pinyin` 3.3.0 生成全拼/首字母列（yhw→夜黑雾） | 10k 行 ≤300ms（C33）无压力；两列随标题同事务更新 |
| 语义表 | 曲库/播放记录(500)/歌单(有序)/红心/少播/墓碑(软删)/冲突副本(origin_id) | 对应 C15–C30；物理设计阶段 3 决策（C15） |
| 元数据/封面读取 | **audio_metadata_reader 1.8.1**（纯 Dart，MIT；MP3/FLAC/M4A/OGG/WAV/APE；getImage 封面） | 活跃（2026-10-14）；3392 首 <200ms（无封面） |
| 凭据 | flutter_secure_storage 11.2.0（见 §3.D） | Linux keyring 依赖需声明 |

### 3.G 封面在线源

| 源 | 费用 | 分辨率 | 条款要点 | 结论 |
|---|---|---|---|---|
| MusicBrainz + Cover Art Archive | 免费无 key | 250/500/1200/原图 | 1 req/s + 必带 UA；图片版权自担 | **主源** |
| iTunes Search API | 免费无 key | artworkUrl100 可升尺寸（社区做法） | Promo 条款苛刻（仅推广商店内容） | 兜底（注意条款） |
| TheAudioDB | 免费 key（$10/月进阶） | 未证实 | 社区站 | 可选 |
| Deezer / Discogs | 免费（登录/token） | 未证实 | ToS 限制 | 可选 |
| 网易云/QQ 非官方 API | — | 覆盖高 | **无授权抓取，违规风险（C52/C61）** | **不推荐** |

实现：dio + 磁盘缓存；只补缺不覆盖、落 `.cover.jpg`（C22）；中文覆盖无量化数据（未证实）→ 接受静默降级。

### 3.H 横切件（按需）

- HTTP：dio（webdav/多数包既有依赖）；封面图本地下盘后图片缓存非关键。
- i18n：flutter_localizations + intl（ARB）；主题 token 组件化（C64/C65）。
- 打包：Android AAB + per-ABI splits（C40）；最低版本/安装器已锁定（§5）：AppImage+deb（Linux）、Win 安装形式在阶段 2/4 定形。
- 状态管理与工程结构：属阶段 2/3，本阶段不锁（避免超范围）。

### 3.Z 待开发者裁决点汇总 — **已全部裁决（DEC-008，2026-10-17）**

1. **R1 Android 引擎** → MIT 版采用（GPL 版落选）
2. **R2 百度网盘** → 彻底移除候选（基线 7 处同步修订，控制台实测取消）
3. **B 音频引擎** → mpv_audio_kit 先真机 PoC 再定；回退线=双引擎
4. **分发/最低版本** → 按默认锁定（Android 8+/Win10 x64/Ubuntu 22.04+·Debian 12+，AppImage+deb；ffmpeg 产品分发改 LGPL 构建）

详情与选项原文见 `DEC-008-tech-selection-decisions.md`；插槽结论同步上表。

## 4. 高风险最小验证（TECH-03）— 进行中

- **R1 工具链（桌面）**：安装自检 + **链路实测通过**（2026-10-17）→ `_06_dev_process/_03_qa_log/EXP-001-R1-desktop-toolchain.md`（yt-dlp 2026.08.19 + ffmpeg 7.1；B 站 av170001 匿名全链路→mp3 解码复核 ✓；匿名音轨上限 64k，高音质需登录 Cookie）
- **R3 桌面预检**：已执行模型获取与样本生成（2026-10-17）→ `_06_dev_process/_03_qa_log/EXP-002-R3-desktop-preview.md`（hf-mirror 239MB≈2min ✓；SAPI `zh-sample.wav` ✓；桌面 RTF 计时受限＝py3.14 无轮子，以真机为主）
- 真机项（R1/R3）工作单保留（ISS-101）；百度控制台实测随 DEC-008 ② 取消（ISS-102 关闭）

## 5. 实施约束（TECH-04）— 已锁定（2026-10-17，DEC-007/008）

### 5.1 Runtime 与依赖版本矩阵

| 层 | 锁定 | 许可 | 备注 |
|---|---|---|---|
| 平台最低版本 | Android 8.0+（arm64 主）/ Windows 10+ x64 / Ubuntu 22.04+ · Debian 12+ | — | Linux 打包 AppImage + deb 双格式 |
| 跨端框架 | Flutter stable（锁版时取当年 stable；Dart ≥3.10 以满足 drift） | BSD-3 | Impeller 桌面回归项阶段 2 复核 |
| 音频 | mpv_audio_kit 0.5.1（PoC 通过后为基线）；回退=just_audio+audio_service / media_kit+smtc_windows+audio_service_mpris | BSD-3/MIT | libmpv 按 LGPL 履行许可文本随包 |
| R1 引擎 | Android: yt-dlp-android（ffmpegkit-maintained，MIT）；桌面: 捆绑 yt-dlp（Unlicense）+ **LGPL 构建 ffmpeg** | MIT/Unlicense/LGPL | yt-dlp 更新随库发版；≥1 次/季查上游 |
| R2 | webdav_client_plus 2.0.x；flutter_web_auth_2 5.x；flutter_secure_storage 11.x | BSD-3/MIT | 上传分块续传自研（C36） |
| R3 | sherpa_onnx Dart 1.13.8+ + SenseVoiceSmall int8（2024-07-17） | Apache-2.0 | 模型 hf-mirror 下载（已实测 EXP-002）+ sha256 校验 |
| 存储 | drift 2.35.x + sqlite3 3.7.x（hooks bundled）+ drift_flutter 0.3.x；audio_metadata_reader 1.8.x；pinyin 3.3.x | MIT | 弃 sqlite3_flutter_libs（EOL） |
| 通用 | dio；flutter_localizations+intl（ARB，C63）；background_downloader | 多为 MIT/BSD | 版本以阶段 3 契约锁定具体号 |

### 5.2 许可与费用

- 依赖注册表全部开源免费（DEC-007 D7-3）；现阶段 0 付费依赖。
- ffmpeg 产品分发＝LGPL 构建并履行「许可文本随包 + 源码链接」义务（当前 dev 机 gyan GPL 构建仅探查用，不入包）；
- 不得混入：GPL 版 youtubedl-android、需付费 key 的服务、网易/QQ 非官方接口（C52/C61）。

### 5.3 部署前提

- Android：不再附加 Google 服务依赖（sideload/渠道包均可）；B 站高音质需扫码登录（Cookie 管理）；
- 桌面：零后台服务、无遥测（C63）；模型首启下载走镜像（断点可续）；
- 落选方案不入执行契约：KMP/Tauri/MAUI/Qt；media_kit 单引擎；百度通道；whisper 系（R3）。

### 5.4 进入阶段 2 的开放点

- mpv_audio_kit Android 真机 PoC（DEC-008 ③；工作单 ISS-101）；
- Impeller 桌面回归实测；AppImage/deb 打包定形（阶段 4）。

## 6. 拍板记录（TECH-05）— 已完成（2026-10-17）

- 2026-10-17：`DEC-007`——跨端栈倾向 **Flutter**（团队适配基准）；三端测试环境齐备；依赖纯开源免费优先（必要付费先请示）；桌面最小验证安装许可 → `DEC-007-tech-selection-inputs.md`
- 2026-10-17：`DEC-008`——四项裁决：① R1=MIT 版；② 百度网盘移除（基线 7 处修订）；③ mpv_audio_kit 先 PoC 再定（回退=双引擎）；④ 分发/最低版本按默认锁定 → `DEC-008-tech-selection-decisions.md`；**最终 ADR = `ADR-0001-build-1-tech-selection.md`（Accepted）**
