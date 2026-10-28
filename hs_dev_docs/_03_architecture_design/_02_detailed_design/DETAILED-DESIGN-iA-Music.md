# iA-Music 详细设计与契约说明（BUILD 阶段 3）

- **状态**：DRAFT（§1–§6 正文齐备；gate=SUBMITTED 待开发者验收）
- **依据**：`engineering_acceptance.md` §4（DETAIL-01..06）；粒度=仅触达本应用的 DB/接口/方法/调用链及测试规格（OpenAPI 仅在适用时使用——本项目无自有服务端，见 §2 说明）
- **上游基线**：`ARCHITECTURE-iA-Music.md`（§1–§7，阶段 2 ACCEPTED）；`ADR-0001` + TECH-SELECTION §5（锁定依赖与版本）；REQ 63 / TEST 34（Gherkin 31）；DEC-001..008
- **关联**：`PLAN-iA-Music-BUILD-3.md`；`PHASE-3-ACCEPTANCE-iA-Music.md`
- **更新时间**：2026-10-17

## 1. 数据契约（DETAIL-01）

### 1.1 惯例

- 时长/时间统一：毫秒整数 `*_ms` / Unix 毫秒 `*_at`；UI 相对时间在展示层换算（不存「3 分钟前」）。
- 体积：字节整数；音质/枚举：本节为唯一事实源（§5 核对）。
- 同步语义基座：**凡需同步的表带 `updated_at` + `device_id`**（由 sync 生成 localDevice，首次启动固化）；本地表（如 play_history）不参与同步。
- 每条主业务记录含 `deleted_at`（软删，REQ-LIB-07/PL-02 等删除=置值不物理删）；物理清理任务仅作用于 play_history（500 淘汰）与临时缓存。

### 1.2 表结构（14 表 + FTS）

**曲库域（library）**

`repository_roots`：id PK；path TEXT UNIQUE NOT NULL；label TEXT；mode ENUM(directory|synced_dir)；added_at。
`tracks`：id PK；root_id FK→repository_roots；rel_path TEXT NOT NULL；UNIQUE(root_id, rel_path)；title TEXT；artist_display/album_display TEXT（原文案）；artist_id/album_id FK nullable（字典引用）；duration_ms INT（内容中位值）；audio_format ENUM(mp3|flac|m4a|ogg|wav|ape)；file_size INT；mtime INT；content_hash TEXT（入库时计算，范围=音频帧）；source_type/source_id TEXT nullable（提取溯源：bilibili/BV…）；sample_rate/channels nullable；added_at/updated_at；deleted_at nullable；missing_at nullable（REQ-LIB-05）；索引：idx_track_root_rel UNIQUE(root,rel_path)；idx_track_album(album_id)；idx_track_artist(artist_id)；idx_track_source(source_type, source_id)（REQ-EXT-06 dup 检测）；规则约束：deleted_at 与 missing_at 语义互斥（缺失≠移除）；deleted_at 非空时不进入随机池/搜索结果。
`artists`/`albums`：id PK；name TEXT；name_norm TEXT UNIQUE（规范化）；sort_key TEXT；updated_at（字典表，入库 upsert）。
`tracks_fts`（FTS5，content=外部 tracks 锚定辅助表 `track_index`）：title/artist/album/pinyin_full/pinyin_initials —— 写入与 tracks 同事务（REQ-NAV-04 拼音搜索）。

**歌单域（playlists）**

`playlists`：id PK；name TEXT；kind ENUM(user|system_favorite)；UNIQUE 部分（kind=system_favorite 仅一行）；created_at/updated_at/deleted_at；sort_order INT。
`playlist_tracks`：id PK；playlist_id FK；track_id FK；position INT NOT NULL；added_at；UNIQUE(playlist_id, track_id)（REQ-PL-03 重复拦截 DB 级）；索引 idx_pt_pos(playlist_id, position)（播放全部顺序 REQ-PL-06）。

