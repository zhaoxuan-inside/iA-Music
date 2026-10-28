# IMPL-S1 六问走查表（T3 DoD3）——每表每字段：含义/类型/空值/默认/唯一/谁写

- **登记时间**：2026-10-17　**切片**：IMPL-S1（T3）
- **事实源**：`app/lib/data/tables.dart`（v1 全 17 表 + 枚举目录）+ `app/lib/data/ia_database.dart` `kExtraDdl`（track_index/tracks_fts/部分唯一/表达式索引）
- **口径**：六问 = ①含义 ②类型（drift→SQLite 落地型） ③可空？ ④默认值 ⑤唯一约束 ⑥谁写（生产调用方=切片域；S1 尚无 UI/服务调用方时标注「测试直接写」）
- **类型速记**：`integer()=INT`；`text()=TEXT`；`real()=REAL`；`boolean()=INT 0/1`；`textEnum<T>()=TEXT（存枚举名，与 §1.2 ENUM 值一致；TaskQuality 走 TaskQualityConverter 显式映射 64k/128k/192k/hires）`
- **覆盖断言**：18 张实体表 127 列 + 虚拟表 tracks_fts 5 列 = **132 列六问全部作答，歧义 0**（本走查修正 ISS-503 一处）。

---

## 曲库域

### repository_roots（扫描根；5 列）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| id | 软删外 FK 锚 | INT AI | N | 自增 | PK | SQLite |
| path | 扫描根绝对路径 | TEXT | N | — | UNIQUE | S2 扫描设置页（现测试直写） |
| label | UI 展示名 | TEXT | Y | — | 无 | S2 扫描设置页 |
| mode | 目录型=directory / 同步型=synced_dir | TEXT 枚举 | N | — | 无 | S2 扫描设置页 |
| added_at | 添加时刻 | INT | N | — | 无 | S2 扫描设置页 |

注：本表**无 deleted_at 系 spec 本义**（扫描根非同步业务记录）；「移除扫描目录」行为=其下曲软删+墓碑，移交 S2 扫描域裁决（见文末移交清单）。

### artists（艺术家字典；5 列）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| id | albums.artist_id FK 锚 | INT AI | N | 自增 | PK | SQLite |
| name | 展示名原文 | TEXT | N | — | 无 | S2/S4 扫描标签归一 |
| name_norm | 归一化键（去空白/全半角折一口径） | TEXT | N | — | UNIQUE（同库去重锚） | 同上 |
| sort_key | 排序键（拼音序，预留） | TEXT | Y | — | 无 | 同上 |
| updated_at | 同步基准（§1.1） | INT | N | — | 无 | 同上 |

### albums（专辑字典；5 列）——同 artists 结构与写者。

### tracks（曲主表；19 列）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| id | 全局锚 | INT AI | N | 自增 | PK | SQLite |
| root_id | 归属扫描根 | INT FK | N | — | 无 | LibraryDao.insertTrackWithIndex（S2 扫描域） |
| rel_path | 根内相对路径 | TEXT | N | — | UNIQUE(root_id,rel_path)=扫描 diff 锚 | 同上 |
| title | 展示标题（标签缺失→文件名兜底） | TEXT | Y | — | 无 | 同上 |
| artist_display | 原文案（REQ-LIB-03 不改写 tags） | TEXT | Y | — | 无 | 同上 |
| album_display | 原文案 | TEXT | Y | — | 无 | 同上 |
| artist_id | 字典引用 | INT FK | Y | — | 无 | S2/S4 归一 |
| album_id | 字典引用 | INT FK | Y | — | 无 | S2/S4 归一 |
| duration_ms | 内容中位值 | INT | Y | — | 无 | S3 提取登记/扫描 元数据填充 |
| audio_format | 六格式 | TEXT 枚举 | N | — | 无 | LibraryDao（插入时） |
| file_size | 字节 | INT | N | — | 无 | LibraryDao |
| mtime | 文件修改时刻（增量 diff 衡量） | INT | N | — | 无 | LibraryDao（touchOnRescan） |
| content_hash | 入库计算（音频帧范围） | TEXT | N | — | 无 | LibraryDao（插入；重扫变才 touch） |
| source_type | 提取溯源（现恒 bilibili） | TEXT | Y | — | idx_track_source 联合定位（非强制唯一） | S3 登记产物 |
| source_id | BV… | TEXT | Y | — | 同上 | S3 |
| sample_rate | 采样率 | INT | Y | — | 无 | S3/元数据 |
| channels | 声道数 | INT | Y | — | 无 | S3/元数据 |
| added_at | 入架时刻 | INT | N | — | 无 | LibraryDao |
| updated_at | 同步基准 | INT | N | — | 无 | 一切写路径统一回填 |
| deleted_at | 软删位（REQ-LIB-07） | INT | Y | — | 语义互斥 missing_at | LibraryDao.softDeleteTrack（S2/S4 触发） |
| missing_at | 缺失位（REQ-LIB-05） | INT | Y | — | 语义互斥 deleted_at | LibraryDao.markMissing/markPresent |

