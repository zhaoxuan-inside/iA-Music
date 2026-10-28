# Context Pack：CP-S8 同步（阶段 4 / TASK-04）

- **绑定切片**：S8（详单 `TASK-S8.md`）
- **来源与版本摘要**：
  - `sync_prd.md`（REQ-SYNC-01..08 + Scenario）；`sync_vibe_spec.md`（**状态机原文 L32-45，逐态权威**）；`overview_prd.md` v1.3.0 同步基线（v1.1.0）
  - `DETAILED-DESIGN-iA-Music.md` §3.3/§4.1（七态逐态表）/§2.1 SyncChannelPort（无 delete）
  - 冻结红线：删除仅解除记录；墓碑不毁云端音频（冻结包 overview_prd v1.3.0 红线条目）
- **规则绑定**：`testing.md`（双实例联测）；`api_engineering.md`（重试语义）；`quality_gates.md`
- **禁则**：远端文件因端删而删（红线级）；本地数据不一致；凭据落 DB/日志；百度网盘；无限重试（分块 3 次）
- **环境前提**：本地 WebDAV fixture 服务；GitHub 测试库；同机双实例环境
- **全真边界（DEC-010）**：无（协议真实现）
