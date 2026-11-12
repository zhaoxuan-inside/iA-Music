# iA-Music 架构宪章 v2

v1 的病根是**边界与重复**：上帝组合根、UI 越层直调 DAO/adapter、四份歌词管线、
手搓 revision 全量刷新。v2 的每一条规则都对应 v1 的一个病灶。

## 分层与依赖规则

```
lib/
  app/       组合根 + 壳 + 主题 + 路由。全仓库唯一允许 new 具体实现的地方。
  domain/    实体 + Port 接口 + sealed ContractError。纯 Dart，禁 import Flutter。
  data/      drift schema + 分域 DAO + repository。唯一持久层。
  services/  领域服务。可依赖 domain + data + Port；禁依赖 adapters/ui/flutter。
  adapters/  Port 的真实现（mpv/http/安全存储）。只被 app/ 与 state/ 装配。
  state/     Riverpod providers——服务与 UI 状态的唯一通道。
  ui/        页面与组件。只准 import state + domain（+ l10n/theme）。
```

依赖只能自上而下（ui → state → services → data/domain；adapters 实现 domain 的 Port）。
**由 `test/architecture_test.dart` 强制**：违规 import 直接测试失败，不靠自觉。

## 状态管理

- 全应用唯一方案：**Riverpod 3**。
- 曲库数据：drift `watch` → `StreamProvider`，细粒度刷新；禁止全局 revision 计数器。
- 播放域：`PlaybackController`（Notifier）持有队列/当前曲/进度/状态；UI 只读状态、调方法。
- 服务通过 provider 暴露；测试用 `ProviderScope(overrides:)` 注入 fake。

## 对外能力一律走 Port

引擎 / 歌词来源 / 封面来源 / 元数据解析 / 安全存储各有一个 `domain/ports/` 接口 +
sealed 错误。adapter 只抛 `ContractError`，文案映射在 UI/l10n 层——adapter 不依赖
Flutter 与 l10n。

## 服务去重纪律（v1 的账）

- 歌词获取/解析/.lrc 落盘/偏移回写：只有 `services/lyrics/lyrics_pipeline.dart` 一份。
- 封面决议（内嵌→旁车→在线→色块）：只有 `services/covers/cover_chain.dart` 一份。
- 未来同步：diff 仲裁只属于 sync engine，通道 adapter 只做传输。

## 数据

- drift 单持久层，schema v1 全新起始；每域一个 DAO 文件，DAO 不做业务裁决。
- FTS5 `track_index` 五列（title/artist/album/pinyin_full/pinyin_initials），
  与业务写入同一事务；CJK 逐字空格分隔 + 拼音双列，查询侧同规则分词。
- 数据库文件名 `ia_music_v2.db`（与 v1 旧库隔离，无迁移链）。
- 元数据解析只读，绝不写回原始音频文件。

## 测试

- 架构守卫测试（分层 import 规则）——第一个测试，永不被删。
- 领域测试用内存真 SQLite + `test/fixtures/library_smoke` 真实音频。
- 每个 Port 至少一个 fake 契约测试；真网络测试一律 `@Tags(['network'])`，默认排除。

## 构建链

- sqlite3：仓库内置源码三端自编（`native/sqlite3/sqlite3.c`，hooks user_defines）。
- mpv：Android arm64 运行库随仓库（`packaging/mpv/`）。
- 原生二进制入库需在 PR 说明里给出理由与 SHA-256。