**历史与少播**

`play_history`：id PK；track_id FK；played_at INT；completed BOOL；device_id；索引 idx_history_played(played_at DESC)；淘汰规则：>500 条时按 played_at 删除最旧（应用层批次，事务 100 条/批）（REQ-PL-05）。
`few_watch_list`：track_id PK；added_at（REQ-PLAY-04；「设置可清空」=全表删除+该操作产生 sync 墓碑）。

**歌词域（lyrics）**

`lyrics_meta`：track_id PK；type ENUM(none|embed|lrc|paste|asr)；lrc_path TEXT nullable（同目录 `.lrc`，REQ-LYR-03）；source_text TEXT nullable（paste 临时内嵌）；offset_ms INT default 0（REQ-LYR-03）；updated_at；edited BOOL。
`lyrics_gen_jobs`：id PK；track_id FK；status ENUM(queued|running|pausing|paused|preview|committed|failed|no_voice|cancelled)；progress REAL；model_id FK→model_registry；created_at/updated_at；started_at/finished_at；error_code nullable；UNIQUE(track_id)（队列聚合 5 首批量=job 序列，串行执行 REQ-LYRAI-03）。

**提取域（extract）**

`extract_tasks`：id PK；source_type TEXT；source_id TEXT；url TEXT；title/uploader/duration_ms nullable（resolve 后填）；quality ENUM(64k|128k|192k|hires)（选择值由登录态决定可用域）；progress_pct REAL；status ENUM(resolved|gating|gated|downloading|paused|transcoding|registered|failed|dup)；error_code nullable（network|auth|dup|disk|transcode）；output_rel_path TEXT nullable；cookies_used BOOL；retry_count INT default 0；created_at/updated_at；UNIQUE(source_type, source_id)（同源重复→dup 走 REQ-EXT-06 状态而非重复行）；产物文件本体在应用私有目录，注册入 track 后以 rel_path 溯源。

**同步域（sync）**

`sync_channel`：id PK；type ENUM(webdav|onedrive|gdrive|github)；base_url TEXT；remote_dir TEXT default 'iA-Music/'；username nullable；credentials_ref TEXT nullable（SecureStorePort key，**凭据本体不入 DB**）；is_active BOOL；部分唯一索引（active=TRUE 恰 1 行）（MVP 单通道 C44）；last_test_at BOOLEAN result。
`last_sync_state`：channel_id PK；last_started/completed_at；pending_up/pending_down INT；summary_json TEXT（REQ-SYNC-07 成功 N/失败 M）。
`tombstones`：id PK；entity_kind ENUM(track|playlist|playlist_item|few_watch|lyrics_meta)；entity_local_id INTEGER；deleted_at INT；deleted_by_device TEXT；remote_cleared_at nullable（**仅传播记录；永不触发云端文件删除**——红线，代码级断言：SyncChannelPort 无 delete 语义）；索引 idx_tomb_kind_time。
`conflict_copies`：id PK；origin_kind TEXT；origin_local_id INTEGER；winner_value_json/loser_payload_json；lost_at；deleted_at nullable（REQ-SYNC-04 可查看/删除——删除=软删本行；**ISS-503**：原字段清单遗漏该列，S1 走查发现补齐）。

**壳层域**

`settings`：key TEXT PK；value TEXT(JSON)；updated_at；指纹 keys：`repo.paths`、`appearance.theme`(dark|light|system × DEC-005)、`appearance.lang`(zh-CN|en-US|系统×DEC-005)、`compliance.acknowledged_at`（REQ-ONB-03 门禁位）、`eq.user`。
`model_registry`：model_id TEXT PK（sensevoice-int8-20240717）；size_bytes；sha256；status ENUM(absent|downloading|paused|present)；local_path nullable；downloaded_at。

### 1.3 索引 ↔ 实际查询对应表

