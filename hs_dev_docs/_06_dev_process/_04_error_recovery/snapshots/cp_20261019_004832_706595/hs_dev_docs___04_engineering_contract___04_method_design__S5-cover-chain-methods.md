# S5 封面链方法与调用契约

- 版本：v1 / 2026-10-18；实现对应 TASK-S5、CP-S5、详细设计 §3.5、REQ-LIB-04/08、DEC-010。
- 公共 Port 沿用 `app/packages/contracts/lib/src/cover.dart`；本次不变更签名，不新增数据库列。工作树原有 schema v2 的生成结果已同步。
- 方法意图查重：`doc_index_db.py --root . method-search --q CoverChain` 返回 0（原索引仅能查到导航）；已有详细设计 §3.5 是本方法语义源。

## CoverChain.decide

- **所属层次**：应用编排层；**所属模块**：library；**方法类型**：ORCHESTRATE；**改动敏感度**：HIGH。
- **文件路径**：`app/lib/library/cover_chain.dart`；**Symbol Anchor**：`CoverChain.decide`。
- **方法签名**：`Future<CoverResolution> decide(int trackId)`。
- 输入：真实库行 ID；读取根路径、相对路径、标题/歌手/专辑与 `cover.autoFetch`。
- 输出：`CoverResolution(kind, localPath?, bytes?)`；kind 沿用 `CoverKind`。内嵌图以真实字节返回；本地/联网图以路径返回；未命中为 none。
- 不变量：内嵌 > 同目录同名 jpg/jpeg/png/webp > 已下载图 > 完全缺失时联网 > 色块；内嵌与同名图存在时零 HTTP 请求；原音频仅只读。
- 副作用：library DAO 仅更新三列封面注册位；不写标题、tags、hash、mtime、updatedAt、FTS。在线落盘 `${audioPath}.cover.jpg`（保留音频扩展名，避免同名异格式曲目碰撞）。
- 并发：同实例同曲目在制 Future 合流；不永久缓存 none。下载完重新检查本地来源与软删状态；exclusive create 不覆盖已有文件；清理本次下载临时文件。
- fallback：metadata/IO/网络异常静默 none；下次浏览/播放重新检查。关闭联网只阻断网络，保留本地优先。
- 测试：`app/test/cover/s5_cover_chain_test.dart`；真实 sqlite/磁盘/APIC 音频；`s5_cover_network_test.dart` 与 `s5_cover_ui_test.dart` 补真实在线集成。`tool/s5_offline_probe.dart` 已在隔离 Android 飞行模式/无默认网络下验证色块、无封面文件与音频哈希不变；不以设置关闭代替断网。

## CoverFetchAdapter.fetchTrackCover / CoverRequestLimiter.acquire

- **所属层次**：基础设施与适配层；**方法类型**：ADAPTER / ALGO；**改动敏感度**：MEDIUM。
- **文件路径**：`app/lib/adapters/cover_fetch_adapter.dart`；锚：`CoverFetchAdapter.fetchTrackCover`、`CoverRequestLimiter.acquire`。
- `CoverQuery` → MusicBrainz recording 检索 发行（MBID） → CAA front thumbnails 1200/500/250 → iTunes song artwork 兜底 → 真 JPEG 临时文件 `CoverResult`。
- 标题精确匹配（忽略首尾空白/大小写）；提供歌手/专辑时同样匹配，防止取搜索首条错误封面。不重试失败请求。
- 单进程共享容量 1 的令牌桶；单调时钟 + 向上取整毫秒等待 + 1ms 调度余量；DNS/TLS 完成后在发送 HTTP 请求前取令牌。重定向逐跳重新取令牌，并保留 User-Agent。
- 连接/响应超时 10/15 秒；JSON ≤2MiB、图片 ≤12MiB；只接受 HTTPS，JPEG 文件签名守卫。请求/响应诊断各最多 200 条，观测真传输、不替代数据源。
- 异常/无匹配输出 null。CAA 实际失败可以进入 iTunes；真实断网、CAA 主源成功命中、模拟器恢复联网后同曲命中均已实证（IMPL-S5 §8）。
- HttpClient 默认尊重进程 `HTTPS_PROXY` / `NO_PROXY`；允许装配时传入明确的 `host:port` 代理，不改系统代理设置。探针仅通过真实 CONNECT 代理连接原 API，保留 HTTPS 主机名与证书校验；没有替换来源、伪造 HTTP 数据或硬编码封面文件。

## LibraryDao.registerCover / UI

- `LibraryDao.registerCover`：library 唯一写者，UPDATE 仅三列注册位且排除软删行；无迁移设计新增。
- `LibraryHub.covers`：列表/播放页共用组合根；hub.dispose 关闭真实 HttpClient。
- `TrackCover`：每次挂载或换曲创建一次稳定 Future；完成后立即重建图像；首字母色块覆盖加载/未命中/解码失败；自身创建的 adapter 随组件关闭。
- `RepositorySettingsPage.setOnlineCovers`：`ShellDao.put` 保存 JSON boolean；默认 true；版权说明只显示在在线封面设置项。
- 旧库保护：`_nativeFileRo` 设置 `enableMigrations:false`，禁止 drift 在异常只读库执行迁移或写版本；已有 S1 真实损坏库用例加入 user_version 不变断言。

## 调用链与证据锚

`LibraryListPage._row / PlayPage._filmFrame → TrackCover → LibraryHub.covers（或页面自持 adapter）→ CoverChain.decide → MetadataReader / 同目录磁盘 / CoverFetchPort → LibraryDao.registerCover → FutureBuilder 图像替换`。

`RepositorySettingsPage → setOnlineCovers → ShellDao.put → CoverChain.decide`；`LibraryHub.dispose / TrackCover.dispose → CoverFetchAdapter.close`。

运行报告：`hs_dev_docs/_06_dev_process/_03_qa_log/IMPL-S5-cover-chain-evidence.md`；命令：`cd app; flutter test test/cover --reporter expanded`。DEC-010 全真策略优先于通用 Mock 测试建议。
