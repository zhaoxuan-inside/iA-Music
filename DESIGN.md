---
version: alpha.3
name: iA Music
description: 本地优先的音乐播放器 — 把你的本地曲库变成一间深夜私人电台（Android / Windows / Linux）
colors:
  primary: "#F4F5F7"        # 主文本（画布上的"亮"，固定）
  secondary: "#9A9CA6"      # 次级文本
  tertiary: "#4BE0A3"       # 品牌绿 = 动态取色回退 seed（D12-6）
  neutral: "#0F1013"        # 近黑画布（Harmonoid #101014 同族）
  surface: "#1A1B20"        # 表面
  heart: "#FF5C7A"          # 红心专用，不随 seed 变
typography:
  section-caps:
    fontFamily: system-ui
    fontSize: 22px
    fontWeight: 800
    letterSpacing: 0.05em   # TRACKS/ALBUMS 大写大标题（Harmonoid 签名）
  body-md:
    fontFamily: system-ui
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.5
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
rounded:
  sm: 8px
  md: 12px
  lg: 16px
  pill: 999px
components:
  button-primary:
    backgroundColor: "{scheme.primary}"
    textColor: "{scheme.onPrimary}"
    rounded: "{rounded.pill}"
    padding: 10px 22px
---

# DESIGN.md — iA Music

> Agent：实现 UI 前读本文件；所有颜色一律经 theme scheme，禁止硬编码。
> 参照物（2026-10-25 用户裁决第三轮切换，DEC-012）：**Harmonoid**（Flutter 桌面/移动
> 音乐播放器，严格 Material 3）。**许可红线：Harmonoid 是 PolyForm Strict 非开源
> 许可——只参照视觉语言，不复制代码/资产/像素级布局。**
> 底层链路零改动（DEC-012 D12-2；S8d 四项链路补全除外）。

## Overview

**具象参照物**：Harmonoid 的"资料库优先、严格 Material 3、规整克制"——应用即曲库：
TRACKS 大写大标题的曲目列表是首页；侧栏（桌面）承载 LIBRARY 子树导航；
侧栏底部常驻迷你播放器；移动端底部 Tab + 悬浮胶囊迷你条；播放页是
近满屏大封面 + 五键控制排的沉浸页。动画规整（列表 stagger、页面渐隐），
无夸张视差。

- **Audience**：拥有一个本地音乐收藏、习惯 B 站等渠道发现音乐的听众（首用户 = 开发者本人）
- **Primary job of the UI**：管理并收听自己的曲库——TRACKS/ALBUMS/ARTISTS 三面一体
- **Density**：`Comfortable`（资料库行/网格留白充足，Harmonoid 式宽松）
- **Mood**：工具感、规整、安静；资料库优先，没有推荐流

## Colors（封面动态取色 · D12-6 延续）

- **机制**：seed = 当前播放封面主色（48px 降采样色相桶提取）→
  `ColorScheme.fromSeed` 派生全套 M3 scheme；换曲平滑过渡不闪跳。
- **回退链**：无封面/失败 → seed = 品牌绿 `#4BE0A3`
- **画布（固定，不随 seed）**：深色画布 `#0F1013`，表面 `#1A1B20`，
  抬升面 `#23242B`，分隔 `rgba(255,255,255,0.07)`
- **浅色主题（DEC-005 延续）**：同 seed 的 light scheme；画布 `#F5F6F8` / 表面 `#FFFFFF` / 抬升 `#ECEEF1`
- **红心色** `#FF5C7A` 不随 seed 漂移
- **对比度**：正文用 scheme.onSurface（≥4.5:1）；M3 tonal 体系兜底
- **强调预算**：播放中/激活/主 CTA 用 accent，同屏 ≤3 处

## Typography

- **字体族**：`PingFang SC / HarmonyOS Sans / Microsoft YaHei UI / Noto Sans CJK SC, system-ui`
- **数字原则**：时间/进度/数量强制 `tabular-nums`
- **字阶**：
  - `SectionCaps` 20-26px / w800 / letter-spacing 0.05em / **大写**（TRACKS / ALBUMS / ARTISTS / PLAYLISTS——Harmonoid 签名标题）
  - `PlayerTitle` 24-28px / w700（播放页歌名，两行）
  - `SectionTitle` 15px / w600；`Body` 14px / w400；`Caption` 12px / w400
- **规则**：歌名/歌手省略号截断（列表 1 行，播放页 2 行）；歌词 17px / w500 / 行高 1.8

## Layout（Harmonoid 形态 · D12-3）

### 桌面（≥1024，Windows/Linux）
- **左侧栏 240px**：品牌区（顶部）→ SEARCH → **LIBRARY 子树**（TRACKS / ALBUMS / ARTISTS，缩进二级）→ PLAYLISTS → SETTINGS → 分隔 → **侧栏底部常驻迷你播放器**（封面 48 + 歌名/歌手 + 上一首/播放/下一首；点按进播放页）
- **内容区**：大写 SectionCaps 标题 + 右侧工具行（排序/视图切换[列表⇄网格]/随机按钮）→ 列表或网格
- **TRACKS**：列表（封面 48 + 标题/歌手 + 专辑 + 时长列；表头可排序）
- **ALBUMS**：封面网格（2 列起，卡片=封面 + 下侧专辑名/歌手；点进专辑详情=大封面+PLAY ALL/SHUFFLE 胶囊按钮+曲目表）
- **ARTISTS**：圆形头像网格（点进=头图 + 曲目表）
- **无全宽底栏**（与 Metrolist 版差异：迷你播放器在侧栏底部）