| 查询（REQ 锚点） | 走的索引/机制 |
|---|---|
| 全局搜索含拼音（REQ-NAV-04） | tracks_fts MATCH('yhw' OR pinyin 前缀)；结果 join tracks |
| 曲库排序（REQ-LIB-06） | idx_track_album/artist + title/added_at/duration 临排（1 万行仅分页） |
| 随机池取样（REQ-NAV-02/PLAY-03） | WHERE deleted_at IS NULL AND missing_at IS NULL + NOT IN few_watch → 首列索引近似扫描+内存采样 |
| 当前队列/歌单浏览（REQ-PL-04/06） | idx_pt_pos |
| 历史分组（REQ-PL-05） | idx_history_played DESC |
| dup 检测（REQ-EXT-06） | idx_track_source 唯一查 |
| 增量扫描 diff（REQ-LIB-02） | UNIQUE(root, rel_path) upsert 比对 |
| 墓碑比较（REQ-SYNC-04/05） | idx_tomb_kind_time |
| 泛查询的 FTS 更新 | 同事务（§1.2 惯例） |

### 1.4 迁移与回退

- drift schema v1（上述全量初版）起步；版本链只增；破坏性变更兼容一期（新旧列并存+写双列读新列）。
- 回退门：迁移失败→开只读连接+壳层「修复引导」（不闪退、不丢数据；写操作禁用直到开发者工具修复）。
- DB 决策留痕：`FTS5 拼音双列方案`、`随机池内存采样+NOT IN`、`play_history 应用层淘汰` 按开发者拍板轮 DEC-009（如拍板轮确认则在 T2 收口时记录）。

通过标准（DETAIL-01）：14+FTS 全表字段可答六问；9 组查询索引逐一对应；迁移回退门明确。

## 2. 接口契约（DETAIL-02）

- **NA 记录（ISS-301）**：无自有服务端/无外部 HTTP API；OpenAPI 不适用。契约形态=Dart 接口签名 + 异常枚举表 + 时序要点；工具验证=Dart analyzer（契约以独立 `contracts/` 包编译校验）。

### 2.1 七 Port 签名（聚合级；全签名以 `contracts/` 包为准）

```dart
// EnginePort —— 播放引擎（双态：MpvEngineAdapter ‖ PairedEngineAdapter[回退]）
abstract class EnginePort {
  Future<void> init(EngineConfig cfg);                     // cfg: 跨端桥选择/缓冲参数；不得重复 init
  Future<void> loadAndPlay(QueueSnapshot snapshot, int startIndex);
  Future<void> play();    Future<void> pause();
  Future<void> seekTo(int positionMs);
  Future<void> setEqBands(List<double> gains);              // 不支持双端 EQ → EngineCapabilityException
  Stream<EngineEvent> get events;                           // stateChanged|positionTick|itemEnded|error|sessionLost
  Future<void> restore(SessionSnapshot snaps);              // 后台回收后恢复队列/进度（ARCH-03 §3.2）
  Future<void> dispose();                                   // 桌面退出即净（§4.2 ARCH）
}

// DownloaderPort —— R1（双态：Android AAR 内嵌 ‖ 桌面 Process [yt-dlp + LGPL ffmpeg]）
abstract class DownloaderPort {
  Future<ResolvedMeta> resolve(String sharedUrl);            // ≤5s 承诺（REQ-EXT-01)；impl 注意 --no-simulate 纪律（EXP-001）
  TaskHandle download(DownloadPlan plan);                    // plan 含 quality(64k..hires)/cookiesRef/输出私有目录
  Stream<TaskEvent> get stream;                              // progress|stagedDone|paused|resumed|failed(code)
  Future<void> pause(TaskHandle h);  Future<void> resume(TaskHandle h);
  Future<void> cancel(TaskHandle h);                          // 资源释放=进程 kill+分片清理（§4.4）
}

// AsrPort —— R3（sherpa_onnx + SenseVoice int8；双态标注=引擎同一，模型可换）
abstract class AsrPort {
  Future<bool> isReady();                                    // model_registry.status==present 且 sha256 已验
  Future<void> prepare(String modelPath);                    // isolate 内加载；失败→ModelInvalidException
  AsrHandle transcribe(String wavPath, {CancelToken? token}); // 16k 单声道；分块 decode；块边界响应取消（C38）
  // AsrResult: segments[]；segments 空 → no_voice（REQ-LYRAI-05，不生成空文件）
}

// MetadataPort —— audio_metadata_reader（只读，绝不写回原文件 REQ-LIB-03）
abstract class MetadataPort { Future<ParsedMeta> read(String audioPath); }

// CoverFetchPort —— CAA 主源 + iTunes 兜底；令牌桶 1req/s；UA 强制；只补缺（C22）
abstract class CoverFetchPort { Future<CoverResult?> fetchTrackCover(TrackQuery q); } // 失败静默=null

// SyncChannelPort —— WebDAV/MVP（Phase2 再多通道）；put 无 delete 语义（红线断言）
abstract class SyncChannelPort {
  Future<TestResult> testConnection(ChannelConfig cfg);       // 失败带人话 reason（REQ-SYNC-01）
  Future<RemoteDiff> diff(String remoteDir, LocalManifest local);
  Stream<TransferEvent> putFile(String remote, File f, {ChunkPlan? chunked}); // chunked=断点续传自研（C36）
  Future<Bytes?> getFile(String remote);                      // Range resume inside
}

// SecureStorePort —— flutter_secure_storage（Keystore/DPAPI/libsecret）
abstract class SecureStorePort { Future<String?> read(String key); Future<void> write(String key, String v); Future<void> delete(String key); }
```

