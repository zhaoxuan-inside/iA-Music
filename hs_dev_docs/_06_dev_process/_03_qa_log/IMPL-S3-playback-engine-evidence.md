# IMPL-S3：播放引擎竖切执行证据（S3 / TASK-S3 / CP-S3）

> **状态：ACCEPTED**（开发者会话签收原话「确认签收」，2026-10-18T03:25:11Z，全档=PHASE-5 §8 切片验收记录 S3 条目；一轮答复原话只覆盖其明确列出的阶段——本轮唯一提交候选=S3/T5）

- **日期**：2026-10-18；环境：EXP-003（Flutter 3.47.6 / Dart 3.13.5）；验证=**DEC-010 全真**（真 mpv 引擎+真 ffmpeg 短样本+真库行；无替身数据、无 stub 引擎）
- **切片**：S3（TASK-S3 DoD 1–6）；引擎=**mpv_audio_kit 0.5.1**（pub 镜像 + GitHub libmpv-r17 hook 产物 DLL 9,143,296 B）；上游：DETAILED-DESIGN §2.1（Port/Adapter）+ §3.6（恢复）+ §4.3（全净生命周期+重试 1 次）+ ARCH §3.2（随机后台/历史语义）+ REQ-NAV-02 / REQ-PLAY-04 / REQ-PLAY-08

## 1. 依赖落位（dispersion lock，TECH-SELECTION RV-A 线推进）

- `mpv_audio_kit 0.5.1`（`Player(PlayerConfiguration(logLevel:))` / `open / openAll(medias, play:, index:)` / `Playlist{index,items}` / `Gapless.weak` / `MpvFileEndedEvent.reason`（无 .code）/ `MpvEndFileReason{eof,stop,quit,error,...}` / `sendRawCommand(['seek','<sec>','absolute'])` / `setMediaSession(...)` / 日志流 `prefix/level/text`）+ `fftea 1.5.0+1`（被动带入）
- pubspec.yaml/pubspec.lock 已改（**uncommitted，随本片待开发者自提**）；Windows 桌面真起播实证（flutter_tester 内真解码真出声）

## 2. 关键机制探针实证（临时探针三只，结论入档后已删）

| # | 探针结论（机村实证） | 落进实现 |
|---|---|---|
| P1 | `endFile(eof)`=中段自然完了；`completed=true`=末条 keep-open park 时扣留的 END_FILE（会成对：`EngineStateChanged(ended)`+`EngineItemEnded(last)`）；`endFile(stop/quit)`=控制指令回声（吞） | 事件映射唯一口径（adapter） |
| P2 | `endFile(error)`→**仅** EngineError；mpv 自动推进下一条（`EOF[1]:error → PLAYING=true` 实证）；无「error→停在原地」语义 | 服务镜像 `_current++` 不重载（零重复 toast/重复重启） |
| P3 | typed `p.seek(Duration(...), relative:false)`=mpv 源头拒（−12）；raw `['seek','<sec>','absolute']` 在暂停态与**播放态**均精确落位 | seek 转义阀=raw absolute（失败→`EngineFailureException`） |

## 3. 交付构成（S3 纵切全件）

