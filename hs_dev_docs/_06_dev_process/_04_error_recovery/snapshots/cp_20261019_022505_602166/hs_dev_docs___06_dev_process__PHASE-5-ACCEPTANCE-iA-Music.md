# 阶段验收记录：iA-Music-BUILD-5 / 阶段 5（实现切片）

> 使用 Skill 的 references/stage_acceptance.md。切片逐个红绿实现并累计证据；多切片可合并验收（IMPL-06），gate 在 S0–S10 全部收口后提交，禁止代签。

- 验收记录 ID：`PHASE-5-ACCEPTANCE-iA-Music`
- 阶段：`5 实现切片`
- 验收状态：`DRAFT`
- 本次范围与 change_size：S0–S10 逐切片实现（垂直切片，阶段 4 已确认顺序） / `L`
- 规则版本：hs-dev-skill `engineering_acceptance.md` §6（2026-10-17 装载；IMPL-01..06）+ `DEC-010`（全真策略）
- 编写者：opencode（agent）
- 验收人/明确委托范围：Hardstone（开发者）；无委托；切片证据随做随录，演练点 D1/D2/D3 现场展示

## 1. 输入与产出基线

| 类型 | 文档/代码路径 | 版本或内容摘要 | 标题锚点/关联 ID | 当前是否有效 |
|---|---|---|---|---|
| 输入 | `_06_dev_process/PHASE-4-ACCEPTANCE-iA-Music.md` | **ACCEPTED**（『确认（验收通过）』2026-10-17） | §6/gate | 有效 |
| 输入 | `TASK-S0..S10.md` + `CP-S0..S10.md` + `TASK-BREAKDOWN §2` | 切片详单/Pack/REQ 映射（阶段 4 已签） | S0–S10 | 有效 |
| 输入 | `DEC-010-no-mock-policy.md` | 验证一票全真 | D10-1..4 | 有效 |
| 输入 | REQ 63 / TEST 34 / 冻结基建线 | 分母（DELIV 回收用） | REQ-*/TEST-* | 有效 |
| 产出 | `PLAN-iA-Music-BUILD-5.md` | T1 done；**T2 ACCEPTED**（2026-10-17T15:38Z）；**T3 ACCEPTED**（2026-10-17T15:41Z） | — | 进行中 |
| 产出 | 应用代码仓库目录（Flutter 工程根 `app/` + `app/packages/contracts/`） | S0/S1 主体落地 | — | 进行中 |
| 产出 | 运行证据 `_03_qa_log/EXP-003-flutter-sdk-install.md` | 环境就绪（Flutter 3.47.6/Android 37.0.0/许可 ✓） | EXP-003 | 有效 |
| 产出 | 运行证据 `_03_qa_log/IMPL-S0-foundation-evidence.md` | S0：三端创建+contracts 一致性+analyze 0+Windows 34.3s/冒烟+apk 361.2s+**Android 装机冒烟** ✓；Linux=ISS-502（开发者裁决挂账） | IMPL-S0 | 有效（**S0 ACCEPTED** 2026-10-17T15:38:47Z，见 §8 切片验收记录） |
| 产出 | 运行证据 `_03_qa_log/IMPL-S1-foundation-evidence.md` | S1 收口：DAO 九组+回退门+六问走查(ISS-503 修正)+FTS delete 全列纪律；测试 27/27 | IMPL-S1 | 有效（**S1 ACCEPTED** 2026-10-17T15:41:15Z，见 §8 切片验收记录） |
| 产出 | 运行证据 `_03_qa_log/IMPL-S2-scan-library-evidence.md` | S2 收口：六联+watcher+DoD1–4；测试 41/41 | IMPL-S2 | 有效（**S2 ACCEPTED** 2026-10-18T00:41:21Z，见 §8 切片验收记录） |
| 产出 | 运行证据 `_03_qa_log/IMPL-S3-playback-engine-evidence.md` | S3 收口：mpv_audio_kit 0.5.1 首适配+池/连播/垃圾桶/缺失/恢复/三锚；测试 59/59；DoD3 OPEN=RV-A 真机窗口 | IMPL-S3 | 有效（**S3 ACCEPTED** 2026-10-18T03:25:11Z，见 §8 切片验收记录） |
| 产出 | 运行证据 `_03_qa_log/IMPL-S4-playback-page-playlists-evidence.md` | S4 收口：沉浸页（胶片帧）+队列页+音效页+歌单/我的+壳三 Tab 常驻条+插队 Port 面；测试 76/76（基线 59+S4 17）；DoD1/2/4/5/6 PASS、DoD3 分支 B 实跑（分支 A 待 RV-A）；待裁决=历史分组 UI 归属 | IMPL-S4 | 有效（**S4 ACCEPTED** 2026-10-18T06:20:02Z，见 §8 切片验收记录） |