### 2.2 异常→UI 文案对应（示例集，契约包内全量）

| 异常 | UI 文案（人话） | REQ 锚点 |
|---|---|---|
| `EngineEqUnsupportedException` | 「当前设备音频输出不支持均衡器调节」 | REQ-PLAY-07 明示不支持 |
| `AuthExpiredException`（提取） | 「B 站登录状态过期，请重新扫码」 | REQ-EXT-05 |
| `DuplicateSourceException` | 「该视频已提取过，可选择重新提取」 | REQ-EXT-06 |
| `ChannelAuthFailedException` | 「授权过期或地址/凭据有误，请重新授权」 | REQ-SYNC-01/06 |
| `DiskFullException` | 「存储空间不足，已暂停；可用空间 X 后继续」 | sync/extract 双域 |
| `NetworkLostException` | 「网络连接中断，任务已暂停，本地数据不受影响」 | REQ-SYNC-06 原话 |
| `AsrNoVoiceException` | 「未检测到人声，未生成歌词文件」 | REQ-LYRAI-05 |
| `ModelInvalidException` | 「模型文件校验失败，请重新下载」 | ONB-05 |

### 2.3 MethodChannel/平台桥（Android 必要桥）

| 桥 | 用途 | 备注 |
|---|---|---|
| 通知/前台服务 | 后台播放与提取通知（REQ-PLAY-05/EXT-04） | 由引擎桥与 DownloaderPort 内部装配 |
| SAF/目录选择 | 仓库/下载目录授权 | file_picker 系插件；仅取目录授权不申请整库权限 |
| 分享 Intent | 可选：分享文本接收至提取页（P1 顺带） | 不阻断 MVP |

### 2.4 通过标准（DETAIL-02）

实现者仅凭本节+契约包可重写任一 adapter；异常=文案一一对应（合成卡兜底记录于 §2.2 缺省行为）。


## 3. 方法行为（DETAIL-03）

6 个聚合级方法；每条=前置/输入输出/后置/不变量/边界/副作用（触达表与 Port 附注）。

### 3.1 `ScanService.scan(root: RepositoryRoot, mode: full|incremental) → Stream<ScanProgress>`

