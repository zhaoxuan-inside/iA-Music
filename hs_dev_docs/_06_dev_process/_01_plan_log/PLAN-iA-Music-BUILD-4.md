# 任务计划账本：iA-Music-BUILD-4

- **task_id**：`iA-Music-BUILD-4`
- **标题**：iA-Music 本地音乐播放器 — BUILD 阶段 4（任务与上下文）
- **change_size**：`L`
- **work_mode**：`PLANNING`
- **所处阶段**：`4`（任务与上下文；上游=阶段 3 ACCEPTED（『详细设计通过。继续执行后续的流程。』2026-10-17）；依据 engineering_acceptance §5 TASK-01..05；产出=任务、依赖、Context Pack 与需求映射，落位 `_05_task_orchestration/`）
- **断点**：`阶段 4 收官（ACCEPTED）` — 开发者原话『确认（验收通过）』（2026-10-17，gate=ACCEPTED，含切片顺序确认）；本账本归档；后续推进 → `PLAN-iA-Music-BUILD-5.md`（阶段 5 实现切片）
- **刷新时间**：2026-10-17
- **上游基线**：阶段 0–3 全 ACCEPTED（REQ 63 / TEST 34 / ARCHITECTURE §1–§7 / DETAILED-DESIGN §1–§6 含 DEC-009）；ADR-0001；governance.yaml（cicd/observability off）

---

## 步骤

| step_id | 描述 | 状态 | 备注 |
|---------|------|------|------|
| T1 | 阶段 4 启动：计划账本 + 验收记录（TASK-01..05） | done | 本文件 + PHASE-4-ACCEPTANCE |
| T2 | TASK-01 分配范围内全部需求：REQ 63 → 切片映射表；无漏项、重复归属、未确认新功能 | done | TASK-BREAKDOWN §1/§2：63/63 唯一归属矩阵 |
| T3 | TASK-02 定义可验证切片：每切片 目标/边界/输入/输出/DoD/测试 seam；优先垂直切片（业务结果可验证，非按层分工） | done | 详单 11 份（`TASK-S0..S10.md`），每片含 DoD/seam/禁则 |
| T4 | TASK-03 排定依赖与风险：… | done | TASK-BREAKDOWN §3/§4（RV-A/B/C 前置时点；无环） |
| T5 | TASK-04 绑定有效上下文：每切片 Pack 记录来源路径/版本摘要/规则 ID/适用约束；无落选方案 | done | Pack 11 份（`CP-S0..S10.md`），禁则清单含落选方案清零 |
| T6 | TASK-05 验收执行计划：阶段验收点、演练点与需求覆盖表齐备；提交 gate=SUBMITTED | done | TASK-BREAKDOWN §3/§7；gate=SUBMITTED 提交开发者 |

## 对应指导文档

- `hs-dev-skill/references/engineering_acceptance.md` §5（TASK-01..05）
- `hs-dev-skill/references/stage_acceptance.md`（阶段验收协议）
- `hs-dev-skill/references/task_state_machine.md`（任务态与编排；切片推进状态权威）
- `hs-dev-skill/references/token_budget.md`（Pack 体积约束）

## 验收项与证据位置

- 任务简报/切片/依赖：`_05_task_orchestration/_01_task_brief/TASK-BREAKDOWN-iA-Music.md`（待产出）
- 切片详单：`_05_task_orchestration/_02_task_detail/`（待产出）
- Context Packs：`_05_task_orchestration/_03_task_context_pack/`（待产出）
- 阶段验收记录：`_06_dev_process/PHASE-4-ACCEPTANCE-iA-Music.md`（DRAFT）

## 阻断项

- 无阻断。ISS-302（引擎终极态）双态契约兜底；三大真机 PoC 属风险验证时点安排（T4 枚举前置），不阻断排期产出。

## 下一步

T2 任务简报正文（切片划分 + REQ 63 全覆盖映射）；随后 T3–T5（详单/Pack），完成后提交阶段 4 验收并进入阶段 5 逐切片编码。
