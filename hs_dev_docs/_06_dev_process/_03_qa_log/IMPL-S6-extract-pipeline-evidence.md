# IMPL S6 证据：提取管线（T9 / TASK-S6 / CP-S6）

- **时间**：2026-10-19（S5/检查点 A / D1 签收后启动；开发者裁决=先开干、RV-B 项挂账）
- **任务**：`iA-Music-BUILD-5` / 阶段 4 TASK-S6 / CP-S6
- **形态**：桌面 Process 先行（`py -m yt_dlp` + `C:\Users\hardstone\tools\ffmpeg`，EXP-001 锚；模型=R3 SenseVoice int8 真实 239MB 在位）
- **工作状态：VERIFYING → 提交候选（SUBMITTED 待签收）。** 未进入 S7。
- IMPL-06：PENDING；开发者尚未签收 S6，不能标记 ACCEPTED。

## 1. 交付物（公共 Port 契约 + 实现）

| 件 | 文件 | 说明 |
|---|---|---|
| 契约增量 | `app/packages/contracts/lib/src/extract.dart` | ResolvedMeta **增补 `coverUrl` 字段**（REQ-EXT-01 解析卡封面展示位；其余 Port 面未动） |
| 适配器 | `app/lib/adapters/downloader_adapter.dart` | DownloaderPort 桌面实现：真 `py -m yt_dlp` 进程（解析=-J 元数据；下载=不带 `--print`，EXP-001 纪律）；Cookie 仅经 SecureStore key → 临时 cookies 文件随进程终态即删（C50：不落日志/库）；Windows 树杀 taskkill /T /F；停/续/取消=kill+.part 保留/清分片 |
| 队列 | `app/lib/extract/extract_queue.dart` | §3.2 方法 + §4.2 任务机：合规门禁→dup 双保险→串行泵→重试退避（1s/4s/16s ≤3）→staging→迁移→事务注册→quarantine→歌词联动 |
| 页面 | `app/lib/ui/extract/extract_page.dart` | 合规声明卡（门禁 RED 引导）+粘链解析卡+音质展示+歌词勾选+任务队列（进度/失败清单/重新提取/取消） |
| 入口 | `app/lib/ui/library/library_list_page.dart` | 音乐空间 AppBar「提取」入口（`extract_entry`）；队列=壳层生命周期（LibraryHub.extract） |

## 2. DoD 对账（七条）

| DoD | 断言 | 证据 | 状态 |
|---|---|---|---|
| 1 合规门禁 | 未确认→enqueue 抛 StateError 且**零任务行**（UI 引导页拦截）；确认后 `compliance.acknowledged_at` 真写入（Settings 行） | `test/extract/s6_gate_dup_test.dart`（4 断言）+ `s6_gate_ui_test.dart`（真 Settings 位+声明卡→主界面切换） | **PASS** |
| 2 解析 ≤5s | 真链接 BV17x411w7KC（EXP-001 同源锚）：标题/UP 主/时长/音质列表（真实 formats 30216 等位映射）；解析耗时断言 <5s；coverUrl 增量字段 | `s6_link_e2e_test.dart` 解析段（stopwatch 断言）。**如实**：解析卡封面展示=URL 字面（首拍即下转为下载段），卡片渲染面在 §4 UI 演示补 | **PASS** |
| 3 dup | extract_tasks UNIQUE 行复用 + tracks.source 二道闸 → dup 终态行（errorCode=dup）；`reEnqueue` 复位重跑；UI 重新提取按钮 | `s6_gate_dup_test.dart` 第二用例（库行数不变+单行终态）+ e2e 末段（已注册同源再 enqueue→dup） | **PASS** |
| 4 失败恢复 | 代码路径齐：classify(network/auth/disk)→网络退避 1s/4s/16s ≤3 次/任务→FAILED(network) 入失败清单；auth 不自动重试；pause 保 .part（staging 确定路径 `<tmp>/ia_extract/<sourceId>`）+ 以原 plan 重提=断点续传 | 实现代码（chain 自查）；**真实断网/AUTH 失效演练=挂账 D2/窗口**（EXP 同 S5 断网纪律；不引入伪造网络） | **代码就位 / 真演练挂账** |
| 5 自动入库 | TRANSCODING→REGISTERED 事务（复用批插单件+字典+FTS+source 列回写）；产物先私有 staging→迁移 `仓库/提取/UP - 歌名.mp3`（合规命名）→注册失败 quarantine 隔离；库不动 | `s6_link_e2e_test.dart`（产物在仓库、staging 终态清空、contentHash 64 位、source 列断言）+ `s6_register_fail_test.dart`（真实磁盘态触发 FAILED(disk)+库不动+无半成品） | **PASS** |
| 6 歌词联动 | 勾选→注册成功→lyrics_gen_jobs **queued**（REQ-LYRAI-03 串行语义由 S7 消费）；模型 present=真实 R3 SenseVoice int8（real SHA-256 现算） | `s6_link_e2e_test.dart` 歌词段（1 job、queued、trackId 齐） | **PASS** |
| 7 排队后台 | 串行泵=同一时刻至多一活动下载（ EXT-04）；取消=树杀+无 .part 残留+行删除 | `s6_cancel_test.dart`（真进度>0→取消→行删+无 .part+库 0 行）。**3 链接真实串行实跑未做**：挂账 D2 演练（单链 e2e 已证全链条；串行性=泵结构，逐链复跑成本高） | **单链全真 PASS / 3 链挂账** |

