# Context Pack：CP-S6 提取管线（阶段 4 / TASK-04）

- **绑定切片**：S6（详单 `TASK-S6.md`；前置 **RV-B**）
- **来源与版本摘要**：
  - `extraction_prd.md`（REQ-EXT-01..08 + Scenario）；`onboarding_prd.md` REQ-ONB-03；`extraction_vibe_spec.md`
  - `DETAILED-DESIGN-iA-Music.md` §3.2/§3.3/§4.2（任务机）/§2.1 DownloaderPort/§5.2 音质族
  - `EXP-001-R1-desktop-toolchain.md`（解析链路实测：匿名 64k / Cookie 高音质 / `--print` 隐含 simulate 纪律）；MIT 版 yt-dlp-android（DEC-008 ①）
- **规则绑定**：`testing.md`（DEC-010 全真证据要求）；`security.md` 相关条=security 治理 on（Cookie 保密）；`quality_gates.md`
- **禁则**：Cookie 进 drift/日志（C50）；百度网盘；DRM 绕过；无限重试；合规前下载（ONB-03）
- **环境前提**：EXP-001 工具链（`C:\Users\hardstone\tools\r1-test`）；`PYTHONIOENCODING=utf-8`；真 B 站链接小样本
- **全真边界（DEC-010）**：解析/下载/中断全走真链路真环境（断网=真实网络开关）；EXP-001 留档仅作对照，不替代真跑
