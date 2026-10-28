# IMPL-S4：播放页与歌单竖切执行证据（S4 / TASK-S4 / CP-S4）

> **状态：ACCEPTED**（开发者会话签收原话「确认验收」，2026-10-18T06:20:02Z，全档=PHASE-5 §8 切片验收记录 S4 条目；一轮答复原话只覆盖其明确列出的阶段——本轮唯一提交候选=S4/T6）

- **日期**：2026-10-18；环境：EXP-003（Flutter 3.47.6 / Dart 3.13.5）；验证=**DEC-010 全真**（真 mpv_audio_kit 0.5.1 引擎 + 真 ffmpeg 短样本 + 真 drift 库 + 真 fs）
- **切片**：S4（TASK-S4 DoD 1–6）；上游：playback_prd（REQ-PLAY-01/03/04/06/07）+ playlists_prd（REQ-PL-01..06）+ navigation_prd（REQ-NAV-01）+ DETAILED-DESIGN §1.2（playlist_tracks 唯一约束）+ §3.5（封面占位来源=CoverChain，S5 供给）+ ARCH §3.2；视觉锚=DEC-004/006（胶片帧 `#0D0F11` r18/画面 r10/框底打孔带/标题左对齐+心动于右/进度白点）
- **边界**（TASK-S4）：封面素材只渲染不决策来源（S5）✓；歌词页不在本片（S7）✓；随机入口大卡/轮盘行为归 S3 ✓

## 1. 交付构成（S4 纵切全件）

| 组件 | 文件 | 要点 |
|---|---|---|
| 播放域服务增量 | `app/lib/playback/playback_service.dart` | `PlaybackMode{loops,single,sequence,random}`（默认=**列表循环**，playback_prd §3.1）+ `setMode`；`_roundTail()`=一轮末/越界的**模式化路由**（随机=池重采样续轮 / 列表循环=同队从 0 重播 / 单曲=同位重播 / 顺序=停驻不重载）——`_onItemEnded` 末条与 `_advanceAfterFailure` 末条**同路由**；`playTrackIds(ids)`=行点击/歌单「播放全部」（服务内做根目录 joinAbs 解析，**页面不越域读表**）；`loadTracks` 公开缝；`insertNextId(trackId)`=插队镜像 `_current+1`+引擎物理增列；`jumpTo(index)`=队列页跳播（记当前曲未完成历史）；`setEqBands` 统一缝（true=实时生效 / `EngineCapabilityException`→false=明示不支持） |
| 引擎契约增量 | `app/packages/contracts/lib/src/engine.dart` | `EnginePort.insertNext(TrackLite)`（REQ-PLAY-06 插队=**Port 面**新增，非页面私技） |
| 引擎适配器增量 | `app/lib/adapters/mpv_engine_adapter.dart` | `insertNext`=mpv `loadfile <path> insert-next`（原生插队：**不打断当前曲**、物理 playlist 即时增列与服务镜像同位对齐）；失败→`EngineFailureException(message:'insertNext 失败', detail:path)` |
| DAO 增量 | `app/lib/data/daos.dart` | `PlaylistDao.listAll()`（排除软删 + 每单曲目计数）/`contains`/`trackCount`/`touchUpdatedAt`；`LibraryDao.libraryTotal()`（活行计数=列表同构）；`HistoryDao.historyTotal()`；**`ensureFavorite` 并发安全化**（撞 `kind=system_favorite` 部分唯一索引→回读既有行，见 §4-L1）；系统歌单名归正 **「我喜欢的音乐」**（PRD REQ-PL-01 规范名；S1 占位名「收藏」归正） |
| 歌单域服务（新） | `app/lib/playlists/playlist_service.dart` | `listAll`（digest=真行+计数）/`toggleFavorite`（加/出+时间戳；REQ-PL-01）/`isFavorite`/`favoriteCount`/`create`/`addTo`（false=重复拦截）/`removeFrom`/`rows`（idx_pt_pos 序）/`delete`（软删）/`libraryCount`/`historyCount`（我的页三卡） |
| 沉浸播放页（新） | `app/lib/ui/play/play_page.dart` | 胶片帧（外框 `#0D0F11` r18+画面 r10+**框底打孔带**）+标题/歌手/专辑+进度（白点 Slider，松手=seek）+三键+垃圾桶+红心+模式循环键+队列/EQ 入口+页内提示横幅（出错/跳过态）；封面=**色块终态占位**（S5 前，DoD1 明示）；公共缝 `toggleHeart/refreshFav/dislike/nextTrack/prevTrack/togglePlay/cycleMode/openQueue/openEq/seekToEnd` |
| 队列页（新） | `app/lib/ui/play/queue_page.dart` | 服务镜像队列列表（当前曲高亮）+行点=跳播+行尾「下一首播放」=插队（真链=insertNextId） |
| 音效页（新） | `app/lib/ui/play/eq_page.dart` | 5 段 EQ（60/230/910/3.6k/14k，contracts §2.1 频率）+**两分支同 UI 路径**：真引擎支持→「已生效（实时）」；`EngineCapabilityException`→**明示不支持横幅**+滑杆只读 |
| 歌单页（新） | `app/lib/ui/playlists/playlist_list_page.dart` / `playlist_detail_page.dart` | 歌单全列（系统红心置顶）+新建（REQ-PL-02）+资料页曲行（序号/移出）+「播放全部」（REQ-PL-06 自第一首顺序起播并进沉浸页） |
| 我的页（新） | `app/lib/ui/mine/mine_page.dart` | 三卡真计数（我喜欢的音乐/最近播放/曲库）+红心入口→资料页（REQ-NAV-05 + REQ-PL-01 计数一致性） |
| 壳骨架 + 常驻条（新） | `app/lib/ui/shell/home_shell.dart` | 三 Tab（音乐空间/歌单/我的）+`IndexedStack` 保活（REQ-NAV-01 切换无数据丢失）+**壳层唯一播放域实例**（跨 Tab 一致）+迷你条/提示横幅在 Tab 内容之外常驻；公共缝 `playTrackIds/startShuffle/openPlayPage/ensurePlayback/dislikeNow/nextNow` |
| 播放条共用缝（新） | `app/lib/ui/play/playback_dock.dart` | `PlaybackStrip`（key 沿用 `playback_strip`/`strip_dislike`/`strip_next`：S3 锚位零漂移）+`PlaybackNoticeBar`（缺失/损坏/少播/异常四色横幅） |
| 曲库列表页增量 | `app/lib/ui/library/library_list_page.dart` | 行点击→真起播+进沉浸页（REQ-PLAY-01）；行级红心；行菜单「加入歌单…」→重复=**原话提示**「《X》已在『Y』中」（REQ-PL-03）；播放域两种装配（壳层注入=唯一实例；独立挂载=页面级自建——S3 锚兼容） |