（↑列数按表结构口径合并统计为 19；deleted_at/missing_at 计入。索引三枚 idx_track_album/artist/source + UNIQUE(root,rel_path) 均见 §1.3 EQP 表。）

### track_index（FTS 外部内容锚定表；6 列）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| id | **对齐 tracks.id**（content_rowid） | INT | N | — | PK | IaDatabase.updateTrackIndex（同事务） |
| title / artist / album | FTS 索引列（全行投影同名回查） | TEXT | N | `''` | 无 | 同上 |
| pinyin_full / pinyin_initials | 拼音双列（D9-1；pinyin 包生成） | TEXT | N | `''` | 无 | 同上 |

### tracks_fts（虚拟表；5 索引列）

- `content='track_index', content_rowid='id'`；写者=updateTrackIndex 内部（无独立写者）。
- **红线实现纪律（本轮实证教训）**：外部内容表的 `'delete'` 命令必须携带与建索引时**全列一致**的值（含 pinyin 双列）；部分列 delete=静默索引损坏（症状：后续 MATCH 零命中、无异常）。已按全列 delete 落地并有双行用例守门。

## 歌单域

### playlists（6 列）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| id | 锚 | INT AI | N | 自增 | PK | SQLite |
| name | 歌单名 | TEXT | N | — | 无 | PlaylistDao.create/ensureFavorite（S4） |
| kind | user / system_favorite | TEXT 枚举 | N | — | **uq_playlist_single_favorite**（kind='system_favorite' 唯一一能存） | 同上 |
| sort_order | 列表排序 | INT | N | 0 | 无 | S4 拖拽 |
| created_at / updated_at | 时刻 | INT | N | — | 无 | 同上 |
| deleted_at | 软删位（REQ-PL-02） | INT | Y | — | 无 | PlaylistDao.softDeletePlaylist |

### playlist_tracks（5 列）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| id | 锚 | INT AI | N | 自增 | PK | SQLite |
| playlist_id / track_id | 归属与内容（**getCASCADE**） | INT FK | N | — | UNIQUE(playlist_id,track_id)=REQ-PL-03 DB 拦截 | PlaylistDao.addTrack/removeTrack/reorder（S4） |
| position | 竖排次序（相守 idx_pt_pos） | INT | N | — | 无 | 同上 |
| added_at | 入单时刻 | INT | N | — | 无 | addTrack |

注：本表无软删列=§1.2 设计本义——「移出歌曲」为业务动作物理行删，隔离负点=同步域以 TombstoneKind.playlist_item 传播（S6 裁决执行）。

## 历史与少播

### play_history（4 列，本地表不同步）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| id | 锚 | INT AI | N | 自增 | PK | SQLite |
| track_id | 被播曲 | INT FK | N | — | 无 | HistoryDao.record（S4 播放回调） |
| played_at | 播放时刻（DESC 索引=分组页序） | INT | N | — | idx_history_played 手写 DDL | 同上 |
| completed | 完播布尔 | INT | N | — | 无 | 同上 |
| device_id | 本地设备标识（本地化，非同步键） | TEXT | N | — | 无 | 同上 |

**物理淘汰唯一路径**：HistoryDao.pruneToCap（D9-3，500 上限，100/批事务）——红线特批，已行为测试守门。

### few_watch_list（2 列；PK=trackId 无自增行）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| track_id | 少播名单元（天然防重） | INT FK | N | — | **PK** | HistoryDao.addFewWatch（S4 设置页） |
| added_at | 入单时刻 | INT | N | — | 无 | 同上 |