| 组件 | 文件 | 要点 |
|---|---|---|
| 引擎适配器 | `app/lib/adapters/mpv_engine_adapter.dart` | 索引权威=`_cursor`（事件投递期 `playlist.index` 竞态漂移→**自持游标**：loadAndPlay/restore 锚 startIndex、eof 自增、error 同步自增）；心跳节流 220ms；`_waitLoaded`（duration>0 上界 5s——mpv 载入未就绪时命令 −12）；EQ=`EngineCapabilityException`（S3 明示不支持线，TASK-S3 规则包内 EqualizerEffect 真实现留 S4/RV-A 直桥）；`setPrefetchPlaylist/setAudioBuffer` **不落引擎**（探针毒化实证：prefetch 使 index 预推进、buffer 使 playing 事件彻底失发）——契约位保留记 IMPL-S3 §5 |
| 播放域服务 | `app/lib/playback/playback_service.dart` | startRandom（池采样→loadAndPlay）/ 自动新一轮（末条 park→池重采样池空→emptyPool 停驻）；dislikeThenNext（名单+跳下一+**首点 Toast「已减少这首的推荐」**）/ next/previous（>3s 回头规则）；缺失判定=**真 fs stat**：不存在→`missing_at` 补写+「《X》文件缺失，已跳过」；在位→「《X》无法播放该文件（格式或文件损坏），已跳过」（行仍记，标 missing 与否分岔）；历史=延迟合并写（阈值 8+显式 flush）自然 EOF=completed=true / 跳过·缺曲·损坏=completed=false；会话快照 `playback.session`（Settings JSON：items/index/pos，路径统一正斜杠）；restoreFromDisk（镜像回填**先于**引擎恢复；失败重试 1 次→二次失败「播放服务异常」notice+false）；FLUTTER_TEST 环境跳过 `_publishSession`（_method-channel 宿主缺失会毒化引擎事件链） |
| DAO 增量 | `app/lib/data/daos.dart` | `randomPool(sampleSize/candidateCap/includeFewWatch)`（SQL 粗筛：双 NULL+NOT IN few_watch→内存 Fisher-Yates 洗牌斩样）；`recordBatch`（多行单事务）；`fewWatchIds`（池口径核对/UI 徽章读取）——D9-1/2/3 与 S1 原语齐装 |
| 会话/异常 | contracts | `EngineFailureException extends ContractException`（默认 message「播放服务异常」；显式 body 传 detail） |
| 曲库列表页 | `app/lib/ui/library/library_list_page.dart` | S3 增量：AppBar 洗牌键（随机入口）+底部迷你播放条（当前曲/垃圾桶/下一首）+顶部服务提示横幅（REQ-PLAY-08 原话链路）；State 公共缝 `startShuffle/dislikeNow/nextNow/playbackOrNull`（页面级引擎生命周期，S9 装配复核） |
| 设置页 | `app/lib/ui/settings/repository_settings_page.dart` | 「清空少播名单」tile（REQ-PLAY-04 末句；roots 空态与非空两分支均挂） |
| Data 增量 | `app/lib/library/library_hub.dart` | `data` 门面 getter（页面级 DataAccess 一次性注入） |

## 4. 测试证据（59/59 全绿：基线 41 + S3 新增 18；`flutter analyze` 0 issue；全量回归实录 `flutter test test/ → All tests passed!（+59）`）

### S3 新增 18 条明细

**A. 引擎适配器（7）** —— `test/playback/s3_engine_adapter_test.dart`
1. init 契约（ensureInitialized 走真 libmpv 载入）+ 会话桥 FLUTTER_TEST 跳过 ✓
2. **短样本连播链**（DoD2 中段）：loadAndPlay（真 mp3×2）→ item0 自然 EOF→`EngineItemEnded(0)`→item1 playing→**心跳 ≥3 次**→末条 park→`EngineItemEnded(1)`+ended ✓
3. `setEqBands` →`EngineCapabilityException`（明示不支持线）✓
4. play/pause 鸣面 ✓
5. **seek 落位 0.6s 中点**（raw absolute；风云洞穿见 L1——目标真实取值 600ms=0.6s**文件内毫秒**）✓
6. **restore**（探 05.m4a，positionMs=900ms）→ openAll(paused)→raw seek→**play 自落点续播+tick ≥850ms** ✓
7. dispose 全净（事件流关闭+会话不再发布）✓

**B. 播放域服务（7）** —— `test/playback/s3_playback_service_test.dart`
8. startRandom（REQ-NAV-02 服务面）：真池 3 件→真播→自然 EOF→**flush 链**（阈值未满显式冲亦成批）→历史 completed=true ✓
9. dislikeThenNext（REQ-PLAY-04 服务面）：名单落库+立即下一首+completed=false 历史+**严格池 لع射性排除**+设置可清空→池恢复 ✓
10. **缺失跳过**（REQ-PLAY-08 真链路）：真不存在的行→EngineError→真 fs stat→`missing_at` 补写+「文件缺失，已跳过」notice（原话）+completed=false 历史+镜像推进不重载 ✓
11. **损坏跳过**：真坏件 10_broken_probe.mp3→「无法播放该文件」notice（**不标 missing**=损坏非缺失）✓
12. **DoD5 restore**：kill（dispose）前会话 JSON 轻持久（settings 真有 playback.session）→新服务 restore=**镜像回填+队列+进度捏位+Mechanics 版自动起播**（kill 前 tick 与 restore 后 tick 差值 ≤330ms 容差窗口）✓
13. **恢复二次失败**（§4.3）：引擎外力 dispose→restore 两次抛（真 StateError 双 src）→「播放服务异常」notice+false（**红测先行：首版 restore 只喂引擎不回填自身镜像——先红后绿**）✓
14. **池不足 10=全库补满**（NAV §3.5 规 1）：少播挤到 2→startRandom 队列=全库 12（少播回场）✓

