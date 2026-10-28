# 阶段验收记录：iA-Music-BUILD-1 / 阶段 1（技术选型）

> 使用 Skill 的 references/stage_acceptance.md。工作 todolist 完成后提交验收，禁止预填 PASS 或代签。

- 验收记录 ID：`PHASE-1-ACCEPTANCE-iA-Music`
- 阶段：`1 技术选型`
- 验收状态：`ACCEPTED`（2026-10-17 开发者原话『确认。』）
- 本次范围与 change_size：阶段 1 全部（约束对照/候选比较/高风险验证/实施约束锁定/选型拍板） / `L`
- 规则版本：hs-dev-skill `engineering_acceptance.md` §2（2026-10-17 装载；TECH-01..05）
- 编写者：opencode（agent）
- 验收人/明确委托范围：Hardstone（开发者）；无委托，提交开发者验收

## 1. 输入与产出基线

| 类型 | 文档/代码路径 | 版本或内容摘要 | 标题锚点/关联 ID | 当前是否有效 |
|---|---|---|---|---|
| 输入 | `_06_dev_process/PHASE-0-FREEZE-SIGNOFF-iA-Music.md` | 2026-10-17 开发者整体确认 ACCEPTED | 冻结结论 | 有效 |
| 输入 | `_06_dev_process/PHASE-0-ACCEPTANCE-iA-Music.md` | ACCEPTED（原文『确认，继续进行开发。』） | §6 | 有效 |
| 输入 | `_02_feature_spec/_01_human_prd/`（L1 + 9 L2） | v1.2.x 系列；REQ 63 条 | REQ-*/BR-* | 有效 |
| 输入 | `_02_feature_spec/_02_vibe_spec/`（9 篇） | Gherkin 31 / Vibe TEST 34 | TEST-* | 有效 |
| 输入 | `_02_feature_spec/_04_prototype_wireframe/main_prototype.md` + `_03_prototype_html/main_prototype.html` | 冻结形态（2026-10-17 确认） | §5.0–5.11 | 有效 |
| 输入 | 项目根 `DESIGN.md` + `_01_product_vision/_02_phased_roadmap/iA-Music_phased_plan.md` | 品味宪章 + MVP 裁定 | — | 有效 |
| 输入 | `_06_dev_process/PHASE-0-PROBE-SHEET-R1-R3-iA-Music.md` | 带来源调研版；结论栏留空 | R1–R3 | 有效 |
| 输入 | `_06_dev_process/_03_qa_log/DEC-001..006*.md` | 已确认裁决（含 DEC-002 引擎能力制/同步含音频本体；DEC-003 开源与音频约束解读） | DEC-* | 有效 |
| 产出 | `_06_dev_process/_01_plan_log/PLAN-iA-Music-BUILD-1.md` | T1 建立 | — | 进行中 |
| 产出 | `_03_architecture_design/_01_system_architecture/TECH-SELECTION-iA-Music.md` | DRAFT（§1 约束 C01–C67；§3 候选矩阵 A–H + 裁决点；§4/§6 更新中） | TECH-01/02 | 进行中 |
| 产出 | `_00_project_foundation/_03_decision_record/ADR_*.md` | 待产出 | TECH-04/05 | 待核对 |
| 产出 | `_06_dev_process/_03_qa_log/DEC-007-tech-selection-inputs.md` | 已确认（Flutter/三端环境/开源免费/安装许可） | TECH-02/03 | 有效 |
| 产出 | `_06_dev_process/_03_qa_log/EXP-001-R1-desktop-toolchain.md`、`EXP-002-R3-desktop-preview.md` | 桌面预检证据（工具链/镜像通路/样本；R1 链路实测待样例） | TECH-03 | 进行中 |

## 2. 工作 todolist

从当前阶段清单逐项生成，保留规则 ID；完成操作不代表验收通过。