## 3. 权威绿跑记录

- `flutter test --reporter json`：**93/93 PASS、0 error、0 skipped**（machine 记录 `output/qa/S6-full-test-final-m.log`；口径=基线 87 + S6 新增 6：gate/dup、UI 门禁、e2e、cancel、迁移失败路径）。
- `flutter analyze`：**No issues found**（`output/qa/S6-analyze.log`）。
- 过程实录（git 无往返）：分析期曾 1 项 CAA 用例在全量并发下走 §3.2 镜像 500 抖动降级 iTunes（历史段实 logging）；单文件复跑全真命中后重跑全量 93/93——如实入 `change_log`，未跳过未弱化。
- 代理窗口依赖：同 S5（本记录全程 HTTPS_PROXY=127.0.0.1:7897；S6 解析/下载对 bilibili 直连，代理影响面=CAA 用例）。

## 4. 挂账与如实差异（不阻塞提交候选）

| 项 | 性质 | 计划 |
|---|---|---|
| DoD4 真实断网→paused→恢复续传 | 真实网络开关=演练条件（S5 同源纪律） | D2 演练现场 or 专用网络窗口 |
| DoD4 AUTH_EXPIRED 人工态 | 真实 Cookie 失效=需真实登录→失效流程，无伪造值 | D2 现场（C50 日志 grep 断言同场做） |
| DoD7 三链接串行全真复跑 | 真实多链路下载成本 | D2 演练 |
| 扫码登录高音质 UI（REQ-EXT-02 上半） | S6 边界内含扫码登录整链（passport.bilibili.com 真 API）；本轮未开工=如实差额 | S6 签收后第一补项（真 API 全真实现+演练扫码） |
| 解析卡封面渲染 | ResolvedMeta.coverUrl 已入契约与适配器；页面未消费 | S6 签收后小补 |

## 5. 与既有签收的界面

- S0–S5 不动（queue/daos 只读复用 ExtractDao.createOrGet、LibraryDao 批插、LyricsDao.schedule）。
- 契约 ResolvedMeta 增量=本档 header 记录源；`contracts` 包 analyze 0。
- S6 Android 侧开工仍前置 RV-B（AAR 真机嵌入）；本节点=桌面形态，RV-B 不因本提交解除。

## 6. 候选后增补（2026-10-19 开发者实机日扰动与修复实录）

