# 任务详单：S5 封面链（BUILD 阶段 4 / TASK-02）

## 归属与映射
- REQ：**REQ-LIB-04,08**（唯一归属见 TASK-BREAKDOWN §2）
- Gherkin 锚（library_prd）：`REQ-LIB-08 无封面自动抓取并本地保存 (Cover Fetch)`；来源链断言=REQ-LIB-04 prd 表行
- 架构场景：ARCHITECTURE §3.5

## 目标
CoverChain.decide 四级来源链决策器 + CoverFetchPort（CAA 主源 1req/s 令牌桶 + iTunes 兜底）+ 命中落盘 `.cover.jpg` 注册位。

## 边界
- 只补缺：已有内嵌/同目录图**永不**发起联网与覆盖（C22 红线）
- 失败/离线静默降级色块（不报错弹窗）

## 输入
DETAILED-DESIGN §3.5（六联）；§2.1 CoverFetchPort；§5.2 语义

## 输出
CoverChain 模块 + CoverFetchAdapter（CAA/iTunes）+ 封面注册位（§1.2 状态列）+ 列表/播放页接入点

## DoD
1. 顺序断言：内嵌>同目录>联网>色块 四层 fixture 各一条→决策结果逐一正确
2. 已有封面曲目：**0 网络请求**（真实网络层观测计数=0）
3. 无封面+联网命中→同目录生成 .cover.jpg + UI 即时替换（REQ-LIB-08 原话）
4. 限流：连续请求间隔 ≥1s（令牌桶单测）
5. 无结果→色块不报错；离线→色块不报错
6. Gherkin 锚场景可跑

## 测试 seam
全部真源：CAA/iTunes 实呼（真实知名曲目/真实不存在曲名/真实断网态）；本地磁盘/真库为真（DEC-010 无替身）。

## 规则与禁则
- C22 封面只补缺不覆盖；UA 强制与 1req/s 在 adapter 内部兜着（调用方无感）
- 禁：封面命中即触碰曲目元数据（原文件本就不改，S2 已有红线；此处=不写回 tracks 除注册位外）
