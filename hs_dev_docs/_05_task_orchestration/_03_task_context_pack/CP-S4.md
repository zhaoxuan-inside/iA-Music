# Context Pack：CP-S4 播放页与歌单（阶段 4 / TASK-04）

- **绑定切片**：S4（详单 `TASK-S4.md`）
- **来源与版本摘要**：
  - `playback_prd.md` / `playlists_prd.md`（REQ 行 + Scenario）；`playlists_vibe_spec.md`/`playback_vibe_spec.md`
  - `main_prototype.md`（播放页胶片帧/歌单视觉锚）+ `main_prototype.html`
  - `DETAILED-DESIGN-iA-Music.md` §2.1/§3.5 占位注记/§1.2（playlist_tracks 唯一约束）
- **规则绑定**：`frontend_craft.md`/`frontend_arch.md`（UI 分层）；`testing.md`（widget）；DEC-005/006（视觉裁决）
- **禁则**：历史淘汰不得触及 play_history 外表行；EQ 不实时生效须走明示路径；跨域直读他域表
- **环境前提**：S3 完成（引擎事件流）；S1 真库
- **全真边界（DEC-010）**：无外部服务；截图回归桌面端
