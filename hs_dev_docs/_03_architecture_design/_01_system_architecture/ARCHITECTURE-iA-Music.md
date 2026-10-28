# iA-Music 架构说明（BUILD 阶段 2）

- **状态**：DRAFT（§1–§7 正文齐备；§7 末项留待阶段 3；待开发者验收边界与取舍）
- **依据**：`engineering_acceptance.md` §3（ARCH-01..06）；arc42 内容维度按本项目规模裁剪（无分布式、无自有服务端，不强行制造系统复杂度）
- **置顶契约**：`ADR-0001-build-1-tech-selection.md`（Accepted）——本文件的视图/机器契约不得引入落选方案（KMP/Tauri/MAUI/Qt、media_kit 单引擎、百度通道、whisper 系）或未授权依赖；技术选型结论与版本以 TECH-SELECTION §5 矩阵为准
- **输入基线**：overview v1.3.0 / features（SYNC v1.1.0）/ vibe & prototype（DEC-008 修订后）/ DEC-001..008 / EXP-001/002 / PROBE 工作单
- **关联**：`PLAN-iA-Music-BUILD-2.md`；`PHASE-2-ACCEPTANCE-iA-Music.md`；`_06_dev_process/_03_qa_log/`
- **更新时间**：2026-10-17

## 1. 上下文与边界（ARCH-01）

### 1.1 使用者

单人类多端自有设备：同一用户在 Android 手机与 Windows/Linux 桌面上使用自己的曲库（REQ-ONB-01/06）；无多租户、无账号体系（本项目自建身份为零），跨设备一致性经由同步通道达成。

### 1.2 外部系统与信任边界

| 外部系统 | 用途 | 协议/载体 | 信任等级与边界 |
|---|---|---|---|
| 哔哩哔哩 | 音频流来源 + 扫码登录（REQ-EXT-01/02） | HTTPS（经 yt-dlp 引擎会话） | **用户显式触发域**：仅在提取/登录流程访问；Cookie 属最高级 secrets，仅入 secure storage（C50）；前置合规门禁 REQ-ONB-03 |
| 用户自有 WebDAV 云端 | 轻数据+音频同步（REQ-SYNC-*） | HTTPS/HTTP（用户配置） | 用户配置域：地址/凭据由用户输入，连接测试通过才保存（REQ-SYNC-01）；本机为主数据源 |
| OneDrive / Google Drive | 可选通道（Phase 2 备选） | OAuth + REST | 同上；凭据=secure storage |
| MusicBrainz / Cover Art Archive | 封面搜索主源（REQ-LIB-08） | HTTPS 公开 REST；1 req/s + UA | 公开只读域：请求不含用户身份；图片版权自担；红线=只补缺不覆盖（C22） |
| iTunes Search | 封面兜底 | HTTPS 公开 REST | 公开只读域 |
| hf-mirror / ModelScope | ASR 模型下载（REQ-LYRAI-01/ONB-05） | HTTPS 静态文件 | 公开只读域：仅固定模型包；落盘前 sha256 校验（通路已实测 EXP-002） |
| 操作系统平台能力 | 存储/通知/媒体会话/分享回收 | MediaStore/SAF、前台服务、MediaSession/SMTC/MPRIS | 平台域：Android 仅必要权限（下载目录、通知、后台）；桌面零提权安装（用户级目录） |

### 1.3 输入输出

- 输入：本地音频目录（扫描）、B 站分享链接（提取）、.lrc/粘贴/ASR（歌词）、用户配置（仓库/通道/外观）
- 输出：曲库与播放状态（本机 UI + 系统媒体会话）、编辑后的元数据**不写回原文件**（REQ-LIB-03）、`iA-Music/` 远程仓库内容（同步）、同目录 `.cover.jpg`（C22）与 `.lrc`

### 1.4 本系统不承担（范围外清单）