- 前置：root.path 存在且可读；`compliance` 无关；并发同一 root 一次（任务锁）。
- 流程：枚举音频文件（.mp3/.flac/.m4a/.ogg/.wav/.ape）→ MetadataPort.read → `library` upsert（批 200/事务）→ FTS+拼音列同事务 → artists/albums 字典 upsert。
- 后置：tracks 计数=实际音频文件数（**真实计数红线**）；上轮全量中消失文件→missing_at（REQ-LIB-05 灰显；放回→恢复可用）；不自动删除 track 记录。
- 不变量：同一 (root_id, rel_path) 唯一；文件名相同且内容哈希相同→视为同一文件（DEC-002 语义）。
- 边界：损坏/零字节文件→跳过计数（不中断）；权限中途失效→任务暂停+人话提示。
- 副作用：NAV-03 区块数据（最近入库/最近播放）失效重算；搜索索引实时可用。
- 触达：repository_roots / tracks / artists / albums / track_index(FTS)；MetadataPort。

### 3.2 `ExtractQueue.enqueue(linkText, quality, {withLyrics}) → ExtractTask`

- 前置：`settings.compliance.acknowledged_at` 非空（REQ-ONB-03 未确认→状态 gating 拦截+引导页）；同源唯一（dup→REQ-EXT-06 分支）。
- 输入：分享文本（多行多链接逐条拆）；输出：任务行+进度流。
- 后置：成功→`library` 注册 track（事务）+ extract_tasks.status=registered→（勾选歌词）lyrics_gen_jobs 追加 queued（REQ-EXT-08）。
- 不变量：下载产物先私有目录后注册；注册失败→产物保留在隔离区（待重试或用户清理），**不影响曲库**。
- 边界：断网→paused 人话；Cookie 失效→AUTH_FAILED（高音质请求时）；磁盘预检（空间不足提前拦截→disk）。
- 副作用：progress 流驱动 UI/通知；Dup 检测同时查 tracks.source+content_hash。
- 触达：extract_tasks / tracks；DownloaderPort、SecureStorePort（cookie）、AsrPort（歌词入队只排期）。

### 3.3 `SyncEngine.run(trigger: autoDebounce|manual) → SyncSummary`

- 前置：is_active 通道配置；凭据可解；== manual 立即；autoDebounce 进入 30s 防抖（新变更重置）。
- 流程：PREPARE=scan_diff（本地 manifest vs 远端目录清单+墓碑时间戳比较）→ TRANSFERRING：up=轻数据 JSON+音频分块（断点自研）；down=远端新条目拉取（缓存/临时→校验→入库事务）。
- 后置：last_sync_state 更新（N 成功/M 失败人话摘要 REQ-SYNC-07）；冲突副本按 last-writer-wins（REQ-SYNC-04）。
- 不变量：**本地数据无损**（RED LINE）；变更延迟 ≤30s（REQ-SYNC-02 观感）；删除仅传播记录；远端文件永不因子端删除而删。
- 边界：状态机异常互斥（§4.1）；GitHub 通道=轻数据 only（REQ-SYNC-08，音频开关禁用 UI+逻辑双侧）。
- 副作用：分块清单在云端 `iA-Music/` 目录（默认）随主目录一并可见。
- 触达：sync_channel/last_sync_state/tombstones/conflict_copies/tracks 系（同步读写门经唯一写者约束）；SyncChannelPort。

### 3.4 `LyricsGenQueue.attach(trackIds) → job`（以及 preview/commit/cancel）

