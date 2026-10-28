# IMPL-S1：数据契约底座执行证据（S1 / 第一批：schema+FTS+回退门）

> **状态：ACCEPTED**（开发者会话签收原话「S1 验收通过」，2026-10-17T15:41:15Z，全档=PHASE-5 §8 切片验收记录）

- **日期**：2026-10-17；环境：EXP-003（Flutter 3.47.6 / Dart 3.13.5）；验证=**DEC-010 全真**（drift 内存库=真 SQLite 3.50.x 引擎，无替身）
- **切片**：S1（TASK-S1 + CP-S1）；上游：DETAILED-DESIGN §1（14 表字段级）+ DEC-009（D9-1..3）

## 1. 依赖落位（TECH-SELECTION §5 / ADR-0001 精确锁版）

- `drift 2.35.2` + 磁盘 `drift_dev ^2.35.1`（pubspec.lock 为版本事实；镜像 ceil 注记）+ `pinyin 3.3.0` + `flutter_secure_storage 11.2.0` + `sqlite3 3.7.1` + `path_provider`
- `drift_flutter 0.3.1`：随 ADR 锁版引入；当前回退门实现走 `NativeDatabase` 手动装配，S2 接壳层时统一评估保留面（登记）
- 77 包解析成功（pub.flutter-io.cn 镜像）

## 2. sqlite3 原生库处置（本轮关键排障，EXP 档案）

| 尝试 | 结果 |
|---|---|
| 官链 GitHub releases DLL | ❌ 直连超时（信号超时） |
| ghfast.top / gh-proxy.com / gh.llkk.cc | ❌ 全部 http=000（15s 总阻塞） |
| sqlite.org amalgamation 下载 | ⚠️ 页面 2.2s可达；8.5MB 包 9KB/s 拖尾（292s 仅 2.7MB，异步续传可复用） |
| **本机 Python 自带 sqlite3.dll** | ✅ **SQLite 3.50.4，FTS5 实测可用**——采纳 |

- 厂内化路径：`app/source/sqlite3/sqlite3.dll`（源自 `D:\HardStone.开发环境\Python\DLLs\sqlite3.dll`，**SHA256=b008b2f99e9a70556386e1884e94b0b13ffe4f355e019705c3885cb1a9ce9fb2**，SQLite 公共域授权，合法）
- 配置：pubspec `hooks.user_defines.sqlite3 { source: system; name.windows: "file:///…/app/source/sqlite3/sqlite3.dll" }`（需 file:// URI——code_assets 的 DynamicLoadingSystem 仅接受 URI 语法，绝对盘符路径抛 format 异常，推证=code_assets 2.1.0 _uri setter）
- **风险登记（必须回改）**：绝对路径绑开发者机；分发包前须切回 `url_pattern` 镜像或 `source: source` 本机 amalgamation 编译——进 PLAN-BUILD-5 风险表

## 3. Schema v1（17 表类 + 约束级 DDL）

- 表类：`lib/data/tables.dart`（RepositoryRoots/Artists/Albums/Tracks/Playlists/PlaylistTracks/PlayHistory/FewWatchList/LyricsMeta/LyricsGenJobs/ExtractTasks/SyncChannel/LastSyncState/Tombstones/ConflictCopies/Settings/ModelRegistry）
- 软删列 `deleted_at` 覆盖全部主业务表；同步表带 `updated_at`+`device_id`（sync_channel/tombstones/localDevice 语义 S6 落）
- 枚举=名字字符串存储（§1.2 值唯一事实源）；`TaskQuality` 因 `64k` 非法标识符走显式映射转换器
- 约束级 DDL（注解无法表达）：track_index 锚定表（**含 pinyin 两列**）+ FTS5 外部内容表 + `uq_playlist_single_favorite` 部分唯一 + `uq_sync_channel_single_active` 部分唯一 + `idx_history_played` DESC 表达式索引
- DEC-009 D9-1 实现注记：FTS 外部内容模式要求锚定表存在与 FTS 声明同名列——`track_index` 含 `pinyin_full/pinyin_initials`（全行投影回查必需；COUNT(*) 实证失败复盘）

## 4. 运行证据

| 命令 | 结果 |
|---|---|
| `dart run build_runner build -d` | ✓ 9 输出（ia_database.g.dart 等）；39s 首跑 / 7s 增量 |
| `flutter analyze` | **0 issue**（4 处 info 全清：字符串插值/废弃 dispose/_m 命名） |
| `flutter test`（全量） | **All tests passed!（+10）** |

### S1 测试明细（行为断言）

1. 17 表 + track_index 全建 ✓
2. FTS 拼音双列同事务写 + **汉字前缀**/全拼短语/首字母三路命中（REQ-NAV-04）✓
3. EQP ①dup 检测走 `idx_track_source`（REQ-EXT-06）✓
4. EQP ②歌单浏览走 `idx_pt_pos`（REQ-PL-04/06）✓
5. EQP ③历史分组走 `idx_history_played` DESC（REQ-PL-05）✓
6. DB 级红规①system_favorite 仅一行（部分唯一拒绝第二行）✓
7. DB 级红规②active 通道恰一行（C44 部分唯一）✓
8. 回退门演练：缺表文件 → `isReadOnlyGate=true` + 引导文案 + **写被拒** ✓
9. 干净文件 → 正常路径 + `PRAGMA user_version=1` ✓
10. （附加）widget 冒烟 ✓

