# iA-Music 架构宪章 v2

v1 的病根是**边界与重复**：上帝组合根、UI 越层直调 DAO/adapter、四份歌词管线、
手搓 revision 全量刷新。v2 的每一条规则都对应 v1 的一个病灶。

## 分层与依赖规则

```
lib/
  app/       组合根 + 壳 + 主题 + 路由。全仓库唯一允许 new 具体实现的地方。
  domain/    实体 + Port 接口 + sealed ContractError。纯 Dart，禁 import Flutter。
  data/      drift schema + 分域 DAO + repository。唯一持久层（底层能力域）。
             兼管推理模型文件生命周期（ModelStore：在线下载/sha256 校验/
             原子落盘/登记记账/丢失自愈）。
  inference/ 模型推理（LiteRT/YAMNet 音频嵌入）。与 data 同级的底层能力域：
             **只负责推理计算**——按调用方解析出的模型路径装载并计算，
             不知模型存储与下载的存在；只依赖 domain（+flutter/外部包）；
             被 app/ 装配、经构造注入被 services 消费。
  services/  领域服务。可依赖 domain + data + Port；禁依赖 adapters/inference/ui/flutter。
  adapters/  Port 的真实现（Media3/HTTP/安全存储）。只被 app/ 与 state/ 装配。
  state/     Riverpod providers——服务与 UI 状态的唯一通道。
  ui/        页面与组件。只准 import state + domain（+ l10n/theme）。
```

依赖只能自上而下（ui → state → services → data/domain；adapters 与 inference
实现 domain 的 Port，二者为并列的底层实现域）。
**由 `test/architecture_test.dart` 强制**：违规 import 直接测试失败，不靠自觉。

## UI 分层（ui/ 内部，同受守卫强制）

自底向上四层 + 页面组合，守卫规则见测试 `_buildForbidden()`：

```
ui/
  shell/       全局框架（底部导航骨架 + 全局背景），唯一宿主
  layout/      基础页面布局：HubPage/PageHeader/SubHeader/zuneRoute（页面
               切换动画唯一挂点）/空态。禁 state、禁页面域。
  components/  页面组件：
    kit/       纯展示件（rows/letter_rail/wp_menu/wp_toast/wp_switch/
               tri_state_bar/search_action/format）。禁 state、禁页面域。
    mapped/    自带映射的复合组件（cover/album_tile/ambient）——允许精确
               watch 单一 provider，禁页面域。
  motion/      交互动画基元（wp_motion）。禁 state、禁页面域。
  routing/     页面路由表——跨页跳转唯一出口，唯一允许 import 页面本体的
               公共层；detail/search 为双域组合容器可被各域直接 import。
  actions/     跨域动作编排（长按菜单/dbActions/radio_starter 开播编排）。
               禁页面域——跳转一律走 routing。
  <业务域>/     组合层：页面 = 布局选择 + 组件装配 + watch→props 映射 +
               动画挂点 + 跳转走 routing；域差异化组件住域内（如
               now_playing 三 pane、detail_hero）。域间禁互相 import
               （共享组合页豁免）。
```

要点：数据映射只发生在 mapped 复合组件与域页面两处；共享桶
`ui/shared/ui_kit.dart` 保留为 re-export 门面（既有引用零改动）。
`app/theme/design_tokens.dart` 是第 0 层（颜色/字体/间距唯一来源）。

## 状态管理

- 全应用唯一方案：**Riverpod 3**。
- 曲库数据：drift `watch` → `StreamProvider`，细粒度刷新；禁止全局 revision 计数器。
- 播放域：`PlaybackController`（Notifier）持有队列/当前曲/进度/状态；UI 只读状态、调方法。
- 服务通过 provider 暴露；测试用 `ProviderScope(overrides:)` 注入 fake。

## 对外能力一律走 Port

引擎 / 歌词来源 / 封面来源 / 元数据解析 / 音频指纹 / 音频嵌入各有一个
`domain/ports/` 接口 + sealed 错误。adapter 只抛 `ContractError`，文案映射在
UI/l10n 层——adapter 不依赖 Flutter 与 l10n。

## 服务去重纪律（v1 的账）

- 歌词获取/解析/.lrc 落盘/偏移回写：只有 `services/lyrics/lyrics_pipeline.dart` 一份。
- 封面决议（内嵌→旁车→在线→色块）：只有 `services/covers/cover_chain.dart` 一份。
- 未来同步：diff 仲裁只属于 sync engine，通道 adapter 只做传输。

## 数据

- drift 单持久层，schema v1 全新起始；每域一个 DAO 文件，DAO 不做业务裁决。
- FTS5 `track_index` 五列（title/artist/album/pinyin_full/pinyin_initials），
  与业务写入同一事务；CJK 逐字空格分隔 + 拼音双列，查询侧同规则分词。
- 音频嵌入向量 `track_vectors` 分表（1:1 冷数据，与 lyrics_meta 同款——
  不进 tracks 主行，避免每次曲目列表查询物化 2-4KB blob）：float32 LE blob
  + model 版本列（向量没绑模型版本就是死字节，换模型按列过滤重算，
  upsert 覆盖不混用）。相似检索 = 内存余弦（落库已归一化，点积即余弦，
  个人库规模 <1ms）；10 万首天花板再上 sqlite-vec（仓库自编译 sqlite3.c
  可并编 sqlite-vec.c，vec0 虚拟表 + KNN SQL）。向量属再生缓存，
  不进备份，vectorAt 记账跨重启续算；模型工件与哈希见 native/PROVENANCE.md。
- 推理模型文件不随 APK 分发（在线下载，APK 减重 16MB）：`model_files`
  表记账 + ModelStore 文件管理（下载源可经 settings KV `models.yamnet.url`
  覆盖为自建直链；sha256 校验锚固化在 config）。职责分界：data 管模型
  文件生命周期，inference 只按路径装载推理。
- 数据库文件名 `ia_music_v2.db`（与 v1 旧库隔离，无迁移链）。
- 元数据解析当前只读；写回音频文件 tag 为允许的演进方向（由 MetadataPort 扩展，不做宪章级禁令）。

## 测试

- 架构守卫测试（分层 import 规则）——第一个测试，永不被删。
- 领域测试用内存真 SQLite + `test/fixtures/library_smoke` 真实音频。
- 每个 Port 至少一个 fake 契约测试；真网络测试一律 `@Tags(['network'])`，默认排除。

## 构建链
- 平台：**仅 Android（arm64）**——`flutter build apk --release --split-per-abi --target-platform android-arm64`（不带 split 会产出混 ABI 包）
- 打包规范：`packaging/build.ps1` 一键 → **产物落 `dist/`**，命名 `iA-Music-v<版本>-arm64-v8a.apk` + `.sha256` 校验件（版本/构建号从 pubspec `version:` 读取；arm64 实际 versionCode = buildNo×1000+2）。`dist/` 不入库。
- sqlite3：仓库内置源码自编（`native/sqlite3/sqlite3.c`，hooks user_defines；
  测试宿主的 Windows 构建同走源码编译）。
- 播放：AndroidX Media3/ExoPlayer（just_audio + audio_service），全 ABI，无自编译播放器。
- 原生二进制入库需在 PR 说明里给出理由与 SHA-256。