- 前置：model present+sha 已验（未就绪→引导下载 onboarding REQ-LYRAI-01）；
- 流程：音频→16k mono wav → AsrPort.transcribe（isolate+分块；token 取消）→ segments→LRC（line timestamps）→ 预览（可编辑）→ commit=落 `.lrc` 同目录+lyrics_meta（type=asr,edited=true 可回归）。
- 后置：进度条/队列逐首（REQ-LYRAI-02/03）；commit 后播放页可立即可用（REQ-LYRAI-04）。
- 不变量：未 commit 不写 lyrics_meta；no_voice 不产文件（REQ-LYRAI-05）；断网无碍（REQ-LYRAI-06 离线）。
- 边界：批量处理可暂停/取消队列；临时 isolate 崩溃→本次预览丢弃+提示（已 commit 不受影响）。
- 副作用：占用大核（构建进程优先级降低、UI 帧率保障）；临时 wav 清理。
- 触达：lyrics_meta / lyrics_gen_jobs / model_registry；AsrPort、MetadataPort（时长/转换）。

### 3.5 `CoverChain.decide(track) → CoverResolution`

- 顺序（REQ-LIB-04）：内嵌图 → 同目录图 → 在线（仅完全无封面时，REQ-LIB-08）→ 首字母色块。
- 后置：命中在线→同目录 `.cover.jpg` 落盘+registry 位（library 唯一写者）→UI 即时替换；失败/离线→静默色块（不报错）。
- 不变量：**只补缺，不覆盖**（C22 红线）；CAA/iTunes 检索失败不重试（静默降级为色块）。
- 边界：多候选→取 ResolutionPriority 顺序（CAA 1200/500/250 优先）；版权自担提示仅在「在线封面」设置项说明处出现。
- 触达：cover 状态列+磁盘缓存；CoverFetchPort。

### 3.6 `EnginePort.restore(SessionSnapshot)`（后台回收/崩溃恢复）

- 前置：快照存在（会话未失效）；
- 后置：队列+位置恢复；媒体会话重绑（三端：MediaSession/SMTC/MPRIS）；
- 不变量：恢复失败→App 层级重试 1 次（双态 adapter 切换允许）；二次失败→「播放服务异常」UI（ARCH-03 §3.2）。
- 触达：playback 域快照（内存/轻持久）；EnginePort。

### 3.7 通过标准（DETAIL-03）

六方法均可 5 行说清；歧义点=0（每条边界行为都有唯一归属）；跨模块只经接口（不直触他域表）。


## 4. 状态机与失败语义（DETAIL-04）

### 4.1 sync 状态机逐态（与 `sync_vibe_spec.md` 逐态对齐；ARCHITECTURE §7 末项关闭）

| 态 | 入口/迁移 | 入口动作 | 出项 | 谁可触发 |
|---|---|---|---|---|
| IDLE | LOCAL_CHANGE→DEBOUNCE；MANUAL_SYNC→PREPARE | 待机 | — | 变更通知/用户按钮 |
| DEBOUNCE（30s）| TIMEOUT→PREPARE；NEW_CHANGE→重置计时 | wait_30s | — | 计时器 |
| PREPARE | DIFF_EMPTY→IDLE+toast(已是最新)；DIFF_FOUND→TRANSFERRING | scan_diff（本地 manifest↔远端清单+墓碑比较） | — | 状态机 |
| TRANSFERRING | DONE→IDLE+summary；NETWORK_LOST→PAUSED；AUTH_EXPIRED→NEEDS_REAUTH；DISK_FULL→SUSPENDED_DISK | 上传轻数据 JSON→音频分块（断点）；拉取远端新条→校验→事务入库 | 进度流/文件名+速度 | 状态机 |
| PAUSED | NETWORK_BACK→TRANSFERRING(resume)；手动放弃→IDLE（任务清单保留） | show_reason（明示原因；本地无损） | — | 网络/用户 |
| NEEDS_REAUTH | REAUTH 成功→TRANSFERRING | 原位重新授权 UI（REQ-SYNC-06） | — | 用户 |
| SUSPENDED_DISK | SPACE_OK→TRANSFERRING(resume) | 明示磁盘不足+清理引导 | — | 系统事件 |

冲突（内嵌规则，非转移）：记录级 last-writer-wins by updated_at；败者→conflict_copies(origin_id)；歌单结构冲突→集合并集；删除按墓碑时间戳比较（较新胜）。多通道=Phase 2（C44）。

