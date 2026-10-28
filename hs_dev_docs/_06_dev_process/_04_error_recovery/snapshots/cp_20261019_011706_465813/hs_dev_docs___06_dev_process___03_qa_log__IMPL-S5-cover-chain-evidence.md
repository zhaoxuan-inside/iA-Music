# IMPL-S5 封面链实现与验证记录

- 记录日期：2026-10-18；续做更新：**2026-10-19（Asia/Shanghai）**；当前入口 RESUME → BUILD 5 / T7 / S5。
- 基线：S0–S4 已有开发者签收；TASK-S5 / CP-S5 / 详细设计 §3.5 / REQ-LIB-04、08 / DEC-010 有效。
- **工作状态：VERIFYING → 提交候选（SUBMITTED 待签收）。** 核心实现、85 项自动检查、CAA 主源真实命中（经开发者本地代理）、Android/x64 真实断网与恢复联网重试均已具备证据；仅剩「代理恢复后的最终全量回归绿跑」与开发者签收。未进入 S6。

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
5. **DoD5 PASS**：两源正常 200 无匹配 → 色块；2026-10-19 Android 真实飞行模式 + Wi-Fi/移动数据关闭 + 无默认网络 → 首字母色块、无弹窗、无封面文件、音频哈希不变（见 §7）。未用关闭设置或网络替身代替断网。
6. **DoD6 PASS（在线兜底与断网场景）**：REQ-LIB-08 用真实已知曲目执行等价 Given/When/Then；内嵌和本地图不覆盖、音频不改有断言；断网变体已有 §7 实证。

- IMPL-01：PASS，红绿与关键回归有上述证据。
- IMPL-02：PASS，方法契约与词典同步，沿用原有 schema v2；未变更公共 Port。
- IMPL-03：PASS（当前 Windows 自动检查），静态零告警，真实回归 85/85；并发、临时文件、关停和只读连接经过核查。
- IMPL-04/05：**证据面已齐，提交候选**——在线兜底（iTunes 真命中）、CAA 主源命中（§8 经代理）、真实本地/UI/迁移/Android+x64 断网与恢复联网重试（x64 实跑成功；ARM64 恢复 DNS 失败如实保留）均有独立原始证据；唯一待办=代理恢复后的 86/86 最终绿跑。
- IMPL-06：PENDING；开发者尚未签收 S5，不能标记 ACCEPTED。

## 6. 下一步与外部条件

- 在有真实可用 CAA/CDN 链路时，用已知匹配曲目取得主源成功命中证据；当前记录仅证明主源实际尝试与 iTunes 真兜底，不把外部失败算实现成功。
- 隔离模拟器的真实断网降级已完成；后续在 DNS 正常的隔离环境补恢复联网后的同曲重试。主机网络未断开、DNS/hosts 未修改。
- 补齐后提交 S5 证据与开发者签收，随后才推进 T8 检查点 A / D1；S6 仍受 RV-B 约束。（T8 / D1 已于 §8 提交候选中先行准备。）
- 默认本地提交尚未执行：工作树基座全部未跟踪，不将前序未知归属内容混入本轮提交。未推送、未发布。

## 7. 2026-10-19 续做：Android 真实断网及构建补证

