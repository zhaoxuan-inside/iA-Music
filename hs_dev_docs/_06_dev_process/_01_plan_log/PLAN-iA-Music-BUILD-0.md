# 任务计划账本：iA-Music-BUILD-0

- **task_id**：`iA-Music-BUILD-0`
- **标题**：iA-Music 本地音乐播放器 — BUILD 阶段 0（需求与产品对齐）
- **change_size**：`L`
- **work_mode**：`DESIGN`
- **当前阶段**：`1`（阶段 0 已冻结——2026-10-17 开发者整体确认『确认，继续进行开发。』；阶段 1 技术选型启动）
- **断点**：`S6` — 阶段 0 全部产出已落盘（9 特性 PRD + 9 Vibe Spec + 主原型 md/HTML + DESIGN.md + 路线图）；轮 4/5/6 反馈（DEC-004：胶片帧播放页 + 无封面自动抓取 REQ-LIB-08；DEC-005：主题/语言 REQ-ONB-07/08；DEC-006：术语更名随机/音乐空间 + 官网实拍视觉完善）已并入基线（PRD/原型/护栏，REQ 63 条 / Gherkin 场景 31 条 / Vibe TEST 34 条）；DEC-006 D6-7「随机」轮盘页终稿（轮 9–16 迭代）随轮 16 开发者确认并入文档层（线框 §5.11 + 导航 PRD v1.2.0 + vibe 契约 + 词典「轮盘页」，非计数性）。验收记录与冻结确认单（v1.2 重提）已提交 → **2026-10-17 开发者整体确认（原文『确认，继续进行开发。』）：阶段 0 冻结通过**（走查/真机探查未单独出具记录；R1–R3 以桌面调研初稿起步，真机结论后置回填并复核选型）。进入阶段 1 技术选型
- **更新时间**：2026-10-17

---

## 步骤

| step_id | 描述 | 状态 | 备注 |
|---------|------|------|------|
| S1 | 开场对齐 O1～O4（已确认，见 DEC-001） | done | 工程结构已初始化（init_hs_dev_docs） |
| S2 | 审讯轮 2：MVP 裁剪（全量 MVP，宽时间箱 3-4 月）+ 交互形态锁定 A + 同步含音频本体 + 引擎能力制（见 DEC-002） | done | R1-R3 风险预登记 |
| S3 | 轮 3：产品探索（Status Quo / JTBD / Aha / FTUE）+ 服务对象/开源 + F8 解读与 GitHub 音频约束确认（见 DEC-003） | done | 开发者已拍板 |
| S4 | PROD：DESIGN.md + 路线图 + L1 总览 PRD + 9 篇 L2 特性 PRD + 9 篇 Vibe Spec + 双轨主原型（md + HTML） | done | 全部落盘；映射矩阵见 `main_prototype.md` §6；含 DEC-004/005/006 补丁（胶片帧播放页 / 封面自动抓取 / 主题·语言 / 术语更名 + 实拍视觉完善） |
| S5 | 阶段 0 冻结门禁自审 + 开发者签收（验收记录 + 冻结确认单，v1.2 重提） | done | 记录已提交；D6-7 已确认并同步文档层；2026-10-17 开发者整体确认冻结（原文引用）；走查/真机探查顺延 |
| S6 | 交回主路由 → 阶段 1 选型（asr/下载引擎/同步适配选型 + R1-R3 探查结论绑定） | doing | 已启动（2026-10-17，hs-dev-design）；R1–R3 真机结论后置回填复核 |

## 对应指导文档

- `hs-dev-skill/references/product_design.md`（阶段 0 主规范）
- `hs-dev-skill/references/product_acceptance.md`（DISC/PROD 验收清单）
- `hs-dev-skill/references/product_roadmap.md`（MVP 裁定，S2 后读）

## 验收项与证据位置

- 开场/审讯问答与拍板：`_06_dev_process/_03_qa_log/DEC-001|002|003|004|005|006`
- MVP 裁定与切片：`_01_product_vision/_02_phased_roadmap/iA-Music_phased_plan.md`
- 品味宪章（宏）：项目根 `DESIGN.md`
- 一源双视图（L1+9L2）：`_02_feature_spec/_01_human_prd/` + `_02_feature_spec/_02_vibe_spec/`
- 双轨原型：`_02_feature_spec/_04_prototype_wireframe/main_prototype.md` + `_03_prototype_html/main_prototype.html`
- 视觉参照证据：`_01_product_vision/_01_design_charter/reference/doubanfm-7.1.2/`
- 术语单一事实源：`_00_project_foundation/_02_dictionary/_02_project_word.dict.yaml`（已替换为 iA Music 领域词表）
- 阶段验收与冻结单：`_06_dev_process/PHASE-0-ACCEPTANCE-iA-Music.md`、`_06_dev_process/PHASE-0-FREEZE-SIGNOFF-iA-Music.md`

## 阻断项

- 已解除：冻结门禁经开发者整体确认（2026-10-17）。注：走查/真机探查未单独出具记录——R1–R3 真机结论后置回填，阶段 1 选型需在结论出后复核。
- 风险登记（阶段 0 探查 / 阶段 1 选型绑定）：R1 Android 端下载引擎嵌入；R2 百度网盘开放 API 限制；R3 Android arm64 小模型推理可行性。

## 下一步

阶段 1 技术选型启动：按 hs-dev-design 主路由编排 BUILD 阶段 1–3（技术选型/架构/契约）；首批议题：R1 下载引擎、R2 同步适配（含百度网盘裁决）、R3 ASR 选型；R1–R3 真机探查结论出后回填复核。
