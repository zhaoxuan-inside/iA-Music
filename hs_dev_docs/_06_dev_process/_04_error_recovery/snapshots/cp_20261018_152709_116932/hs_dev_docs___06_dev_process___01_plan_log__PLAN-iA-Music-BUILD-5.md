# 任务计划账本：iA-Music-BUILD-5

- **task_id**：`iA-Music-BUILD-5`
- **标题**：iA-Music 本地音乐播放器 — BUILD 阶段 5（实现切片，IMPL-01..06）
- **change_size**：`L`
- **work_mode**：`CODE`（行为红绿实现；配合 `task_state_machine.md` 推进）
- **所处阶段**：`5`（上游=阶段 4 ACCEPTED（『确认（验收通过）』含切片顺序确认，2026-10-17）；切片=S0–S10 串行（阶段 4 已确认）；验证=**DEC-010 全真**）
- **断点**：`T2 进行中` — 环境就绪（EXP-003 ✓）；S0 主体=flutter create 三端工程 + contracts 包
- **刷新时间**：2026-10-17
- **上游基线**：阶段 0–4 全 ACCEPTED；ADR-0001；DEC-009/010；TASK-S0..S10 详单 + CP-S0..S10 Pack（阶段 4 已签）

---

## 环境底数（已就绪，EXP-003）

- Flutter SDK：**3.47.6 stable**（既有安装采纳，未重复下载）`E:\HardStone.Flutter\flutter`（开发者指令：E 盘目录规则；证据 EXP-003）
- Android SDK：✓ SDK 37.0.0（`ANDROID_HOME=E:\HardStone.Android\AndroidSDK`，许可已全接受，JAVA=jdk-21.0.12.1+1）
- Windows 桌面编译线：✓（VS 生成工具 2022）；Linux 桌面：开发者环境执行（ISS-502）
- pub/gradle 镜像与缓存：pub-cache=E 盘（C 盘零占用）；maven 走项目内阿里云镜像（S0 证据）

## 步骤

| step_id | 描述 | 状态 | 备注 |
|---------|------|------|------|
| T1 | 阶段 5 启动：账本 + 验收骨架 + 环境检查 | done | 本文件 + `PHASE-5-ACCEPTANCE-iA-Music.md` |
| T2 | **S0 工程底座**：Flutter 三端工程 + `contracts/` 包（七 Port+异常+DTO）+ 目录治理 | **ACCEPTED** | 开发者签收原话「S0 验收通过」（2026-10-17T15:38:47Z 会话答复，PHASE-5 §8 切片验收记录全档）；证据链=IMPL-S0 §1–§7（含装机冒烟 pid=2658+截图）；Linux=ISS-502 挂账（开发者裁决）、S10 前回改项在册 |
| T3 | S1 数据契约底座（drift v1 全表+DAO+SecureStore+回退门） | **ACCEPTED** | 开发者签收原话「S1 验收通过」（2026-10-17T15:41:15Z 会话答复，PHASE-5 §8 切片验收记录全档）；DoD 四项全 PASS（九组查询+EQP 3/回退门/六问 132 列 0 歧义/红线核对）；测试 27/27+analyze 0；残留：SecureStore 运行时验证→S2/S3/S8 链路、sqlite3 file:// 路径→S10 前回改、RV 窗口补真机项 |
| T4 | S2 曲库扫描与浏览（真实计数红线） | **ACCEPTED** | 开发者签收原话「确认验收」（2026-10-18T00:41:21Z 会话答复，PHASE-5 §8 切片验收记录全档）；证据链=IMPL-S2 §1–§7（41/41+analyze 0；DEC-010 全真链；五教训 L1–L5 入档）；残留：UI 真 picker→S10、onboarding 联动→S9、RV-A/B/C 不变 |
| T5 | S3 播放引擎竖切 | **ACCEPTED** | 开发者签收原话「确认签收」（2026-10-18T03:25:11Z 会话答复，PHASE-5 §8 切片验收记录全档）；证据链=IMPL-S3 §1–§7（59/59=基线 41+S3 18，analyze 0；DEC-010 全真：真 mpv_audio_kit 0.5.1+真 ffmpeg 短样本+真库行；教训 L1–L6 入档）；DoD1/2/4/5/6 全 PASS；**DoD3=OPEN 顺延**（后台/锁屏/媒体键真平台演练+会话真桥，依赖 RV-A 真机窗口）；残留：bufferMs/preloadNextCount 契约位不落引擎（毒化实证）、typed seek −12 待包升级/RV-A、EQ=明示不支持线待 RV-A 直桥、pubspec 改动 uncommitted 待自提 |
| T6 | S4 播放页与歌单 | **ACCEPTED** | 开发者签收原话「确认验收」（2026-10-18T06:20:02Z 会话答复，PHASE-5 §8 切片验收记录全档）；证据链=IMPL-S4 §1–§7（**76/76**=基线 59+S4 17，analyze 0；DEC-010 全真：真 mpv 0.5.1+真短样本+真库+真 fs；教训 L1–L4 入档）；DoD1/2/4/5/6 **PASS**；**DoD3=分支 B 实跑**（EQ 明示不支持面；分支 A 实时生效待 RV-A 真机回填）+真平台演练沿 S3 顺延；交付=沉浸页（胶片帧/打孔带/进度/三键）+队列页（插队）+音效页+歌单列表/资料页+我的页三卡+壳三 Tab 常驻条；契约增量=EnginePort.insertNext（mpv insert-next）；**待开发者裁决**=REQ-PL-05「历史按日期分组」列表 UI 归属切片；残留：播放页加载态无独立 spinner（S9/S10 视觉收口）、pubspec/新文件 uncommitted 待自提 |
| T7 | S5 封面链 | pending | CP-S5（真实 CAA/iTunes，DEC-010） |
| T8 | 检查点 A + 演练 D1（S0–S5 后：扫描→随机播放→歌单竖闭环） | pending | 证据进 QA log + IMPL 行更新 |
| T9 | S6 提取管线 | pending | **RV-B 阻塞点**；CP-S6 |
| T10 | S7 歌词与 ASR | pending | **RV-C 阻塞点**；CP-S7 |
| T11 | S8 同步 | pending | CP-S8（双实例联测） |
| T12 | 检查点 B + 演练 D2/D3（S6–S8 后） | pending | D3 需双设备 |
| T13 | S9 壳层整合 | pending | CP-S9 |
| T14 | S10 三端打包交付 | pending | CP-S10 |
| T15 | 提交 PHASE-5 gate（SUBMITTED；合并切片验收） | pending | IMPL-06 |

## 对应指导文档

- `engineering_acceptance.md` §6（IMPL-01..06）；`stage_acceptance.md`；`task_state_machine.md`
- `DEC-010-no-mock-policy.md`（验证一票全真）

## 阻断项

- 无阻断；RV-A/B/C 真机窗口（ISS-401/ISS-302 同源）到点阻塞对应切片，不阻断前置切片推进。

## 下一步

S0 收口（`flutter --version` + 三端编译线 + contracts 包），随后 T3 S1。