### 6.1 产品首次实跑装配（如实缺口修复）
- 事实：`lib/main.dart` 一直保持 Flutter 计数器模板，S0–S6 组件**从未进入应用入口**；开发者于模拟器实跑发现「Flutter Demo Home Page」。
- 修复：入口改真装配 = `openIaDatabase`（含 §1.4 回退门）→ `LibraryHub` → 三 Tab `HomeShell`（NAV-01）+ AppBar `extract_entry`；只读门时顶部横幅 `kRecoveryHint`。原 `widget_test.dart`（计数器冒烟）重写为**真库真壳**冒烟（内存 SQLite 真引擎，断言三 Tab/入口/空态）。
- 实跑面：`ia_s5_cover` 模拟器真装真跑——壳/音乐空间/提取页合规声明卡/提取主界面真渲染（截图 `output/qa/S6-app-live-2/3/4.png`）。

### 6.2 契约增量（第二条）
- `contracts` 新增 `FormUnsupportedException`（人话：『提取功能当前为桌面端形态（Windows），Android 端将在后续版本支持』）。触发实证=开发者模拟器实跑解析报「链接解析失败」误导人话；根因=Android 无桌面工具链，`Process.run` 抛 `ProcessException` 被当作链接失效。现两类错误分流（诚实红线）。
- 同窗记录实报链接真验证：开发者现场链接 **BV1ANQqBTEVU**（有效、无需登录）：单文件真跑用例 `test/extract/s6_user_link_test.dart` 真解析 ≤5s 全字段（title/uploader/296s/30216·30232·30280/coverUrl）。

### 6.3 权威记录刷新（候选口径更新）
- machine 记录（`--concurrency=1` 消请求突发）：**95/95 PASS、0 FAIL、0 SKIP、0 加载故障，退出 0**（`output/qa/S6-full-test-final-m.log`；口径=原 93（含重写冒烟 1）+ 实报链接用例 2）。
- `flutter analyze`：**No issues**（`output/qa/S6-analyze.log`）。
- 过程实录（不再重复计数动机，全程真实网络）：全量并发 4 连跑中 S5 封面真网络用例两次降级（MusicBrainz 全天高频=限流窗口；冷却后单文件 4/4 全真命中复证）；一次全量出现 s3 套件 7 用例同刻加载错误（95 宇宙对齐、单文件复跑 7/7 全真、复跑全量读秒即消）——均如实入 change_log，未跳过未弱化。

### 6.4 桌面端（Windows）环境挂账（真跑前置）
| 项 | 状态 |
|---|---|
| VS 「C++ ATL」组件（flutter_secure_storage_windows 需 atlstr.h） | **开发者动作**（管理员安装后桌面端可全跑，S6 Process 形态也在此首启） |
| `mpv_audio_kit` 0.5.1 pub 缓存 CMakeLists 补 `/utf-8`（中文代码页 C4819 当错误） | 已修=缓存内第三方文件修补；pub cache 刷新后需重打（环境补丁，登记） |

## 7. Android 侧 T9A 实证档（AAR 全真链，x86_64 模拟器先行；2026-10-19）

### 7.1 装配与依赖（锁组件实证）
- `dev.ffmpegkit-maintained:yt-dlp-android:2.0.2`（Chaquopy 内嵌 CPython 3.13 + yt_dlp 2026.6.9）+ `dev.ffmpegkit-maintained:ffmpeg-kit-full:8.1.7`（`com.arthenica.ffmpegkit` 包名，logcat 实证 `--enable-libmp3lame`、`ffmpeg-kit-custom-x86_64-8.1-20260712`）。
- fork POM 未声明 `com.arthenica:smart-exception-java` → 补显式 `0.2.1`（缺它 FATAL `NoClassDefFoundError`，已修+编译验证）。

### 7.2 yt-dlp 运行时升级（2026.6.9 → 2026.8.19）
- AAR 打包版被 B 站指纹级拒绝（vt-dlp 412/TLS RST）；宿主对照实验锁定结论后，运行时从 PyPI 拉 `yt_dlp-2026.8.19-py3-none-any.whl`（3,185,533B）解包 `files/ytdlp_override` + `sys.path.insert(0)` 压过打包版（marker `version.txt`→2026.8.19，失败回落打包版）。实证：Android 端 resolve 成功且 minutes-duration 元数据真返回。