不承担：内容分发/分享/社交（REQ-LIB-07 移除=仅解除记录）、DRM 与加密内容规避（产品红线，无任何绕过代码路径）、跨用户身份与权限、任何自有服务端（DEC-002：仅用户自有存储中转）、常驻转码服务（编解码仅存在于提取链内）。

### 1.5 通过标准（ARCH-01）

七类外部系统、三信任域（用户显式触发/用户配置/公开只读）、不承担清单一次成立；与 REQ 63 全集零冲突。

## 2. 模块职责与数据所有权（ARCH-02）

### 2.1 模块域 ↔ REQ 全集映射（63 条全覆盖）

| 模块 | 域职责 | 覆盖 REQ |
|---|---|---|
| `library`（曲库域） | 仓库管理/扫描（全量+增量）/元数据与手工编辑/封面来源链/缺失恢复/检索索引 | REQ-LIB-01..08；REQ-NAV-03 |
| `playback`（播放域） | 引擎桥（EnginePort）/队列与随机/媒体会话三端/EQ 与倍速/前台服务 | REQ-PLAY-01..08；REQ-NAV-01（迷你条共用）/02 |
| `playlists`（歌单域） | 红心与系统歌单/歌单 CRUD/历史记录（归属其表）/队列入口 | REQ-PL-01..06 |
| `lyrics`（歌词域，含 AI 子域） | .lrc 解析与逐行高亮/点击跳转/偏移保存/粘贴/ASR 生成队列/模型文件生命周期 | REQ-LYR-01..05；REQ-LYRAI-01..06；REQ-ONB-05 |
| `extract`（提取域） | 链接解析/扫码登录（Cookie 唯一持有者）/下载队列/转码入库/重复检测/合规门禁实现 | REQ-EXT-01..08；REQ-ONB-03 |
| `sync`（同步域） | 通道配置/轻数据+音频同步/冲突副本/墓碑/失败恢复/最近同步状态 | REQ-SYNC-01..08；REQ-ONB-06 |
| `shell`（壳层域） | 三 Tab 导航/全局搜索 UI 与路由/设置（六组）/引导/外观双通道（主题·语言） | REQ-NAV-01/04/06；REQ-ONB-01/02/04/07/08 |

### 2.2 数据写入权矩阵（每表唯一写者；drift 为唯一持久化层）

| 数据 | 唯一写入方 | 主要读者 | 红线/规则关联 |
|---|---|---|---|
| 曲目/歌曲（track)/歌手/专辑记录、FTS5+拼音列、缺失状态 | `library` | playback / sync / shell | REQ-LIB-07：移除=解除记录（软删可恢复），不触文件 |
| 封面缓存状态（`.cover.jpg` 标志） | `library`（封面链裁决器） | playback / sync | C22 只补缺不覆盖 |
| 歌单/歌单曲目/红心（系统歌单=我喜欢的音乐） | `playlists` | playback / sync / shell | 删除传播仅经 sync 墓碑 |
| 播放历史（500 淘汰）/少播名单 | `playback` 写历史；`playlists` 写名单 | sync / shell | 少播=名单不删记录（RED LINE 同源） |
| `.lrc` 文件/偏移字段/生成队列状态 | `lyrics` | playback / sync | 生成的 .lrc 属本地文件，纳入同步 |
| 下载任务/Cookie 与登录态 | `extract` | shell（登录入口） | Cookie 只进 secure storage，永不进 drift 与日志（C50） |
| 通道配置（非凭据）/最近同步状态/墓碑/冲突副本 | `sync` | 全域（变更通知） | REQ-SYNC-05 云端文件保留；REQ-SYNC-06 本地无损 |
| 设置/外观/仓库路径/合规声明状态 | `shell` | 全域 | REQ-ONB-07/08 |
| 模型文件与注册状态 | `lyrics`（AI 子域） | shell（模型页） | 删除=回未下载态（可再取） |

### 2.3 依赖方向（ports & adapters，轻型六边形）