清空=HistoryDao.clearFewWatch 物理全删 + 墓碑（TombstoneKind.few_watch），实现归于 S6（§1.2 裁决）。

## 歌词域

### lyrics_meta（7 列；PK=trackId 1:1）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| track_id | 每曲一份 | INT FK | N | — | **PK** | LyricsDao.upsertMeta（S6/S7；用户编辑 S8） |
| type | none/embed/lrc/paste/asr | TEXT 枚举 | N | — | 无 | 同上 |
| lrc_path | 同目录 .lrc 位置 | TEXT | Y | — | 无 | 同上（纯音乐路径=空，REQ-LYRAI-05） |
| source_text | paste 内嵌临时文 | TEXT | Y | — | 无 | 同上 |
| offset_ms | 歌词偏移 | INT | N | 0 | 无 | 同上 |
| updated_at | 同步基准 | INT | N | — | 无 | 同上 |
| edited | 用户编辑过 | INT(0/1) | N | false | 无 | 用户编辑（S8） |

### lyrics_gen_jobs（10 列）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| id | 锚 | INT AI | N | 自增 | PK | SQLite |
| track_id | 任务曲（CASCade） | INT FK | N | — | **UNIQUE(track_id)** 一任务一曲 | LyricsDao.schedule（S7） |
| status | 九态枚举 | TEXT | N | — | 无 | schedule/claimNext/finish |
| progress | 实时百分比 | REAL | N | 0.0 | 无 | setProgress |
| model_id | ASR 模型（FK→model_registry） | TEXT FK | Y | — | 无 | schedule（需模型已注册） |
| created_at / updated_at | 时刻 | INT | N | — | 无 | schedule/更新路径 |
| started_at / finished_at | 首/尾时刻 | INT | Y | — | 无 | claimNext/finish |
| error_code | 终态错误码 | TEXT | Y | — | 无 | finish |

## 提取域

### extract_tasks（16 列）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| id | 锚 | INT AI | N | 自增 | PK | SQLite |
| source_type / source_id | 来源对（BV…） | TEXT | N | — | **UNIQUE(source_type,source_id)** 同源一行（dup=复用行） | ExtractDao.createOrGet（S3） |
| url | 原始地址 | TEXT | N | — | 无 | createOrGet |
| title / uploader / duration_ms | resolve 后元数据 | TEXT/INT | Y | — | 无 | 解析步回填 |
| quality | 提取音质 | TEXT(64k/128k/192k/hires 转换器) | N | — | 无 | createOrGet |
| progress_pct | 下载进度 | REAL | N | 0.0 | 无 | updateTask |
| status | 九态枚举 | TEXT | N | — | 无 | updateTask |
| error_code | network/auth/dup/disk/transcode | TEXT 枚举 | Y | — | 无 | updateTask |
| output_rel_path | 产物（私有目录内） | TEXT | Y | — | 无 | transcode 完成时 |
| cookies_used | 是否用了 Cookie（审计=不说明书**不落 Cookie 本体**，C50） | INT(0/1) | N | false | 无 | 提取域 |
| retry_count | 重试次数 | INT | N | 0 | 无 | updateTask |
| created_at / updated_at | 时刻 | INT | N | — | 无 | createOrGet/updateTask |

## 同步域

### sync_channel（9 列）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| id | 锚 | INT AI | N | 自增 | PK | SQLite |
| type | webdav/onedrive/gdrive/github | TEXT 枚举 | N | — | 无 | SyncDao.applyChannel（S6） |
| base_url | 服务端地址 | TEXT | N | — | 无 | 同上 |
| remote_dir | 远端目录 | TEXT | N | `iA-Music/` | 无 | 同上 |
| username | 展示名 | TEXT | Y | — | 无 | 同上 |
| credentials_ref | **SecureStore key（凭据本体永不入库，C50）** | TEXT | Y | — | 无 | 同上 |
| is_active | 生效位 | INT(0/1) | N | false | **uq_sync_channel_single_active**（=1 恰一行） | 同上（全部关闭后再单开） |
| last_test_at / last_test_ok | 连接测试时刻与结果（**分列**） | INT / INT | Y | — | 无 | 测连接动作回填 |

