# 决策日志 DEC-012：UI 轮 12 — 参照物切换 Harmonoid（全删重写 / 资料库中心 / B 站链路补全闭环）

- **时间**：2026-10-25（同日第三轮 UI 裁决）
- **来源**：开发者当日指令 + 会话内两项确认裁决。
- **参照依据**：Harmonoid 官方 screenshots 分支 8 张截图逐张视觉解析（存档 `output/harmonoid_*.webp`）。
- **许可红线**：Harmonoid 为 **PolyForm Strict 1.0.0（限制性许可，非开源）**——**仅参照视觉语言，严禁复制其代码/资产/像素级克隆**（与 Spotify/Metrolist 同一纪律；本项目代码与 Harmonoid 无衍生关系）。

---

## 1. 裁定事项

| # | 事项 | 裁定 | 状态 |
|---|---|---|---|
| D12-1 | 参照物切换 | Metrolist → **Harmonoid**（严格 Material 3、资料库中心、规整动画）。`DESIGN.md` 升 alpha.3；DEC-011 的 S7 实现**同日作废**（其裁决链中动态取色机制以"重写后保留"形式延续） | `CONFIRMED` |
| D12-2 | 删除深度 | **字面全删**：`app/lib/ui/` 目录整体删除，全部 UI 文件（含主题/图标/封面组件/页面/壳层）从零重写；UI 测试锚点全部重建。域层（data/scan/playback/extract/lyrics/playlists/adapters）**不动**（S8d 链路补全除外，见 D12-4） | `CONFIRMED` |
| D12-3 | 导航形态 | **资料库中心**（照 Harmonoid）：桌面=240px 侧栏（SEARCH / LIBRARY 子树 TRACKS·ALBUMS·ARTISTS / PLAYLISTS / SETTINGS）+ **侧栏底部常驻迷你播放器**；移动=底部 Tab（曲库/搜索/歌单/设置）+ Tab 上方悬浮胶囊迷你条；首页=TRACKS。**取代** DEC-003 音乐空间首页与 DEC-011 D11-2 四 Tab（随机入口降级为曲库页工具栏按钮；轮盘页 D6-7 保留形态重绘）。GENRES 不做（tracks 无 genre 列，加列属域变更超本轮范围） | `CONFIRMED` |
| D12-4 | B 站链路补全闭环 | 已有：登录/搜索/提取/三通道歌词/反查回写歌名歌手专辑/整轨 B 站封面。**本轮补齐四缺口**：①反查命中后按 songId 抓网易标准歌词覆写 .lrc；②按 songId 抓网易封面落盘 `<音频名>.cover.jpg`（零封面链改动）；③合集拆分段封面补齐（coverUrl 传递+落盘）；④LRCLIB 命中路径补 `onTrackEnriched` 联动。Android 无 ASR/反查=平台限制维持现状 | `CONFIRMED` |
| D12-5 | 补全状态可见性 | 曲库行显示来源/补全角标（读现有 `lyrics_meta.type`/`coverKind`，只读不增列）；提取页消息面沿用 | `CONFIRMED` |
| D12-6 | 动态取色延续 | 封面 seed → M3 scheme 机制**保留但代码重写**（Harmonoid 同样是 M3/Material You 精神）；品牌绿 #4BE0A3 仍为回退 | `CONFIRMED` |

## 2. 对受影响基线的修补（本轮落盘）

| 文档 | 变更 | 版本 |
|---|---|---|
| `DESIGN.md` | 参照物 Harmonoid 全量重写（资料库中心布局/侧栏子树/五键控制排/侧栏底迷你条/大写标题字阶） | alpha.3 |
| `navigation_prd.md` | FEAT-NAV-01 改案 v1.4：资料库中心导航（TRACKS/ALBUMS/ARTISTS 树 + 搜索/歌单/设置）；音乐空间页移除、随机降级 | v1.4.0 |

## 3. 实施切片（S8，2026-10-25 当日完成）

