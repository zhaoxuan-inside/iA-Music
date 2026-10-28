# 任务计划账本：iA-Music-BUILD-1

- **task_id**：`iA-Music-BUILD-1`
- **标题**：iA-Music 本地音乐播放器 — BUILD 阶段 1（技术选型）
- **change_size**：`L`
- **work_mode**：`DESIGN`
- **当前阶段**：`1`（技术选型；输入＝阶段 0 冻结基线，2026-10-17 ACCEPTED；主路由 hs-dev-design，功能轴 hs-dev-architecture）
- **断点**：`阶段 1 收官（ACCEPTED）` — 开发者原话『确认。』（2026-10-17，gate=ACCEPTED）；本账本归档；后续推进 → `PLAN-iA-Music-BUILD-2.md`（阶段 2 架构设计）
- **更新时间**：2026-10-17

---

## 步骤

| step_id | 描述 | 状态 | 备注 |
|---------|------|------|------|
| T1 | 阶段 1 启动：计划账本 + 验收记录（TECH-01..05 展开为工作 todolist） | done | 本文件 + `_06_dev_process/PHASE-1-ACCEPTANCE-iA-Music.md`（DRAFT） |
| T2 | TECH-01 约束对照：冻结基线 → 能力/平台/数据/预算/质量约束抽取 → 候选能力映射与不满足项 | done | 约束清单（TECH-SELECTION §1，C01–C67 + 留白 15 项）与候选能力映射/不满足项（§3）已落盘 |
| T3 | TECH-02 候选比较：跨端栈 / 音频引擎 / R1 下载引擎 / R2 同步适配 / R3 ASR / 存储检索（关键收益·代价·团队适配·迁移与退出成本，评分有据） | done | 草案完成（TECH-SELECTION §3 A–H；团队适配按 DEC-007；评分均附来源，未证实项显式标注）；待 T6 验收与开发者复核 |
| T4 | TECH-03 高风险最小验证：可执行项执行（桌面 yt-dlp/ASR 最小实验等，需安装工具先请示）；不可执行项按工作单保留负责人/时点 | done | agent 侧收口：EXP-001=工具链+链路实测 ✓（av170001 匿名全链路→mp3 解码复核 ✓）；EXP-002=模型镜像通路 ✓+SAPI 样本 ✓（RTF 后置真机）；真机项按工作单保留（ISS-101，含 DEC-008 ③ 音频 PoC） |
| T5 | TECH-04 实施约束锁定 + 选型说明/ADR 落盘：runtime/依赖版本范围、兼容性、部署前提、许可/费用；顶部执行契约与最终 ADR 一致 | done | §5 已锁定（版本矩阵/许可费用/部署前提/开放点）；`ADR-0001-build-1-tech-selection.md`（Accepted）与 TECH-SELECTION 一致 |
| T6 | TECH-05 提交阶段 1 验收 + 开发者拍板：推荐理由追溯产品约束、风险处理人/时点、不可逆取舍具体版本 | done | 拍板完成：DEC-008 四项（R1=MIT / 百度移除 / mpv 先 PoC / 版本锁定）；验收提交=SUBMITTED，开发者结论待填 |

## 对应指导文档

- `hs-dev-skill/references/engineering_acceptance.md` §2（TECH-01..05 验收清单）
- `hs-dev-skill/references/stage_acceptance.md`（阶段验收协议）
- `hs-dev-skill/skills/hs-dev-architecture/SKILL.md`（阶段 1 功能轴）
- `hs-dev-skill/references/dev_paradigm.md`（按需）

## 验收项与证据位置

- 约束对照与候选矩阵：`_03_architecture_design/_01_system_architecture/TECH-SELECTION-iA-Music.md`（§1 约束 C01–C67 · §3 矩阵 A–H/Z · §5 实施约束）
- ADR：`_00_project_foundation/_03_decision_record/ADR-0001-build-1-tech-selection.md`（Accepted）
- 最小验证证据：`_06_dev_process/_03_qa_log/EXP-001-R1-desktop-toolchain.md`、`EXP-002-R3-desktop-preview.md`
- R1–R3 探查工作单：`_06_dev_process/PHASE-0-PROBE-SHEET-R1-R3-iA-Music.md`
- 阶段验收记录：`_06_dev_process/PHASE-1-ACCEPTANCE-iA-Music.md`
- 拍板问答：`_06_dev_process/_03_qa_log/DEC-007-tech-selection-inputs.md`、`DEC-008-tech-selection-decisions.md`

## 阻断项

- R1–R3 真机验证未执行（ISS-101，工作单保留：R1 Android 嵌入 / R3 arm64 RTF / mpv_audio_kit Android PoC——均待开发者设备安排，结论回填后复核选型）。
- 基线文档尚未入 git（untracked）；建议开发者适时提交快照（agent 不代提交）。

## 下一步

阶段 1 已提交验收（gate=SUBMITTED）：请开发者验收 `PHASE-1-ACCEPTANCE-iA-Music.md`（可逐条核对 §3 五规则与 §7 变更记录）；验收通过后进入阶段 2（架构设计，RESUME 时核对新基线版本 overview v1.3.0 / sync_prd v1.1.0 有效性）。真机工作单（ISS-101）可并行安排。
