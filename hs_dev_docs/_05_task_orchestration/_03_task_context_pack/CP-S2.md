# Context Pack：CP-S2 曲库扫描与浏览（阶段 4 / TASK-04）

- **绑定切片**：S2（详单 `TASK-S2.md`）
- **来源与版本摘要**：
  - `library_prd.md`（REQ-LIB-01..08 行 + Scenario 4 条）；`onboarding_prd.md` REQ-ONB-02
  - `library_vibe_spec.md`（扫描/列表行为）；`DETAILED-DESIGN-iA-Music.md` §3.1/§1.2
  - `main_prototype.md`（曲库区块视觉锚）
- **规则绑定**：`testing.md`（红线断言=真实计数）；`deep_modules.md`（ScanService 收口）；`quality_gates.md`
- **禁则**：跳过计数造假；移除曲目删物理文件；写回原文件元数据；扫描占 UI isolate
- **环境前提**：S1 完成；目录监听权限差异（Win/Android）记录进证据
- **全真边界（DEC-010）**：无外部服务；文件系统 fixture 真实
