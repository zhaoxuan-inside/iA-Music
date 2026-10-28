# EXP-003：Flutter 三端工具链环境（S0 前置 / IMPL-03 环境证据）

- **日期**：2026-10-17
- **授权依据**：DEC-007 D7-4；开发者指令原话『安装到 E盘按照目录命名规则创建目录进行安装。』（2026-10-17）
- **裁决过程**：C 盘首装（后台）在下载 1.8GB zip 中止——开发者改判 E 盘；现场发现 `E:\HardStone.Flutter\flutter` **已有完整绿色安装（2026-10-03）**（此前未入 PATH，`command -v flutter` 不可见）。C 盘残留已清理；**采纳既有安装，未重复下载**。

## 环境结论（采纳安装）

| 项 | 值 / 状态 |
|---|---|
| Flutter SDK | **3.47.6 stable**（Dart 3.13.5，DevTools 2.60.0），`E:\HardStone.Flutter\flutter` |
| 版本锁定 | TECH-SELECTION §5 锁「Flutter stable（Dart ≥3.10）」→ 契约版本=**3.47.6**；最新 stable=3.47.7（晚两天补丁差，非功能性依赖，暂不动） |
| `flutter --version` | ✓（exit=0，实测） |
| Windows 桌面编译线 | ✓ Visual Studio 生成工具 2022 17.14.42 |
| Android 工具链 | ✓ SDK 37.0.0（`ANDROID_HOME=E:\HardStone.Android\AndroidSDK`）；**许可已全接受**（ JAVA=jdk-21.0.12.1+1 识别正常） |
| Linux 桌面 | 本机无从验证——在开发者 Linux 环境执行（D7-2/ISS-502） |
| Chrome | ✗ 缺失——**NA**（本项目无 Web 构建目标，不设 CHROME_EXECUTABLE） |
| maven.google.com | 超——S0 Android 构建前在项目 gradle 配阿里云镜像（预案入 TASK-S0 证据） |

## 持久化环境变量（用户级，2026-10-17 设置）

```
Path 追加   E:\HardStone.Flutter\flutter\bin
PUB_CACHE   E:\HardStone.Flutter\pub-cache     （README 约定；C 盘零占用）
PUB_HOSTED_URL          https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL https://storage.flutter-io.cn
JAVA_HOME   D:\HardStone.开发环境\JDK\jdk-21.0.12.1+1   （Gradle 构建；README 既有约定）
GRADLE_USER_HOME E:\HardStone.Android\GradleHome
```

- `flutter config --android-sdk "E:/HardStone.Android/AndroidSDK"` 已绑定
- 同 Borosource：`E:\HardStone.Flutter\README.md`（目录规则事实源）

## 影响与关联

- S0 正式可开工（三端中两端编译线本机齐备）
- 证据链：PHASE-5-ACCEPTANCE §5 / TASK-S0 / PLAN-BUILD-5 环境底数