## 2. 工作 todolist

- [ ] IMPL-01：按行为红绿实现——逻辑变更有能暴露错误行为的测试及执行记录；接口/领域不变量验证，不只断言内部调用
- [ ] IMPL-02：同步契约与变更——实现与 REQ、接口、Schema、状态规则一致；偏离有裁决；未决产品空白回 DESIGN
- [ ] IMPL-03：检查语言与运行风险——静态检查通过；人工核对异常/资源/并发/数据/安全
- [ ] IMPL-04：验证真实协作边界——真实 adapter/DB/界面集成有结果；按 **DEC-010 无 Mock**；不以替身通过
- [ ] IMPL-05：演练高风险业务切片——用已确认样例核对真实运行结果；重要偏差关闭后复制
- [ ] IMPL-06：提交切片验收——DoD/差异/证据可逐项追溯；开发者确认业务预期（合并可接受）

## 3. 适用性与验收检查

| 规则 ID | 项目检查内容与通过标准 | 适用性/NA理由 | 证据路径、版本与锚点 | 核对方式及执行结果 | 候选结果 | 验收人结论/记录 |
|---|---|---|---|---|---|---|
| IMPL-01 | 每切片红绿证据（测试先红后绿记录中含失败名/version） | 待确定 | 随切片累计（`_03_qa_log/`+test 文件） | 待执行 | PENDING | 待验收 |
| IMPL-02 | 实现与 DETAILED-DESIGN/REQ 一致；偏离=DEC 记录 | 待确定 | 随切片累计 | 待执行 | PENDING | 待验收 |
| IMPL-03 | `dart analyze` 0 error + 人工风险核对清单 | 待确定 | 随切片累计 | 待执行 | PENDING | 待验收 |
| IMPL-04 | 真实集成证据（真库/真引擎/真网络/真协议服务）；**无替身**（DEC-010） | 待确定 | 随切片累计 | 待执行 | PENDING | 待验收 |
| IMPL-05 | D1/D2/D3 演练记录（样例结果与预期逐条对） | 待确定 | T8/T12 演练记录 | 待执行 | PENDING | 待验收 |
| IMPL-06 | 切片 DoD 追溯 + 开发者业务预期确认（合并） | 待确定 | gate 提交时 | 待执行 | PENDING | 待验收 |

## 4. 问题、反例与范围差异

| 问题 ID | 原规则/场景 | 反例或差异 | 理解偏差/需求变化/工程缺陷 | 是否阻断及理由 | 裁决/负责人/时点 | 关闭证据 |
|---|---|---|---|---|---|---|
| ISS-501 | IMPL-04（RV-A/B/C） | 真机窗口未定 | 工程依赖（ISS-401 同源） | 阻塞对应切片开工（S3/S6 Android/S7 ASR），不阻断其余切片 | 开发者（真机安排） | 进行中 |
| ISS-502 | IMPL-04（Linux 桌面） | 本机为 Windows；Linux 桌面构建需 Linux 环境 | 工程依赖（D7-2 三端环境） | 不阻断 S0–S10 其余两端；Linux 构建在开发者环境执行 | 开发者（Linux 环境） | **进行中**（开发者裁决 2026-10-17T15:36Z 原话『Linux 构建/冒烟先不用做』→维持挂账不阻断；补验时点=分发期/开发者环境窗口；IMPL-S0 §7） |

