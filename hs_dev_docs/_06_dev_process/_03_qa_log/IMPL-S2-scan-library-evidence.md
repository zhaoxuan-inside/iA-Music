# IMPL-S2：曲库扫描与浏览执行证据（S2 / TASK-S2 / CP-S2）

> **状态：ACCEPTED**（开发者会话签收原话「确认验收」，2026-10-18T00:41:21Z，全档=PHASE-5 §8 切片验收记录 S2 条目）

- **日期**：2026-10-18；环境：EXP-003（Flutter 3.47.6 / Dart 3.13.5；sqlite3 厂内化 3.50.4 FTS5 ✓）；验证=**DEC-010 全真**（真文件/真事件/真 isolate/真引擎，无替身数据）
- **切片**：S2（TASK-S2 DoD 1–5）；上游：DETAILED-DESIGN §3.1（扫描六联）+ §6.2 样例 1 判据 + REQ-LIB-01/02/03/05/06/07 + REQ-ONB-02

## 1. 依赖落位（ dispersion lock，TECH-SELECTION 记录一致）

- `audio_metadata_reader ^1.8.1`（解析器真件：含 ApeParser 侧支持；`readMetadata` 同步返回）+ `crypto ^3.0.7`（content hash）
- **ISS-504 差异登记**：S2 的 content_hash = **整文件 SHA-256**；spec 写「范围=音频帧」。S2 内两者对断言等价（编辑红线=不写文件，mtime/size/hash 纹丝不动）；分发期/同步引擎期（S6 前）裁决归属。adapter 头注与 scan_service 头注均声明。

## 2. 真 fixture（DoD1 判据载体，可再生成）

- `app/test/fixtures/library_smoke/`——**12 真音频**：
  1. 有效 10 件：探曲01–03.mp3 / 04–05.m4a / 07–08.ogg / 09–10.flac（真 ffmpeg 编码管线产出，中文 tag 全嵌——mp3/vorbis/mp4 header 实测解码 ✓）/ 探曲06.wav（32KB 无 tag=**文件名兜底用例**）
  2. `10_broken_probe.mp3`（2048 乱码字节——**真实损坏事故类**）
  3. `11_empty_probe.flac`（0 字节）
- 生成器 `app/tool/gen_library_fixture.py`（幂等：干净重跑可用；ffmpeg exe=imageio-ffmpeg 自带，中文目录经 py subprocess 调用规避 bash 内嵌展开问题）
- 字典覆盖：测试歌手A/B × 测试专辑壹/贰 → 断言 artists=2 行、albums=2 行（name_norm 唯一锚 upsert）

## 3. 交付构成（S2 纵切全件）

| 组件 | 文件 | 要点 |
|---|---|---|
| 扫描服务 | `app/lib/scan/scan_service.dart` | 六联：枚举白名单六扩展→**批 200/事务**（单 Isolate 批解析：tag+stat+整文件 SHA-256 合一）→ 字典 upsert→插/复删/恢复/touch 四分支（同批事务）→ 全轮 diff missing→ScanDone 报告（真实计数） |
| 目录监听 | `app/lib/scan/root_watcher.dart` | 真事件→**全事件脏信号**（不过滤扩展名）→防抖→增量枚举 diff 补扫；扫描期信号 `_dirty` 排队不丢 |
| 曲库域服务 | `app/lib/library/library_service.dart` | 移除=软删（REQ-LIB-07）；编辑=只动库行+FTS 同事务（REQ-LIB-03） |
| 协调器 | `app/lib/library/library_hub.dart` | 组合根：根行唯一校验→先挂 watcher（防竞态 `_dirty` 补扫）→全量扫描事件桥；`revisions` 广播流=页面刷新事件源 |
| 设置页 | `app/lib/ui/settings/repository_settings_page.dart` | 空态「尚未配置仓库」→添加（选择器缝，分发期接真 picker）→实时计数「已发现 N 首」→终态「入库 N · 跳过 M · 缺失 K」→自动进入音乐空间；「立即扫描」按钮=REQ-LIB-05 锚「触发下一轮」 |
| 曲库列表页 | `app/lib/ui/library/library_list_page.dart` | 四排序 chip（最近/标题/歌手/时长，REQ-LIB-06）；缺失行灰显+「文件缺失」徽标（REQ-LIB-05）；行菜单「编辑标题」对话框 /「从曲库移除」确认对话框 |
| DAO 增量 | `app/lib/data/daos.dart` | `insertTrackCore/WithIndex/Batch`（批 200 事务内含字典 upsert）+ `reconcileTrackMeta`（展示+FTS 同事务）+ `reviveTrack` + `rowsByRoot`（**含软删行**，diff 基线）+ `markMissing/markPresent` 缺删互斥 + `rootsSnapshot/liveTracksOnce`（四排序快照）+ `rowById/rootById` |