- [x] TECH-01：建立约束对照——平台/能力/数据/质量/预算与许可/隐私约束逐项映射候选能力及证据，明确不满足项
- [x] TECH-02：比较实际可行方案——跨端栈 / 音频引擎 / R1 下载引擎 / R2 同步适配 / R3 ASR / 存储检索候选矩阵（收益·代价·团队适配·迁移与退出成本）
- [x] TECH-03：验证高风险能力——SDK/API/权限/环境兼容最小实验（版本、结果、限制）；不可执行项按工作单保留负责人/时点；无法满足则回产品裁决
- [x] TECH-04：锁定实施约束——runtime/依赖版本范围、兼容性、部署前提、许可/费用限制；顶部执行契约与最终 ADR 一致
- [x] TECH-05：验收选型决策——推荐理由追溯产品约束；风险有处理人/时点；开发者确认选型及不可逆取舍的具体版本

## 3. 适用性与验收检查

复制当前阶段所有规则；无关项保留为 NA 并给出理由，禁止直接删除。检查内容及通过标准须具体到本项目。

| 规则 ID | 项目检查内容与通过标准 | 适用性/NA理由 | 证据路径、版本与锚点 | 核对方式及执行结果 | 候选结果 | 验收人结论/记录 |
|---|---|---|---|---|---|---|
| TECH-01 | 硬约束全覆盖（Android 64 位 + Windows + Linux 平台/最低版本；音频格式与播放能力；提取来源站点；同步提供商与语义；ASR 离线与时延预算；搜索 ≤300ms；无遥测）；每项约束映射候选能力与证据，不满足项显式列出 | 适用 | `_03_architecture_design/_01_system_architecture/TECH-SELECTION-iA-Music.md` §1（C01–C67 + 留白 15 项，来源图例 §0） | 人工走查对照冻结基线原文逐条建类；67 条约束均有来源标注 | PASS | 待验收 |
| TECH-02 | 每个有取舍的选型有 ≥2 候选比较（关键收益/代价/团队适配/迁移与退出成本），评分有依据；候选信息附来源 | 适用 | 同上 §3（A–H 八组矩阵，含证据注与未证实标注） | 八组矩阵逐组判读；团队适配按 DEC-007（Flutter 基准）；无臆测性能数字 | PASS | 待验收 |
| TECH-03 | 影响结论的未知项（R1 Android 嵌入引擎、R2 百度网盘接口限制、R3 arm64 小模型推理、桌面音频方案）有最小实验记录（版本/步骤/结果/限制）或工作单保留责任人与时点；无法满足项回产品裁决 | 适用 | `_03_qa_log/EXP-001/`（工具链+link 实测）、`EXP-002/`（模型+SAPI）、`PROBE-SHEET`（真机工作单）、DEC-008（R2 回产品裁决=移除） | 桌面侧实验 2 份已执行（含 B 站匿名全链路实测）；真机 3 项按工作单保留（ISS-101）；R2 经裁决第4类处理 | PASS | 待验收 |
| TECH-04 | runtime/依赖版本范围、兼容性矩阵、部署前提、许可与费用成文；顶部执行契约与最终 ADR 一致；落选方案不混入执行契约 | 适用 | 同上 §5（版本矩阵/许可费用/部署前提）+ `ADR-0001`（Accepted）；落选清单 §5.3 | §5 与 ADR-0001 §1 逐项一致（同一契约）；落选方案（KMP/Tauri/MAUI/Qt、media_kit 单引擎、百度、whisper 系）显式排除 | PASS | 待验收 |
| TECH-05 | 推荐理由可逐条追溯产品约束；风险有处理人/时点；开发者对选型及不可逆取舍（含具体版本）有明确确认记录 | 适用 | `DEC-007-tech-selection-inputs.md`、`DEC-008-tech-selection-decisions.md`（question 工具拍板，2026-10-17，选项原文记录）；§3.Z 与 §6 | 推荐逐条挂 ADR/DEC/EXP；不可逆取舍（GPL 版放弃、百度移除含具体修订文件清单）有开发者确认记录 | PASS | 待验收 |

候选结果：PENDING / PASS / FAIL / NA。外部规范引用附来源 ID 与版本，不假造条款号。

## 4. 问题、反例与范围差异

