# 决策日志 DEC-011：UI 轮 11 — 参照物切换 Metrolist（四 Tab / 动态取色 / 桌面重设计）

- **时间**：2026-10-25
- **来源**：开发者当日指令（会话内裁决，三项选择均由开发者本人确认）：UI 参照物切换到 `MetrolistGroup/Metrolist`（Android 开源 YouTube Music 客户端，Kotlin/Compose/Material 3，GPL-3.0，维护模式）；**底层功能沿用现有逻辑不改动**——B 站链路五环（登录→搜索→提取→ASR/CC 字幕→歌词反查元数据）当日已全部在库，其中歌词正文反查见 `adapters/netease_lyric_search.dart` 头注（同日拍板）。
- **参照依据**：Metrolist 官方 6 张商店截图（存档 `output/metrolist_ss1..6.png`，逐张视觉解析完成）：纯黑画布、动态取色、大圆角卡片、四 Tab 底部导航（胶囊选中态）、大封面正在播放页 + 大号胶囊主播放键 + 粗进度条、居中滚动歌词页（当前行 accent 加粗）、顶部大标题 + 右上图标排。

---

## 1. 裁定事项

| # | 事项 | 裁定 | 状态 |
|---|---|---|---|
| D11-1 | 参照物切换 | UI 参照物：Spotify 桌面/移动端 → **Metrolist**（同日二次切换；`DESIGN.md` 全量重写）。只参照布局语言与视觉体系，**不克隆其视觉资产**（logo/插画/像素级布局），Metrolist 为 GPL-3.0 项目，iA Music 仅作视觉参照不做代码衍生 | `CONFIRMED` |
| D11-2 | 结构对齐深度 | **结构也对齐四 Tab**：底部导航 = 音乐空间 / 搜索 / **曲库** / 我的（Metrolist 四 Tab 骨架的 iA Music 映射；其 Together 无 MVP 对应物不引入）。FEAT-NAV-01 冻结案由三 Tab 改案为四 Tab（见 §2）；曲库页复用现有 P-LIBRARY（`ui/library/library_list_page.dart`）升格为 Tab | `CONFIRMED` |
| D11-3 | 强调色 | **封面动态取色**：强调色 = 当前播放封面主色（seed）→ Material 3 `ColorScheme.fromSeed` 派生全scheme；无封面/提取失败回退品牌绿 `#4BE0A3`（品牌绿保留为身份回退色，不再是唯一强调色）。红心 `#FF5C7A` 不随 seed 变（既有规则）；浅色主题（DEC-005）由同 seed 的 light 变体承载 | `CONFIRMED` |
| D11-4 | 桌面端 | **桌面同步重设计**（≥1024，Windows/Linux）：Metrolist 无桌面参照，按其视觉语言重设计——左侧导航栏（同四目的地，图标+文字）+ 内容区（封面网格卡片）+ 底部迷你播放条；点击展开封面驱动沉浸式正在播放页（大封面 + 歌词双列）。废弃"Spotify 侧栏+全宽底栏"桌面骨架与"三 Tab + 悬浮胶囊"移动骨架 | `CONFIRMED` |
| D11-5 | 底层零改动 | 本轮**只动 UI 层**（壳层/主题/页面视觉与导航），data/scan/playback/extract/lyrics/playlists 域服务与 adapters 不改行为；测试仅调整受主题/导航结构影响的断言 | `CONFIRMED` |
| D11-6 | 取代关系 | **取代**：当日早前的"参照物=Spotify"裁决；DEC-006 D6-x 中与黑胶胶囊迷你条、三 Tab 图标化相关的视觉裁定（术语更名等其余项继续有效） | `DERIVED` |

## 2. 对受影响基线的修补（本轮落盘）

| 文档 | 变更 | 版本 |
|---|---|---|
| `DESIGN.md` | 参照物、Colors（动态 seed 机制）、Layout（四 Tab 移动端 + 桌面重设计）、Components（胶囊 Tab/大 Play 胶囊/迷你条/居中歌词）、Do's & Don'ts、Agent Prompt Guide 全量重写 | alpha.2 |
| `_02_feature_spec/_01_human_prd/features/navigation_prd.md` | FEAT-NAV-01 三 Tab → 四 Tab；新增 §3.6 曲库 Tab；§3.4 迷你播放条改 Metrolist 形态（取代黑胶胶囊）；REQ-NAV-01 改述 + 新增 REQ-NAV-07；+1 Gherkin | v1.3.0 |