## 2. 关键机制与决策（实证口径）

| # | 决策/机制 | 依据与实证 |
|---|---|---|
| M1 | **插队走 Port 面 + mpv `insert-next`** | 镜像-only 插队会把引擎物理队列与服务镜像**错位**（自然 EOF 时 mpv 按旧序推进=曲名/历史错位）——故插队必须同时物理增列；`insert-next` 不打断当前曲（无重载重启代价）。实证：`s4_playback_service_test`「插队」条——插入后队列 `[A,C,B]`，A 自然 EOF → `EngineItemEnded(0)` → `_current=1` 命中 C ✓ |
| M2 | **模式语义=一条路由** | PRD §3.1 四模式；随机=S3 池重采样续轮（FM 无限电台）、列表循环=同队重播、单曲=同位重播、顺序=**停驻**（不重载不重采样）。`_onItemEnded` 末条与失败末条复用 `_roundTail()`（单点分岔，无第二处漂移） |
| M3 | **歌单/我的页不越域读表** | 一切经 `PlaylistService`（其内只走 DAO 门面）；播放起播经 `PlaybackService.playTrackIds`（服务内解析根目录）——TASK-S4 禁则「播放页直接读其他域表」零违反 |
| M4 | **EQ 两分支同路径** | 分支 B（当前端）实跑=明示不支持横幅；分支 A（引擎支持）代码路径同源，仅 `setEqBands` 成败分岔——**真机 RV-A 结论回填后同 UI 即生效**（DoD3 诚实线：本端唯一可跑的实证=分支 B） |
| M5 | **跨 Tab 一致性=壳层唯一实例** | 播放域生命周期归壳层；页内（独立挂载）仍可自建（S3 锚零回归）。`IndexedStack` 保活三 Tab |
| M6 | **页内实时面=每帧 Future 重读**（沿 L6） | 迷你条/横幅/播放页快照/队列页均每帧 `FutureBuilder` 直读服务快照；并发守卫（`_inflight`）防每帧查询叠浪 |

## 3. 测试证据（**76/76 全绿**：基线 59 + S4 新增 17；`flutter analyze` 0 issue）