## 5. 运行证据（随切片累计）

| 命令/演练场景 | 环境与时间 | 代码基线 | 退出码/观察结果 | 报告位置及关联规则 |
|---|---|---|---|---|
| Flutter SDK 安装（flutter-io.cn 镜像）+ `flutter --version` | Windows 10 本机 2026-10-17 | — | 进行中 | EXP-003（IMPL-03/04 前置环境） |
| Android 装机冒烟（专用 AVD `ia_music_smoke`；冷启动 116s→install Success→am start） | Windows 11 + Android SDK 37（google_apis x86_64）2026-10-17T15:36Z | app-debug.apk（361.2s 构建） | pid=2658 @3/8/15s 存活；`mCurrentFocus=com.hardstone.ia_music/.MainActivity`；截图存档 | `_03_qa_log/IMPL-S0 §6` + `artifacts/IMPL-S0-android-smoke.png`（DoD-4 / IMPL-04） |

## 6. 提交与最终验收

- 适用项统计：PENDING 6/6（证据随切片累计后收敛）
- Agent 候选结论：随 T15 提交（合并切片验收，引用 D1/D2/D3 与逐切片证据）
- 开发者结论：待验收
- 确认原文（位置/时间）：待补充
- 下一阶段：阶段 6 验证与交付（DELIV-01..05）

## 7. 变更与失效记录

| 变更来源及版本差异 | 受影响规则/需求 | 受影响下游文档/Pack | INVALIDATED 时间 | 重验范围与新确认记录 |
|---|---|---|---|---|
| 无（阶段 5 新开） | — | — | — | — |

## 8. 切片验收记录（随签累计）

### S6 提取管线（T9 / TASK-S6 / CP-S6）——**SUBMITTED 提交候选（待签收）**

- 已实现：桌面 Process 形态（真 yt-dlp+ffmpeg 进程）DownloaderAdapter；§4.2 任务机串行泵（合规门禁/dup 双保险/网络退避 ≤3/断点 staging/迁移/事务注册/quarantine/歌词联动）；提取页（声明卡+解析卡+队列+失败清单）；契约增量=ResolvedMeta.coverUrl（解析卡封面位）。公共其余 Port 未动。
- 证据：`_03_qa_log/IMPL-S6-extract-pipeline-evidence.md` §1–§5——**93/93 全量绿跑 0 error/0 skipped**（machine 记录 `output/qa/S6-full-test-final-m.log`）+ analyze 0 + 真链接 BV17x411w7KC 全链 e2e（真解析 ≤5s/真下载/真注册/真歌词排队/真 dup/真封面链）+ 真进程取消无 .part 残留 + 真实磁盘态迁移失败路径（库不动），过程 CAA 抖动如实入档。
- 挂账（IMPL-S6 §4）：DoD4 真断网/AUTH 失效演练、DoD7 三链串行实跑、扫码登录 UI（REQ-EXT-02 上半，未开工如实差额）、解析卡封面渲染——S6 签收后第一补项=扫码登录真 API 链。
- RV-B 约束不变：S6 Android 侧（AAR 真机嵌入）未开工；桌面形态先行。
- **开发者确认：PENDING**——未签收不标 ACCEPTED；S7 提取侧歌词消费（RV-C）原待决状态保留。

### S5 封面链（T7 / TASK-S5 / CP-S5）——**ACCEPTED**（开发者签收原话「签收。」，2026-10-19T01:19:37Z，见 §8 切片验收记录）