### 移动端（390px 基准）
- **底部 4 Tab**：曲库 / 搜索 / 歌单 / 设置（图标+标签）
- **曲库 Tab 内部分段**：TRACKS / ALBUMS / ARTISTS 顶部分段器（Material 3 PrimaryTabBar）
- **悬浮胶囊迷你条**：Tab 栏上方（封面 44 + 歌名–歌手 + 播放/下一首），点按进播放页
- **播放页（沉浸）**：顶部返回/更多 → **近满屏宽大封面（圆角 16）** →
  歌名（大）+ 歌手 + 右侧圆形操作钮 → 细进度条 + 双侧时间 →
  **五键控制排：随机 | 上一首 | 大圆播放键 | 下一首 | 循环模式** →
  次行工具（队列/歌词/红心/垃圾桶）

### 页面清单（S8 重建）
TRACKS / ALBUMS(+详情) / ARTISTS(+详情) / PLAYLISTS(+详情) / SEARCH（本地+B站双模式）
/ EXTRACT（提取队列）/ SETTINGS（外观/仓库/B站账号/关于）/ LOGIN（扫码+Cookie）
/ NOW PLAYING / LYRICS / QUEUE / EQ / 随机轮盘（D6-7 形态重绘）

## Elevation & Depth

色阶 + 细描边分层，不用投影：画布 → 表面 → 抬升面（弹层）；弹层才加投影。
网格卡片 = 表面色 + 1px 分隔线。

## Shapes

- 封面：16px（网格卡/播放页）/ 8px（列表缩略）；**艺术家头像 = 全圆**
- 卡片 12px；按钮=胶囊或 10px 圆角；输入框 12px；底部弹层顶部 20px

## Components

### Sidebar（桌面）
- 二级树缩进 20px；选中项 = scheme.secondaryContainer 底 + 圆角 12
### MiniPlayer
- 桌面=侧栏底部通栏（高 ~72）；移动=悬浮胶囊（圆角 999、投影 24）
### NowPlayingControls（五键排 · Harmonoid 签名）
- 随机 / 上一首 | **大圆播放键（直径 64，accent 实底）** | 下一首 / 循环模式
- 次行工具排：队列 / 歌词 / 红心 / 垃圾桶（44×44 触控）
### ListRow / GridCard
- 行：透明底 + hover 白 4%；网格卡：封面即卡 + 底部文字层
### Lyrics
- 居中滚动、当前行 accent w700、点行 seek；来源角标（LRCLIB/字幕/ASR，D12-5）
### 来源角标（曲库行 · D12-5）
- B 站来源曲目标记（读 tracks.sourceType / lyrics_meta.type），Caption 级不喧宾

## Do's and Don'ts

**Do**
- 资料库优先：TRACKS 是首页，不是推荐流
- 大写 SectionCaps 标题 + 规整对齐（Harmonoid 的"严格 Material"精神）
- 换曲 scheme 平滑过渡（200-300ms）
- 封面即视觉主角；无封面→联网补齐（仅补缺不覆盖）→首字母色块
- 四态齐备：空态给引导（"扫描音乐目录"/"粘贴一条 B 站链接"），错误态人话+原位重试

**Don't**
- 复制 Harmonoid 的代码/资产/像素级布局（PolyForm 红线，只参照语言）
- 绕过 theme scheme 的硬编码颜色；紫靛万能渐变/霓虹发光/整页 fade-up
- 假数据、"AI 智能推荐"等未兑现文案
- 本轮改 UI 顺手改域服务行为（DEC-012 D12-2 红线；S8d 授权项除外）

## Theming & Language

- 深色（默认）/ 浅色 / 跟随系统（DEC-005）；中文 / English / 跟随系统；应用名不译；内容资产原样

## Responsive Behavior

- 断点：移动 390 / 桌面 ≥1024；触控 ≥44×44；桌面快捷键（空格/←→/⌘K）

## Agent Prompt Guide

```text
Follow project-root DESIGN.md tokens and Do's/Don'ts.
Build <screen> for iA Music (local-first music player).
Harmonoid-style: strict Material 3, library-first (TRACKS is home),
desktop sidebar with LIBRARY subtree + sidebar-bottom mini player,
mobile bottom tabs + floating capsule mini player, SectionCaps
uppercase titles, circle artist avatars, immersive now-playing with
near-fullwidth cover + 5-key control row (shuffle|prev|big-round-play|
next|repeat). Accent = cover-seeded ColorScheme (fallback #4BE0A3).
No AI-default aesthetic. All states with real copy. Do not copy
Hararmonoid code/assets (PolyForm license) — visual language only.
Do not touch domain services (DEC-012).
```
