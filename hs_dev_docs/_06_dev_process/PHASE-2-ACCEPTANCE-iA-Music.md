# 阶段验收记录：iA-Music-BUILD-2 / 阶段 2（架构设计）

> 使用 Skill 的 references/stage_acceptance.md。工作 todolist 完成后提交验收，禁止预填 PASS 或代签。

- 验收记录 ID：`PHASE-2-ACCEPTANCE-iA-Music`
- 阶段：`2 架构设计`
- 验收状态：`ACCEPTED`（2026-10-17 开发者原话『确认』）
- 本次范围与 change_size：阶段 2 全部（上下文边界/职责与数据所有权/运行场景/部署配置/质量安全/权衡风险） / `L`
- 规则版本：hs-dev-skill `engineering_acceptance.md` §3（2026-10-17 装载；ARCH-01..06）
- 编写者：opencode（agent）
- 验收人/明确委托范围：Hardstone（开发者）；无委托，提交开发者验收

## 1. 输入与产出基线

| 类型 | 文档/代码路径 | 版本或内容摘要 | 标题锚点/关联 ID | 当前是否有效 |
|---|---|---|---|---|
| 输入 | `_06_dev_process/PHASE-1-ACCEPTANCE-iA-Music.md` | **ACCEPTED**（原话『确认。』2026-10-17） | §6/gate | 有效 |
| 输入 | `_00_project_foundation/_03_decision_record/ADR-0001-build-1-tech-selection.md` | Accepted（置顶执行契约） | §1 | 有效 |
| 输入 | `_03_architecture_design/_01_system_architecture/TECH-SELECTION-iA-Music.md` | §1 C01–C67 / §3 矩阵 / §5 实施约束 / §6 拍板 | TECH-* | 有效 |
| 输入 | `_02_feature_spec/_01_human_prd/` | overview **v1.3.0**；features（SYNC=**v1.1.0**，其余 v1.0.0–v1.2.1）；REQ 63 | REQ-* | 有效 |
| 输入 | `_02_feature_spec/_02_vibe_spec/` + `_04_prototype_wireframe/` + `_03_prototype_html/` | 冻结（DEC-008 修订后） | TEST-* / §5.x | 有效 |
| 输入 | `DESIGN.md` + `iA-Music_phased_plan.md` | 品味宪章 + MVP Slice S0–S6 | — | 有效 |
| 输入 | `_06_dev_process/_03_qa_log/DEC-001..008*.md`；EXP-001/002 | 既有裁决与实验证据 | DEC-*/EXP-* | 有效 |
| 产出 | `_06_dev_process/_01_plan_log/PLAN-iA-Music-BUILD-2.md` | T1–T7 全 done | — | 有效 |
| 产出 | `_03_architecture_design/_01_system_architecture/ARCHITECTURE-iA-Music.md` | §1–§7 正文齐备（DRAFT 待验收） | ARCH-* | 有效 |
| 产出 | `_00_project_foundation/_03_decision_record/ADR-0002+*.md` | 无新增架构级拍板（沿用 ADR-0001；§5.1 声明） | ARCH-06 | NA |

## 2. 工作 todolist

- [x] ARCH-01：定义上下文与边界——使用者、外部系统、输入输出、信任边界及本系统不承担的职责明确；与产品范围一致
- [x] ARCH-02：分配职责与数据所有权——每个核心能力有负责模块，数据写入权、模块接口和依赖方向明确；避免职责重叠或无主业务规则
- [x] ARCH-03：还原关键运行场景——核心成功/失败场景映射至模块协作，事务边界、异步顺序、重试与恢复有归属；不以静态目录树替代运行设计
- [x] ARCH-04：描述部署与配置——目标运行环境、进程/服务依赖、配置/机密来源及启动顺序可解释；单机方案可用一张图
- [x] ARCH-05：对应质量与安全约束——关键质量场景对应设计措施及验证计划；认证/授权位置与隔离边界明确；不因引用安全规范默认启用全部治理模式
- [x] ARCH-06：验收权衡与风险——ADR、已知风险/技术债、演进限制有记录；开发者确认系统边界和重要取舍，机器契约与视图一致

## 3. 适用性与验收检查