### 7.3 模拟器网络语义（验证配置，非产品行为）
- 提取流量经宿主代理 `http://10.0.2.2:7897`（python `opts['proxy']` + Kotlin `Proxy` 双侧）；真机直连不走此分支。仓库根 `repository_roots` 行经 run-as sqlite3 直插（mode=.name 序列化注意已记入工作备忘）。

### 7.4 下载链修复实录（本节全为 logcat/实测证据）
1. **mcdn PCDN 节点 Range 语义**：流 URL 为 `xy….mcdn.bilivideo.cn:8082`（P2P CDN）；对 `Range: bytes=N-` 回 **416**（mcdn 返回无 Content-Range；官方节点 `upos-sz-mirrorcoso1` 回 416 + `Content-Range: bytes */3716075`）。
2. **关键判读**：`*/3716075` = 半成品已达全文件长度。前情「下载卡死」实证为 **下完后 PCDN 连接不发 FIN、read 挂死**（非 stall 段丢失）；看门狗 `disconnect()` + 重试收口即治。
3. 落地修复（`MainActivity.kt`）：
   - `downloadStreamWithRetry`：≤3 次；416→按 Content-Range 判定「已满收→直接完成」或「续传无效→删残重下」；其余 IO 异常保留半成品带 Range 重试（logcat：`416 but part complete → done` / `resp=200 len=3716075` 2 秒满收）。
   - `scan` 看门狗 90s 无位移 → `disconnect()` → 外层重试（治「下完不 FIN」）。
4. **转录 args 顺序**（ffmpeg CLI 强约束，两次实证报错后修正）：先列全部 `-i` 输入、再列输出选项（输出选项后跟 `-i` → "apply an input option to an output file"）；显式 `-map` 下不再放 `-vn`（否则封面视频轨被砍）。

### 7.5 终端全链实证（2026-10-19 07:17，模拟器全真）
- 链：UI 驱动解析（真元数据卡：标题/UP/4分56秒/192k·128k·64k）→ 开始提取 → runDownload k192 → mcdn 416 重试收口 → resp 200 满收 3,716,075B（<2s）→ ffmpeg-kit mp3 转录（video:166kB=封面流）→ **任务队列绿勾 `registered`**。
- 落盘：`files/music/提取/那首你最爱的歌谣啊 - …海屿你 - 马也_Crabbit.mp3`（4,849,045B，含封面版；无封面对照版 4,679,335B）。
- DB 对账：`tracks#2`（duration_ms=295992、file_size=4849045、source_type=bilibili、source_id=BV1ANQqBTEVU_p1）；`extract_tasks` status=`registered`。
- 宿主 ffprobe 终验：ID3 title/artist 正确；`Stream #0:1 Video: mjpeg 1920x1080 (attached pic)` + 帧 title=`Album cover`（APIC 实证）；Duration 4:55.99。
- 曲库 UI：音乐空间 1 首，标题/UP/时长全对（截图 `output/qa/S6-android-t9a/*.png`：元数据卡、任务绿勾、曲库行）。

### 7.6 挂账（不阻塞 T9A x86_64 候选）
- arm64 真机验证挂账（APK ~307MB 后续治理）。
- 代理瞬时 SSL 抖动（`DECRYPTION_FAILED_OR_BAD_RECORD_MAC` / `UNEXPECTED_EOF_WHILE_READING`）复现于 resolve 阶段，重试即过；属环境语义非代码缺陷，如实记档。
- override 版本泛化（PyPI latest 自动跟踪）、冷启动 resolve 预算记账：后续可议。

## 8. T9B 拆分档（B 站多 P/合集 → 逐分 P 独立任务；2026-10-19）

