# Context Pack：CP-S7 歌词与 ASR（阶段 4 / TASK-04）

- **绑定切片**：S7（详单 `TASK-S7.md`；前置 **RV-C**）
- **来源与版本摘要**：
  - `lyrics_display_prd.md`（REQ-LYR-01..05 + Scenario）；`lyrics_ai_prd.md`（LYRAI-01..06）；`onboarding_prd.md` REQ-ONB-05
  - `lyrics_display_vibe_spec.md`/`lyrics_ai_vibe_spec.md`；`DETAILED-DESIGN-iA-Music.md` §3.4/§2.1 AsrPort/§4.3
  - `EXP-002-R3-desktop-preview.md`（hf-mirror 239MB≈2min / SAPI 中文样本）；sherpa_onnx + SenseVoiceSmall int8（ADR-0001）
- **规则绑定**：`testing.md`；`quality_gates.md`（RTF 观察项）；`deep_modules.md`（队列收口）
- **禁则**：UI isolate 内转写；未 commit 写 lyrics_meta；纯音乐生成空文件；R3 模型版本浮动（锁定 int8）
- **环境前提**：模型文件（EXP-002 链路）；arm64 真机（RV-C）；纯音乐 fixture
- **全真边界（DEC-010）**：无替身（模型 CDN=真源小样本；本地全真）