### 4.2 extract 任务机逐态

`RESOLVED`（解析完成，展示信息）→`GATING`（合规未确认，REQ-ONB-03 拦截，等待声明）→`GATED`（已确认/立即下载）→`DOWNLOADING`（断点 off↔min；paused 由用户/网络触发）→`TRANSCODING`（ffmpeg 转码，可失败 transcode）→`REGISTERED`（入库事务成功）‖ 结局集：`FAILED(network|auth|disk|transcode)`（retry_count 增；UI 入失败清单可重试 REQ-EXT-05）与 `DUP`（REQ-EXT-06 用户选择 skip|re-extract；skip→本行终态）。

### 4.3 重试/超时/部分失败/补偿与资源释放

| 场景 | 重试策略 | 上限 | 结局 |
|---|---|---|---|
| 提取下载断点 | 恢复续传；网络级指数退避（1s/4s/16s） | 3 次/任务 | FAILED(network) 入清单，手动重试无遗留半成品（分片清理） |
| 转码失败 | 不自动重试（输入可疑） | 1 次（仅 kill 后重投） | FAILED(transcode)+产物隔离 |
| sync 分片上传 | 分块级续传+通道错误重试 | 3 次/块 | PAUSED（REQ-SYNC-06） |
| 模型下载 sha 失败 | 删除半成品→允许手动重下 | ∞（用户手动） | prompt 校验失败 |
| 批量扫描入库批事务 | 批内失败整批回滚→批重试 | 2 次/批 | 跳过计数+扫描日志（REQ-LIB-01 可无无人损） |
| DB 唯一冲突（upsert 竞态） | 幂等 upsert（INSERT OR IGNORE/ON CONFLICT UPDATE） | — | 写者语义一致 |
| **资源释放** | 桌面进程=退出码回收+超时 kill（3s 宽限）；isolate=块边界 cancel；临时目录（下载分片/转码中转/模型半成品）=终态即清理；引擎会话=dispose 全净 | — | 无泄漏默认 |

任何重试均有条件/上限；默认无限重试禁止（规则原文；上表上界为准）。

### 4.4 通过标准（DETAIL-04）

sync 状态机与 vibe spec 原文逐态一致（7 态全覆盖）；extract 状态机结局唯一；重试表全部有上限；资源释放五类（进程/isolate/临时/缓存/会话）均有 owner。

## 5. 跨文档映射（DETAIL-05）

### 5.1 REQ 组 ↔ 产出构造 ↔ 验证锚点矩阵（63 REQ 全覆盖；细分行=锚点组）

| REQ 组 | 数据表 | Port/方法 | TEST（Gherkin 锚） | 架构场景（ARCHITECTURE §3） |
|---|---|---|---|---|
| REQ-ONB-01..08 | settings/model_registry/repository_roots | shell 流程+LyricsGenQueue 引导 | FTUE 组 | §3.1/§3.6 |
| REQ-LIB-01..08 | tracks/roots/字典/FTS/cover 位 | ScanService.scan；CoverChain.decide | 曲库组（扫描/排序/封面） | §3.1/§3.5 |
| REQ-PLAY-01..08 | play_history/few_watch/队列快照 | EnginePort.loadAndPlay/restore；RandomPool | 播放组（随机/后台/EQ/缺失跳过） | §3.2 |
| REQ-PL-01..06 | playlists/playlist_tracks | playlists 域 CRUD | 歌单组 | §3.2 |
| REQ-LYR-01..05 | lyrics_meta（offset/lrc_path） | lyrics 域解析/偏移存 | 歌词组 | §3.5 |
| REQ-LYRAI-01..06 | lyrics_gen_jobs/model_registry | LyricsGenQueue.attach/commit/cancel；AsrPort | ASR 组（下载/进度/批量/纯音乐/离线） | §3.5/§3.6 |
| REQ-EXT-01..08 | extract_tasks/Cookie(SecureStore) | ExtractQueue；DownloaderPort | 提取组（解析≤5s/登录高音质/排队/失败恢复/dup/合规/歌词联动） | §3.3 |
| REQ-SYNC-01..08 | sync_channel/last_sync_state/tombstones/conflicts | SyncEngine.run；SyncChannelPort | 同步组（闭环/墓碑/断网） | §3.4 |
| REQ-NAV-01..06 | —（壳层路由+跨域查询） | shell | 导航组（三 Tab/搜索 300ms/随机入口） | §3.1/§3.2 |

