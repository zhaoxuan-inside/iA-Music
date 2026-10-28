# IMPL-S5 封面链实现与验证记录

- 记录日期：2026-10-18（按会话项目日期）；当前入口 RESUME → BUILD 5 / T7 / S5。
- 基线：S0–S4 已有开发者签收；TASK-S5 / CP-S5 / 详细设计 §3.5 / REQ-LIB-04、08 / DEC-010 有效。
- **工作状态：VERIFYING；切片验收：DRAFT，未签收。** 核心实现与自动检查已具备证据；真实断网演练、CAA 主源独立成功命中仍待补证。未进入 T8 检查点 A 或 S6。

## 1. 恢复与回退依据

- `process_log.py --root . resume-scan` 返回 0 个登记任务；既有计划采用 `PLAN-iA-Music-BUILD-5.md`，不符合工具默认文件名，且旧 change_log 为空。以 PLAN T2–T6 和 PHASE-5 §8 的明确签收记录恢复，不重开需求。
- 初次检查 `git status --short`：DESIGN.md、app、config、hs_dev_docs、mock 均为既有未跟踪内容；本次不把这些全部作为新工作提交。内容清单与 SHA-256 见 `output/qa/S5-content-manifest.json`。
- 首次真实 checkpoint：`cp_20261018_152709_116932`；后续 checkpoint 见 `_02_change_log/iA-Music-BUILD-5_changes.jsonl`。生成文件在重新生成前另有快照。
- 有一次 checkpoint 命令误在 app 根运行，生成两个工具账本文件；发现后已删除该两文件，全部有效回退依据保存在工程根的过程目录；未用其表示实际进度。
- 保留 S4 历史日期分组 UI 归属待裁决、RV-A/B/C、ISS-502 与 S10 既有回改项。

## 2. 实际改动

- `CoverChain`：内嵌字节 > 同目录同名图 > 已抓取图 > 联网补缺 > 首字母色块；同曲目并发合流；下载结束再次检查本地来源；exclusive create 不覆盖；只更新封面注册三列。
- `CoverFetchAdapter`：真实 MusicBrainz → CAA → iTunes；强制 User-Agent；共享 1req/s 令牌桶，重定向也限流；限定大小/超时与 JPEG 签名；失败静默，不自动重试。
- `TrackCover` 接入真实列表与胶片播放页，稳定 Future 避免每帧重复联网；命中后 FutureBuilder 即时呈现；加载/失败使用首字母色块。
- 设置页加入「在线封面」持久开关（默认 true）与版权说明；关闭时不联网，保留本地封面。
- 工作树已有 schema v2 与迁移代码，但 `ia_database.g.dart` 未同步，初次基线无法编译。运行 `dart run build_runner build --delete-conflicting-outputs` 完成生成；该版本工具提示最后选项已废弃，生成成功；后续执行使用 `dart run build_runner build` 即可。本次没有新增数据设计。
- 全量回归暴露旧异常库保护连接会执行 v1→v2 迁移。`NativeDatabase.opened(... enableMigrations:false)` 修复，S1 测试补异常库 user_version 保持 1 的断言。
- 方法/调用链契约：`_04_engineering_contract/_04_method_design/S5-cover-chain-methods.md`。公共 CoverFetchPort 未变更。

## 3. 红绿与问题修复

- 首条 C22 同名图测试先红（CoverChain/adapter 不存在，同时暴露旧生成文件未同步），实现与生成后转绿。
- 首轮本地测试发现 `whenComplete(() => _inflight.remove(id))` 返回自身在制 Future，形成循环等待；改为 void 块清理，加入并发同 Future 与重复浏览断言。
- 真实网络断言暴露「取令牌后才 DNS/TLS 建连」可让实际发送间隔缩至 531ms；取令牌移至建连后、发送前。并发全量运行再暴露 Windows 微秒定时器可能早醒 314μs；向上取整毫秒、单调时钟循环复核并保留 1ms 余量后通过。
- Widget binding 默认把 HTTP 换成合成 400；S5 联网 UI 测试显式移除该覆盖，恢复真正 dart:io HttpClient，测试结束恢复绑定。未以合成响应证明封面功能。
- Windows 路径断言统一比较 File URI，避免斜杠写法不同造成误报。

## 4. 当前运行证据