### 8.1 产品裁决与契约增量
- 裁决原话：「很多 B 站上面的分享链接是歌曲合计，需要进行拆分，成多个单独的歌曲。」（PLAN T9B 行）
- 契约：`DownloaderPort` 增 `resolveAll(sharedUrl) → List<ResolvedMeta>`（≤5s 量级承诺不变：flat 枚举不逐页取详情；条目级 title/duration/cover 由下载任务对条目 url `?p=N` 二次 resolve 补全——不复核伪造面）。contracts 增量随本节登记。
- 拆分域裁决（实证定）：**该视频自身分 P 页域**。flat 枚举实证：URL 裸打（无 `?p`）对多 P 视频返回全部分 P 条目（BV1ANQqBTEVU→100；BV17x411w7KC→10，条目 url 全部同 BV 实证=自身分 P 非合集劫持）；`?p=1` 锚定反而退出 playlist 上下文（单页直出）；真·单 P 视频（B 站 popular API 实取 BV1j5nj68E48，videos=1）→ 无 entries → 走 `mapYtDlpJson` 全量面恰 1 条。故 flat 条目集语义与「分享一首歌解析一张卡」对单 P 完全兼容（ ouvert 分 P 才拆）。

### 8.2 实现（三面）
- 桌面 `DownloaderAdapter.resolveAll`：`py -m yt_dlp -J --flat-playlist --no-warnings <url>` → `mapPlaylistJson`（flat 条目：url/?p=N、sourceId=BVID_pN、title=条目无则顶面标题 pNN 回退、durationMs=0（不伪造）、qualities=B 站 DASH 枚举族（§5.2 注释口径，任务二次 resolve 仍真读 formats 复核）、coverUrl=null 逐任务真取）。
- Android：通道新 case `resolveAll` → Kotlin `ytDlpPlaylistJson`（`extract_flat:'in_playlist'` 同语义）→ Dart `AndroidDownloaderAdapter.resolveAll` 同映射；单视频回落同路。
- 队列：`parseLinkText` 逐行 `resolveAll` 攤平（多行多链接 × 各自条目集，笛卡尔正常展开）；UI 批量卡（`resolve_batch_card`/`extract_submit_all`）：≥2 条目时渲染摘要「解析到 N 个分页/条目（多 P/合集），每条将作为独立歌曲任务提取」+「全部提取」一次入队（不逐条渲染误导卡：flat 条目无逐条时长/UP）。

### 8.3 桌面真网用例（DEC-010 全真）
`test/extract/s6_link_split_test.dart` 三用例（真 yt-dlp 进程 + 真 SQLite）：100 条目枚举（sourceId p1..p100 全序唯一 + 条目 url `?p=N` + ≤15s flat 口径实测 00:0x 秒级）；BV17x411w7KC 10 分 P 锚（同源断言）；BV1j5nj68E48 真·单 P 锚（恰 1 条全量元数据 durationMs>0/UP 非空）。`flutter analyze` 全仓 0；`:app:compileDebugKotlin` 过。

### 8.4 模拟器 E2E（真 UI 驱动，1080x2400）
- 输入 `https://www.bilibili.com/video/BV1ANQqBTEVU` → 解析卡真显「解析到 100 个分页/条目（多 P/合集），每条将作为独立歌曲任务提取」+ 可选音质（textContent 取证：uiautomator dump）→「全部提取」。
- DB：`extract_tasks` 100 行（id 2..101；id2=p1 终态 **dup**（已 registered 曲库守望）→ dup 门禁真拦实证、id3=p2 ~5s 内全链 **registered**、resolved 98）。
- 截图：`output/qa/S6-android-t9b/s6_split_00_home.png / _01_extract.png / _03_resolved.png / _04_enqueued.png`。