### 5.2 语义核对清单（唯一事实源=本文件）

- 音质枚举：`64k(30216)|128k(30232)|192k(30280)|hires`（匿名可用域=64k/128k 依实测？EXP-001 实测 64k@匿名；128k+ 需 Cookie——UI 以登录态划定可选域）。
- 红心：BOOL（favorites playlist 派生视图）；倍速：ENUM(0.75|1.0|1.25|1.5|2.0)；EQ：5 段 60/230/910/3600/14000 Hz gain -12..+12 dB。
- 时间：duration_ms/position_ms（心跳 stream 250ms）；relative time 仅展示层。
- 歌曲名规范化：不存在「同一曲目多行」——dup 拦截在 source_id+content_hash 双保险（REQ-EXT-06+DEC-002 路径匹配）。
- device_id：`sync` 首次启动生成 short-id（用于墓碑溯源），UI 不可见。

通过标准（DETAIL-05）：九组 REQ 全覆盖；96 行矩阵一致性走查通过；枚举/时间语义唯一事实源。

## 6. 实现准备度与测试规格（DETAIL-06）

### 6.1 「编码者不可猜测点」扫描 → 已全部除清

| 潜在疑似 | 判定（本文件位点） |
|---|---|
| 歌单删除时曲库内曲目如何？ | 行不（REQ-PL-02 仅歌单记录）；删除传播走墓碑（§4.1） |
| 移除曲目后本地播放中断？ | EnginePort 事件 itemEnded→top 提示+自动下一首（REQ-PLAY-08） |
| 两端同时编辑元数据？ | last-writer-wins+冲突副本（§4.1 场景内嵌规则） |
| Cookie 谁写谁读？ | extract 唯一写者；secure storage 只进 SecureStorePort（§1.2/§2.1） |
| 匿名 vs Cookie 音质族系？ | §5.2 枚举+登录态划定可选域（EXP-001 实测依据） |

### 6.2 测试规格样例（三例，正/误实现可判）

1. **扫描计数**：fixture 目录 12 个音频（1 损坏+1 零字节）→ 正确实现 Report.total=10、skipped=2、track 行=10；错误实现（坏文件计 0 total）判失败。
2. **墓碑传播**：设备 A 移除《晚风》→ 正确：A 本地团员声团记录消失（放回即恢复）+B 同步后记录消失+cloud 《晚风.flac》保留；错误实现（云端文件删）判失败（红线级）。
3. **ASR 取消**：批量 2 首，进度 40% 取消第一首 → 正确：job2 仍可插入；job1 状态=cancelled；临时 wav 删除；错误实现（取消后队列卡死）判失败。

### 6.3 开发者确认清单（提交验收时逐点确认）

- [ ] 对外行为：提取（合规门禁/音质族/失败恢复）、同步（冲突/墓碑）、删除语义 ☐
- [ ] 数据设计：§1.2 全表（重点 tombstones/conflict_copies/tracks_deleted 语义） ☐
- [ ] 关键契约：EnginePort 双态、DownloaderPort（AAR/Process）、SyncChannelPort 分块续传 ☐
- [ ] 重试上限表与资源释放归属 ☐

### 6.4 通过标准（DETAIL-06）

疑似零点=已全除清；三例测试规格可判定实现正确性；验收后实现者无需回溯 PRD 即可编码。

