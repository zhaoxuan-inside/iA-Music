# D1 / 检查点 A：S0–S5 真实纵向闭环证据

- 日期：2026-10-19（Asia/Shanghai）。
- 依据：TASK-BREAKDOWN §3/§7，BUILD-5 T8；S0–S4 已签收，S5 当前提交候选结果。
- 范围：真实扫描 → 随机播放 → 封面来源 → 红心/自建歌单 → 歌单按序装载；不推进 S6，不代签检查点 A。
- **演练结果：技术断言 PASS；开发者验收 ACCEPTED（签收原话「签收。」，2026-10-19T01:19:37Z，与 S5 切片合并生效）。**

## 环境与命令

- Windows / Flutter 3.47.6；真实 ffmpeg 编码音频、真实 SQLite 3.50.4 / drift、真实 mpv_audio_kit 0.5.1。
- `cd app; flutter test test/integration/d1_library_playback_playlist_test.dart --reporter expanded`。
- 退出码 0，**1/1 PASS**，3s；原始记录 `output/qa/D1-checkpoint-A-test.log`。
- 源码锚：`app/test/integration/d1_library_playback_playlist_test.dart` 的 D1 测试。没有 Fake、Mock 或回放数据源。

## 实际流程与断言

1. 复制 S2 的 12 个真实音频文件（含一个损坏件、一个零字节件）到新临时仓库；其中一首替换为真实 APIC 内嵌封面 MP3，保存 SHA-256。
2. `LibraryHub.addRepositoryAndScan` 扫描入真实库：入库 **10**、跳过 **2**；页面数据门面取到 10 个真实 Track；扫描 contentHash 与文件 SHA-256 一致。
3. 同一个 LibraryHub 的 CoverChain 决策到 `embedded`，确认 S5 注册路径可与真实扫描结果协作，不为已有封面联网。
4. 创建真实 MpvEngineAdapter / PlaybackService；监听并等待真 `EngineStateChanged(playing)`；随机池大小 **5**，队列 ID **5 个互异**，模式为 random，然后暂停保留本次选曲。
5. 对当前曲目加红心，真实库计数 **1**；创建「D1 真链演练」歌单，加入当前曲与另一曲，两次成功；重复加入当前曲返回 false。
6. 从真库读歌单，顺序为当前曲、第二曲；把该序列交给 `playTrackIds`，实际引擎装载成功，队列顺序和首曲均正确。
7. 再读音频，SHA-256 与扫描前一致；关闭真引擎、Watcher、DB，清理本次临时仓库。

## 与 S5 及阶段验收的关系

- S5 来源链、在线 CAA 与 iTunes、无匹配、断网/恢复、界面即时换图等专项，见 `IMPL-S5-cover-chain-evidence.md` §8 及 `app/test/cover/`。
- D1 验证既有模块之间的真实协作，不能替代 RV-A/B/C、三端完整打包或未来 S6–S10 的 DoD。
- 候选范围：S5 封面链 + 检查点 A / D1；S0–S4 复用已有有效签收，不重复索取。
- 开发者确认：**ACCEPTED**——「签收。」（2026-10-19T01:19:37Z，与 S5 合并）；下一步 S6 提取管线（T9）待 RV-B 真实验证条件/窗口确认后启动。