- 已实现：CoverChain 四级来源、CAA/iTunes 真外呼与共享限流、同目录 JPEG 与注册、列表/播放页即时换图、在线封面持久开关；公共 Port 未改。
- 回归修复：工作树原有 v2 生成文件补齐；异常只读库禁用 drift 迁移并验证版本不变；既有 S0–S4 签收保持。
- 2026-10-19 补证一（§7）：ARM64 探针构建与隔离 Android 真实断网已过，SQLite=3.50.4；无默认网络时色块/无弹窗/无封面文件/音频不变，DoD5 闭合。
- 2026-10-19 补证二（§8）：**CAA 主源真实命中**——开发者既有本地代理 127.0.0.1:7897 下，MusicBrainz→CAA→archive.org→`dn*.ca.archive.org:200` 取得 1200 JPEG（112406 字节），独立测试 4/4 且不调 iTunes；**恢复联网同曲重试 x64 实跑成功**（断网 none → 恢复后同一 CoverChain 同一库行 → kind=fetched，7 请求全真，音频不变）；ARM64 先前恢复 DNS 失败如实保留。`flutter analyze` 复跑 0 问题。
- 2026-10-19 收口：开发者重新打开本地代理后执行最终全量——`flutter test --reporter json` **87/87 PASS、0 error、0 skipped**（基线 85 + widget 冒烟 1 + D1 1；machine 记录 `output/qa/S5-full-test-final-m.log` 为权威计数，expanded 日志并发互写不作为缺考依据）；`flutter analyze` **No issues found**。此前 1 项网络性失败已核销（代理关闭窗口，非实现回归）。
- 提交候选范围：S5 封面链 + 检查点 A / D1（`_03_qa_log/IMPL-D1-checkpoint-A-evidence.md`，1/1 PASS，已并入最终全量绿跑）。
- **开发者确认：ACCEPTED**——签收原话「签收。」（2026-10-19T01:19:37Z 会话答复），合并覆盖 S5 封面链与检查点 A / D1 演练；S0–S4 既有签收不变。签收时点依据=最终全量 87/87、analyze 0、IMPL-S5 §7–§8、IMPL-D1。S6 后续仍受 RV-B 真机窗口约束；插槽验收记录按 §8 归档。

### S4 播放页与歌单（T6 / TASK-S4 / CP-S4）——**ACCEPTED**（开发者签收原话「确认验收」，2026-10-18T06:20:02Z）

- **候选判据（agent 提交，DoD 六条）**：①DoD1 播放页呈现=胶片帧（`#0D0F11` r18+画面 r10+框底打孔带）+标题/歌手/专辑+进度（白点）+三键；封面缺失→色块（S5 前终态占位）②DoD2 模式=列表循环/单曲/顺序/随机四态一轮末路由分岔（随机单轮不重复实证）+插队「下一首播放」=Port 面 `insertNext`（mpv insert-next 物理增列，自然推进命中插队曲）③DoD3 EQ **两分支同 UI 路径**：当前端实跑=明示不支持面；分支 A（实时生效）待 RV-A 真机回填 ④DoD4 红心=图标即时填充红+「我喜欢的音乐」计数同步+我的页卡一致；重复添加=DB UNIQUE 拦截+原位提示「《X》已在『Y』中」⑤DoD5 历史植入 500 条+真播放第 501 条→flush 淘汰最旧（分批 100/事务）⑥DoD6 跨 Tab 迷你条一致（壳层唯一播放域实例+IndexedStack 保活）
- **证据**：`_03_qa_log/IMPL-S4-playback-page-playlists-evidence.md` §1–§7——**76/76 全绿**（基线 59+S4 17：歌单服务 5/播放服务 6/五锚+壳骨干 6）+ analyze 0 + 全量多连绿实录；教训 L1–L4 入档（`ensureFavorite` 并发撞部分唯一索引→DAO 幂等回读；pumpWidget 不清 Navigator 栈→UniqueKey 换根；SnackBar 串行队列→hideCurrentSnackBar 原位顶替；FakeAsync 帧预算 2–3 拍）
- **DEC-010**：全真链——真 mpv_audio_kit 0.5.1 + 真短样本 + 真 drift 库 + 真 fs；无替身引擎/无 stub 页
- **残留（均不阻断）**：DoD3 真平台演练+EQ 分支 A=依赖 RV-A 真机窗口；**须裁决**=REQ-PL-05「历史按日期分组」列表 UI 的归属切片（本片交付其淘汰语义 DoD5）；播放页加载态（无独立 spinner）待 S9/S10 视觉收口
- **签收原话**：「确认验收」（2026-10-18T06:20:02Z，开发者会话答复；《一次答复原话只覆盖其明确列出的阶段》：本轮唯一提交候选=S4/T6）。agent 本轮仅提交候选，未代签、未代提交 git。