## 4. 测试证据（41/41 全绿：S1 基线 27 + 模板冒烟 1 + S2 新增 13；`flutter analyze` 0 issue）

### S2 新增 13 条明细

**A. adapter 真 tag（4）** —— `test/scan/s2_scan_test.dart`
1. mp3/ogg/flac/m4a 真 tag→ParsedMeta 全真（title/artist/album/format/size/mtime；**mp3 时长=0 注记**：audio_metadata_reader 对 mp3 Xing 标签时长返回 null→`tracks.duration_ms` 可空，播放期由引擎补齐〔S3 边界，非隐瞒〕——断言按格式分级 hasDuration）
2. 无 tag wav→裸值空串（兜底责任在扫描层，tables.dart 注释口径探曲06）✓
3. 损坏件（乱码）→契约层 `FormatException`（adapter 统一翻译，非新契约异常）✓
4. 零字节→`FormatException`（Error 类异常也被广捕，不走 `on Exception` 漏网）✓

**B. DoD1 真实计数红线（1）**
5. 12 件全扫→**`ScanDone.report`: total=10 / skipped=2 / added=10**；skippedPaths 含 10_broken_probe.mp3；track 行=10、FTS 行=10、字典 2+2；**「坏文件计 0 total」错误实现判败线**（§6.2 样例 1）✓

**C. 任务锁（1）**
6. 同 root 并发→StateError（async* 生成器首 yield 后挂起且锁仍持有至 moveNext——StreamIterator 确定性时序）✓

**D. DoD2–4 服务层（3）** —— `test/scan/s2_dod_test.dart`
7. **DoD2**：真事件→防抖增量→新文件 ≤15s 入库（stopwatch 实测）+ 改写件 size/mtime/hash 变更→updated_at 刷新 ✓
8. **DoD3**：编辑→FTS 同事务翻新+新拼音可搜+**文件字节/mtime/size/hash 零变化**（REQ-LIB-03 红线）✓
9. **DoD4**：软删→记录消失+**物理文件在**；活行文件移出→missing=1（软删行不计缺失=缺删互斥）；放回→07 复活（added=1）+ 08 missing_at 清零 ✓ **红测先行实证：原实现缺『缺失恢复』分支（只清 deleted 行）→补 `_dao.markPresent` alive 行分支后转绿**

**E. DoD5 三 Gherkin 锚 + REQ-LIB-06 行断言（4）** —— `test/ui/s2_ui_test.dart`（真库内存门+真 fixture+真 isolate 扫描链）
10. **锚 1 REQ-LIB-01**：空态「尚未配置仓库」→选择器缝返回**真实 fixture 目录**（无替身数据）→页面 `addAndShow` 同入口编排（runAsync 真时窗口）→自动进入音乐空间→**「10 首」** ✓
11. **锚 3 REQ-LIB-05**：移出仓库→「文件缺失」灰显（行仍在）→放回→恢复 ✓
12. **锚 4 REQ-LIB-07**：行菜单「从曲库移除」→确认→**「9 首」**+文件保留 ✓
13. **REQ-LIB-06**：标题升（首=探曲01，BINARY 序）/歌手升（null-artist 行 SQLite NULLS FIRST 首位）/时长降（**首位=库内时长最大行动态对齐**——fixture 实测最长者探曲04 而非假设的探曲01，避免脆弱硬编码）三序即时切换 ✓

