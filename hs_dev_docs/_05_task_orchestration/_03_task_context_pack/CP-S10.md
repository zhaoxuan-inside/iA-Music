# Context Pack：CP-S10 三端打包与交付预演（阶段 4 / TASK-04）

- **绑定切片**：S10（详单 `TASK-S10.md`）
- **来源与版本摘要**：
  - DEC-008 ④（分发基线：Android 8+ / Win10 x64 / Ubuntu 22.04+·Debian 12+；ffmpeg LGPL 构建）
  - `DETAILED-DESIGN-iA-Music.md` §4（部署/机密四层/降级路径）；`TECH-SELECTION-iA-Music.md` §5（版本钉死）
  - engineering_acceptance §7（DELIV-01..05——阶段 6 输入材料）
- **规则绑定**：`version_control.md`；`completion_audit.md`（交付前核账）；`auxiliary_governance.md`
- **禁则**：版本钉死漂移（构建可复现记录）；GPL 运行库混入 bundle；未声明限制私自遮盖
- **环境前提**：S9 完成；Android debug 签名可用；桌面打包链路（S0 工具）
- **全真边界（DEC-010）**：无（冒烟全真）
