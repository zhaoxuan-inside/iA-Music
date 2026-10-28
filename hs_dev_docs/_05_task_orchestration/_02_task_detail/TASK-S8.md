# 任务详单：S8 同步（BUILD 阶段 4 / TASK-02）

## 归属与映射
- REQ：**REQ-SYNC-01..08 + REQ-ONB-06**（唯一归属）
- Gherkin 锚（sync_prd）：`REQ-SYNC-02/03 跨端完整闭环 (Happy Path)`；`REQ-SYNC-05 墓碑删除不毁云端资产 (Guardrail)`；`REQ-SYNC-06 断网恢复 (Error Recovery)`
- 架构场景：ARCHITECTURE §3.4（同步冲突/墓碑）+ §4.1 状态机逐态（vibe 对齐）

## 目标
通道配置+连接测试 / 轻数据 30s / 音频本体（文件型）/ 冲突副本 / 墓碑传播 / 断网恢复 / 手动摘要 / GitHub 轻数据限制 / 新设备从同步恢复。

## 边界
- **MVP 完整实现=WebDAV**（ADR-0001）；GitHub=轻数据型实现（REQ-SYNC-08）；OneDrive/GDrive 为通道池注册但延后接入（UI 不展示未激活通道——避免半成品入口）
- 通道单活跃（部分唯一索引 §1.2）

## 输入
DETAILED-DESIGN §3.3（SyncEngine 六联）；§4.1 七态状态机；§2.1 SyncChannelPort（无 delete 语义）；C 红线全集

## 输出
SyncEngine（状态机+事件喂点）+ WebDav/GitHub adapter（分块上传自研 C36）+ 同步设置页 + 冲突查看页 + 「从同步恢复」FTUE 捷径

## DoD
1. 通道测试：错误凭据/错误地址→具体人话 reason，通过才可保存（SYNC-01）
2. 轻数据闭环：A 改红心→30s 内远端出现→B 拉取一致（SYNC-02；双实例联测）
3. 音频：新歌上传→另一实例下载可直接播放（SYNC-03；分块断点中断恢复演练）
4. 冲突：两实例先后改同一曲→新者胜+副本可查看（SYNC-04；落 conflict_copies）
5. **墓碑**：A 移除《晚风》→B 记录消失+云端 .flac 保留（SYNC-05 红线级断言；SyncChannelPort 无 delete 的代码级检查）
6. 断网→PAUSED 明示原因→恢复续传，本地无损（SYNC-06）
7. 手动同步：进度+摘要 成功N/失败M（SYNC-07）
8. GitHub 通道：轻数据 only，音频开关禁用（UI+逻辑双侧，SYNC-08）
9. 状态机逐态走查：7 态迁移与 vibe 原文一致（§4.1 表）

## 测试 seam
- 本地 WebDAV fixture 服务（真实协议）+ 同机双实例（双数据目录）；GitHub 用测试库真 repo
- **全真边界（DEC-010）**：WebDAV fixture 服务为真实协议实现（非替身）；GitHub=真测试库；同机双实例联测

## 规则与禁则
- 本地数据无损（RED LINE）；删除仅传播记录；远端文件永不因此端删除被删
- 重试=分块级 3 次（§4.3）；凭据经 SecureStorePort（不入 DB/日志）