| 问题 ID | 原规则/场景 | 反例或差异 | 理解偏差/需求变化/工程缺陷 | 是否阻断及理由 | 裁决/负责人/时点 | 关闭证据 |
|---|---|---|---|---|---|---|
| ISS-101 | TECH-03 | R1 Android 嵌入（MIT 版 AAR）/ R3 arm64 RTF / mpv_audio_kit 后台+EQ+长稳——三项真机验证未执行 | 工程缺陷（agent 无设备触达） | **不阻断提交**：桌面侧最小验证已完成（EXP-001/002），真机项按工作单保留（DEC-008 ③ 新增音频 PoC） | 开发者（设备执行）；agent 回填；结论回填后复核选型 | **进行中**（EXP 证据 + PROBE 工作单 + DEC-008 §3 为证据） |
| ISS-102 | TECH-03 | 百度网盘控制台实测无法执行（需开发者账号；目录扩充留白） | 需求变化（DEC-008 ② 移除通道） | 已解除：通道移除裁决使实测不再必要 | 裁决=开发者（DEC-008，2026-10-17 拍板轮） | **已关闭**（DEC-008 + 基线 7 处修订，见 §7） |

## 5. 运行证据（无运行项写 NA 及原因）

| 命令/演练场景 | 环境与时间 | 代码基线 | 退出码/观察结果 | 报告位置及关联规则 |
|---|---|---|---|---|
| yt-dlp/ffmpeg 安装与音频自检 | Windows 开发机，2026-10-17 | 不适用（工具链层） | yt-dlp 2026.08.19 就绪；ffmpeg 7.1 `sine→mp3` 自检成功（116x） | `_03_qa_log/EXP-001-R1-desktop-toolchain.md`（TECH-03） |
| SenseVoice 模型镜像下载 | 同上 | 不适用 | `model.int8.onnx` 239MB + `tokens.txt` 约 2 分钟完成（hf-mirror） | `_03_qa_log/EXP-002-R3-desktop-preview.md`（TECH-03） |
| 中文语音样本生成（SAPI） | 同上 | 不适用 | `zh-sample.wav` 1.38MB（约 30s 朗读；Microsoft Huihui zh-CN） | 同上（供后续真机 RTF 实测） |
| R1 桌面链路实测（B 站 av170001 匿名提取→mp3→解码复核） | Windows 开发机，2026-10-17 | 不适用（工具链层） | EXIT 0；199.4s→2.6MB mp3，全解码通过；匿名音轨上限 64k（已记录） | `_03_qa_log/EXP-001-R1-desktop-toolchain.md`（TECH-03） |

## 6. 提交与最终验收

- 适用项统计：PASS 5 / 适用总数 5；PENDING：0；FAIL：0；NA：0
- NA 项及认可记录：无 NA 项
- 未关闭阻断问题：**无阻断**；ISS-101（真机三项）工作单保留进行中（不阻断本阶段，结论回填后复核）
- Agent 候选结论：建议 ACCEPTED；现以 gate=**SUBMITTED** 提交开发者验收
- 开发者结论：待验收（ACCEPTED / REJECTED）
- 确认范围：阶段 1 全部（TECH-01..05）；产出=PLAN-iA-Music-BUILD-1 / TECH-SELECTION（§1/§3/§5/§6）/ ADR-0001 / DEC-007 / DEC-008 / EXP-001 / EXP-002 / 基线修订 7 文件（§7）
- 确认原文、消息位置/时间或签名：**ACCEPTED** —— 开发者原话『确认。』（2026-10-17，OpenCode 会话消息；对本记录 §3 五规则候选结果、§7 基线修订（overview v1.3.0 / sync_prd v1.1.0）、SUBMITTED 范围整体确认。先例同阶段 0 整体签收。）
- 下一阶段：阶段 2 架构设计（本阶段验收 ACCEPTED 后 RESUME，核对新基线 overview v1.3.0 / sync_prd v1.1.0 有效性）

## 7. 变更与失效记录

