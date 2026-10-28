# Context Pack：CP-S3 播放引擎竖切（阶段 4 / TASK-04）

- **绑定切片**：S3（详单 `TASK-S3.md`；前置 **RV-A**）
- **来源与版本摘要**：
  - `playback_prd.md`（REQ-PLAY 行）、`navigation_prd.md` REQ-NAV-02；`playback_vibe_spec.md`（随机/队列行为）
  - `DETAILED-DESIGN-iA-Music.md` §2.1 EnginePort（双态）/§3.6/§4.3；`ARCHITECTURE-iA-Music.md` §3.2/§5
  - 选型裁决：mpv_audio_kit 0.5.1 先 PoC（DEC-008 ③）；PoC 证据位=EXP-003（RV-A，待开发者真机）
- **规则绑定**：`cross_platform.md`（通知/SMTC/MPRIS 差异）；`quality_gates.md`（≤300ms/后台连续）；`testing.md`（IMPL-04 严格化=DEC-010 全真）
- **禁则**：GPL 引擎混入；无限重试；EQ 假支持（不支持必须明示路径）
- **环境前提**：Android 真机+adb（RV-A 窗口）；短音频 fixture
- **全真边界（DEC-010）**：引擎=真 mpv 流；验证落在真实设备/桌面（缺真机时 RV-A 保持阻塞，不降级替身）