### S3 播放引擎竖切（T5 / TASK-S3 / CP-S3）——**ACCEPTED**（开发者签收原话「确认签收」，2026-10-18T03:25:11Z）

- **候选判据（agent 提交，DoD 六条）**：①DoD1 随机池=双 NULL+NOT IN few_watch+500 行真库内存采样（497 严格 / 498 补满双口径，毫秒级上界窗 <200ms）②DoD2 连播+垃圾桶=itemEnded 自动下一首（真 mpv 连播链）、跳下一+名单落库+设置可清空+首点 Toast「已减少这首的推荐」→池恢复 ③DoD4 缺失跳过=真 fs stat→`missing_at` 补写+顶部提示原话「《旧信》文件缺失，已跳过」(+损坏线「无法播放该文件」不标缺失) ④DoD5 恢复=kill→会话 JSON→restore 队列+进度+自动起播（镜像回填先行）；二次失败→「播放服务异常」notice+false（§4.3 重试 1 次）⑤DoD6 三 Gherkin 锚全绿（REQ-NAV-02 随机开播 / REQ-PLAY-04 垃圾桶+设置清空 / REQ-PLAY-08 外部删除真删+原话横幅）⑥DoD3 **OPEN**——后台/锁屏/媒体键+会话真桥=真平台演练证据（依赖开发者 RV-A 真机窗口；FLUTTER_TEST 桥跳过已防毒化）
- **证据**：`_03_qa_log/IMPL-S3-playback-engine-evidence.md` §1–§7——59/59 全绿（基线 41+S3 18：adapter 7/service 7/密度 1/三锚 3）+ analyze 0 + 全量回归实录；教训 L1–L6 入档（ms 单位穿写事故→文件内毫秒目标；openAll 替换世代守卫；raw seek 播放态实证；runAsync `Future<T?>`；testWidgets 真 IO 挂死→runAsync 包住+同步 teardown API；broadcast 跨 zone 不成帧+无重放→每帧 Future 重读）
- **DEC-010**：全真链——真 mpv_audio_kit 0.5.1（真 libmpv DLL hook 产物 9,143,296 B）+真 ffmpeg 短样本（S2 真件库拷贝）+真库行+真 fs stat；500 行密度为**行级 fixture**（判据对象=SQL 粗筛+内存采样本身，证据 §4-C 注记；训练线不造 500 个物理文件亦不粘 stub）
- **签收原话**：「确认签收」（2026-10-18T03:25:11Z，开发者会话答复；《一次答复原话只覆盖其明确列出的阶段》：本轮唯一提交候选=S3/T5）。agent 本轮仅提交候选，未代签、未代提交 git。

### S2 曲库扫描与浏览（T4 / TASK-S2 / CP-S2）——**ACCEPTED**（开发者签收原话「确认验收」，2026-10-18T00:41:21Z）

