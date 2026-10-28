# ISS-503：conflict_copies 缺 deleted_at 列（spec 字段清单遗漏）

- **登记时间**：2026-10-17
- **登记切片**：IMPL-S1（T3 六问走查=DoD3）
- **状态**：已在 S1 解决（代码+文档同步修正，待开发者签收确认）
- **发现者/裁决**：agent（六问走查逐字段核对）；修正依据均为既有 spec 文义，无产品语义新增

## 现象

DETAILED-DESIGN §1.2 `conflict_copies` 行（原第 51 行）写明
「REQ-SYNC-04 可查看/删除——**删除=软删本行**」，但同行的字段清单没有
`deleted_at` 列；§1.1 惯例「每条主业务记录含 deleted_at」在本表上无法落实。
六问走查口径下属**字段级歧义**（DoD 要求 0 歧义），故在 S1 内修正而非移交 S6。

## 修正

1. `app/lib/data/tables.dart` ConflictCopies 增列 `deletedAt`（nullable，无默认值）。
2. drift codegen 重跑（ia_database.g.dart）。
3. DETAILED-DESIGN §1.2 第 51 行字段清单补 `deleted_at nullable` 并标注 ISS-503 溯源。
4. S1 六问走查表（IMPL-S1-eight-questions 对照文档）按新列作答。

## 影响面

- schema v1 仍成立（同日 S1 未冻结，未签收前修正成本最低；未新增表/索引）。
- S6 同步切片：冲突副本「删除」动线直接用本列软删 + 墓碑（ TombstoneKind 不需扩展——
  conflict_copies 不参与云端同步，软删记录仅本端保留）。
- 现有 S1 测试无破坏（tests 27/27 复跑通过；EQP 与红规断言不变）。

## 备注

`repository_roots` 无 deleted_at 属 **spec 本义**（扫描根非同步业务记录，移除目录
的行为=其下曲软删+墓碑，由 S2 扫描域在设计时决定）——不构成字段歧义，已在
六问走查表「行为移交清单」显式移交。