### 8.5 两处如实缺陷修复（拆分场景暴露）
1. **泵崩**：`_runLoop` 用 `getSingleOrNull` 取下一行——resolved ≥2 行即 `Bad state: Too many elements`（07:59:50 p2 下载完成后 08:00:00 实录，随后队列静止 30s 复现）。修复=按 id 升序 `limit(1).get()`（泵=严格串行，多行安全）。
2. **启动无续泵**：泵仅 enqueue/reEnqueue 起步；杀程/重启后遗留 resolved 行无人处理（单任务时代既有缺口，拆分场景放大）。修复=`ExtractQueue.resumeQueued()`（合规门禁一致）+ `main()` 装配点调用。
- 二者均 analyze 0 + 重装回归。

### 8.6 续泵全量对账（收口，2026-10-19 16:27 以最终 DB 为准）
- 修复版装回：boot 20s 内 p3 全链 registered（tracks=3）、p4 downloading、resolved 96 → 续泵实证成立。
- **全量终点（QUEUE-CLEARED，宿主监控 45s×33 采样实录）**：100 任务终态 = `dup 1 + registered 99`，**tracks=100，failed=0**。速率 ~5 首/45s（每首=resolve→mcdn 下载→ffmpeg-kit 转录→注册）。
- **真题名实证（flat 条目在任务侧真补全）**：p02「002. 如果可以 - 韦礼安」、p49「049. 异地恋 - ZAVIS、坤木Joymo」、p99「099. 楼顶上的小斑鸠 - 队长」逐一各异（非派生回退面）。
- 曲库冷启动「100 首」实证（`s6_split_final_library2.png`）。

### 8.7 热刷新缺口修复（如实录）
- **缺口**：曲库快照消费 `hub.revisions`（原只挂 scan/edit/remove），提取注册事件不 bump → 100 首 all-registered 后热读仍「2 首」，冷启动才是 100 首（期间截图 `s6_split_final_library.png` 如实存档）。
- **修复**：`LibraryHub.wireExtractRevisionToRevisions()`（ExtractRegistered → revision bump；main 装配点调用，extract 为 late final 构造期不可订阅）。
- **热刷新实证**：现场再提取 BV1j5nj68E48（真·单 P）注册（tracks=101）→ 不重启回曲库 **「101 首」**（`s6_split_hotrefresh_101.png`）。
- 热刷新期间任务终态口径：`dup 1 + registered 100 = 101 任务`。

### 8.8 全量回归对账（T9B 拆分版，machine log=`output/qa/S6-full-test-t9b-split.log`）
- 总数 98（95 基线 + 新增 s6_link_split 3）；批跑 **96 过 2 败**，两败均在 `test/cover/s5_cover_network_test.dart`（S5 封面真网络域，非 T9B 改动面）：
  1. 「真实不存在曲名（无匹配两源）」：批跑时 `musicbrainz.org:503`（服务端故障冒充无结果被门禁拦住=按设计）。**单文件复跑即消**（复跑实录 `musicbrainz.org:200,itunes.apple.com:200` → 通过）——503 瞬时故障窗语义，同 §6.3 惯例。
  2. 「CAA 主源真实命中」：批跑与复跑均败，实录 `musicbrainz.org:503 / coverartarchive.org:404+307 → 链按设计回退 iTunes`。归因=MusicBrainz 服务端 503 窗（2026-10-19 时段持续）+ archive.org 传输端点经宿主代理不可达（独立复证 `000/5s`）；代码路径与 93/93 基线一致。**挂账择窗复跑（真网络条件窗口，不跳不弱不弱化用例）**。
- 汇总口径：**97/98 实过 + 1 网络窗挂账复跑**；T9B 拆分面新增用例 3/3 全绿、单视频锚换面 3 用例全绿。

### 8.9 挂账
- 真「合集/series」上下文 URL（space.bilibili.com lists 等）非本轮拆分域（域=视频自身分 P）；如需再议。
- paused/downloading 行重启恢复（非 resolved）沿用既往状态（不改，既有挂账面）。
- 单视频语义锚变更记录：s6_link_e2e/s6_cancel/s6_register_fail 锚从 BV17x411w7KC（实为 10 分 P）换为真·单 P BV1j5nj68E48（B 站 popular API 实取 videos=1），意图=单视频单任务不变；样本诚实回归后全绿。
- S5 CAA「CAA 主源真实命中」择窗复跑（网络窗：MusicBrainz 503 + archive.org 经代理不可达；上一轮 94/95 的同文件失败与本轮同族）。

