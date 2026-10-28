# 任务计划账本：iA-Music-BUILD-2

- **task_id**：`iA-Music-BUILD-2`
- **标题**：iA-Music 本地音乐播放器 — BUILD 阶段 2（架构设计）
- **change_size**：`L`
- **work_mode**：`DESIGN`
- **当前阶段**：`2`（架构设计；上游=阶段 1 ACCEPTED（『确认。』2026-10-17）；主轴 hs-dev-architecture；依据 engineering_acceptance §3 ARCH-01..06）
- **断点**：`阶段 2 收官（ACCEPTED）` — 开发者原话『确认』（2026-10-17，gate=ACCEPTED）；本账本归档；后续推进 → `PLAN-iA-Music-BUILD-3.md`（阶段 3 详细设计）
- **刷新时间**：2026-10-17
- **上游基线**：阶段 0 冻结包（2026-10-17 ACCEPTED）+ 阶段 1 产出（ADR-0001 Accepted / TECH-SELECTION §1 · §3 · §5 / DEC-007/008 / EXP-001/002）+ **新版本基线** overview v1.3.0 / sync_prd v1.1.0（DEC-008 百度移除）

---

## 步骤

| step_id | 描述 | 状态 | 备注 |
|---------|------|------|------|
| T1 | 阶段 2 启动：计划账本 + 验收记录（ARCH-01..06 展开）+ 架构文档骨架 | done | `_03_architecture_design/_01_system_architecture/ARCHITECTURE-iA-Music.md`（骨架，arc42 维度裁剪） |
| T2 | ARCH-01 上下文与边界：使用者/外部系统/输入输出/信任边界/本系统不承担职责；与产品范围一致 | done | §1：外部系统 7 类、三信任域、不承担清单；零冲突对照 REQ 63 |
| T3 | ARCH-02 职责与数据所有权：核心能力→模块矩阵；数据写入权/接口/依赖方向，避免无主业务规则 | done | §2：7 模块域×63 REQ 全覆盖；11 类数据唯一写者；ports & adapters 依赖单向 |
| T4 | ARCH-03 关键运行场景：成功/失败场景→模块协作（事务/异步/重试/恢复归属），不以目录树替代 | done | §3：六场景（扫描/后台随机/提取/同步/歌词 ASR/模型）成功+失败分支全归属 |
| T5 | ARCH-04 部署与配置：三端运行环境/进程依赖/配置与机密来源/启动顺序；单机一图 | done | §4：三端形态表+单进程模型+四层配置分层+启动 mermaid+降级路径 |
| T6 | ARCH-05 质量与安全：关键质量场景→设计措施+验证计划；认证/隔离边界明确 | done | §5：8 质量场景三联（措施+验证+归属阶段）；安全边界与 governance.yaml 对齐 |
| T7 | ARCH-06 权衡/风险/演进限制（ADR 关联 ADR-0001；新增决策出 ADR-0002+并把机器视图与契约拉齐）+ 提交阶段 2 验收 | done | §6/§7：风险 5 项含处理人时点；一致性核对 4/5 勾（末项待阶段 3）；gate=SUBMITTED，开发者结论待填 |

## 对应指导文档

- `hs-dev-skill/references/engineering_acceptance.md` §3（ARCH-01..06）
- `hs-dev-skill/references/stage_acceptance.md`（阶段验收协议）
- `hs-dev-skill/skills/hs-dev-architecture/SKILL.md`（本阶段主轴）
- `ADR-0001`（置顶执行契约：视图/机器契约不得引入落选方案或未授权依赖）

## 验收项与证据位置

- 架构说明：`_03_architecture_design/_01_system_architecture/ARCHITECTURE-iA-Music.md`（§1–§7 正文齐备）
- ADR：`_00_project_foundation/_03_decision_record/ADR-0001-*`（既有，阶段 2 无新增架构级拍板 → 未出 ADR-0002）
- 阶段验收记录：`_06_dev_process/PHASE-2-ACCEPTANCE-iA-Music.md`（SUBMITTED）

## 阻断项

- 无阻断。ISS-101（真机三项）与 ISS-201 按双态建模兜底，结论回填后一次收敛文档终稿。

## 下一步

开发者验收阶段 2（`PHASE-2-ACCEPTANCE-iA-Music.md`）；ACCEPTED 后进入阶段 3（详细设计：DB/API/方法契约 + sync 状态机与 ARCHITECTURE §7 映射核对），并按 T5 预定推进真机 PoC 与分块协议验证。