```
flutter analyze                          → No issues found!
flutter test test/playlists/s4_playlist_service_test.dart   → All tests passed!（+5）
flutter test test/playback/s4_playback_service_test.dart    → All tests passed!（+6）
flutter test test/ui/s4_ui_anchor_test.dart                 → All tests passed!（+6）
flutter test                             → All tests passed!（+76，全量三连绿）
```

> 诚实注记：全量首跑曾出现一次 `+69 Some tests failed`（失败明细被输出截断），其后**连续三次全量 +76 全绿**、单文件复跑亦全绿；该次未复现，按「未获落证的偶发」记录在册（不掩盖）。

### A. 歌单域服务（5）—— `test/playlists/s4_playlist_service_test.dart`

1. **REQ-PL-01**：红心切换=system_favorite 唯一格 + 计数随加/出同步（1→0）+ 幂等（反复取格不重复建行，DB 部分唯一兜底）✓
2. **REQ-PL-02**：新建真行 + **软删后 listAll 不再列出**（且原行仍在库=非物删，墓碑归 S6）✓
3. **REQ-PL-03**：重复添加被 UNIQUE 拦截（服务层 false）+ 顺序保持（idx_pt_pos）+ 移出 ✓
4. **我的页计数卡**：曲库活行（软删不计=列表同构）+ 历史总数 ✓
5. **歌单计数**随加入/移出同步 ✓

### B. 播放域服务（6）—— `test/playback/s4_playback_service_test.dart`（真 mpv + 真短样本）

6. **REQ-PLAY-01**：`playTrackIds` 行点击起播（默认列表循环）+ **一轮末=同队重播**（id 集不变=非重采样）✓
7. **REQ-PLAY-03 顺序**：末条自然 EOF → **停驻**（4s 观察窗不重载、不回零、不重采样）✓
8. **REQ-PLAY-03 单曲**：末条=**同位重播**（从第 1 位起播，回停位=1 而非 0——与列表循环可判别）✓
9. **REQ-PLAY-06 插队**：`insertNextId` → 镜像 `[A,C,B]`+不打断当前曲 → A 自然 EOF 后**引擎物理位命中插队曲 C** ✓
10. **REQ-PLAY-03 随机**：`sampleRound` 单轮 10 首**无重复** + `startRandom` 会话模式=random、实际队列无重复 ✓
11. **REQ-PL-05**：分批 100/事务植入 500 条 → 真播放第 501 条 → `flushHistory` 触发淘汰 → **500 条且最旧（playedAt=1）被删**、新记录在最新位 ✓

### C. 五 Gherkin 锚 + 壳骨架（6）—— `test/ui/s4_ui_anchor_test.dart`（真引擎+真库+真 fixture 拷贝；FakeAsync 三定律）

12. **锚 REQ-PLAY-01**：真用户链（列表行点击）→ 起播 → **沉浸页**：胶片帧 + 打孔带 + 标题/歌手/专辑 + 进度条 + 三键 ✓
13. **锚 REQ-PL-01**：播放页红心 → **图标即时填充红**（`Icons.favorite`）+ 计数「我喜欢的音乐 · 1」+ **「我的」页卡=1** + 册内真包含该曲（browse 行）✓
14. **锚 REQ-PL-03**：首次加入→「已加入『深夜』」；再次加入→**原位提示「《探曲01》已在『深夜』中」**+ 册内仍 1 条 ✓
15. **锚 REQ-NAV-01**：起播后迷你条常驻（真名）→ 切「歌单/我的/音乐空间」三 Tab 迷你条始终在且同曲（IndexedStack 保活）+ 队列页真推入（行/插队键齐）✓
16. **锚 REQ-PLAY-04（页级）**：播放页垃圾桶 → 「已减少这首的推荐」+ 立即切下一首 + 名单落库 ✓
17. **REQ-PLAY-07**：真引擎 `setEqBands` → false → **明示不支持横幅**渲染（分支 B 实跑；滑杆只读）✓

### 本轮实证教训（工程事实，入档防复发）