- 新增复跑工具：`app/tool/s5_cover_probe.dart`（真实 CAA/iTunes 诊断）、`app/tool/s5_offline_probe.dart`（真实音频字节、SQLite、CoverChain 和 TrackCover；独立开发探针入口）。未修改产品默认入口。
- CAA 排障：再次使用 Come Together / The Beatles 实呼；MusicBrainz 200 → CAA 404/307 → archive.org 连接超时 → iTunes 200 + 真 JPEG。原始 URL/状态见 `output/qa/S5-caa-probe.log`。系统解析和 HTTPS DNS 查询结果不同；指定 HTTPS DNS 返回的地址后 TLS 连接仍超时。没有改主机 DNS、hosts 或降低证书校验。已向开发者询问是否有可用本机代理，未收到地址前不配置代理。
- 专用 AVD `ia_s5_cover` / `emulator-5580`（Android 35）由本轮创建，不触碰既有 BloodPress_EMU。启动参数 `-no-window -no-audio -no-snapshot`，只对这个模拟器操作网络。
- Java 21 的 Gradle daemon 初次报 `Unable to establish loopback connection`（UnixDomainSockets EINVAL）。仅本轮构建设置 `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=E:/HardStone.Android/java-tmp -Djava.io.tmpdir=E:/HardStone.Android/java-tmp` 后构建继续。参数依据 Oracle JDK 21 的 [Unix domain sockets 文档](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/net/doc-files/net-properties.html)，未改全局环境或 JVM 安装。
- x86_64 mpv 官方二进制下载连续失败；已下载 ARM64 真实 libmpv，AVD 声明支持 `x86_64,arm64-v8a` 与 libndk_translation。以 ARM64 构建并用 `adb install -r --abi arm64-v8a` 安装；普通自动选 ABI 曾因 transitive libdartjni 的 x86_64 条目误选主 ABI 而启动失败，强制正确 ABI 后正常运行。该限制属于此探针安装过程，未据此声称三端打包验收通过。
- Android SQLite：原 `source: system` 只指定 Windows 文件名，不能作为 Android 自带 sqlite3 的分发保证。改为 source 按 OS 选择：Windows 沿用原 DLL；Android 从官方未改动 SQLite 3.50.4 amalgamation 编译；默认其他端采用包管理二进制。`app/source/sqlite3/SOURCE.md` 记录来源；zip SHA-256=`1d3049dd0f830a025a53105fc79fd2ab9431aea99e137809d064d8ee8356b032`；native hooks 默认定义含 FTS5，真实 schema 建表已成功。Android 主 manifest 补 INTERNET（以前只在 debug manifest）。没有新增 DB 表/列或变更版本语义。
- 构建：`flutter build apk --debug --no-pub --target-platform android-arm64 -t tool/s5_offline_probe.dart`，退出 0，24.9s（首次含源码编译为 149.6s）；归档 `output/app_mobile/S5-cover-probe-debug.apk`，SHA-256=`bacecefdc0087e86d732b295f17a0f6fe40d0c7d868239fc409abd0a5946f02b`。这是专用探针 APK，不是生产应用交付包。
- 真断网步骤：`adb -s emulator-5580 shell cmd connectivity airplane-mode enable`、`svc wifi disable`、`svc data disable`；等待系统状态确认 `Active default network: none`、`airplane_mode_on=1`、`Wifi is disabled`，然后启动探针。状态文件 `output/qa/S5-emulator-connectivity-offline.log`。
- **实跑结果**：SQLite **3.50.4**；`kind=none`；`registeredKind=none`；`coverExists=false`；`audioUnchanged=true`；`requests=0`（离线时连接在 HTTP 发送前失败），耗时 5301ms。宿主脚本解析 JSON 并逐项断言通过。原始结果 `output/qa/S5-android-offline-result.json`，日志 `S5-android-offline.log`，截图 `S5-offline-probe.png` 展示首字母 I 色块且无错误弹窗。
- 恢复演练：飞行模式关闭、Wi-Fi/移动数据开启后，默认网络恢复为 102；经 UI「重新检查封面」调用同一个 CoverChain、同一真实库行 ID=1。结果仍 none、音频不变；系统 `ping` 两个 API 域名均报 `unknown host`。因此**恢复成功未验证**，不将链路失败当作成功；结果 `S5-android-restored-result.json` 与 `S5-android-restored.log`。
- 修改后重跑：全量 **85/85 PASS**，`flutter analyze` **No issues found**；日志沿 §4 更新。校验与内容 manifest 随此记录重新生成。
- 探针设备在网络开关恢复后关闭，保留专用 AVD 与 QA 证据用于复跑；不保留后台模拟器占用资源。

## 8. 2026-10-19 续做（二）：代理恢复 CAA 主源命中与恢复联网重试补证