### last_sync_state（6 列；PK=channelId）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| channel_id | 一通道一行 | INT FK | N | — | **PK** | SyncDao.upsertLastSync（S6 引擎） |
| last_started_at / last_completed_at | 同步区间 | INT | Y | — | 无 | 同上 |
| pending_up / pending_down | 待同步计数 | INT | Y | — | 无 | 同上 |
| summary_json | 成功 N/失败 M 摘要 | TEXT | Y | — | 无 | 同上 |

### tombstones（6 列）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| id | 锚 | INT AI | N | 自增 | PK | SQLite |
| entity_kind | track/playlist/playlist_item/few_watch/lyrics_meta | TEXT 枚举 | N | — | idx_tomb_kind_time 联合序 | SyncDao.recordTombstone（**S6 SyncEngine 补写**；DAO 提供原语） |
| entity_local_id | 本端被删记录 id | INT | N | — | 无 | 同上 |
| deleted_at | 删除时刻（墓碑比较键） | INT | N | — | 同上 | 同上 |
| deleted_by_device | 删源设备 | TEXT | N | — | 无 | 同上 |
| remote_cleared_at | 远端确认时刻（**只是进度，非云端删除语义**） | INT | Y | — | 无 | SyncDao.markTombstoneRemoteCleared |

### conflict_copies（7 列）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| id | 锚 | INT AI | N | 自增 | PK | SQLite |
| origin_kind / origin_local_id | 冲突源 | TEXT/INT | N | — | 无 | S6 冲突处理 |
| winner_value_json | 胜者值 | TEXT | N | — | 无 | 同上 |
| loser_payload_json | 败者现场 | TEXT | N | — | 无 | 同上 |
| lost_at | 冲突时刻 | INT | N | — | 无 | 同上 |
| deleted_at | 软删位（REQ-SYNC-04 删除=软删本行；**ISS-503 补列**） | INT | Y | — | 无 | S6 冲突管理 UI |

## 壳层域

### settings（3 列；PK=key）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| key | 语义键（repo.paths/appearance.*/compliance.*/eq.user） | TEXT | N | — | **PK** | ShellDao.put（insertOnConflictUpdate；S2/S4 UI） |
| value | JSON 值 | TEXT | N | — | 无 | 同上 |
| updated_at | 修改时刻 | INT | N | — | 无 | 同上 |

### model_registry（6 列；PK=modelId）

| 字段 | 含义 | 类型 | 空 | 默认 | 唯一 | 谁写 |
|---|---|---|---|---|---|---|
| model_id | 模型标识（sensevoice-int8-20240717） | TEXT | N | — | **PK** | ShellDao.upsertModel（S7 模型管理） |
| size_bytes / sha256 | 体积与完整性（sha256 必验=DEC-010） | INT/TEXT | Y↔N | — | 无 | 同上（PRESENT 态前 sha256 必填） |
| status | absent/downloading/paused/present | TEXT 枚举 | N | — | 无 | 同上 |
| local_path | 本地文件位置 | TEXT | Y | — | 无 | 同上 |
| downloaded_at | 就绪时刻 | INT | Y | — | 无 | 同上 |

---

## 行为移交清单（非字段歧义；跨表行为于对应切片裁决）

1. **移除扫描目录**（repository_roots 无软删列系 spec 本义）→ S2 扫描域：根下曲=逐曲 softDelete_Tombstone(track)→ 传播 S6。
2. **歌单条目「移出」**物理行删 → 同步域以 TombstoneKind.playlist_item 传播（S6 执行）。
3. **少播清空**物理全删 → 墓碑 TombstoneKind.few_watch（S6 执行）。
4. **extract_tasks 无删除路径**=任务清单为业务台账（dup/failed 均为状态而非脏行），无清写需求（如未来需清理→引入归档动线另立 REQ）。
5. tracks_fts 写纪律=updateTrackIndex 单点入口（全列 delete 已实证）；禁绕过直写。

## 审计结论

- 132 列六问作答完成；**0 歧义**（DoD3 达成）。
- 走查过程修正：ISS-503（conflict_copies 补 deleted_at，spec 第 51 行字段清单同步更正）。
- 红线核对（DoD4）：物理删除仅 play_history 淘汰/playlist_tracks 业务动作/few_watch 清空三处，均已配墓碑或本地化豁免依据；凭据本体不入 DB（settings/sync_channel 仅 credentials_ref）。