| # | 教训 | 处置 |
|---|---|---|
| L1 | **`ensureFavorite` 并发竞态**：每帧刷新面（播放页红心面+我的页卡）并发调 `ensureFavorite`，两者皆见「无行」→ 双 insert 撞 `kind=system_favorite` 部分唯一索引 → **SqliteException 泄漏到 UI 帧**（首版 4 锚连挂的根因） | DAO 幂等化：撞唯一索引即**回读既有行**（并发安全，不抛给调用方）；页面再加 `_inflight` 并发守卫防叠浪 |
| L2 | **`pumpWidget` 换根不清路由栈**：沉浸页已 push 后 `pumpWidget(MaterialApp(home: MinePage))` 因 Navigator **state 保留**（同型 widget 原位更新）而仍显示旧路由顶=新页找不到 | 换根断言场景用 `key: UniqueKey()` 强制新 Navigator；跨页断言优先「同会话换根」而非依赖路由弹出 |
| L3 | **SnackBar 串行队列吞掉后到提示**：同一页连续操作时第二条提示排队等待第一条超时——REQ-PL-03「原位提示」不成立 | 发提示前 `hideCurrentSnackBar()`（原位顶替语义，用户感知即时） |
| L4 | **SnackBar/`FutureBuilder` 均需「帧数预算」**：`pump()` 单拍只见首帧（waiting→shrink）；FakeAsync 下需 2–3 拍（含 200ms 档）方可断言文字/横幅 | 断言前统一 `pump()+pump(200ms)+pump()`（S3-L6 的帧预算显化）；异步真 IO 仍必须 `runAsync`（不可用 pump 代替） |

## 4. S4 DoD 对照（TASK-S4 六条）

1. **播放页呈现断言**（胶片帧封面+标题/歌手/专辑+进度；封面缺失→色块）**PASS** ✓（§3-C12；色块=**S5 前终态占位**，DETAILED-DESIGN §3.5 明示）
2. **模式随机不重复直到一轮播完 + 插队「下一首播放」立即生效** **PASS** ✓（§3-B10 随机单轮无重复；§3-B9 插队镜像+物理位命中；§3-B7/8/6 模式分岔三态）
3. **EQ 两分支都有实现** **PASS（分支 B 实跑）** ✓（§3-C17 明示不支持面；分支 A=同路径代码，真机 RV-A 结论回填后生效——**DoD 括注「真机结论回填」=OPEN 待 RV-A**）
4. **红心：图标即时变红 + 计数同步；重复添加拦截提示** **PASS** ✓（§3-C13/C14；DB UNIQUE 具体 §1.2）
5. **历史 500 淘汰：植入 501 条→最旧被删（分批 100/批事务断言）** **PASS** ✓（§3-B11）
6. **跨 Tab 迷你条状态一致（NAV-01）** **PASS** ✓（§3-C15）

## 5. 残留与移交（不阻断；含须开发者裁决项）

- **DoD3 顺延 OPEN（沿 S3）**：后台/锁屏/媒体键真平台演练 + 桌面 SMTC/MPRIS/Android 通知真桥——依赖开发者 **RV-A 真机窗口**；EQ 分支 A（实时生效）同窗口回填。
- **须开发者裁决**：**REQ-PL-05「历史按日期分组」列表 UI** 未在本片交付——TASK-S4「输出」清单未列历史页（列的是播放页/队列/音效/歌单资料/我的/Tab/迷你条），本片落的是其 **DoD5 淘汰语义**（已 PASS）。请裁决：归 S9 装配的独立页，或补入 S4 尾项。
- **播放页四态**：空态（「暂无播放内容」）+ 出错/跳过态（页内提示横幅，REQ-PLAY-08 原话面）已落；**加载态**当前=事件驱动即时态（队列非空即渲染当前曲，进度 0），无独立 spinner——S9/S10 视觉收口补（DoD 未设加载态判据，如实记）。
- **歌词预览（三行）/点击进歌词页**：归 S7（TASK-S4 边界明示）。
- **轮盘视图（`#p-shuffle`）/随机大卡**：已归 S3（TASK-S4 边界明示）——S4 未动。
- **部分唯一索引的并发写**（L1 已修）与 **`playlist_tracks` 无软删列**（§1.2 原设计）：无新增残留。
- ISS-502 Linux 分发（不阻断）；ISS-504 content_hash 口径（S6 前裁决）；S1 SecureStore 运行时验证、sqlite3 `file://` 路径（S10 前回改）沿 S3 顺延。

## 6. 运行命令实录

```
flutter analyze                                            → No issues found!
flutter test test/playlists/s4_playlist_service_test.dart   → +5
flutter test test/playback/s4_playback_service_test.dart    → +6
flutter test test/ui/s4_ui_anchor_test.dart                 → +6
flutter test                                               → All tests passed!（+76；三连绿）
dart format（新 UI 件）                                      → 无差异
```

## 7. 待开发者动作

1. 验收/签收本片（agent 只提交候选，不代签）。
2. 裁决 §5 中「历史按日期分组 UI」的归属切片。
3. 安排 **RV-A 真机窗口**（DoD3 + EQ 分支 A 回填）。
4. git 自提：本片新增/修改文件（含 `pubspec.yaml`/`lock` 沿 S3 uncommitted 项）。
