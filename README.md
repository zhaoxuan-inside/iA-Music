# iA-Music

本地优先的个人音乐库播放器：把散落的音乐收进来、看得清、听得好。

- **曲库**：文件夹扫描入库、专辑/艺术家聚合、拼音全文搜索、封面自动补全
- **聆听**：mpv 引擎、队列/随机、逐行歌词、会话恢复、Android 媒体会话
- **整理**：歌单、喜欢的音乐、播放历史
- **平台**：**仅 Android**（arm64）

v2 是一次推倒重写：架构宪章见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)，
产品设计见 [docs/PRODUCT.md](docs/PRODUCT.md)。v1 代码保留在 `legacy/v1` 分支。

## 开发

```bash
flutter pub get
flutter pub run build_runner build            # drift codegen
flutter gen-l10n                              # 文案 codegen
flutter analyze
flutter test
powershell -File packaging/build.ps1          # Android arm64 APK
flutter run                                   # 真机/模拟器调试
```

## 仓库结构

- `lib/`：应用代码，按 `app / domain / data / services / adapters / state / ui` 分层
- `native/sqlite3/`：随仓库分发的 SQLite 源码（自编，FTS5 内建）
- `packaging/mpv/`：随仓库分发的 mpv 运行库（离线打包；见 SOURCE.md）
- `test/`：架构守卫测试 + 领域测试（内存真 SQLite + 真实音频夹具）
- `docs/`：产品设计与架构宪章

构建生成物一律不入库（`build/`、`output/` 已忽略）。