- **候选判据（agent 提交）**：DoD 五条全达成——①真实计数 total=10/skipped=2（红测守门）②真事件增量 ≤15s ③编辑不写原文件（字节/mtime/hash 不动+FTS 同事务）④软删复活+缺失恢复（红测驱动补 markPresent 分支）⑤REQ-LIB-01/05/07 三锚 widget 全绿+REQ-LIB-06 四排序。
- **证据**：`IMPL-S2-scan-library-evidence.md` §1–§7（fixture 真件/41+1 全绿/analyze 0/五条教训入档 L1–L5）。
- **DEC-010**：全真链——真 ffmpeg fixture、真目录注入、真 isolate 扫描、真内存 SQLite；锚 1「500 首目录」以 10 真件同构判据替代（证据 §5 注记）。
- **签收原话**：「确认验收」（2026-10-18T00:41:21Z，开发者会话答复；《一次答复原话只覆盖其明确列出的阶段》：本轮仅覆盖 S2/T4）

### S1 数据契约底座（T3 / TASK-S1 / CP-S1）——**ACCEPTED**（2026-10-17T15:41:15Z）

- **范围/版本**：drift schema v1（17 表 + `track_index` FTS5 锚定表 + 部分唯一/表达式索引 DDL）+ 回退门 `openIaDatabase` + DAO 门面 `daos.dart`（8 域+聚合 `DataAccess`）+ SecureStore 三端 adapter + 枚举目录/TaskQualityConverter
- **检查项对照（TASK-S1 DoD 四项全 PASS）**：
  1. 九组查询单测逐一可执行 PASS——DAO 行为测试 18 条（搜索三路/浏览排序分页/随机池 D9-2 排除采样/扫描 diff 全路径/历史 DESC+D9-3 淘汰 530→500 删最旧/歌单全动线/墓碑序/通道 C44/lastSync/提取 dup 复用行/ASR 串行队列/shell put+model upsert）+ **EQP 抽查 3 条**（idx_track_source/idx_pt_pos/idx_history_played 走索引实证）
  2. 迁移回退门演练 PASS——缺表文件→`isReadOnlyGate=true`+壳层引导文案+**写被拒**；只读门连接跳过 schema 校验（schema 异常即门状态语义）
  3. 六问走查 0 歧义 PASS——`IMPL-S1-six-question-walkthrough.md` **132 列（18 实体表 127+FTS5 虚表 5）六问全答**；走查中修正 ISS-503（conflict_copies 补 `deleted_at`，spec 行同步）；跨表行为移交清单在册（S2 root 移除/S6 墓碑三类）
  4. 红线核对 PASS——物理删除仅 D9-3 淘汰/playlist_tracks 业务动作/few_watch 清空三处（墓碑配套归属 S6）；凭据本体零入库（credentials_ref 仅 key=C50）
- **质量线**：`flutter analyze` **0 issue**；`flutter test`（s1_dao+s1_schema）**27/27 All tests passed**；build_runner codegen 15 outputs
- **关键实证（红线级实现纪律）**：FTS5 外部内容表 `'delete'` 命令必须携带**全列一致**旧值（含 pinyin 双列）——部分列=静默索引损坏（首轮单行测试不触发 delete 路径而漏网，探针定位后修正并加双行守门用例）；已写入走查表审计结论与代码注释
- **确认原文（可追溯）**：本会话（opencode）Hardstone 答复原话：「**S1 验收通过**」（记录时点 2026-10-17T15:41:15Z）
- **证据链**：`_03_qa_log/IMPL-S1-foundation-evidence.md`（首批+收口块）+ `_03_qa_log/IMPL-S1-six-question-walkthrough.md` + `_03_qa_log/ISS-503-conflict-copies-soft-delete-column.md` + `app/test/data/s1_dao_test.dart` / `s1_schema_test.dart` + `app/lib/data/{tables,ia_database,daos}.dart` / `app/lib/adapters/secure_store_adapter.dart`
- **残留（均不阻断，边界清晰）**：①SecureStore **运行时**验证移交 S2 开机集成 + S3/S8 凭据真实链路（DEC-010 不做替身，如实移交非隐瞒）②pubspec sqlite3 `file://` 绝对路径=S10 分发前回改（PLAN-BUILD-5 风险表）③Android 真机侧 SecureStore=RV 窗口补验④ISS-502 同前

