# 任务详单：S0 工程底座（BUILD 阶段 4 / TASK-02）

## 归属与映射
- REQ 映射：**无直接业务 REQ（支撑切片）**；验证目标=三端编译线 + 契约包一致性
- 上游：TECH-SELECTION §5（版本锁定）；DETAILED-DESIGN §2（七 Port 清单）；governance.yaml（cicd/observability=off）

## 目标
Flutter 单工程三端可编译（android 8+ / windows 10 x64 / linux 22.04+·12+）+ `contracts/` 契约包编译通过。

## 边界
- 不含任何业务行为/页面（不含扫库、播放）
- 不启用 CI/CD、不装遥测依赖（治理红线）

## 输入
ADR-0001；DETAILED-DESIGN §2.1 签名与异常枚举

## 输出
- 工程目录：`lib/modules/{shell,library,playback,playlists,lyrics,extract,sync}/`、`lib/ports/`、`contracts/`（7 Port 抽象 + 异常 + DTO）
- Flutter SDK 环境记录（版本写入 EXP 证据）

## DoD
1. `flutter build apk --debug` / `flutter build windows` / `flutter build linux` 三条命令退出码 0（证据进 QA log）
2. contracts 包与 DETAILED-DESIGN §2.1 逐签名一致（人工核对表）
3. `dart analyze` 0 error；无未授权依赖（pubspec 对照 ADR-0001 锁定版本）
4. 三端启动冒烟窗口可开（无业务交互）

## 测试 seam
无外部服务；纯结构切片——集成风险=0

## 前置外部条件
Flutter SDK 三端工具链安装（D7-4 许可范围）；Windows/Linux 桌面机器；Android SDK