```
shell ──► library / playlists / extract / sync / lyrics / playback      （仅经接口）
              └──► ports：EnginePort / DownloaderPort / AsrPort / MetadataPort /
                         CoverFetchPort / SyncChannelPort / SecureStorePort
                       ports ──► adapters：
                         Engine:  mpv_audio_kit（优先）‖ just_audio+audio_service + media_kit 系（回退，ISS-201 双态）
                         Downloader: yt-dlp-android(AAR) ‖ 桌面 Process(yt-dlp+LGPL ffmpeg)
                         Asr: sherpa_onnx + SenseVoice int8；Metadata: audio_metadata_reader
                         SyncChannel: webdav_client_plus（+OAuth 通道后置）；SecureStore: flutter_secure_storage
```

- 禁止：反向依赖；跨域直查他人表；绕过 port 直连平台 API（如 UI 直接实例化引擎）。
- 双态要点：EnginePort 为唯一切换面，业务层零分支；桌面 EQ 若随最终引擎态缺失，以「合成卡+明示文案」承载（DEC-002 引擎能力制）。

### 2.4 通过标准（ARCH-02）

63 条 REQ 均有 owner；11 类数据唯一写者；依赖单向；引擎可替换点收敛于 EnginePort。

## 3. 关键运行场景（ARCH-03）

每场景给出：成功路径模块协作 → 失败分支归属 → 事务/异步/重试。

### 3.1 首启引导与全量扫描入库（REQ-ONB-01/02 + LIB-01/02/06）

- 成功：`shell`(FTUE) 选目录 → `library.ScanService` 后台 isolate 全量扫描 → MetadataPort 解析 → 每 ~200 条一批事务入库（含 FTS5/拼音列同事务更新）→ UI 实时计数（**真实计数**）→ 曲库计数=音频文件数。
- 失败：目录权限拒绝→shell 引导换目录；单个损坏文件→跳过并累计「跳过 N」（细节入扫描日志，任务不中断）。
- 异步/事务：扫描为可暂停任务（进度流）；启动增量扫描（≤15s 目标）复用同一管线+目录事件监听。

### 3.2 随机连续播放 + 后台/锁屏/媒体键（REQ-NAV-02 + PLAY-02/03/05/08）

- 成功：随机大卡/轮盘页（仅上滑切歌 D6-7）→ `playback.RandomPool`（池=全库−少播名单；单轮不重复）→ EnginePort → 三端媒体会话状态推送；切后台/锁屏由前台服务与会话承载（REQ-PLAY-05）。
- 失败：文件缺失→跳过+顶部提示+自动下一首（REQ-PLAY-08；该曲不写“完成播放”历史）；引擎异常→前台服务内重启一次并恢复队列，二次失败→「播放服务异常」人话文案。
- 事务：切歌完成事件批量写历史（延迟合并写）；垃圾桶仅追加少播名单。

### 3.3 提取链（REQ-EXT-01..08 + ONB-03）

- 成功：粘贴文本 → 解析（≤5s：标题/UP/时长/封面/音质列表）→ 合规门禁校验（未确认拦截）→ 串行下载队列（离开页面任务不死，REQ-EXT-04）→ ffmpeg 转码 → metadata+封面 → `library` 注册（事务）→ 曲库即时可见（REQ-EXT-03）→ 勾选「同时生成歌词」→ `lyrics` 入队（REQ-EXT-08）。
- 登录态：扫码（QR URL 由 `extract` 出）→ Cookie 写 SecureStorePort（唯一写者）→ 引擎会话注入 `--cookies`；**失效**：auth 错误→队列暂停+「登录状态过期请重新扫码」（EXP-001 实测：匿名上限 64k 音轨，高音质以 Cookie 取得）。
- 失败：断网→暂停+恢复续传（REQ-EXT-05）；重复→按源 ID+内容哈希提示已存在（REQ-EXT-06）；转码失败→单任务失败标记、队列续跑。
- 事务/异步：Android=AAR 内嵌引擎（进程内）；桌面=Process+流式 JSON（同 DownloaderPort）；下载产物先落应用私有目录，入库成功后按 REQ-LIB-07 语义管理。

