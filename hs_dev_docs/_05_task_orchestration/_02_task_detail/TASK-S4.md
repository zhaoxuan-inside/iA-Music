# 任务详单：S4 播放页与歌单（BUILD 阶段 4 / TASK-02）

## 归属与映射
- REQ：**REQ-PLAY-01,03,06,07 + REQ-PL-01..06 + REQ-NAV-01**（唯一归属；EQ 的「明示不支持」平滑承接 S3 预留路径）
- Gherkin 锚（playback_prd/playlists_prd/navigation_prd）：`REQ-PLAY-01 点击播放进入沉浸页 (Happy Path)`；`REQ-PLAY-04 垃圾桶行为 (Dislike)`；`REQ-PL-01 红心仪式感与一致性 (Happy Path)`；`REQ-PL-03 重复添加拦截 (Validation)`；`REQ-PL-05 历史容量淘汰 (Boundary)`
- 架构场景：ARCHITECTURE §3.2

## 目标
沉浸播放页（胶片帧+模糊底+三键+进度）+ 模式切换/队列插队/EQ 面板 + 红心/历史/歌单 CRUD + 三 Tab 骨架与迷你条常驻。

## 边界
- 封面素材由 S5 链供给（本片只渲染，不决策来源）
- 歌词页不在本片（S7）；随机入口大卡/轮盘行为已归 S3

## 输入
DETAILED-DESIGN §3.5（封面素材占位来源：CoverChain 由 S5）；§2.1 EnginePort 全量；wireframe（`main_prototype.md` 播放页/歌单区）

## 输出
播放页 UI 全态（含加载/空/出错）+ 队列页 + 音效页（EQ）+ 歌单资料页 + 我的页红心入口 + Tab 导航骨架 + 迷你条

## DoD
1. 播放页呈现断言：胶片帧封面+标题/歌手/专辑+进度（REQ-PLAY-01 行），封面缺失→色块（S5 前以色块为终态占位）
2. 模式随机不重复直到一轮播完（REQ-PLAY-03）；插队「下一首播放」立即生效（REQ-PLAY-06）
3. EQ：拖动实时生效或明示不支持两分支都有实现（真机结论回填）
4. 红心：图标即时变红 + 「我喜欢的音乐」计数同步（REQ-PL-01）；重复添加拦截提示（DB UNIQUE 具体 §1.2）
5. 历史 500 淘汰：植入 501 条 fixture→最旧被删（分批 100/批事务断言）
6. 跨 Tab 迷你条状态一致（NAV-01）

## 测试 seam
widget 测试 + 真 drift 库；截图回归桌面端；性能观察项（1 万行列表）在 S9 复归。

## 规则与禁则
- 历史淘汰=[只删 play_history 表行]（唯一合法物理删除）
- 禁：播放页直接读其他域表（经唯一写者/DAO 门面）