### 回退门实现要点（§1.4）

- `openIaDatabase`：原始 sqlite3 预检（文件已存在时：quick_check+期望表计数）→ 失败直进只读分支；否则正常 drift open，`beforeOpen` 校验（quick_check=ok + 18 表齐备）抛 `SchemaGateException` → 关闭 + `sqlite3.open(readOnly)` + `NativeDatabase.opened`
- **只读门连接跳过 `_validateSchema`**（schema 异常正是门状态；壳层「修复引导」后续负责修复动线）
- 曾现「drift 半开实例持锁导致 Temp 目录不可删」→ 预检改造后消除

## 5. S1 DoD 进度对照（TASK-S1）

**【2026-10-17 后续块收口——S1 全 DoD 达成，候选 PASS 待签】**

- **DAO 门面**：`app/lib/data/daos.dart`——`LibraryDao/HistoryDao/PlaylistDao/SyncDao/ExtractDao/LyricsDao/ShellDao` + 聚合门面 `DataAccess`：
  - 九组查询全部落域方法：①`search`（FTS 五列前缀+软删/缺失过滤，排序保持 MATCH 命中序）②`browse`（title/addedAt/duration 三排序+分页）③`randomPool`（D9-2 SQL 粗筛+内存采样，排除 deleted/missing/few_watch）④`PlaylistDao.browse`（idx_pt_pos 序+tracks 联查）⑤`historyPage`（DESC 分页）⑥`findBySource`（dup 检测，含软删行）⑦`findByRelPath/insertTrackWithIndex/touchTrackOnRescan/markMissing/markPresent/softDeleteTrack`（扫描 diff 原语，FTS 同事务）⑧`SyncDao.pendingTombstones/recordTombstone/markTombstoneRemoteCleared`（idx_tomb_kind_time 序）⑨FTS 更新=`IaDatabase.updateTrackIndex` 单点（同事务）。
  - 行为写路径：`createOrGet`（REQ-EXT-06 dup=复用行）、`addTrack`（REQ-PL-03 DB 拦截→false）、`ensureFavorite`（REQ-PL-01 部分唯一兜底）、`reorder/removeTrack/softDelete*`、D9-3 `pruneToCap`（100/批事务，行为测 530→500 外加最旧 30 条断言）、ASR `schedule/claimNext/finish` 串行队列（同曲唯一行=UNIQUE(track_id)；重派=终态重置）。
- **SecureStore 三端 adapter**：`app/lib/adapters/secure_store_adapter.dart`（flutter_secure_storage 直桥，implements `contracts` 的 SecureStorePort）。S1 交付=代码级契约一致；**按 DEC-010 不做替身**，运行时验证移交 S2 开机集成 + S3/S8 凭据真实链路（文档注记，非隐瞒）。
- **六问走查**：`IMPL-S1-six-question-walkthrough.md`——18 实体表 127 列 + tracks_fts 5 列 = **132 列六问全答、歧义 0**；含跨表行为移交清单（S2 root 移除/S6 墓碑补写三类）。
- **走查修正＝ISS-503**：conflict_copies 按REQ-SYNC-04「删除=软删本行」补 `deleted_at` 列（spec 字段清单同步补遗；codegen 重跑 15 outputs；测试复跑无破坏）。
- **FTS 外部内容表 delete 全列纪律（本轮实证教训，红线级实现要点）**：`'delete'` 命令只喂 part 列（旧实现 3/5 列）→ **静默索引损坏**（后续 MATCH 零命中且无异常；单行用例不触发 delete 路径故首轮 schema 测试通过）。探针实证 match 语法/五行/参数绑定皆无问题后定位；修正=`updateTrackIndex` 全列 delete（含 pinyin 双列）+ DAO 双行用例守门。此纪律已写入六问走查表审计结论与代码注释。
- **最终状态**：`flutter analyze` **0 issue**；`flutter test test/data/s1_dao_test.dart test/data/s1_schema_test.dart` **27/27 All tests passed**。

**S1 DoD 四项对照（全达成）**：
1. 九组查询单测逐一可执行 ✓（DAO 18 条；EQP 抽查 3 条=earlier §测试明细 3–5）
2. 迁移回退门演练 ✓（earlier §测试明细 8–9）
3. 六问走查 0 歧义 ✓（IMPL-S1-six-question-walkthrough.md；ISS-503 已修正）
4. 红线核对 ✓（物理删仅 D9-3 淘汰/playlist_tracks 业务动作/few_watch 清空三处+墓碑配套归属；凭据本体零入库；无 DRM 接触面）



1. 9 组查询 EQP 抽查 3 条 ✓（①②③）；**DAO 门面+其余 6 组单测**=本片后续块
2. 回退门演练 ✓（只读连接+引导文案+写被拒）
3. 六问走查：表类 doc comment 已带关键断言；**走查表文档**=本片后续块
4. 红线核对：无硬删业务记录路径 ✓（仅 play_history 500 淘汰+缓存列入计划）；凭据本体不入 DB ✓（credentials_ref 仅存 key；C50 注释在表）
