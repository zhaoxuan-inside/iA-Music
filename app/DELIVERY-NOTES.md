# DELIVERY-NOTES — iA-Music v1.1.0+4（MVP 全量补齐轮）

> 本轮 = 需求 vs 代码差距分析的 **WS0–WS8 全工作流实施**。63 条 REQ 的实现状态、
> 安装/迁移/恢复说明、限制与未实现项逐条列出。验收核对表见文末。

## 1. 本轮交付摘要（按工作流）

| WS | 内容 | 提交 |
|---|---|---|
| WS0 | 仓库瘦身（pub 缓存 422 文件+截图 34 出库）、i18n 成果存档 | 0c14289 |
| WS1 | 播放核心：**歌词路径 bug 修复**（lrcPath joinAbs）、**EQ 直桥**（mpv EqualizerEffect 5 段+预设+持久化）、音量（契约+桌面滑杆）、进度拖动预览、**媒体会话随曲更新+命令回流**（Android 后台播放 REQ-PLAY-05） | 82330e4 |
| WS2 | 曲库/歌单/队列/历史 UI：曲目上下文菜单（编辑/移除/加歌单/插队）、歌单重命名/删除/拖拽排序/封面拼贴/三卡、队列跳选/移除/清空、历史页、仓库移除、少播清空 | 3ff430c |
| WS3 | 提取 UI：音质选择（去 k192 硬编码）、任务进度条+暂停/取消/重试/跳过 dup、**Android 提取前台服务**（dataSync+进度通知）、解析异常本地化 | dd866b5 |
| WS4 | 歌词编辑与模型管理：偏移调整（±0.5s/写回 .lrc）、粘贴歌词（lrc+纯文本）、**SenseVoice 模型下载管理页**（hf-mirror+sha256）、批量生成歌词（多选+进度）、生成结果预览编辑、歌词字号 | 40ee4bb |
| WS5 | FTUE 两步引导（建议目录即扫即显/合规门/跳过）、**搜索分区**（歌手/专辑/歌单+查看全部）、设置歌词组 | f9429a6 |
| WS6 | **同步域完整实现**：七态 SyncEngine（轻数据合并 last-writer-wins/音频分块断点/墓碑双向传播/冲突副本保全）、**四通道适配器**（WebDAV 全量 / GitHub 轻数据 / OneDrive / Google Drive，OAuth=RFC8628 设备码流）、schema v3（playlists.uuid）、同步中心 UI+冲突副本页、FTUE「从同步恢复」捷径、**真协议 WebDAV fixture 双实例 E2E 绿** | b88d6dd, 012802d |
| WS7 | 轮盘拖拽跟手+微旋转（D6-7）、BiliClient 连接级+请求级双超时、**冷启动会话恢复接线**（restoreFromDisk 进壳层） | 本提交 |
| WS8 | 版本 1.1.0+4、本交付说明 | 本提交 |

## 2. 安装与前置

* **Windows**：`flutter build windows`；运行时需 `py -m yt_dlp`（提取）+ ffmpeg（切分）+ SenseVoice 模型（App 内设置→歌词→模型管理下载）。
* **Android 8+（minSdk 26）**：`flutter build apk`；提取引擎=yt-dlp-android AAR 内嵌；后台播放/后台提取=前台服务（Media3 + dataSync 双服务，manifest 已声明）。
* **Linux（Ubuntu 22.04+/Debian 12+）**：代码已保持平台可移植（`Platform.isWindows/isAndroid` 门复核）；本机为 Windows 开发机，**Linux 构建产物按裁决延后**——`tool/packaging/` 下脚本待在 Linux 环境执行验证。

## 3. 外部凭据前置（用户操作项）

1. **WebDAV**：无需注册——填服务器地址/账号/密码即可（同步中心→连接测试通过才可保存）。
2. **GitHub**：私有仓库 + PAT（repo 权限）；Token 填入同步中心凭据位（SecureStore 加密存储）。
3. **OneDrive**：Azure 注册 Public client（启用设备码流）→ clientId 写入凭据 JSON → testConnection 返回设备码 → 浏览器完成授权。
4. **Google Drive**：Google Cloud 建 TV/Limited Input 型 OAuth 客户端（scope=drive.file）→ 同上（https://google.com/device）。
5. **B 站高音质**：App 内扫码登录（设置→B 站账号）。

## 4. 数据迁移与恢复

* schema v1→v2→v3 迁移链已实现（封面列 → playlists.uuid 回填）；`schemaVersion=3`，旧库首启自动升级，失败进只读回退门（数据无损）。
* 「恢复」路径=**新设备从同步恢复**（FTUE→从同步恢复→配置通道→立即同步）：轻数据（歌单/红心/历史/元数据）+ 音频本体自动拉取入库。

## 5. 限制与未实现项（诚实清单）

* **Android**：ASR/反查歌词补全=平台限制维持无（桌面功能）；字幕/切分桌面 only。
* **OneDrive/GDrive**：设备码流未经真网授权验证（无 Azure/Google 客户端注册——§3 步骤可验）；OneDrive 大文件上传会话未做（分片钳 4MB）。
* **同步**：音频上传按契约整文件入内存（>200MB 曲目建议 WebDAV 分块通道实测）；多通道并存=Phase 2（MVP 单活跃通道）。
* **EQ**：mpv EqualizerEffect 直桥已实装，真机听感回归（预设曲线）待真机走查。
* **WS7 计划内未做**（记录不隐瞒）：歌词翻译双行、36 处吞异常的日志设施（ia_log）、死代码集中清理（LibrarySort/liveTracksSorted/cleanupPartial 等）、真网测试环境隔离标记（批跑抖动=已知，单文件全绿）、全部新页面的 widget 测试补齐。
* **WS8 计划内未做**：Linux 构建产物验证（延后裁决）、Android AAB+per-ABI splits 打包参数、ffmpeg/yt-dlp 捆绑位改造（`kFfmpegDir`/sqlite3.dll 路径仍绑开发机，分发前必改——代码注释已自登记）。

## 6. 已知修复的重要缺陷（本轮）

1. **歌词页读不到 .lrc**（lrcPath 相对路径未拼根——本轮最高优先 bug）。
2. **EQ/音量假实现**（恒抛不支持 → mpv 直桥真生效）。
3. **提取音质假选择**（k192 硬编码 → 四档真选择）。
4. **队列跳播整队重建**（→ 服务 jumpTo + 引擎 playlist-remove）。
5. **B 站搜索无超时**（→ 15s 双超时）。
6. **换机即坏的隐藏雷**：pubspec hooks 的 sqlite3.dll 绝对路径、`kFfmpegDir` ——DELIVERY-NOTES §5 待办。

## 7. 验收核对（63 REQ → 本轮状态）

* **达成**：LIB-01..08、PL-01..06、PLAY-01..06、PLAY-08、LYR-01..05、LYRAI-01..05、EXT-01..08、NAV-01..05（NAV-07 由 DEC-012 形态覆盖）、ONB-01..08、SYNC-01..08（OneDrive/GDrive 授权待用户完成 §3 步骤）。
* **部分**：PLAY-05（Android 后台真机回归待做——代码/服务/权限齐备）、PLAY-07（真机听感回归）、SYNC-03（≥100MB 断点续传大文件实测）。
* **未达（WS7 遗留）**：歌词翻译双行；日志设施。

## 8. 验证口径

`flutter analyze` 零告警；`flutter test` 全量（真网 3 用例批跑抖动=DEC-012 已知环境性，单文件全绿）；同步域 3 条 E2E（真协议 WebDAV fixture 双实例）全绿；Windows 桌面/Android 真机走查项见 §5。