| 切片 | 产物 | 验证 |
|---|---|---|
| S8a 全删+基座 | `lib/ui/` 整目录删除（24 文件）；重写 `theme/ia_theme|ia_icons|cover_seed|accent_controller`、`shell/appearance` | analyze 0 |
| S8b 壳+资料库 | `shell/app_shell`（桌面侧栏子树+侧栏底迷你条；移动 4 Tab+悬浮胶囊）；`library/tracks_page`（排序/列表⇄网格/随机键/B站来源角标）、`albums_page`(+详情)、`artists_page`(+详情，圆形头像)；`data/daos.dart` 增只读查询 `albumsWithCounts/artistsWithCounts/tracksOfAlbum/tracksOfArtist`、`ExtractDao.recentTasks` | widget 冒烟×2 绿 |
| S8c 全页面重写 | `play/now_playing_page`（大封面+五键排）、`mini_player`（双形态）、`queue_page`、`lyrics_page`（居中滚动+来源角标）、`eq_page`、`shuffle_page`（轮盘重绘）；`search/search_page`（本地+B站双模式+链接直提）；`extract/extract_page`（合规门+解析卡+队列实时面）；`settings/settings_page`（外观/账号/仓库/封面开关/关于）；`login/bili_login_page`（扫码+Cookie）；`playlists_page`(+详情)；`shared/cover_art|ia_format`；`main.dart` 重装配 | analyze 0 |
| S8d 链路补全 | ①`NetEaseLyricSearch.fetchSyncedLyrics`（/api/song/lyric lv=1）+②`fetchCover`（detail.picUrl→字节）+`LyricTextSearchPort` 增默认空实现；`lyrics_service`：反查命中后标准歌词覆写 .lrc + `<音频名>.cover.jpg` 落盘（CoverChain fetched 档天然衔接）+④LRCLIB 路径补 `onTrackEnriched`；③`extract_queue`：`_taskCoverUrl` 会话账本（enqueue/resolveAll 双点入账）→ 拆分段统一写 sibling 封面 | analyze 0；asr_test 补 fake 面绿 |
| S8e 测试重建 | 删旧 UI 测试 6 个 + 旧集成测试 2 个（引用已删 UI）；新 `widget_test`×2（移动 4 Tab/桌面子树跳转）+ `ui/lyrics_parse_test`×3 | 见下 |

**最终验证**：`flutter analyze`（含 test/tool/integration_test）**0 问题**；逐文件测试全绿（约 130 用例）；批跑偶发超时=本机引擎/真网并发竞争（单文件全绿复现）+ `s5_cover_network` 真网 MusicBrainz 限流（503/307，环境性）。

**未验证项**：双端真机视觉走查（用户验收进行中）；NetEase 歌词/封面回填链路端到端（需真实提取一首歌验证——建议验收时走 B 站搜索→提取→看歌名/歌词/封面是否全部补全）。

## 4. 作废清单（避免残留引用）

- DEC-011 §5 S7 全部实现产物（当日生命周期=1 天）；DEC-011 D11-2 四 Tab 结构、D11-4 桌面 rail 形态作废，D11-3 动态取色与 D11-5 底层零改动红线**延续有效**。
- `space_page.dart`/`home_shell.dart`/Metrolist 版播放页与歌词页/通栏迷你条：删除。
- 旧 UI 测试（widget_test 断言、s4_ui_anchor、desktop_layout、s3_ui_anchor、s5_cover_ui 的 UI 锚部分）：重建。

## 7. 性能缺陷修复（同日晚间，用户报告「总是未响应」）

- **取证**：安卓启动日志 Skipped 207/90 frames；库内 32 轨 + **102 提取任务（69 resolved + 1 downloading）**——每次启动 `resumeQueued` 复活全量。
- **已证实根因**：`asr_adapter.transcribe` 中 `native.transcribeSamples(samples)` 为**主 isolate 同步 FFI 推理**（SenseVoice 一首歌数十秒起）——推理期间 UI 线程完全冻结；批量任务串行经过 ASR 即反复「未响应」。
- **修复 A**：新增 `adapters/asr_isolate_worker.dart`（长驻 worker isolate，协议 probe/run；wav 读取+识别器缓存+推理+临时件清理全在 worker），`asr_adapter.transcribe` 改为委托（主线程只传路径；probe 不可用仍回落 Python 脚本路径）。
- **修复 B**：`tracks_page` 由急切 Column/shrinkWrap 网格改为 **SliverList/SliverGrid builder 懒构建**（曲库规模化防线；32 轨非本次根因）。
- **验证**：analyze 0；widget/lyrics/asr 13 用例绿（含网易真网反查 E2E）；双端重启复测。

## 8. 补全链路改案（同日晚间，用户裁决）：移除 LRCLIB 标题匹配级

- **裁决**：「先用歌名找一次（LRCLIB）去掉这个」——不再按 B 站标题猜歌。改案后链路=**单级**：标题剖析 → SenseVoice ASR 转写（worker isolate）→ 歌词正文反查（网易 1006 投票+时长锚）→ 身份回写（歌名/歌手/专辑）+ 网易标准歌词覆写 .lrc + 专辑封面落盘。
- **动机**：B 站标题与正式歌名偏差大，标题匹配命中面窄且可能错配（同名异曲风险）；正文反查以实际音频内容为准，语义更强。
- **代码落点**：`lyrics_service.dart`（删 `_port`/`runForTrack` LRCLIB 分支/`_writeLrc`/`_enrich`/`_upsertAlbumName`/`LyricsOutcomeKind.enriched`）；`extract_queue`/`library_hub`（`lyricsPort` 注入缝全移除）；`LrclibAdapter` 类与 `LyricsPort` 契约**保留**（适配器直测仍绿，未来可作可选源回归）。
- **平台影响**：**安卓端补全能力归零**（此前安卓还有 LRCLIB 标题匹配一条路）——安卓只落音频+B站标题+内嵌/B站封面，无歌词补全；桌面端不受影响（ASR/反查在位）。
- **验证**：analyze 0；lyrics 域 13 用例绿（含 ASR→反查真网 E2E 走新链路）；widget/搜索冒烟全绿。
