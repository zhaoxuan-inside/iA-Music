# Context Pack：CP-S1 数据契约底座（阶段 4 / TASK-04）

- **绑定切片**：S1（详单 `TASK-S1.md`）
- **来源与版本摘要**：
  - `DETAILED-DESIGN-iA-Music.md` §1（14 表字段级/惯例/索引九组/迁移回退门）；§2.1 SecureStorePort
  - `DEC-009-data-design-decisions.md`（D9-1 FTS 拼音双列 / D9-2 随机池 / D9-3 历史 500 应用层淘汰）
  - REQ 分母：§1.3 索引行各锚 REQ
- **规则绑定**：`coding_standards.md`；`api_engineering.md`（DAO 契约式异常）；`testing.md`（行为断言优于内部断言）
- **禁则**：硬删业务记录路径；凭据本体入库/落日志；schema 版本漂移（v1 起步+只增）
- **环境前提**：drift + sqlite3(FTS5) + drift_flutter（版本=ADR-0001）；flutter_secure_storage
- **全真边界（DEC-010）**：drift 内存库=真引擎；SecureStore 真三端实现
