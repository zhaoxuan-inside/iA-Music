# 任务详单：S1 数据契约底座（BUILD 阶段 4 / TASK-02）

## 归属与映射
- REQ 映射：**数据底座（支撑切片）**——行为断言=「DETAILED-DESIGN §1.3 九组查询全部可执行」
- 上游：DETAILED-DESIGN §1（14 表字段级）；§2.1 SecureStorePort；DEC-009（D9-1..3）

## 目标
drift schema v1 全表 + DAO 门面 + SecureStorePort 三端 adapter + 迁移回退门。

## 边界
- 只做 schema/DAO/存储；不做任何 UI 调用方（S2 起才有首个调用方）
- 物理删除仅限 play_history 500 淘汰与临时缓存；其余一律软删列

## 输入
§1.2 全表字段清单；§1.3 索引↔查询对应表；§1.4 迁移与回退门

## 输出
- drift 表 + 索引 + FTS5（`track_index` 拼音双列，写与 tracks 同事务）
- DAO（按 9 组查询签名）；SecureStore adapter（Keystore/DPAPI/libsecret）
- schema 编译产物 + 内存库单测

## DoD
1. 9 组查询单测逐一可执行且符合 §1.3 走的索引（EXPLAIN QUERY PLAN 抽查 3 条）
2. 迁移回退门演练：schema 校验失败观察→只读连接+壳层引导文案（不闪退）
3. 六问走查：每表字段答「含义/类型/空值/默认/唯一/谁写」=0 歧义
4. 红线核对：无「硬删业务记录」路径；凭据本体不入 DB（credentials_ref 仅存 key）

## 测试 seam
真实 SQLite 引擎（drift 内存库=真 sqlite3，非替身；DEC-010）；SecureStore 用真实三端实现（无外部网络），Android 侧在 RV 真机窗口补验

## 规则与禁则
- FTS 写与业务事务同批（D9-1）；拼音列由 pinyin 包生成（版本锁定）
- 禁：迁移成功路径外 openReadWrite 写一半 schema（回退门语义）
