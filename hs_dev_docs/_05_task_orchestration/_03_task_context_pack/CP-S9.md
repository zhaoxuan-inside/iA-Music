# Context Pack：CP-S9 壳层整合（阶段 4 / TASK-04）

- **绑定切片**：S9（详单 `TASK-S9.md`）
- **来源与版本摘要**：
  - `navigation_prd.md`（REQ-NAV-03,04,05,06）、`onboarding_prd.md`（ONB-01,04,07,08）
  - `navigation_vibe_spec.md`/`onboarding_vibe_spec.md`；`main_prototype.md`+`main_prototype.html`（全区块/三态）
  - `DETAILED-DESIGN-iA-Music.md` §2.3（平台桥）；DEC-005（主题语言三选）/DEC-006（UI 微调）
- **规则绑定**：`frontend_craft.md`/`frontend_aesthetic.md`（视觉一致性）；`testing.md`（性能断言记录机器差异）；`intent_routing_and_gates.md`（导航入口路由）
- **禁则**：设置页冒出新功能域；性能造假（300ms 必须实测记录）；开机自启/常驻类越界
- **环境前提**：S2–S8 主体行为就位；1 万行合成库 fixture
- **全真边界（DEC-010）**：无外部服务
