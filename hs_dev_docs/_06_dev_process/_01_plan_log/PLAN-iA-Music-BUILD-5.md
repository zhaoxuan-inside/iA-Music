# 任务计划账本：iA-Music-BUILD-5

- **task_id**：`iA-Music-BUILD-5`
- **标题**：iA-Music 本地音乐播放器 — BUILD 阶段 5（实现切片，IMPL-01..06）
- **change_size**：`L`
- **work_mode**：`CODE`（行为红绿实现；配合 `task_state_machine.md` 推进）
- **所处阶段**：`5`（上游=阶段 4 ACCEPTED（『确认（验收通过）』含切片顺序确认，2026-10-17）；切片=S0–S10 串行（阶段 4 已确认）；验证=**DEC-010 全真**）
- **断点**：`T9/S6 SUBMITTED 候选待签收（T9A/T9B/T9C 已实证并入候选）` — 桌面 Process 形态提取链全实现：T9C 歌词域第一批落定（宿主真网 6/6 + 模拟器全真 E2E All tests passed 1:04 + analyze 0；IMPL-S6 §9）。下一动作：开发者对 S6（含 T9A/T9B/T9C 与挂账面）签收；签收后第一补项=扫码登录 UI（真 passport API）+ D2 挂账项回收；S7（T10）仍受 RV-C。**增项 T9W（2026-10-20 开发者指令：「现在的页面少了一个半圆形滑动切歌的页面」）= D6-7「随机」轮盘页应用侧 1:1 落地（S4 域）：宿主 2 锚用例全绿 + 模拟器全真 E2E 14s All tests passed + analyze 0，charge IMPL-T9W 档；**同日动效打磨轮（开发者「UI 动画有点差」反馈）= shuffle_page 动效重构（标量补间矩阵/拖拽零 setState 变换层/微补间进度/inFloor 入场淡，键位语义手感零改）后全链复绿（36/36+E2E 14s+analyze 0，IMPL-T9W §8 全档）+ 复验二轮=开发者澄清裁决「卡恒满 5 张不缺失」（环形回绕五主道+torn 走廊+_SlotP == 补刀，形态锚 4→5 按裁决同步，78/78+E2E 16s+analyze 0，IMPL-T9W §8.1 全档；E2E 正常收尾=卸包清库实录 §4.5-9），**三轮=手势域收窄卡组层（拖拽只动卡片、整页定层不动，78/78+E2E 22s+analyze 0，§8.2 全档）+ 四轮=轮转轨迹绕轴心弧线（极坐标插值，直线/上移观感根除，78/78+E2E 21s+analyze 0，§8.3 全档），**同屏候审。**
- **刷新时间**：2026-10-20（Asia/Shanghai）
- **上游基线**：阶段 0–4 全 ACCEPTED；ADR-0001；DEC-009/010；TASK-S0..S10 详单 + CP-S0..S10 Pack（阶段 4 已签）

---

## 环境底数（已就绪，EXP-003）

- Flutter SDK：**3.47.6 stable**（既有安装采纳，未重复下载）`E:\HardStone.Flutter\flutter`（开发者指令：E 盘目录规则；证据 EXP-003）
- Android SDK：✓ SDK 37.0.0（`ANDROID_HOME=E:\HardStone.Android\AndroidSDK`，许可已全接受，JAVA=jdk-21.0.12.1+1）
- Windows 桌面编译线：✓（VS 生成工具 2022）；Linux 桌面：开发者环境执行（ISS-502）
- pub/gradle 镜像与缓存：pub-cache=E 盘（C 盘零占用）；maven 走项目内阿里云镜像（S0 证据）

## 步骤