## 3. 待后续切片同步（不在本轮补齐）

| 产物 | 缺口 | 归属 |
|---|---|---|
| `_02_vibe_spec/navigation_vibe_spec.md` | TEST 契约需随四 Tab/迷你条/动态色补条目 | UI 重构切片 |
| `_04_prototype_wireframe/main_prototype.md` / `_03_prototype_html/` | 原型仍是三 Tab + 胶囊条旧形态 | UI 重构切片（以实现为准，原型不再回填 HTML） |
| `overview_prd.md` 全局规则行 | 补「强调色=封面动态取色」一行 | UI 重构切片收尾 |

## 4. 动态取色技术契约（本轮设计决定，S7a 实现修订）

- **提取**：**仓库内自研** `ui/theme/cover_seed.dart`（48px 降采样 + 24 色相桶 × 3 明度桶饱和度加权投票；灰图/坏图→null）。
  修订理由：不引第三方包（供应链锁版纪律 supply_chain_security + 本机 pub 拉包不稳定）；设计稿原提 palette_generator，实现取自研等价方案，算法语义不变。
- **派生**：Flutter SDK `ColorScheme.fromSeed(seed, brightness)` 生成 accent 族（primary/onPrimary/primaryContainer/onPrimaryContainer）；
  画布/表面/文本/红心/语义色保持基板固定（`IaPalette.seeded` 只覆盖 accent 四位）。
- **接线**：`ui/theme/accent_controller.dart`——壳层播放域就绪即 `bind`；换曲 → `hub.covers.decide` → 提取（trackId 键控缓存，容量 512）→ `value` 通知；
  快速切曲只认当前曲（不闪跳）；停播/无封面 → null = 品牌绿基板。`main.dart` 双层 ValueListenableBuilder（seed × themeMode）装配。
- **过渡**：`IaPalette.lerp` 全字段插值（原阶梯 lerp 弃用）；MaterialApp 内建 AnimatedTheme 承载换曲过渡。
- **测试注入**：`buildIaTheme(brightness, {seed})` seed 可注入、缺省=品牌绿基板（既有主题断言不受影响）。

## 5. S7 实现落盘清单（2026-10-25 当日完成）

| 切片 | 产物 | 验证 |
|---|---|---|
| S7a 动态取色 | `ui/theme/cover_seed.dart`（新）、`ui/theme/accent_controller.dart`（新）、`ia_theme.dart`（seeded 工厂/lerp/胶囊主键/coverXL·cardLg token）、`main.dart` 装配 | analyze 0；主题相关断言（desktop 双主题）绿 |
| S7b 四 Tab 壳层 | `home_shell.dart`（四 Tab 胶囊底栏/桌面 rail/通栏迷你条/accent bind）、`ui/shell/space_page.dart`（新，音乐空间 Home）、`playback_dock.dart`（移动端胶囊→通栏迷你条 + 底缘进度线） | widget_test/s4/desktop 锚绿 |
| S7c 播放/歌词页 | `play_page.dart`（大封面 24 圆角/粗进度 8px/大胶囊主键 132×56/FittedBox 防窄幅溢出/歌词入口）、`ui/play/lyrics_page.dart`（新，居中滚动 + 当前行 accent + 点行 seek + 底部迷你条；只读现有 .lrc，空态说明生成链路） | s4 PLAY/PL 系列锚绿 |
| S7d 收尾 | 测试修补：`widget_test`/`s4_ui_anchor`/`desktop_layout` 增「先切 nav_library 再断言曲库页」（Flutter find 默认跳过 IndexedStack 未选中页，DEC-011 D11-2 的结构代价）；播放页控制排窄幅收缩 | analyze 0；受影响 5 文件逐文件 24 用例全绿 |

**未验证项**：多测试文件并发批跑在本机偶发超时（mpv 引擎/真网冒烟 + Windows DLL 并发竞争；失败集合逐次不同、逐文件全绿）——环境性，非本轮回归；三端真机走查（视觉验收 B 组）待用户进行。

## 6. 底层零改动声明（D11-5 执行核对）

data/scan/playback/extract/lyrics/playlists 域服务与 adapters 本轮**零修改**（B 站五环链路：扫码登录 / wbi 搜索 / yt-dlp 提取 / ASR+CC 字幕→LRC / 网易歌词反查 —— 全部原样运行）。
