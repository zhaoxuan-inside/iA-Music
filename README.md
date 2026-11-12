# iA-Music

本地优先的个人音乐库播放器：把散落的音乐收进来、看得清、听得好。

- **曲库**：文件夹扫描入库、专辑/艺术家聚合、拼音全文搜索、封面自动补全
- **聆听**：mpv 引擎、队列/随机、逐行歌词、会话恢复、桌面 SMTC / Android 媒体会话
- **整理**：歌单、喜欢的音乐、播放历史
- **平台**：Windows · Android（v2 起聚焦双端）

v2 是一次推倒重写：架构宪章见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)，
产品设计见 [docs/PRODUCT.md](docs/PRODUCT.md)。v1 代码保留在 `legacy/v1` 分支。

## 开发

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs   # drift codegen
flutter gen-l10n                                                  # 文案 codegen
flutter analyze
flutter test
flutter run -d windows                                            # 桌面
flutter build apk --release                                       # Android arm64
```

## 仓库结构

- `lib/`：应用代码，按 `app / domain / data / services / adapters / state / ui` 分层
- `native/sqlite3/`：随仓库分发的 SQLite 源码（三端自编，FTS5 内建）
- `packaging/mpv/`：随仓库分发的 mpv arm64 运行库（离线打包）
- `test/`：架构守卫测试 + 领域测试（内存真 SQLite + 真实音频夹具）
- `docs/`：产品设计与架构宪章

构建生成物一律不入库（`build/`、`output/` 已忽略）。