| 规则 ID | 项目检查内容与通过标准 | 适用性/NA理由 | 证据路径、版本与锚点 | 核对方式及执行结果 | 候选结果 | 验收人结论/记录 |
|---|---|---|---|---|---|---|
| ARCH-01 | 使用者（移动端/桌面端个人用户）、外部系统（B 站、WebDAV 云端、MusicBrainz/iTunes、hf-mirror 模型源）、IO 与信任边界清晰；无自有服务端/无 Web 端与之产品范围一致 | 适用 | `ARCHITECTURE-iA-Music.md` §1（外部系统 7 类表/三信任域/不承担清单；输入基线=overview v1.3.0 等） | 人工走查：外部系统逐一挂 REQ 锚点；不承担清单对照红线与 DEC-002 | PASS | 待验收 |
| ARCH-02 | 核心能力（曲库/播放/提取/歌词 ASR/同步/壳层）→ 模块矩阵；数据写入权（drift 单一写入路径等）、接口与依赖方向明确 | 适用 | 同上 §2（7 模块域×REQ 63 全覆盖映射；11 类数据唯一写者表；ports & adapters 依赖单向图） | 逐 REQ 对照 owner；无漏项/重复；EnginePort 双态集中切换 | PASS | 待验收 |
| ARCH-03 | 关键场景（扫描入库/随机连续播放/后台断网恢复/提取 Cookie 失效/同步冲突合并/ASR 中断取消）成功+失败路径均可映射模块协作 | 适用 | 同上 §3（六场景正文：成功序列+失败分支归属+事务/异步/重试；sync 状态机逐态对应） | 六场景人工推演；所有失败分支均有写者与 UI 归属；EXP-001 实测锚点（64k/Cookie） | PASS | 待验收 |
| ARCH-04 | 三端运行环境与打包形态（AAB/Win/AppImage+deb）、进程与插件依赖、配置/机密（secure storage）与启动顺序成文 | 适用 | 同上 §4（三端形态表/单进程模型/机密四层/启动 mermaid+降级路径） | 与 ADR-0001 版本矩阵互查一致；「首次打开」全链可讲 | PASS | 待验收 |
| ARCH-05 | 质量场景（无遥测、本地数据无损、搜索 ≤300ms、后台播放连续性、Cookie 安全存储）→ 设计措施+验证计划；governance.yaml 开关一致 | 适用 | 同上 §5（8 质量场景「措施+验证计划+归属阶段」三联表） | governance.yaml 逐开关核对（cicd/observability off；security on）；红线与 Cookie 有可复验机制 | PASS | 待验收 |
| ARCH-06 | 架构权衡/风险/技术债/演进限制有记录并关联 ADR；开发者确认边界与重要取舍 | 适用 | 同上 §6（ADR-0001 关联+风险 5 项含处理人时点+演进预留/不演进项）与 §7 一致性核对（4/5 勾；末项待阶段 3） | 真机收敛项（ISS-101/201）双态兜底登记；未出 ADR-0002（无新拍板） | PASS | 待验收 |

候选结果：PENDING / PASS / FAIL / NA。

## 4. 问题、反例与范围差异

| 问题 ID | 原规则/场景 | 反例或差异 | 理解偏差/需求变化/工程缺陷 | 是否阻断及理由 | 裁决/负责人/时点 | 关闭证据 |
|---|---|---|---|---|---|---|
| ISS-201 | ARCH-02/03 | mpv_audio_kit 与双引擎二选一未最终定（真机 PoC 未做） | 工程缺陷（真机依赖） | 不阻断：按「单引擎优先+双引擎回退」双态建模，PoC 结论回填后收敛 | ISS-101 同源（开发者/设备）；结论回填复核 | 进行中 |

## 5. 运行证据（无运行项写 NA 及原因）

| 命令/演练场景 | 环境与时间 | 代码基线 | 退出码/观察结果 | 报告位置及关联规则 |
|---|---|---|---|---|
| 设计阶段无运行项（NA） | — | — | NA：架构正文为设计产物；架构冒烟实验按 §5.1 验证计划归属阶段 5/6 执行 | — |

## 6. 提交与最终验收