**C. DoD1 密度面（1）** —— `test/data/s3_pool_density_test.dart`
15. **500 行真库**：双 NULL+NOT IN 精确 497（三类排除样本断言即时计数 1/1/1）；**样本 3=有界子集+单轮不重复**；池计算毫秒级（实测上界窗 <200ms）；495 少播后→严格池 2 / includeFewWatch 全库补满 498（=500−软删−缺失：**补满语义=少播回场**，口径分界诚实记录）
- **fixture 口径注记（DEC-010 诚实线）**：本测是**行级 fixture**（真 DB 实体 500 行、真查询、真洗牌）而非 500 个物理音频文件——D9-2 抽断言的对象是 SQL 粗筛+内存采样（§1.3 对应查询），种行物理落盘与 DoD1 判据无关；S1 已有 12 物理真件载体 ✔

**D. DoD6 三 Gherkin 锚（3）** —— `test/playback/s3_ui_anchor_test.dart`（真引擎+真库+真 fixture 拷贝临时目录；FakeAsync 三定律全遵守）
16. **锚 REQ-NAV-02**：点随机→曲库随机开播→迷你条=当前曲真名 (探曲01)+playing ✓
17. **锚 REQ-PLAY-04**：垃圾桶→立即切下一首+**Toast「已减少这首的推荐」**+名单落库；设置页「清空少播名单」tile→清空→该曲重新可被随机 ✓
18. **锚 REQ-PLAY-08**：「文件已被外部删除」（**真删** 旧信.mp3）→自动跳到再下一首+顶部提示**「《旧信》文件缺失，已跳过」**（原话）+`missing_at` 补写 ✓

### 本轮实证教训（工程事实，入档防复发）

| # | 教训 | 处置 |
|---|---|---|
| L1 | **positionMs 语义穿写事故**：此前探针把 ms 目标写成 600000（=600 秒）→mpv 合纪夹到文件末（2 秒短片）：将全部「seek 掉队/park 神话」落到**单位错误**——契约 `positionMs` 按毫秒完善理解：**目标必须落在文件时长内**，短样本 seek/restore 测试用 600/900ms | seek/restore 测试目标改成文件内真实毫秒（红线提醒：契约级单位=ms；实现层 mpv 需 `/1000=秒`——转义点在 adapter 单处） |
| L2 | **openAll 替换队列时旧代事件串场**（实证：restore 序列 `[loading, ended, E=0, playing,…]`——上一代 park 的 completed 在新代 loading 期漏投） | adapter `_onCompletedValue/_onEndFile` 加**世代状态守卫**：`loading/idle` 期 eof/completed 一律不经语义路由（playing/paused 才有效）；还能防御服务层重载竞态 的 in-flight 旧代事件 |
| L3 | raw absolute seek 在**播放态**同样精确落位（0.6s 中点 tick 实测）；typed seek −12 是 mpv 源头拒（非状态问题） | raw absolute 转义阀保留；typed −12 归档为包待升级/RV-A 项（不弃） |
| L4 | **`tester.runAsync` 返回 `Future<T?>`**（binding.dart `runAsync<T> → Future<T?>`——T 推断正确仍可能 null 收尾） | 所有 runAsync 结果非空解包（`(...)!`）；分析器逐条爆出后全量修复 |
| L5 | **testWidgets 体内的真 IO（createTemp/File.copy）在 FakeAsync zone 永不推进=挂死无输出**（三锚全柱瘫 3 分钟） | 纪律升级：harness 整段真 IO+真库操作**一次 runAsync 包住**；teardown 用**同步 API**（createTempSync/copySync→deleteSync——dart:io 同步面在 fake zone 可用） |
| L6 | **broadcast 事件跨 zone 不成帧+无重放**（实证：svc.notices/status 的 StreamBuilder 挂上后事件不做帧、首点监听挂晚了=永远错过；`tester.runAsync` 内 `firstWhere` 等事件 30s 不来） | 消费面改**每帧 Future 重读**（服务暴露 `lastNotice` 单值读；页 strip/横幅 FutureBuilder 直读 `svc.snapshot`）+ pumpWidget 根重建双拍；断言策略从「流侦听」改「**轮询 lastNotice/快照直读**」（S2-L5 的姐妹律，S4 沉浸面接真 zone 响应式流另行裁决） |