- 开发者提供既有本地代理 `127.0.0.1:7897`（此前系统代理处于开启状态）。未改主机 DNS、hosts 或降级证书校验；`CoverFetchAdapter` 以 `HttpClient.findProxyFromEnvironment` 走环境代理，属既有环境感知实现，不为通过测试特配。
- **CAA 主源真实命中（DoD3/IMPL-04 缺口闭合）**：
  - 探针复跑 `s5_cover_probe.dart`（Come Together / The Beatles）：MusicBrainz 200 → CAA 307 → archive.org 302 → `dn711004.ca.archive.org:200`（index.json）→ 1200 JPEG 302 → `200`，`RESULT caa`，JPEG **112406 字节**。逐请求原始日志 `output/qa/S5-caa-probe-proxy.log`；CAA 索引原始响应样本 `S5-caa-index-live.json`（release d8da5039-…，5 张已批准图含 Front 1200 桩）。
  - 独立网络测试 4/4 PASS（`S5-caa-network-test.log`、`S5-caa-primary-test.log`，00:41）：主链命中 `dn721907/dn711305.ca.archive.org:200` 且**不调用 iTunes**、≥1 秒逐跳限流断言过；REQ-LIB-08 全链场景与两源 200 无匹配分支同轮通过。 archive.org 间歇 500/超时由链路真实重试覆盖（日志中 500 后换宿主命中），未伪造成功。
- **恢复联网同曲重试（DoD6/IMPL-05 缺口闭合，x64 实跑）**：x86_64 模拟器（同 AVD `ia_s5_cover`，S5-emulator.log Device ID 46a6）真实断网（kind=none、requests=0、色块、音频不变，`S5-x64-offline-result.json`，SQLite 3.50.4）→ 恢复联网后经 UI「重新检查封面」同一 CoverChain、同一真实库行：**7 请求全真**（MusicBrainz 200 → CAA 307/302 → `dn711104.ca.archive.org:200` ×2），`kind=fetched`、`coverExists=true`、`audioUnchanged=true`、`sameTrackId=1`。原始 JSON `S5-x64-restored-result.json`、logcat `S5-x64-network.log`（S5_PROBE_RESULT / S5_PROBE_RETRY）、界面截图 `S5-x64-restored.png`。
- **如实保留的差异**：ARM64（emulator-5580）先前的恢复联网重试仍为 `kind=none`（模拟器 DNS unknown host，`S5-android-restored-result.json` 00:30，早于代理可用时间窗），未回刷为成功；ARM64 断网降级 PASS 结论不变。
- 01:50 那轮全量为代理关闭、archive.org 直连不可达所致的 1 项 CAA 网络性失败，非实现回归；测试未弱化、未跳过，记录存档于此。`flutter analyze` 已确认 **No issues found**（`S5-analyze.log`；D1 测试 34:9 的 curly-braces info 已随文件修正消解）。最终结果以下一行绿跑为准。
- **最终全量绿跑（2026-10-19，代理可用窗口）**：`flutter test --reporter json` 退出 0，**87/87 PASS、0 error、0 skipped**——基线 85（S0–S5 各切片）＋ widget 冒烟 1 ＋ 检查点 A D1 集成 1；17 个测试文件全部加载（含 `test/integration/d1_library_playback_playlist_test.dart` 与 `test/widget_test.dart`）。原始 machine 记录 `output/qa/S5-full-test-final-m.log`（权威计数源）；同批 expanded 记录 `S5-full-test-final.log` 因并发互写仅显尾部的 4 个文件轨迹，计数「+87 All tests passed!」一致，不作为缺考依据。`flutter analyze` **No issues found**。
- **结论口径**：S5 六条 DoD 证据面已齐（DoD3 补上 CAA 主源命中；DoD6 补上恢复联网重试 x64 实跑）；submitting = S5 + 检查点 A / D1（`IMPL-D1-checkpoint-A-evidence.md`，1/1 PASS，且已并入全量绿跑）。开发者签收前不标 ACCEPTED。