### S0 工程底座（IMPL-01..04 首块 / TASK-S0 / CP-S0）——**ACCEPTED**（2026-10-17T15:38:47Z）

- **范围/版本**：Flutter 三端工程 `app/`（applicationId=`com.hardstone.ia_music`、minSdk=26=DEC-008④、华为 wrapper+阿里云镜像链）+ 契约包 `app/packages/contracts`（七 Port+8 异常+DTO）+ S0 目录治理
- **检查项对照（TASK-S0 DoD 四项全 PASS）**：
  1. 三端编译线 PASS——Android `app-debug.apk` 361.2s ✓（镜像排障有 EXP 台账）/ Windows Release exe 34.3s ✓；Linux=**NA→挂账豁免**（ISS-502，开发者明示裁决）
  2. contracts↔§2.1 一致性核对表全 PASS（SyncChannelPort 无 delete 语义、MetadataPort 无写方法等红线代码级 ✓）
  3. `dart analyze`0 + `flutter analyze`0 + 无未授权依赖 PASS
  4. 三端启动冒烟 PASS——Windows `SMOKE-OK pid=17128` ✓ / **Android 装机冒烟 ✓（2026-10-17T15:36Z：AVD ia_music_smoke 冷启 116s→install Success→pid=2658 @3/8/15s 存活→焦点窗体 MainActivity→截图存档 artifacts/IMPL-S0-android-smoke.png）** / Linux=**NA→同挂账豁免**
- **NA 适用性理由**：本机=Windows（无 Linux 解析层可执行面）；开发者裁决认可挂账不阻断——非平均抵消，属权限明确的例外处理
- **确认原文（可追溯）**：本会话（opencode）Hardstone 答复原话：「**S0 验收通过**」（记录时点 2026-10-17T15:38:47Z）；前置三条裁决原话（2026-10-17T15:36:01Z 前后）：「Linux 构建/冒烟先不用做。Android 装机冒烟需要做；应用 ID 分发前回改；可以；」
- **证据链**：`_03_qa_log/IMPL-S0-foundation-evidence.md` §1–§7（含 §6 装机冒烟补录/§7 裁决引用）+ `artifacts/IMPL-S0-android-smoke.png` + EXP-003
- **残留（均不阻断，边界清晰）**：①ISS-502 Linux 构建+冒烟（分发期/开发者 Linux 环境补）②S10 分发前应用 ID 定名 + pubspec sqlite3 `file://` 绝对路径回改（PLAN-BUILD-5 风险表在册）

## 9. CLI 完成门禁记录

<!-- HS_ACCEPTANCE_GATE_V1
{
  "schema_version": 1,
  "task_id": "iA-Music-BUILD-5",
  "acceptance_status": "DRAFT",
  "developer_confirmation": {
    "decision": "PENDING",
    "reviewer": "",
    "confirmed_at": "",
    "source": "",
    "excerpt": ""
  },
  "verification": {
    "tests": []
  },
  "checks": [
    {"rule_id": "IMPL-01", "result": "PENDING", "evidence": "", "reason": ""},
    {"rule_id": "IMPL-02", "result": "PENDING", "evidence": "", "reason": ""},
    {"rule_id": "IMPL-03", "result": "PENDING", "evidence": "", "reason": ""},
    {"rule_id": "IMPL-04", "result": "PENDING", "evidence": "", "reason": ""},
    {"rule_id": "IMPL-05", "result": "PENDING", "evidence": "", "reason": ""},
    {"rule_id": "IMPL-06", "result": "PENDING", "evidence": "", "reason": ""}
  ],
  "dod": [
    {"criterion": "S0–S10 切片 DoD 全过 + 红线核对 + 演练 D1/D2/D3 记录", "result": "PENDING", "evidence": ""},
    {"criterion": "开发者确认业务预期（合并切片验收）", "result": "PENDING", "evidence": ""}
  ],
  "unimplemented": []
}
HS_ACCEPTANCE_GATE_V1 -->
