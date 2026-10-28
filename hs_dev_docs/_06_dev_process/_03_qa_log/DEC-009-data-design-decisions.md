# DEC-009 数据设计裁决（阶段 3 收口）

- **裁决日期**：2026-10-17
- **入场**：DETAILED-DESIGN-iA-Music.md §1.2/§1.4 候选方案（PLAN-BUILD-3 T2 备注预登记）
- **裁决**：开发者在阶段 3 验收中整体确认（原话『详细设计通过。继续执行后续的流程。』，2026-10-17，OpenCode 会话消息）

| ID | 决策点 | 裁决 | 依据锚点 |
|---|---|---|---|
| D9-1 | 搜索拼音方案 | FTS5 外部内容表 `track_index`（title/artist/album/**pinyin_full / pinyin_initials 双列**），与 tracks 同事务写 | DETAILED-DESIGN §1.2；REQ-NAV-04 |
| D9-2 | 随机池取样 | SQL 侧 `NOT IN few_watch_list` 粗筛（deleted/missing 双 NULL）+ 内存采样（少播上限 500 级别可承受） | DETAILED-DESIGN §1.3；REQ-NAV-02/PLAY-03 |
| D9-3 | 历史 500 淘汰 | 应用层批次删除（按 played_at 最旧，100 条/批事务），不用数据库触发器 | DETAILED-DESIGN §1.2；REQ-PL-05 |

- **影响范围**：drift schema v1（T 节奏见 PLAN-BUILD-4/5）；上述方案属「实现契约」，阶段 5 实现偏离需重开 DEC。
- **验收来源**：PHASE-3-ACCEPTANCE-iA-Music.md §6（gate=ACCEPTED）。
