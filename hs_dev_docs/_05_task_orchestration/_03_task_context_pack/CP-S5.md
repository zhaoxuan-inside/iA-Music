# Context Pack：CP-S5 封面链（阶段 4 / TASK-04）

- **绑定切片**：S5（详单 `TASK-S5.md`）
- **来源与版本摘要**：
  - `library_prd.md` REQ-LIB-04/08 + Scenario；`DETAILED-DESIGN-iA-Music.md` §3.5/§2.1 CoverFetchPort
  - CAA/iTunes 检索源规则（ADR-0001：CAA 主+iTunes 兜底；限流 1req/s；UA 强制）
- **规则绑定**：`testing.md`；`auxiliary_governance.md`（外呼礼貌性约束）；DEC-004（在线封面设置项说明含版权自担）
- **禁则**：C22 只补缺不覆盖——任何来源命中后禁止向已具封面曲目再请求；抓取失败重试（静默降级）
- **环境前提**：S2 完成（曲库表）；网络可达/或离线断言可用
- **全真边界（DEC-010）**：CAA/iTunes 真源实呼（命中=真实知名曲目、无结果=真实不存在曲名、断网=真实关闭网络）；磁盘与 DB=真