### 本轮实证教训（工程事实，入档防复发）

| # | 教训 | 处置 |
|---|---|---|
| L1 | `Isolate.run` 闭包在实例方法内嵌套会**隐式传染 `this._db`**（不可发送对象）→ spawn 失败 | 解析批调用壳提为**静态方法**（`_runParseChunk`），闭包只捕获可发送 locals |
| L2 | dart:io `File.copy`（Windows）走**临时名写入→改名落位**，最终名**无 create 事件**（probe 实证事件=[create/delete/delete/8] 只挂临时名）→ 靠扩展名过滤事件找新文件必漏 | RootWatcher 改为**全事件脏信号**：新文件发现一律由增量枚举 diff 承担，事件只负责触发 |
| L3 | widget 测试 FakeAsync 内，真实 IO/isolate await（createTemp/复制/File.exists）**永不推进**——挂死无输出 | 真实 IO 一律包 `tester.runAsync` 真时窗口；断言经 pumpAndSettle 观察 |
| L4 | `await Navigator.pushReplacement(...)` 的 Future 依赖路由闭合 | 入库编排弃接该 Future（drop await），路由切换由帧循环自完成 |
| L5 | **drift watch 流在 FakeAsync 下拖挂后续查询**（实证：watchRoots 订阅在场时 rootById 挂死；无订阅全链路通过） | 页面消费改 `hub.revisions`（纯 int 广播流）+ Future 快照重取；watch API 保留（生产真 zone 理论可用，S9 装配期再裁决默认形态——非隐瞒注记） |

## 5. S2 DoD 对照（TASK-S2 五条，全达成）

1. **真实计数**：12 件→total=10/skipped=2 ✓（红测守门，§4-B5）
2. **增量 ≤15s**：真事件链+updated_at 刷新 ✓（§4-D7）
3. **编辑不写原文件**：字节/mtime/size/hash 纹丝不动+FTS 同事务 ✓（§4-D8）
4. **移除/恢复**：软删记录消失+文件保留；软删复活+缺失恢复（红测驱动补 markPresent 分支）✓（§4-D9）
5. **三条锚可跑**：REQ-LIB-01/05/07 widget+真库全绿 ✓（§4-E10–12）

**锚措辞偏差注记（如实）**：锚 1 Gherkin「含 500 首目录」——以真实 ffmpeg 生成的 10 有效件固定量替代（判据口径同构：计数=实际音频数）；「界面展示扫描进度与实时计数」=ScanProgress 流（service 断言 admitted 单调）+设置页状态行；「500 首 1 万首量级性能」=S9 装配期量测项（SQL 排序+批事务架构已就位）。

## 6. 残留与移交（不阻断）

- **UI 选择器**：`pickDirectory` 缝当前由壳层装配系统目录选择器（S10 分发期接真 picker；测试注入处返回**真实目录**，DEC-010 合规）
- **onboarding 自动进入音乐空间**：锚 1 链路已立（pushReplacement）；与 S0 壳层引导流的联动= S9 装配期复核
- **RV-A/B/C** 真机三项不变（mpv 后台/EQ/长稳；yt-dlp AAR；sherpa arm64 RTF）→ **S3 前提醒开发者 Android 真机窗口**
- ISS-502 Linux 构建/冒烟（分发期开发者环境）；ISS-503（S1 修正留档）；ISS-504 content_hash 口径（S6 前裁决）
- S1 移交项状态不变：SecureStore 运行时验证→S3/S8 链路；sqlite3 `file://` 原型路径→S10 前回改

## 7. 运行命令实录

```
flutter analyze          → No issues found!
flutter test test/       → All tests passed!（+41）
```

（本轮开发链：fixture 生成→红测实录→DoD1 绿→DoD2–4 红/绿→UI 纵切→DoD5 锚 4/4 绿；孤立 flutter_tester 持锁排障与 FakeAsync 复盘详见 §4-L3–L5）
