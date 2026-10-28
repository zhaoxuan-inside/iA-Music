# 任务详单：S2 曲库扫描与浏览（BUILD 阶段 4 / TASK-02）

## 归属与映射
- REQ：**REQ-LIB-01,02,03,05,06,07 + REQ-ONB-02**（唯一归属见 TASK-BREAKDOWN §2）
- Gherkin 锚（library_prd）：`REQ-LIB-01 添加仓库并完成首次扫描 (Happy Path)`；`REQ-LIB-05 文件缺失的容错与恢复 (Error Recovery)`；`REQ-LIB-07 移除曲目不删物理文件 (Guardrail)`；其余 REQ 行断言=对应 prd 表行
- 架构场景：ARCHITECTURE §3.1（扫描）

## 目标
仓库添加/全量+增量扫描（计数真实红线）/列表排序/元数据编辑（不写原文件）/缺失灰显与恢复/移除不删文件/建议目录一键采用（实时计数）。

## 边界
- 扫描只入库音频文件（.mp3/.flac/.m4a/.ogg/.wav/.ape）
- 封面播放不在本片（S5）；搜索入口装配不在本片（S9）

## 输入
DETAILED-DESIGN §3.1（scan 六联）；§1.2 tracks/roots/字典表；REQ 锚点

## 输出
ScanService（full/incremental）+ library 域 DAO 调用方 + 设置页仓库管理 + 曲库列表 UI（排序/编辑/缺失态/移除菜单）

## DoD
1. fixture 目录 12 音频（1 损坏+1 零字节）→ **计数=10、skipped=2**（§6.2 样例 1 正确版）；错误实现判失败
2. 增量：新增文件 ≤15s 入库（REQ-LIB-02）；mtime 变更→updated_at 刷新
3. 编辑标题→列表/播放页即时更新且 **mtime/文件内容不变**（REQ-LIB-03）
4. 移除=记录消失 + 物理文件保留（红线）；恢复=放回→missing_at 清空
5. Gherkin 锚 3 条场景可跑（widget+真库）

## 测试 seam
真实文件系统 fixture（临时目录）；MetadataPort 真解析；目录监听真事件（Windows/Android 差异记录）

## 规则与禁则
- 扫描真实计数（禁「看起来正常」跳表）；损坏文件跳过计数不中断
- 禁：扫描进程占用 UI isolate（批事务 200/批，§3.1）
