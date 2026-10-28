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