| step_id | 描述 | 状态 | 备注 |
|---------|------|------|------|
| T1 | 阶段 5 启动：账本 + 验收骨架 + 环境检查 | done | 本文件 + `PHASE-5-ACCEPTANCE-iA-Music.md` |
| T2 | **S0 工程底座**：Flutter 三端工程 + `contracts/` 包（七 Port+异常+DTO）+ 目录治理 | **ACCEPTED** | 开发者签收原话「S0 验收通过」（2026-10-17T15:38:47Z 会话答复，PHASE-5 §8 切片验收记录全档）；证据链=IMPL-S0 §1–§7（含装机冒烟 pid=2658+截图）；Linux=ISS-502 挂账（开发者裁决）、S10 前回改项在册 |
| T3 | S1 数据契约底座（drift v1 全表+DAO+SecureStore+回退门） | **ACCEPTED** | 开发者签收原话「S1 验收通过」（2026-10-17T15:41:15Z 会话答复，PHASE-5 §8 切片验收记录全档）；DoD 四项全 PASS（九组查询+EQP 3/回退门/六问 132 列 0 歧义/红线核对）；测试 27/27+analyze 0；残留：SecureStore 运行时验证→S2/S3/S8 链路、sqlite3 file:// 路径→S10 前回改、RV 窗口补真机项 |
| T4 | S2 曲库扫描与浏览（真实计数红线） | **ACCEPTED** | 开发者签收原话「确认验收」（2026-10-18T00:41:21Z 会话答复，PHASE-5 §8 切片验收记录全档）；证据链=IMPL-S2 §1–§7（41/41+analyze 0；DEC-010 全真链；五教训 L1–L5 入档）；残留：UI 真 picker→S10、onboarding 联动→S9、RV-A/B/C 不变 |
| T5 | S3 播放引擎竖切 | **ACCEPTED** | 开发者签收原话「确认签收」（2026-10-18T03:25:11Z 会话答复，PHASE-5 §8 切片验收记录全档）；证据链=IMPL-S3 §1–§7（59/59=基线 41+S3 18，analyze 0；DEC-010 全真：真 mpv_audio_kit 0.5.1+真 ffmpeg 短样本+真库行；教训 L1–L6 入档）；DoD1/2/4/5/6 全 PASS；**DoD3=OPEN 顺延**（后台/锁屏/媒体键真平台演练+会话真桥，依赖 RV-A 真机窗口）；残留：bufferMs/preloadNextCount 契约位不落引擎（毒化实证）、typed seek −12 待包升级/RV-A、EQ=明示不支持线待 RV-A 直桥、pubspec 改动 uncommitted 待自提 |
| T6 | S4 播放页与歌单 | **ACCEPTED** | 开发者签收原话「确认验收」（2026-10-18T06:20:02Z 会话答复，PHASE-5 §8 切片验收记录全档）；证据链=IMPL-S4 §1–§7（**76/76**=基线 59+S4 17，analyze 0；DEC-010 全真：真 mpv 0.5.1+真短样本+真库+真 fs；教训 L1–L4 入档）；DoD1/2/4/5/6 **PASS**；**DoD3=分支 B 实跑**（EQ 明示不支持面；分支 A 实时生效待 RV-A 真机回填）+真平台演练沿 S3 顺延；交付=沉浸页（胶片帧/打孔带/进度/三键）+队列页（插队）+音效页+歌单列表/资料页+我的页三卡+壳三 Tab 常驻条；契约增量=EnginePort.insertNext（mpv insert-next）；**待开发者裁决**=REQ-PL-05「历史按日期分组」列表 UI 归属切片；残留：播放页加载态无独立 spinner（S9/S10 视觉收口）、pubspec/新文件 uncommitted 待自提 |
| T7 | S5 封面链 | **ACCEPTED** | 开发者签收原话「签收。」（2026-10-19T01:19:37Z 会话答复，PHASE-5 §8 切片验收记录全档）；证据链=IMPL-S5 §1–§8（**87/87 全量绿跑 0 error/0 skipped + analyze 0 + CAA 主源经代理命中 + x64 恢复联网重试 fetched 实证**；ARM64 断网 PASS 且恢复 DNS 失败如实存档；教训沿 §7 入档）；残留：ARM64 恢复重试待正向复跑（网络条件）、RV-A 不变 |
| T8 | 检查点 A + 演练 D1（S0–S5 后：扫描→随机播放→歌单竖闭环） | **ACCEPTED**（与 S5 合并签收） | `IMPL-D1-checkpoint-A-evidence.md`：真扫描 10 入库+真 mpv 随机 5 曲+CoverChain embedded+红心/歌单/按序装载；1/1 PASS 且已计入最终 87/87；开发者签收原话「签收。」（2026-10-19T01:19:37Z） |
| T9 | S6 提取管线 | doing / **SUBMITTED 候选** | 桌面 Process 形态实现完毕（2026-10-19T02:23:10Z）：真 yt-dlp+ffmpeg DownloaderAdapter+§4.2 串行泵（门禁/dup/退避/断点 staging/迁移/事务注册/quarantine/歌词联动）+提取页+声明引导；契约增量=ResolvedMeta.coverUrl。**93/93 全量绿跑 0 error/0 skipped（machine）+ analyze 0 + BV17x411w7KC 真链 e2e（解析 ≤5s/下载/注册/歌词 queued/dup/封面链）+ 真进程取消无残留 + 迁移失败路径库不动**（IMPL-S6 §1–§5）。挂账=DoD4 真断网/AUTH 演练、DoD7 三链实跑、扫码登录 UI 未开工（REQ-EXT-02 上半）、解析卡封面渲染；RV-B（Android AAR）约束不变 |
| T9A | S6 Android 侧（yt-dlp-android AAR 嵌入） | doing（x86_64 全链实证达成） | 开发者产品裁决（2026-10-19 会话原话「安卓端也需要支持。」）= RV-B 窗口以 x86_64 模拟器先行开干（DEC-008 ① 已锁定 ffmpegkit-maintained/yt-dlp-android 2.0.2 MIT AAR、arm64+x86_64 双 ABI）。**2026-10-19 07:17 模拟器全链真跑实证**：解析真卡（4分56秒/192k·128k·64k）→ mcdn PCDN 416 语义修复（满收判定+重试收口+看门狗）→ 满收 3,716,075B → ffmpeg-kit(libmp3lame) mp3 转录 **含封面 APIC（ffprobe Stream #0:1 mjpeg attached pic 实证）** → 任务绿勾 `registered` → tracks#2 入库（4,849,045B/295992ms）→ 曲库 UI 1 首；证据档=IMPL-S6 §7（含转录 args 顺序/`-vn` 残附件两次实证修复、smart-exception-java 补依赖、yt-dlp 运行时 2026.6.9→2026.8.19 升级实录）。**arm64 真机验证挂账**（APK ~307MB 后续治理）；桌面 T9 候选证据不变 |
| T9B | S6 B 站多 P/合集拆分（一条链接 → 逐分 P 独立任务） | doing（模拟器/桌面全真收口） | 开发者产品裁决（2026-10-19 会话原话「很多 B 站上面的分享链接是歌曲合计，需要进行拆分，成多个单独的歌曲。」）。实现=契约 `DownloaderPort.resolveAll`（flat-playlist 枚举）+ 双端适配器 + `parseLinkText→resolveAll` 攤平 + 提取页**批量卡**（≥2 条目→「解析到 N 个分页/条目」+全部提取）。拆分域=该视频自身分 P 页（flat 实证：BV1ANQqBTEVU→100 条目 sourceId=BVID_p1..p100；BV17x411w7KC→10 条目同源实证=自身 10 分 P；真·单 P 锚 BV1j5nj68E48（B 站 popular API 实取 videos=1）→恰 1 条全量元数据）。真网用例 `test/extract/s6_link_split_test.dart` 3 用例全绿 + 单视频语义锚三用例换锚回归全绿 + analyze 0。**模拟器 E2E 全真收口**：解析卡 100 条目→全部提取→ extract_tasks 100 行（p1 dup 门禁 + p2..p100 全量）、**终态 dup1+registered99、tracks=100、failed=0**、真题名抽查（如果可以-韦礼安/异地恋/楼顶上的小斑鸠 各异）+ 曲库冷启动「100 首」。**两处如实缺陷修复**（泵 `getSingleOrNull` 多 resolved 行炸→limit(1)+get 串行；启动无续泵→`resumeQueued` 合规门禁一致）+ **热刷新缺口修复**（曲库 revisions 接线 ExtractRegistered，现场注册实证 hot「101 首」）。全量回归 machine 收口：**98 用例（95 基线+3 拆分）批跑 96 过 2 败**，两败均在 S5 封面真网络域（非 T9B 改动面）：「无匹配曲名」503 故障窗单文件复跑即消（**97/98 实过**）；「CAA 主源命中」撞 MusicBrainz 503 窗+archive.org 经代理不可达，**挂账择窗复跑**（同族 §6.3）。machine log=`output/qa/S6-full-test-t9b-split.log`。证据档=IMPL-S6 §8 |
| T9C | S6 歌词域第一批（LRCLIB 真取 + 正规歌名/歌手补全 + 同目录 .lrc） | doing（**宿主 6/6 + 模拟器 E2E 全绿，候选就位**） | 开发者产品裁决（2026-10-19 原话「提取歌词，并根据歌词搜索歌名歌手等信息。」+ 双拍板：LRCLIB 优先+真 ASR 兜底；「歌词反查歌名歌手」=暂用 LRCLIB 正规值补全，正文反查引擎不做——LRCLIB 实测不索引正文，反查源挂账待另行拍板）。契约增量 `contracts/src/lyrics.dart`（`LyricsPort.resolve`，source=lrclib|asr；asr 本批不产出）。适配器=检索四级语义（/api/get → 条件 search → 模糊 q → **T9C 增量仅曲名+时长锚兜底**「孤勇者 artist 尾巴杂质」实证）+ 时长锚 ±2s + 非 200 如实记档不吞 + 仅传输异常重试一次 + 诊断面。服务=分页标题剖析 + 串行 worker + **.lrc 同目录落盘（REQ-LYR-03）** + lyrics_meta + 轨目/字典补全（溯源不动）。接线=`ExtractQueue.lyricsPort` 注入 + 注册后 enqueue + **解除「present 模型」门控**（LRCLIB 不依赖 ASR 模型，schedule modelId 可空——空库实证门控吞联动）。宿主真网 6/6（lyrics_t9c_test；含 404/503 如实记档与兜底命中实录）。**模拟器全真 E2E 1:04 All tests passed**（真 UI tester.tap→真 URL BV1ifUDBREF3 孤勇者→真下载 SSL 失败自动重试成功实录→真转码→真注册→LRCLIB 真取→.lrc 真实存在→补全断言→终态 registered）。**适配器 proxy 归一化缺陷修复**（findProxy 带scheme 全 -1；剥 scheme 宿主全绿——E2E 绿/宿主红差分实证）。flutter analyze 全仓 0。证据档=IMPL-S6 §9（排障 4 归因+挂账）。挂账=ASR 运行时（T10/RV-C）、正文反查源拍板、job 终态机接第二批 |
| T9W | S4 事后增量：D6-7「随机」轮盘页应用侧落地（开发者 2026-10-20 指令「现在的页面少了一个半圆形滑动切歌的页面」） | done（**宿主 2 锚全绿 + 模拟器全真 E2E 14s passed，候审**） | 新页 `ui/play/shuffle_page.dart`：原型 `#p-shuffle` 逐像素实测槽位表（p2/p1/cur/nxt/nxt2+in/out 过渡槽；卡组左沿出血；层次仅旋转渐进+z 序）+ element trackId-key 跨槽迁移切歌动效（550ms cubic(.32,.72,.28,1)）+ 仅上滑切歌（阈 40px；无下滑/点击切歌）+ 整盘拖拽跟手回弹 + 信息区/控件/提示原话；数据面与胶片页共享同一随机会话；接线=HomeShell jumpToTab/openShufflePage 缝 + 曲库随机按钮层推页 + 胶片页↔轮盘互跳。**宿主真引擎 2 用例全绿**（`test/ui/s4_shuffle_wheel_test.dart`）+ **模拟器全真 E2E**（`integration_test/s4_shuffle_wheel_test.dart`，真扫描→按钮链真推页→真引擎真播放→上滑真切歌/下滑不切/垃圾桶少播真行/红心真库，14s passed；IMPL-T9W §3.5）+ 宿主域回归 36/36 + analyze 0。**排障修复实录**（IMPL-T9W §4.5/§5）：①NAV-01 保活实测违规=壳层/曲库页 Column 条件子项无 key 位置配对，svc 悬现时掀掉页面 State（deactivate 实录→按钮链 mounted=false 静默不推页）——全键修复（既有产品质量级缺陷）；②`Navigator.push` Future 语义=pop 才完成，推页一律 unawaited；③`find.byType` 默认 skipOffstage——全屏路由压栈后底层壳取数须 `skipOffstage:false`；④fixture 污染事故如实记档（wheel 种子误留 library_smoke→15 首基线→已删复原）。全量批跑失败面=既有真网络窗口族（cover×5/extract×6/lyrics×3），零 T9W 新败。挂账=浅色主题（DEC-005 应用态）、arm64 真机核（RV-A）、半圆手感目视核、EOF 轮转真平台核、阻尼系数回原型档。**2026-10-20 验收窗口增录**：开发者重申裁决「随机=整池无限循环」（与 REQ-PLAY-03 FM 无限电台语义一致；模拟器 EOF 探针实证轮转+重采样真链，挂账「EOF 真平台核（模拟器侧）」关闭）；E2E runner 成轮卸包行为实录（人工验收 aperture=种子探针+外部击杀保数据面，探针已删）；pub 网络窗全灭致 file_picker/permission_handler 依赖加装暂缓（分发链挂账沿用）。**2026-10-20 动效打磨增录（开发者反馈「随机页面的 UI 动画有点差」）**：shuffle_page 动效重构=①槽位运动标量五元组逐项补间+每帧现算矩阵（AnimatedContainer 复合矩阵直接 lerp=枢轴抽动产因根除；卡的补间帧封面零重建）②拖拽层 ValueNotifier 纯 Transform 零 setState（拖拽掉帧根除）+显式 controller 回弹（320ms easeOutCubic 口径保持）③进度条 260ms 微补间消步进④inFloor 入场淡 0.55 落地（此前违档=静态 1.0）。**键位/手势语义/手感参数（40px 阈值/260px 头上限/0.045deg/px）零改动**。回归=宿主 2 锚+宿主域 36/36+analyze 0+E2E 14s 全绿（重构期排障两刀=手势增量态/视觉补间耦合泄漏→下滑误切红线近踩，已修；实录 IMPL-T9W §4.5-6/§8）。模拟器手动复验环境已重建（5 首实库+标准包，APK test-listener 变体事故与 EOF 轮转目视取景陷阱实录 §4.5-7/8）。**2026-10-20 复验二轮增录（开发者澄清裁决「歌曲卡片永远都会有 5 个，不因上滑缺失」）**：五主道改环形回绕解析恒满位（早轮 idx0/尾位/out 抑制缺位面根除）+ torn 走廊双实体机制（旧 _outId 抑制体系退役）+ `_SlotP` 全字段 ==（500ms tick 重建恒微抖产因补刀）；宿主形态锚 4→5 按开发者裁决同步；回归=analyze 0+宿主 2 锚+宿主域串行 78/78+E2E 16s 全绿（IMPL-T9W §8.1 全档）；E2E 正常收尾=卸包清库实录（§4.5-9），seed 探针改真驻留协议重建复验环境。**复验三轮增录（开发者澄清裁决「上滑只能滑动卡片，不是整个页面都动」）**：拖拽动面从整页收窄到卡组层（信息区/控件/提示定层不动；GestureDetector 整盘捕获不随位移热区稳定；手感参数/手势判定零改），回归=analyze 0+宿主 2 锚+78/78+E2E 22s 全绿（IMPL-T9W §8.2 全档）。**复验四轮增录（开发者澄清裁决「卡片的滚动应该是沿着圆心转动，而不是所有的卡片都进行上移后再进行切换」）**：轮转轨迹=绕转盘轴心 (-143.8,464) 极坐标弧线插值（直线 lerp 退役；550ms 曲线/端值/手感零改），回归=analyze 0+宿主 2 锚+78/78+E2E 21s 全绿（IMPL-T9W §8.3 全档）。证据=IMPL-T9W 全档 |
| T10 | S7 歌词与 ASR | pending | **RV-C 阻塞点**；CP-S7 |
| T11 | S8 同步 | pending | CP-S8（双实例联测） |
| T12 | 检查点 B + 演练 D2/D3（S6–S8 后） | pending | D3 需双设备 |
| T13 | S9 壳层整合 | pending | CP-S9 |
| T14 | S10 三端打包交付 | pending | CP-S10 |
| T15 | 提交 PHASE-5 gate（SUBMITTED；合并切片验收） | pending | IMPL-06 |

