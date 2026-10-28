# 任务详单：S3 播放引擎竖切（BUILD 阶段 4 / TASK-02）

## 归属与映射
- REQ：**REQ-PLAY-02,04,05,08 + REQ-NAV-02**（唯一归属见 TASK-BREAKDOWN §2）
- Gherkin 锚（playback_prd/navigation_prd）：`REQ-PLAY-04 垃圾桶行为 (Dislike)`；`REQ-PLAY-08 缺失文件跳过并提示 (Error Recovery)`；`REQ-NAV-02 随机一触即听 (Happy Path)`
- 架构场景：ARCHITECTURE §3.2（随机后台）

## 目标
EnginePort 首适配（mpv_audio_kit）竖切：加载/控制/进度/自动连播/随机池开播/垃圾桶少播/后台+通知+媒体键/缺失自动跳过。

## 边界
- 播放页视觉（胶片帧/模式切换 UI）不在本片（S4）
- **RV-A 前置**：mpv_audio_kit 真机三项（后台/媒体键/长稳）先于本片 UI 侧开工；失败→PairedEngineAdapter 回退线（ISS-201/302 契约双态）

## 输入
DETAILED-DESIGN §2.1 EnginePort（双态）；§3.6 restore；§4.3 重试/资源释放表（引擎 PoC 证据位=EXP-003，RV-A）

## 输出
MpvEngineAdapter（或回退）+ 随机池取样（D9-2）+ 少播互斥 + Android 前台服务通知 + 桌面 SMTC/MPRIS 桥

## DoD
1. 随机池：deleted/missing 双 NULL + NOT IN few_watch（§1.3 对应查询）+ 内存采样断言（500 级 fixture）
2. 短样本连播：itemEnded→自动下一首；垃圾桶→当前曲跳下一首+名单落库+设置可清空
3. 后台/锁屏/媒体键：Android 真机 + 桌面真平台各 1 条演练证据
4. 缺失自动跳过+顶部提示（REQ-PLAY-08 原话断言）
5. 恢复：kill 进程→restore 队列+进度；二次失败→「播放服务异常」UI
6. Gherkin 锚 3 条场景可跑

## 测试 seam
真实 mpv 流（真实短音频样本）；通知/会话桥真平台验证；**全真（DEC-010）**——无替身；缺真机时 RV-A 保持阻塞待窗口

## 规则与禁则
- 后台连续播放不中断（质量场景 ARCH §5）；恢复重试=1 次（禁无限）
- 等化器在本片先接「明示不支持」路径（真机 EQ 结论 RV-A 回填后收敛 REQ-PLAY-07 归属 S4）