工程根 `E:/HardStone.iCodeing/GitHub/iA-Music`，Flutter 3.47.6 / Windows；真实 SQLite、磁盘、ffmpeg/APIC 音频、mpv_audio_kit 与公网服务。

- 命令（app 目录）：`flutter test --reporter expanded`，退出码 **0**；**85/85 PASS**（既有 76 + S5 9）。原始输出 `output/qa/S5-full-test.log`。
- 命令（app 目录）：`flutter analyze`，退出码 **0**，`No issues found!`；原始输出 `output/qa/S5-analyze.log`。
- 真联网样本：Imagine / John Lennon；MusicBrainz 返回 200，CAA 实际尝试且遇到 307 跳转后未成功完成主链；iTunes 200、mzstatic 图片 200，走兜底成功。下载为真实 JPEG，落位 Imagine.mp3.cover.jpg，再浏览零新增外呼；原音频字节不变。
- 无匹配测试用唯一不存在曲名；显式断言 MusicBrainz 与 iTunes **均返回 200** 后才认定无结果，避免把两源故障当作正常无匹配。
- 本地 fixture：`py app/tool/gen_cover_fixture.py` 用真实 ffmpeg 编码 JPEG 并封装 APIC MP3（无网络替身）；内嵌/同目录/已抓取/关闭开关色块分支均经真库真盘。
- UI：同一真实曲库与真 mpv 会话，先挂载列表/播放页，再等待真正联网命中；两处 placeholder 均替换为 Image，无 Flutter 异常。设置默认、持久化关闭与重进恢复单独测试。
- v1→v2 迁移：真实文件库降至 v1 表结构后重开，补齐列且旧曲目/FTS 保留；异常只读保护用例另验证拒写且版本不改。
- 严格一致性检查与索引重建结果：见 `output/qa/S5-consistency.log`、`output/qa/S5-index-rebuild.log`（本记录落盘后执行）；不将工具成功等同开发者签收。

## 5. TASK-S5 DoD 与 IMPL 核对

1. **DoD1 PASS**：四级来源分别有真实内嵌、本地图、真网络命中、关闭/无匹配色块的结果断言。
2. **DoD2 PASS**：已有内嵌/同名图/缓存图请求数为 0；诊断观察真实 HTTP adapter，不使用假的计数数据源。
3. **DoD3 PASS（iTunes 兜底实跑）**：同目录 JPEG + 注册位 + 已打开的列表/播放页即时换图；CAA 主链成功命中未宣称通过。
4. **DoD4 PASS**：容量一并发真实计时 ≥1 秒；实际外呼发送间隔另有断言。
5. **DoD5 部分 PASS / PENDING**：两源正常 200 无匹配 → 色块已过；**真实断网未演练**，不以关闭设置、关闭 HttpClient、错误端点或网络替身代替。
6. **DoD6 PASS（在线主场景）**：REQ-LIB-08 用真实已知曲目执行等价 Given/When/Then；内嵌和本地图不覆盖、音频不改有断言。断网变体仍保留上一项缺口。

- IMPL-01：PASS，红绿与关键回归有上述证据。
- IMPL-02：PASS，方法契约与词典同步，沿用原有 schema v2；未变更公共 Port。
- IMPL-03：PASS（当前 Windows 自动检查），静态零告警，真实回归 85/85；并发、临时文件、关停和只读连接经过核查。
- IMPL-04/05：**PENDING 完整闭合**，在线兜底/真实本地/UI/迁移证据齐全，主源成功与真实断网仍缺独立证据。
- IMPL-06：PENDING；开发者尚未签收 S5，不能标记 ACCEPTED。

## 6. 下一步与外部条件

- 在有真实可用 CAA/CDN 链路时，用已知匹配曲目取得主源成功命中证据；当前记录仅证明主源实际尝试与 iTunes 真兜底，不把外部失败算实现成功。
- 取得隔离测试环境的真实断网窗口，执行已知曲目缺封面→真断网→色块/无弹窗/无文件变更→恢复网络后再次浏览重试。不要自动断开开发者正在使用的主机网络。
- 补齐后提交 S5 证据与开发者签收，随后才推进 T8 检查点 A / D1；S6 仍受 RV-B 约束。
- 默认本地提交尚未执行：工作树基座全部未跟踪，不将前序未知归属内容混入本轮提交。未推送、未发布。