## 5. 残留与移交（不阻断）

- **bufferMs / preloadNextCount**：契约字段在、适配器**不落引擎**（毒化实证×2）——契约位保留，mpv_audio_kit 升级/RV-A 后再议（非隐瞒，代码 `if (cfg.bufferMs < 0)` 占位注释）
- **typed seek −12**：包待升级项；转义阀=raw absolute（已实证暂停/播放双态落位）
- **会话桥（SMTC/MPRIS/Android 通知栏）**：FLUTTER_TEST 跳过 `_publishSession`（MethodChannel 宿主缺失会毒化引擎链）；**真桥=桌面/Android 真应用演练**=DoD3 遗留证据项（待开发者真机窗口）
- **RV-A 真机三项**（不变）：mpv 后台连续播放/EQ/长稳定——**DoD3 收口依赖**；EQ 行挡在 `EngineCapabilityException`（明示不支持）上，RV-A 结论回填后 S4 直桥
- **会话 restore 的首页进度误差窗**：kill 与 restore 的 tick 需求差 ≤330ms（单 tick 粒度 220ms 内生，S4 沉浸页可视化另有无障碍口径）
- ISS-502 Linux 分发（不阻断）；ISS-504 content_hash 口径（S6 前裁决）
- 移交自 S2 的项全部顺延：S1 SecureStore 运行时验证（S3/S8 链路）、sqlite3 `file://` 原型路径（S10 前回改）

## 6. S3 DoD 对照（TASK-S3 六条，含明示不支持线路径）

1. **随机池**：双 NULL+NOT IN few_watch（§1.3 对应查询）+**500 行内存采样断言** ✓（§4-C15）
2. **短样本连播+垃圾桶**：itemEnded→自动下一首（§4-A2）；垃圾桶=跳下一+名单+设置可清空（§4-B9/锚 17）✓
3. **后台/锁屏/媒体键**：桌面/Android 真平台演练=OPEN 项（§5；**阻塞依赖开发者真机窗口**——RV-A 并面）⚠（任务内唯一保留敞口；其余五条全绿候选）
4. **缺失自动跳过+顶部提示（REQ-PLAY-08 原话）** ✓（§4-B10/锚 18；设置页四态原话「无法播放该文件」 borne（§4-B11））
5. **恢复：kill→restore 队列+进度；二次失败→「播放服务异常」UI** ✓（§4-B12/13）
6. **DoD6 三 Gherkin 锚可跑**：REQ-NAV-02 / REQ-PLAY-04 / REQ-PLAY-08 全绿 ✓（§4-D16–18）

## 7. 运行命令实录

```
flutter analyze          → No issues found!（含 amp 临时探针删除后归零）
flutter test test/playback/s3_engine_adapter_test.dart    → +7（先红后绿：seek 单位、restore 镜像两红）
flutter test test/playback/s3_playback_service_test.dart  → +7（先红后绿：restore 不回填镜像红→绿）
flutter test test/data/s3_pool_density_test.dart          → +1（497/498 双口径）
flutter test test/playback/s3_ui_anchor_test.dart         → +3（FakeAsync 三定律全遵守）
flutter test test/       → All tests passed!（+59）
```

（开发链：探针三只实证→adapter 红→绿（含 L1/L2 修复）→service 红→绿（含 restore 镜像）→DoD1 密度→UI 最小挂接→三锚→全量回归。mpv_audio_kit 首适配经验集=r7；纵横两线（THRESHOLD 8/flush、镜像先行）已与 ARCH/DESIGN 对齐。）