## 9. T9C 歌词域第一批档（LRCLIB 真取 + 正规歌名/歌手补全 + 同目录 .lrc；2026-10-19）

### 9.1 开发者裁决（2026-10-19 原话）
- 「提取歌词，并根据歌词搜索歌名歌手等信息。」
- 拍板①：歌词来源=**LRCLIB 优先 + 真 ASR 兜底**（ASR 兜底运行时=T10/RV-C 挂账）。
- 拍板②：「根据歌词搜索歌名歌手」=**暂用 LRCLIB 正规歌名/歌手/专辑补全**（正文反查引擎不做；LRCLIB 实测不索引歌词正文——真句 `刮风这天 我试过握着你手` `q=` 检索 0 结果；正文反查源 Musixmatch 商业 token / 网易灰接口挂账待另行拍板）。

### 9.2 契约与实现
- 契约增量 `contracts/src/lyrics.dart`（barrel export）：`LyricsPort.resolve(LyricsQuery{trackId,title,artistDisplay,albumDisplay,durationMs}) → LyricsResolution?`，`source=lrclib|asr`（asr 本批不产出）。
- 适配器 `lib/adapters/lrclib_adapter.dart`：检索语义=/api/get（404 频现）→ /api/search?track_name&artist_name → 模糊 q → **T9C 增量末兜底 /api/search?track_name（仅曲名+时长锚）**；时长锚 ±2s（有锚时）；候选须有 synced/plain 至少一项；非 200=真语义不重试不吞（failures 含 body 片段）；**仅传输层异常重试一次**。诊断面 requests/responses/failures 只观测真实出网。
- 服务 `lib/lyrics/lyrics_service.dart`：B 站分页标题剖析（`<合集>pNN NNN. 歌名 - 歌手`→剥前缀/分页号/编号→末 dash 切）+ 串行 worker + .lrc 同目录落盘（REQ-LYR-03，相对仓库根）+ lyrics_meta.upsert + 轨目补全（title/artistDisplay/albumDisplay/字典 upsert，溯源不动）。
- 接线 `extract_queue`：`lyricsPort` 可选注入（验证配置位）；注册回执后 `schedule+enqueue`。**门控变更（依裁决）**：原 EXT-08 语义要求 model_registry 有 present 模型才联动——LRCLIB 优先不需要 ASR 模型，`LyricsDao.schedule` 的 modelId 改可空、enqueue 不再被模型在位门控（模拟器空库实证：门控在位时歌词联动整体跳过）。
- **适配器 proxy 归一化缺陷修复**：`_http.findProxy='PROXY $proxy'` 直拼 env 形态（带 `http://`）在宿主全请求传输异常（responses 全 -1 实录）；剥 scheme 后宿主 6/6 全绿。模拟器 `10.0.2.2:7897`（无 scheme）原本即通——E2E 曾绿而宿主同码全红，差分实证此缺陷。

### 9.3 宿主真网用例（test/lyrics/lyrics_t9c_test.dart，6/6 全绿）
剖析 3 例（纯剖析）；「如果可以|韦礼安|274840ms」/api/get 条件检索命中（trackName/artistName/正文/时长锚）；**「孤勇者|陈奕迅【Hi-Res无损音质】|256031ms」artist 尾巴杂质 → get/条件检索 404-空 → 仅曲名+时长锚兜底命中**（BV1ifUDBREF3 实录；LRCLIB 侧 `/api/get 孤勇者+陈奕迅+256`=正主实证）；编造曲名 → null（不伪造）；全链（真 DB+真文件+真网 → .lrc+meta+title/artist 补全+溯源不动）；未命中 → asrUnavailable（如实）。
注：本轮适配器增量前宿主用例 5/5（无杂质兜底用例）。

