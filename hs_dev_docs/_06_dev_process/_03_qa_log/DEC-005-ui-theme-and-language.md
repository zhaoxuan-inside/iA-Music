# 决策日志 DEC-005：UI 轮 5 反馈 — 界面主题与语言（浅色主题 + 英文界面）

- **时间**：2026-10-16
- **来源**：开发者对主原型走查后的轮 5 反馈（要点记录，逐字稿未单独留存；决策以本表为准）
- **要点**：界面支持主题切换（含浅色主题）与语言切换（含英文界面）；应用名与歌曲信息不翻译；浅色下胶片帧保持深色实体；歌词生成语言跟随界面语言。

---

## 1. 裁定事项

| # | 事项 | 裁定 | 状态 |
|---|---|---|---|
| D5-1 | 界面主题 | 三选：深色（默认）/ 浅色 / 跟随系统；本地持久化、即时生效；浅色调色板：画布 `#F6F7F9` / 表面 `#FFFFFF` / 抬升 `#ECEEF1` / 主文本 `#17191C` / 次文本 `#6E747C` / 分隔 `rgba(0,0,0,0.08)` / accent `#17A566` | `CONFIRMED` |
| D5-2 | 界面语言 | 三选：中文（默认）/ English / 跟随系统；仅 UI 文案切换；应用名 "iA Music" 不译 | `CONFIRMED` |
| D5-3 | 不译边界 | 歌曲自身信息不随语言变化：曲名 / 歌手 / 专辑 / 歌词 / 文件名 / 歌单名（内容资产一律原样展示） | `CONFIRMED` |
| D5-4 | 胶片帧与浅色 | **DERIVED**：胶片帧（含封面模糊氛围底）在所有主题下保持深色实体，不随浅色主题变脸；冻结签收时请一并确认 | `DERIVED` 待确认 |
| D5-5 | 歌词生成语言 | **DERIVED**：歌词生成的输出语言 = 当前界面语言（本地小模型按界面语言约定输出）；冻结签收时请一并确认 | `DERIVED` 待确认 |

## 2. 对受影响基线的修补（本轮已落盘）

| 文档 | 变更 | 版本 |
|---|---|---|
| `DESIGN.md` | Colors 增浅色 token；Don't 移除"单深色"并改为双主题硬编码禁令；新增 Theming & Language 节；Shapes 胶片帧注明主题关系 | — |
| `overview_prd.md` | 全局业务规则增「主题与语言」行 | v1.2.0 |
| `features/onboarding_prd.md` | 设置 IA 增「外观」组；新增 `REQ-ONB-07`/`REQ-ONB-08` + 2 条 Gherkin 场景 | v1.1.0 |
| `_02_vibe_spec/onboarding_vibe_spec.md` | SettingsScreen 组、appearance 字段约束、+2 条 TEST（TEST-ONB-04-THEME / 05-LANG） | — |
| `_04_prototype_wireframe/main_prototype.md` | §2.3 主题与语言 tokens；§5.10 设置外观组（Mermaid+ASCII） | v1.2 |
| `_03_prototype_html/main_prototype.html` | 主题/语言切换（🌗/中·EN）+ 全文案 localize()（内容不译）+ `data-theme`/`lang` 接入；浅色 CSS 块 | v1.2 |
| `iA-Music_phased_plan.md` | 浅色主题从 Phase 2 池提前入 MVP（Should-have P1，随 ONB 外观）；S6 切片含外观 | — |

## 3. 对冻结门禁的影响

- 需求总量：61 → **63** 个 REQ（+REQ-ONB-07/08）；Gherkin 29 → **31** 条；Vibe Spec TEST 级 GWT 32 → **34** 条。
- D5-4 / D5-5 两个 DERIVED 项随冻结确认单 A 组一并确认。
- 视觉签收（B 组）需基于含主题/语言的原型重新走查。
