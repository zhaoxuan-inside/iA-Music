# 任务计划账本：iA-Music-BUILD-3

- **task_id**：`iA-Music-BUILD-3`
- **标题**：iA-Music 本地音乐播放器 — BUILD 阶段 3（详细设计）
- **change_size**：`L`
- **work_mode**：`DESIGN`
- **当前阶段**：`3`（详细设计；上游=阶段 2 ACCEPTED（『确认』2026-10-17）；依据 engineering_acceptance §4 DETAIL-01..06；仅产出本应用触达的 DB/接口/方法/调用链契约与测试规格）
- **断点**：`阶段 3 收官（ACCEPTED）` — 开发者原话『详细设计通过。继续执行后续的流程。』（2026-10-17，gate=ACCEPTED）；本账本归档；后续推进 → `PLAN-iA-Music-BUILD-4.md`（阶段 4 任务与上下文）
- **刷新时间**：2026-10-17
- **上游基线**：阶段 0 冻结包 + 阶段 1（ADR-0001/TECH-SELECTION/DEC-007·008/EXP-001·002）+ 阶段 2（ARCHITECTURE §1–§7 ACCEPTED）；overview v1.3.0 / features（SYNC v1.1.0）；REQ 63 / Gherkin 31 / Vibe TEST 34

---

## 步骤

| step_id | 描述 | 状态 | 备注 |
|---------|------|------|------|
| T1 | 阶段 3 启动：计划账本 + 验收记录（DETAIL-01..06）+ 契约文档骨架 | done | `_03_architecture_design/_02_detailed_design/DETAILED-DESIGN-iA-Music.md` |
| T2 | DETAIL-01 数据约束 | done | §1：惯例+14 表字段级+FTS+9 组索引↔查询对应+迁移回退门（DEC-009 DB 决策点列出待拍板） |
| T3 | DETAIL-02 接口契约 | done | §2：七 Port 签名（双态标注）+异常→UI 文案对应表+平台桥+OpenAPI NA（ISS-301 成文） |
| T4 | DETAIL-03 方法行为 | done | §3：六聚合方法（前置/后置/不变量/边界/副作用/触达） |
| T5 | DETAIL-04 状态与失败语义 | done | §4：sync 状态机逐态（对齐 vibe 原文）+extract 任务机+重试上限表+资源释放五类归属 |
| T6 | DETAIL-05 跨文档映射 | done | §5：9 组 REQ 全覆盖矩阵+语义清单（枚举/时间/音质族唯一事实源） |
| T7 | DETAIL-06 实现准备度+提交验收 | done | §6：疑似点=0 表+三例测试规格（正/误可判）+开发者确认清单；gate=SUBMITTED |

## 对应指导文档

- `hs-dev-skill/references/engineering_acceptance.md` §4（DETAIL-01..06）
- `hs-dev-skill/references/stage_acceptance.md`（阶段验收协议）
- `hs-dev-skill/skills/hs-dev-architecture/SKILL.md` 与 hs-dev-design 路由（阶段 3 归属）
- `ADR-0001`（契约不得引入落选方案或未授权依赖；TECH-SELECTION §5 版本为本契约锁定基线）

## 验收项与证据位置

- 契约主文档：`_03_architecture_design/_02_detailed_design/DETAILED-DESIGN-iA-Music.md`（待产出正文）
- 阶段验收记录：`_06_dev_process/PHASE-3-ACCEPTANCE-iA-Music.md`（DRAFT）
- 关联：`ARCHITECTURE-iA-Music.md` §7（末项映射核对在本阶段关闭）

## 阻断项

- 无阻断。ISS-101/201（真机 PoC）仅影响 Engine 终极态标注，契约按双态建模全覆盖；开发者 DB 决策点（若有）在 T2 中以问答轮提出。

## 下一步

T2 数据契约正文（表结构逐表 + 索引 + 迁移策略）；随后 T3–T5 正文；全程与 vibe spec 状态机逐态对齐。