- 适用项统计：PASS 6（候选结果）/ 适用总数 6；PENDING：0；FAIL：0；NA：0
- NA 项及认可记录：§5 运行证据=NA（设计阶段，无运行项；验证计划已归属阶段 5/6）
- 未关闭阻断问题：**无阻断**；ISS-201（引擎终极态，ISS-101 同源）双态建模兜底进行中，结论回填后收敛
- Agent 候选结论：建议 ACCEPTED；现以 gate=**SUBMITTED** 提交开发者验收
- 开发者结论：待验收（ACCEPTED / REJECTED）
- 确认范围：阶段 2 全部（ARCH-01..06）；产出=PLAN-iA-Music-BUILD-2 / ARCHITECTURE-iA-Music（§1–§7）/ ADR-0001（沿用，无新 ADR）
- 确认原文、消息位置/时间或签名：**ACCEPTED** —— 开发者原话『确认』（2026-10-17，OpenCode 会话消息；对本记录 §3 六规则候选结果、架构正文 §1–§7、SUBMITTED 范围整体确认。先例同阶段 0/1 整体签收。）
- 下一阶段：阶段 3 详细设计（本阶段验收 ACCEPTED 后 RESUME；ARCHITECTURE §7 末项「状态机↔契约映射」在该阶段完成）

## 7. 变更与失效记录

| 变更来源及版本差异 | 受影响规则/需求 | 受影响下游文档/Pack | INVALIDATED 时间 | 重验范围与新确认记录 |
|---|---|---|---|---|
| 无（阶段 2 新开；上游 DEC-008 修订已计入 §1 基线） | — | — | — | — |

## 8. CLI 完成门禁记录

<!-- HS_ACCEPTANCE_GATE_V1
{
  "schema_version": 1,
  "task_id": "iA-Music-BUILD-2",
  "acceptance_status": "ACCEPTED",
  "developer_confirmation": {
    "decision": "ACCEPTED",
    "reviewer": "Hardstone",
    "confirmed_at": "2026-10-17",
    "source": "OpenCode 会话消息（对话回复）",
    "excerpt": "确认"
  },
  "verification": {
    "tests": []
  },
  "checks": [
    {"rule_id": "ARCH-01", "result": "PASS", "evidence": "TECH... 见 ARCHITECTURE-iA-Music.md §1（外部系统/信任域/不承担清单）", "reason": "候选结果，待开发者验收"},
    {"rule_id": "ARCH-02", "result": "PASS", "evidence": "ARCHITECTURE-iA-Music.md §2（7 域×REQ63 映射；11 类数据唯一写者；依赖单向）", "reason": "候选结果"},
    {"rule_id": "ARCH-03", "result": "PASS", "evidence": "ARCHITECTURE-iA-Music.md §3（六场景成功/失败归属与事务/重试；EXP-001 锚点）", "reason": "候选结果"},
    {"rule_id": "ARCH-04", "result": "PASS", "evidence": "ARCHITECTURE-iA-Music.md §4（三端形态/机密四层/启动图+降级）", "reason": "候选结果"},
    {"rule_id": "ARCH-05", "result": "PASS", "evidence": "ARCHITECTURE-iA-Music.md §5（8 质量场景三联；governance.yaml 对齐）", "reason": "候选结果"},
    {"rule_id": "ARCH-06", "result": "PASS", "evidence": "ARCHITECTURE-iA-Music.md §6/§7（风险含处理人时点；一致性核对 4/5；ADR-0001 关联）", "reason": "候选结果"}
  ],
  "dod": [
    {"criterion": "架构说明（上下文/职责/运行场景/部署/质量安全/权衡）+ ADR 关联 + 风险表齐备", "result": "PASS", "evidence": "ARCHITECTURE-iA-Music.md §1–§7 正文齐备；PLAN-iA-Music-BUILD-2 T1–T7 done"},
    {"criterion": "开发者确认系统边界与重要取舍", "result": "PENDING", "evidence": "待开发者验收 §6 填写确认原文"}
  ],
  "unimplemented": ["ARCHITECTURE §7 末项「状态机↔阶段 3 契约映射」（归属阶段 3）；ISS-201/ISS-101 真机 PoC 收敛项（不阻断验收）"]
}
HS_ACCEPTANCE_GATE_V1 -->