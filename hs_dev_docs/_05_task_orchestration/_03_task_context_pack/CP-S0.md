# Context Pack：CP-S0 工程底座（阶段 4 / TASK-04）

- **绑定切片**：S0（详单 `TASK-S0.md`）
- **来源与版本摘要**（路径+锚点）：
  - `TECH-SELECTION-iA-Music.md` §5 版本矩阵（锁定：Flutter 稳定版/依赖版本对齐 ADR-0001）
  - `ADR-0001`（Accepted，全条）
  - `DETAILED-DESIGN-iA-Music.md` §2（七 Port 签名/异常枚举）
  - `governance.yaml`（cicd=off / observability=off / security=on）
- **规则绑定**：`coding_standards.md`（语言与命名）；`cross_platform.md`（三端差异守则）；`version_control.md`（提交粒度）
- **禁则（落选方案清零）**：GPL 版 yt-dlp-android；百度网盘通道；遥测/埋点类依赖；未锁定版本浮动
- **环境前提**：Flutter SDK 三端工具链（D7-4 许可）；Android SDK/NDK；桌面机 Win10+ 与 Ubuntu 22.04（或容器）
- **全真边界（DEC-010）**：无（结构切片）
