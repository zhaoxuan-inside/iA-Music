# IMPL-S0：工程底座执行证据（S0 / IMPL-01..04 首块）

> **状态：ACCEPTED**（开发者会话签收原话「S0 验收通过」，2026-10-17T15:38:47Z，全档=PHASE-5 §8 切片验收记录）

- **日期**：2026-10-17；环境：EXP-003（Flutter 3.47.6 / Dart 3.13.5 / Android SDK 37.0.0 / VS 2022）
- **切片**：S0（TASK-S0 + CP-S0）；验证策略=**DEC-010 全真**（本片无外部服务，Mock 边界天然=0）

## 1. 工程创建与结构

```bash
flutter create --project-name ia_music --org com.hardstone --platforms android,windows,linux app   # ✓
cd app/packages && dart create contracts -t package                                               # ✓
```

- 目录：`app/{lib,android,windows,linux,test}` + `app/packages/contracts`
- 应用 ID：`com.hardstone.ia_music`（S10 分发前可再定名——登记 PLAN-BUILD-5）
- pubspec：`contracts` path 依赖（`flutter pub get` ✓，缓存全走 E 盘）

## 2. contracts ↔ DETAILED-DESIGN §2.1 一致性核对（DoD-2）

| Port | 契约文件 | 关键签名/约定 | 结论 |
|---|---|---|---|
| EnginePort | `engine.dart` | init/loadAndPlay/play/pause/seekTo/setEqBands/**events**（5 事件类型含 sessionLost）/restore/dispose；双态注释 | ✓ |
| DownloaderPort | `extract.dart` | resolve（≤5s 注释+`--no-simulate` 纪律）/download/stream/pause/resume/cancel；Quality 4 档；cookiesRefKey 只传键 | ✓ |
| AsrPort | `asr.dart` | isReady/prepare(→ModelInvalidException)/transcribe(wav,{token})→AsrHandle(result+progress+requestCancel)；空段=纯音乐；unload | ✓ |
| MetadataPort | `metadata.dart` | read→ParsedMeta；**类中无任何写方法**（REQ-LIB-03 红线代码级） | ✓ |
| CoverFetchPort | `cover.dart` | fetchTrackCover→CoverResult?（未命中/离线静默 null；C22） | ✓ |
| SyncChannelPort | `sync.dart` | testConnection/diff/putFile(chunked 断点)/getFile/**listRemote；类中无 delete 语义（墓碑红线代码级断言）** | ✓ |
| SecureStorePort | `secure_store.dart` | read/write/delete/containsKey；C50 注释 | ✓ |
| 异常目录 | `exceptions.dart` | 8 类 ↔ §2.2 人话文案一一对应（测试断言） | ✓ |

## 3. 运行证据（命令/结果）

| 命令 | 结果 |
|---|---|
| `dart analyze`（contracts） | **No issues found!** |
| `dart test`（contracts） | **All tests passed!（+2：异常文案目录/音质族+纯音乐判定）** |
| `flutter analyze`（app） | **No issues found!** |
| `flutter build windows` | **√ Built build\windows\x64\runner\Release\ia_music.exe（34.3s）** |
| Windows 冒烟 | `SMOKE-OK pid=17128`（4s 存活含窗口）→ 强杀；`SMOKE-KILLED` |
| `flutter build apk --debug` | **①首跑失败：腾讯镜像 gradle-9.3.1-all.zip TLS 读取超时（`Install.createDist`，Exp 台账 2026-10-17 21:53）→ 清 GradleHome 半成品 + 切华为云镜像重跑 → ②√ Built build\app\outputs\flutter-apk\app-debug.apk（361.2s；gradle 全量拉取 + AGP 镜像链首验证通过）** |
| `flutter build linux` | **本机不可**（ISS-502：Linux 构建在开发者 Linux 环境；不阻断 S0 其余证据链） |

## 4. Android 配置变更（EXP-003 预案落地）

- `app/build.gradle.kts`：`minSdk = 26`（DEC-008 ④：Android 8+；移除 flutter.minSdkVersion 漂浮值）
- `settings.gradle.kts`：aliyun 镜像链（pluginManagement + dependencyResolutionManagement，官源兜底在列）
- `gradle-wrapper.properties`：distributionUrl→**华为云镜像**（实测连通性：华为 0.3s / 腾讯 0.9s 且曾超时 / 官源 services.gradle.org 20s 无响应；镜像切换有 Exp 证据）

## 5. DoD 对照（TASK-S0）

1. 三端编译线：Android ✓（app-debug.apk，361.2s）/ Windows ✓（34.3s）/ Linux=ISS-502 挂账
2. 一致性核对表：§2 全 ✓
3. analyzer 0 error + 无未授权依赖 ✓（pubspec=flutter+contracts+模板依赖）
4. 三端启动冒烟：Windows ✓（pid 存活）；Linux 同 ISS-502 挂账；Android ✓（装机冒烟已补，见 §6）

## 6. Android 装机冒烟补录（2026-10-17T15:36Z）

- **方式**：专用干净 AVD `ia_music_smoke`（system-images;android-37.0;google_apis;x86_64；AVD 落 E:\HardStone.Android\AvdHome，E 盘纪律）
- **步骤**：冷启动 116s → `adb install -r app-debug.apk` **Success** → `am start -n com.hardstone.ia_music/.MainActivity`
- **存活观测**：pid=2658 在 3s/8s/15s 三次 `pidof` 稳定一致 → **SMOKE-OK-ANDROID**
- **焦点窗体**：`mCurrentFocus=Window{… u0 com.hardstone.ia_music/com.hardstone.ia_music.MainActivity}`（应用前台）
- **截图证据**：`_03_qa_log/artifacts/IMPL-S0-android-smoke.png`（S0 模板壳正常渲染，DEBUG 角标=debug 构建预期）
- **DoD-4 对照**：Windows ✓ + Android ✓ + Linux=ISS-502 挂账（开发者裁决见下）→ 三端冒烟证据链收口

## 7. 开发者裁决记录（原话引用）

> 「Linux 构建/冒烟先不用做。Android 装机冒烟需要做；应用 ID 分发前回改；可以；」——Hardstone，会话记录 2026-10-17T15:36:01Z 前后

裁决落点：
1. **Linux 构建/冒烟先不用做** → ISS-502 维持挂账、不阻断，开发者明示；补验时点=分发期/开发者 Linux 环境窗口。
2. **Android 装机冒烟需要做** → 本日已补（§6），挂账关闭。
3. **应用 ID 分发前回改：可以** → `com.hardstone.ia_music` 维持至 S10 分发前统一定名（PLAN-BUILD-5 风险表已在册）。