### 9.4 模拟器 integration_test 全真 E2E（integration_test/t9c_extract_lyrics_test.dart，**All tests passed! 1:04**）
真 UI（tester.tap 语义层，规避 adb input 冷启动 NO_INPUT_CHANNEL 实测）→ 合规门禁真 ack → 输入真 URL `https://www.bilibili.com/video/BV1ifUDBREF3`（孤勇者，单 P）→ 勾「同时生成歌词」→ 真解析（Kotlin yt_dlp 通道 reply ~27KB）→ 单卡 → 提交 → 真下载（192k mp3，网络窗内一次 SSL 失败+自动重试成功一次实录）→ ffmpeg-kit 转码 → 注册（真 DB tracks 行）→ 歌词联动真取（LRCLIB 命中）→ `.lrc` 同目录落盘（`提取/知己音乐 - 孤勇者 - 陈奕迅Hi-Res无损音质.lrc` 真实存在断言）→ lyrics_meta type=lrc → 轨目补全（title 含「孤勇者」、artistDisplay='陈奕迅'、sourceId 溯源不动）→ extract_tasks 终态 registered。
E2E 适配要点（如实记账）：① 全新安装 DB 无仓库根 → 泵①「尚未配置音乐仓库」判盘失败实证；测试预置真根（`addRepositoryAndScan`（真 API 真库写）至应用私有 docs/repo）。② 模拟器 NAT 继承不到宿主 TUN——Kotlin 侧 `verifyProxyUrl` 同语义，歌词域注入 `LrclibAdapter(proxy:'10.0.2.2:7897')`。③ flutter test integration_test 每轮后卸载应用包（数据目录清空；/sdcard 不受影响——T9B 证据早已归档 repo）。④ 测试初始锚 BV1j5nj68E48 实为 K/DA MV（非歌曲），剖析/检索如实未命中（asr_unavailable 实录）→ 换真歌曲锚 BV1ifUDBREF3。

### 9.5 排障实录（关键归因，防复发）
1. 裸 BV 码不放行：`parseLinkText` 经 `extractFirstUrl` 需完整 URL（测试初始只输 BV 码 → metas=[] → 无卡无报错）。DBG 差分定位（adapter 无首打印=未进 resolveAll）。
2. 果如上；另录 flutter test 框架期 HttpClient 全 400 mock（TestWidgetsFlutterBinding）→ 真网用例一律 plain test()（S5 先例同款）。
3. compose 通道回执时长：异常叶=yt-dlp SSL `DECRYPTION_FAILED_OR_BAD_RECORD_MAC`（宿主代理 TLS 抖动窗；与 §6.3 同族）。择窗复跑即绿。
4. LRCLIB 服务器抖动窗：503 ServerOverloaded / 404 / SSL EOF 交替（同族网络窗）。宿主用例在低窗复跑 6/6 全绿（503/404 如实记档+兜底命中）。

### 9.6 全量回归（机器）
- `flutter analyze` 全仓 0 issues。
- 宿主全量批跑：窗口抖动族（cover CAA/extract 真网/lyrics 真网）间歇 2–10 败波动；单独复跑即绿（s6_link_e2e+s6_link_split 单独 4/4；lyrics_t9c 6/6；编造曲名单跑过）——属既往既有网络窗语义（§6.3/§8.6 同族），非 T9C 改动面回归。确定性子集（剖析/全链负例/所有单元）稳定。

### 9.7 挂账
- ASR 兜底运行时（T10/RV-C，宿主无 onnxruntime/sherpa-onnx）——未命中如实 `asr_unavailable`。
- 歌词正文反查源（Musixmatch 商业 token / 网易灰接口）待开发者另行拍板。
- lyrics_gen_jobs 终态机（claim/complete/dispatch）未接入 runForTrack（job 行留 queued；T9C 第一批 outcome 经 meta/集成断言承载）——第二批接 job 生命周期时收口。
- CAA 主源真实命中择窗复跑（既往挂账不变）；arm64 真机窗口（既往挂账）。