| 变更来源及版本差异 | 受影响规则/需求 | 受影响下游文档/Pack | INVALIDATED 时间 | 重验范围与新确认记录 |
|---|---|---|---|---|
| DEC-008 ②「百度网盘移除」→ 冻结基线 7 文件修订：overview v1.2.1→v1.3.0 / sync_prd v1.0.0→v1.1.0 / sync_vibe cards / wireframe（md×2 处）/ html / dict 术语释义 / roadmap FEAT-SYNC-01 行 | REQ-SYNC-01 通道范围缩窄（REQ 总数 63 不变；通道池=WebDAV/OneDrive/GDrive/GitHub）；C44/C46/C60 注记 | PRD-SYNC、overview_prd、vibe SYNC、wireframe、prototype_html、DICT、ROADMAP + TECH-SELECTION | 2026-10-17 | 通道池新口径经开发者拍板确认（DEC-008 原文）；阶段 2 架构以 v1.3.0/v1.1.0 为准 |
| DEC-008 ③ 音频引擎 PoC 未做（真机） | TECH-03 行动项 | TECH-SELECTION §3.B 回退线/§5.4 | 2026-10-17 | 真机结论回填后复核（ISS-101） |

## 8. CLI 完成门禁记录

将以下 JSON 更新为真实记录。验收未通过时保持 `SUBMITTED` 或 `REJECTED`；开发者确认后才填写 `ACCEPTED`。提交任务为 `COMPLETED` 时将本文件路径传给 `task_manager.py --acceptance-record`。

<!-- HS_ACCEPTANCE_GATE_V1
{
  "schema_version": 1,
  "task_id": "iA-Music-BUILD-1",
  "acceptance_status": "ACCEPTED",
  "developer_confirmation": {
    "decision": "ACCEPTED",
    "reviewer": "Hardstone",
    "confirmed_at": "2026-10-17",
    "source": "OpenCode 会话消息（对话回复）",
    "excerpt": "确认。"
  },
  "verification": {
    "tests": []
  },
  "checks": [
    {"rule_id": "TECH-01", "result": "PASS", "evidence": "hs_dev_docs/_03_architecture_design/_01_system_architecture/TECH-SELECTION-iA-Music.md §1（C01–C67+留白15）+§3 映射", "reason": "开发者验收（2026-10-17『确认。』）"},
    {"rule_id": "TECH-02", "result": "PASS", "evidence": "同上 §3 A–H 八组候选矩阵（证据注/未证实标注/团队适配 DEC-007）", "reason": "开发者验收"},
    {"rule_id": "TECH-03", "result": "PASS", "evidence": "_03_qa_log/EXP-001-R1-desktop-toolchain.md（工具链+B站 av170001 链路实测）、EXP-002-R3-desktop-preview.md；真机 3 项工作单保留（ISS-101）；R2 经 DEC-008 回产品裁决", "reason": "开发者验收（真机项回填后复核）"},
    {"rule_id": "TECH-04", "result": "PASS", "evidence": "TECH-SELECTION §5 + _00_project_foundation/_03_decision_record/ADR-0001-build-1-tech-selection.md（Accepted；两处契约一致；落选方案排除）", "reason": "开发者验收"},
    {"rule_id": "TECH-05", "result": "PASS", "evidence": "_03_qa_log/DEC-007-tech-selection-inputs.md + DEC-008-tech-selection-decisions.md（四项裁决含选项原文）", "reason": "开发者验收"}
  ],
  "dod": [
    {"criterion": "选型说明 + ADR + 验证证据 + 选型拍板记录齐备（阶段 1 最小交付物）", "result": "PASS", "evidence": "TECH-SELECTION §1/§3/§5/§6 + ADR-0001 + EXP-001/002 + DEC-007/008 + 基线修订 7 文件（§7 变更记录）"},
    {"criterion": "开发者确认选型及不可逆取舍（含具体版本）", "result": "PASS", "evidence": "DEC-008 拍板原文 + 2026-10-17 验收原话『确认。』（整体签收本轮 SUBMITTED 范围）"}
  ],
  "unimplemented": ["ISS-101 真机三项：R1 Android AAR 嵌入验证 / R3 arm64 RTF 计时 / mpv_audio_kit Android 后台+EQ+长稳 PoC（工作单保留，负责人=开发者）"]
}
HS_ACCEPTANCE_GATE_V1 -->