### 3.4 同步闭环（REQ-SYNC-01..08）

- 成功：`sync` 订阅全域变更通知 → 30s 防抖 → PREPARE(diff) → 轻数据 PUT（webdav）/音频分块上传（断点续传自研，C36）→ 拉取合并 → 状态面板（REQ-SYNC-07）；新设备走「从同步恢复」（REQ-ONB-06）。
- 冲突：元数据双向修改→last-writer-wins+冲突副本（`sync` 唯一写者，origin_id）；歌单结构性冲突→集合并集；删除比较墓碑时间戳。
- 失败：断网→PAUSED 明示原因（REQ-SYNC-06）；授权过期→NEEDS_REAUTH 原位重授；磁盘满→SUSPENDED_DISK；GitHub=仅轻数据（REQ-SYNC-08 音频开关禁用）。
- 红线复检：本地删除只传播记录；云端音频文件永不因子端删除而被删（REQ-SYNC-05）。

### 3.5 歌词与 ASR 生成（REQ-LYR-01..05 + LYRAI-01..06）

- 成功：歌词页 → `lyrics` 解析（内嵌 > .lrc > 粘贴，REQ-LYR-01/04）→ 逐行高亮随位置流推进；无歌词→引导生成（REQ-LYR-05）→ 模型就绪检查 → isolate 串行队列（暂停/取消，REQ-LYRAI-03；C38 分块+取消点）→ LRC 预览可编辑 → 保存（REQ-LYRAI-04）。
- 失败：纯音乐→「未检测到人声」不生成空文件（REQ-LYRAI-05）；下载中断→断点续传；模型损坏→回下载引导；队列中断→已生成结果不丢。
- 取消语义：分块 decode 在块边界退出；生成结果未确认不落库（预览态）。

### 3.6 模型生命周期（REQ-ONB-05 + LYRAI-01/06）

- 成功：模型页状态/体积 → 下载（镜像通路，EXP-002；断点续传）→ sha256 校验 → 注册态写入 `lyrics` 域 → 离线可用（REQ-LYRAI-06）。
- 失败：磁盘满→人话提示+清理引导；校验失败→删除半成品并允许重试；手动删除→状态回「未下载」。

### 3.7 通过标准（ARCH-03）

六场景覆盖 REQ 主干（入库/播放/提取/同步/歌词/模型）；每个失败分支都有写者与 UI 归属（无悬空中间态）；事务/异步/重试归属与各 PRD 状态机一致（sync 状态机逐态对应）。


## 4. 部署与配置（ARCH-04）

### 4.1 三端形态与打包

| 端 | 形态 | 最低版本/目标 | 关键打包点 |
|---|---|---|---|
| Android | AAB + per-ABI splits（arm64 主；armeabi-v7a 视体积与 PoC 裁量） | 8.0+（O） | 前台服务权限（播放/下载）；无 Google 服务依赖，sideload 可装；下载产物默认私有目录（分享导出用 SAF） |
| Windows | 用户级安装（阶段 4 定形：安装器或自助解压） | 10+ x64 | 零提权安装；ffmpeg(LGPL 构建)+yt-dlp.exe 随包；SMTC 由引擎桥注册 |
| Linux | AppImage + deb | Ubuntu 22.04+ / Debian 12+ | AppImage 免提权；deb 走系统包管理；MPRIS 注册；libsecret 依赖声明 |

### 4.2 进程/服务模型

- **单进程应用**：UI 主 isolate + 工作 isolate 池（扫描、ASR 解码、下载编排）；桌面无自启动服务、无常驻后台进程（退出即净）。
- Android：后台播放/提取＝前台服务（通知可见）；被系统回收后由会话状态恢复（EnginePort 恢复接口）。
- 桥接进程：桌面 yr（yt-dlp/ffmpeg）以 Process 运行，生死由 DownloaderPort 管理（超时+进程退出码回读）；Android 为库内嵌（同 Port 合约）。