## 对应指导文档

- `engineering_acceptance.md` §6（IMPL-01..06）；`stage_acceptance.md`；`task_state_machine.md`
- `DEC-010-no-mock-policy.md`（验证一票全真）

## 阻断项

- 无阻断；RV-A/B/C 真机窗口（ISS-401/ISS-302 同源）到点阻塞对应切片，不阻断前置切片推进。

## 下一步

T9/S6 桌面形态提交候选已就位（93/93 machine 绿跑 + analyze 0 + IMPL-S6 §1–§5），唯一待办=开发者对 S6 含挂账面签收；签收后第一补项=扫码登录 UI（真 passport API，REQ-EXT-02 上半）+ DoD4 真断网/AUTH 演练 + DoD7 三链实跑（D2 现场相约）。S4 历史分组归属、RV-A/B/C 保留原状态。

## 续做恢复（2026-10-18）

- `process_log.py --root . resume-scan` 返回 0：旧任务未登记该脚本使用的状态清单，且旧计划名为 `PLAN-iA-Music-BUILD-5.md`；不据此重建 BUILD。以本计划 T2–T6 与 PHASE-5 §8 的签收记录恢复。
- 旧 change_log 目录为空；本轮首次建立真实 checkpoint。既有文件均未跟踪，保留原工作树，不将其冒认为本轮变更。
- 沿用 CP-S5 / TASK-S5 / 详细设计 §3.5 和 DEC-010；不改变数据设计与已签收范围。
