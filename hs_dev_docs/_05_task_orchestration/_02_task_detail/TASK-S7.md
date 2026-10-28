# 任务详单：S7 歌词与 ASR（BUILD 阶段 4 / TASK-02）

## 归属与映射
- REQ：**REQ-LYR-01..05 + REQ-LYRAI-01..06 + REQ-ONB-05**（唯一归属）
- Gherkin 锚：`REQ-LYR-01/.02 歌词展示与跳转 (Happy Path)`；`REQ-LYR-03 偏移同步微调 (Adjustment)`；`REQ-LYR-05 无歌词时的出路 (Empty State)`；`REQ-LYRAI-01/02/04 首次生成闭环 (Happy Path)`；`REQ-LYRAI-05 纯音乐处理 (Validation)`；`REQ-LYRAI-06 离线可用 (Constraint)`；`REQ-ONB-05 歌词模型的下载与清理 (Settings)`
- 架构场景：ARCHITECTURE §3.5（歌词 ASR 取消）/§3.6（模型生命周期）

## 目标
.lrc 三路径（解析/粘贴/ASR）+ 偏移保存 + ASR：模型下载/校验/队列串行/分块取消/预览编辑/纯音乐提示/离线。

## 边界
- ASR 目标模型：SenseVoiceSmall int8（ADR-0001）；**RV-C** arm64 RTF 实测先于生成侧开工；失败→手动粘贴路径保底（REQ-LYR-04）+ 模型换档裁决
- 逐行高亮随播属本片（REQ-LYR-01）；纯视觉打磨不阻塞 DoD

## 输入
DETAILED-DESIGN §3.4（六联）；§2.1 AsrPort；§5.2 语义；EXP-002（模型下载/中文样本链路）

## 输出
歌词解析/渲染域 + LyricsGenQueue + AsrAdapter（isolate+分块）+ 模型管理设置页 + 预览编辑器 + `lyrics_gen_jobs` 状态机 UI

## DoD
1. .lrc 展示逐行高亮随播推进；点击第 N 行→播放进度跳该行（LYR-01/02）
2. 偏移 +0.5s 保存→同目录 .lrc 更新（LYR-03）
3. 模型生命周期：未就绪→引导下载；下载完成 sha256 校验通过才 present；可删除（模型下载=设置页 ONB-05）
4. 批量 5 首：队列串行+进度条+可暂停/取消（LYRAI-03；多任务取消=块边界 §2.1）
5. 预览编辑错别字→保存 .lrc→歌词页立即可用（LYRAI-04）；未 commit 不落 lyrics_meta（不变量）
6. 纯音乐：segments 空→「未检测到人声」不生成空文件（LYRAI-05 红线）
7. 断网（模型已下后）→全流程离线可用（LYRAI-06）
8. Gherkin 锚 7 条场景可跑

## 测试 seam
真实音频样本（含纯音乐）；ASR 真 engine+真模型（EXP-002 链路）；下载 hf-mirror 真源；**全真（DEC-010）**——无替身

## 规则与禁则
- 取消响应=块边界（C38）；临时 wav 终态清理（资源释放 §4.3）
- 禁：UI isolate 内跑转写（isolate 硬性）