### 4.3 配置/机密来源分层

| 层 | 内容 | 载体 | 安全级 |
|---|---|---|---|
| 机密层 | WebDAV 凭据、B 站 Cookie、OAuth token（预留） | flutter_secure_storage：Android=Keystore 加密 prefs；Windows=DPAPI；Linux=libsecret/keyring | 最高（C50；明文禁入 drift/日志/一遍性 dump） |
| 业务层 | 曲库/歌单/历史/通道配置（除凭据）/模型注册/合规声明状态 | drift 单库（bundled SQLite+FTS5） | 高（本地完整；删除语义红线） |
| 缓存层 | 模型文件、封面缓存、临时下载分片 | 应用私有目录（Android）/用户数据目录（桌面） | 中（可重建，删除不伤曲库） |
| 用户配置 | 仓库路径、外观（主题/语言）、音效 | drift（壳层域） | 低 |

### 4.4 启动顺序（单机一图）

```mermaid
flowchart LR
  A[启动] --> B[壳层装配: 外观/语言/设置]
  B --> C[storage: drift 打开+迁移]
  C --> D[引擎初始化 EnginePort: mpv 或回退组合]
  D --> E[恢复状态: 上次页签/迷你条/未完任务清单]
  E --> F[增量扫描触发(≤15s 内可见) | 同步防抖定时器装配]
  F --> G[主界面就绪]
```

启动失败降级：drift 迁移失败→进入只读引导（提示修复），不闪退；引擎初始化失败→双态 adapter 互补（mpv 失败切回退线），双双失败→提示并允许离线浏览。

### 4.5 通过标准（ARCH-04）

装完第一次打开会发生什么可全链讲述（顺序图+降级路径）；配置/机密四层各自唯一的写入者（与 §2 矩阵互查一致）。

## 5. 质量与安全（ARCH-05）

### 5.1 质量场景 → 措施 → 验证计划

| 质量场景（约束锚点） | 设计措施 | 验证计划 |
|---|---|---|
| 无遥测无埋点（C63；governance.yaml: cicd/observability off） | 架构级：无任何上报端口；依赖准入清单核对（ADR-0001 附录） | 阶段 6 构建产物核查（DPI 出网域名仅列 CAA/iTunes/mirror/user 通道）；governance 开关切走时零行为差异 |
| 本地数据无损（RED LINE：删除仅解除记录/墓碑；REQ-LIB-07/REQ-SYNC-05） | 软删字段+墓碑表；删除传播仅经 `sync`；云端音频不因子端删除而删 | 阶段 5/6 场景级验收（含「移除后文件仍在」断言）；DB 约束测试 |
| Cookie/Token 安全（C50） | SecureStorePort 分端落地（Keystore/DPAPI/libsecret）；日志统一脱敏 hook（正则抹除 Cookie/Authorization 字段） | 阶段 5 演练：登录→抓日志无明文；secure storage 读写断言 |
| 全局搜索 ≤300ms（C33，1 万首） | FTS5 辅助表+拼音列同事务；查询仅走索引前缀页 | 阶段 3 契约确定结构；阶段 5 演练 10k 行基准计时（P95≤300ms） |
| 后台播放连续性（REQ-PLAY-05/C09） | 前台服务+会话状态机（EnginePort）；锁屏控制事件直达事件总线 | 真机 30min 后台播放冒烟（ISS-101 清单内）；桌面 SMTC/MPRIS 事件驱动测试 |
| 探查用贴身工具不入产品 | 构建依赖白名单=ADR-0001 §1+§5.2；GPL 版 yt-dlp 引擎/百度通道/网易 QQ 非官方接口显式禁止 | 阶段 4 依赖审核（pubspec 白名单比对） |
| 合成卡（DEC-002 引擎能力制） | 能力探针 Port：启动时探测 EQ/音质/续传能力 → UI 用合成卡或明示文案 | 阶段 5 演练三端能力差异矩阵（EQ 明示不支持路径） |
| 搜索与列表 1 万首不卡顿（REQ-LIB-06） | 分页+索引排序；列表虚拟化 | 基准 10k 行滚动/排序帧率抽查（阶段 6） |

### 5.2 安全边界汇总

- 认证仅两类：用户自有云（凭据/Cookie）；均不经过任何第三方中转服务器。
- 隔离边界：网络出网清单白名单（B 站=显式触发；通道=用户配置；公开只读=封面/模型）。
- 与治理配置一致性：`config/governance.yaml` security 项 on → 冷启动/网络白名单/日志脱敏为强制 DoD；cicd/observability off → 不引入上证工具。

### 5.3 通过标准（ARCH-05）

八类质量场景均有措施+验证计划+归属阶段；红线（无损删除）与安全（Cookie）有可复验的机制而非口号；与 governance.yaml 开关逐项一致。


## 6. 权衡、风险与演进（ARCH-06）

### 6.1 ADR 关联

- ADR-0001（Accepted）：技术栈与实施约束置顶契约——本文件 §2 ports/§4 形态/§5 安全与其逐项一致，无落选方案混入。
- 新架构层决策（如模块路由实现方式、状态管理选型）随本阶段/阶段 3 拍板出 **ADR-0002+**，不得口头变更。

### 6.2 风险登记（含处理人/时点）

| 风险 | 影响 | 应对 | 处理人/时点 |
|---|---|---|---|
| ISS-101 三真机验证（R1 Android AAR 嵌入 / R3 arm64 RTF / mpv_audio_kit 后台+EQ+长稳） | EnginePort 收敛精度；R3 时延预算实证 | 双态建模已兜底（§2.3）；PoC 结论回填即终审 | 开发者（设备）；agent 回填；阶段 2/5 内并行 |
| ISS-201（同源） | 模块接口层/协作场景双态已并存表述 | PoC 后一次性收敛文档版本 | 同上 |
| yt-dlp 库内更新受限（MIT 裁决代价） | B 站适配失效需等库发版 | 季度上游巡检 + 应急发小版本（§5.2 TECH） | 阶段 5 维护机制落地 |
| WebDAV 上传续传无标准 | 自研分块工作量与边界情况 | 阶段 3 DETAIL 定分块协议（清单+校验）；桌面先行验证 | 阶段 3 |
| 桌面 EQ 最终归属（随引擎 PoC 结果） | 桌面音效合成卡形态 | 能力探针+明示文案兜底（§5.1） | PoC 结论点 |

### 6.3 演进限制与预留

- 多通道并存（Phase 2）：SyncChannelPort 已多态预留，MVP 仅激活 1 条（C44）。
- 多语言/多主题：外观双通道（DEC-005）已在壳层域内聚。
- 扩展到更多提取站点：DownloaderPort 不绑死 B 站（引擎能力制），新增站点=适配器扩展。
- 不演进项（以红线为准）：服务端化、DRM 绕过、通用转码服务。

### 6.4 通过标准（ARCH-06）

风险全部有处理人与时点；演进预留不扩大当前范围；开发者对「边界+三处重大取舍（删除语义/许可裁决/双态引擎）」拍板确认。

## 7. 一致性核对（ARCH-06 附属）

- [x] 视图 ↔ ADR-0001：无落选方案/未授权依赖混入（§2.3/§4.1 对照 §5.2 TECH）
- [x] 模块矩阵 ↔ REQ 63 全集：无漏项/重复归属（§2.1）
- [x] governance.yaml 开关 ↔ §5.2 一致（cicd/observability off；security on）
- [x] 写入权矩阵 ↔ §4.3 配置分层：机密层唯一写者=SecureStorePort 持有域一致（extract/sync/shell 各自入口）
- [x] 状态机 ↔ 阶段 3 契约：sync 状态机逐态已在 `DETAILED-DESIGN-iA-Music.md` §4.1 与 vibe spec 原文逐态对齐（7 态全覆盖）
