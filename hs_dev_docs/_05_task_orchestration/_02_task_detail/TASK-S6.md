# 任务详单：S6 提取管线（BUILD 阶段 4 / TASK-02）

## 归属与映射
- REQ：**REQ-EXT-01..08 + REQ-ONB-03**（唯一归属）
- Gherkin 锚：`REQ-EXT-01/03 主 Aha 路径 (Happy Path)`；`REQ-EXT-05 链接失效的人话错误 (Error Recovery)`（extraction_prd）；`REQ-ONB-03 合规声明门禁 (Guardrail)`（onboarding_prd）；`REQ-EXT-02 登录后高音质 (Login State)`
- 架构场景：ARCHITECTURE §3.3（提取含 Cookie 失效）

## 目标
合规门禁 + 粘贴解析（≤5s）+ 排队串行/后台继续 + 扫码登录高音质 + dup 检测 + 失败恢复/断点续传 + 自动入库 + 「同时生成歌词」联动（入 S7 队列）。

## 边界
- 桌面 Process 形态先行（yt-dlp+LGPL ffmpeg 捆绑）；**RV-B** Android AAR 嵌入先于 S6 Android 侧开工
- OneDrive/GDrive 等无关；百度网盘禁入（DEC-008 ②）

## 输入
DETAILED-DESIGN §3.2/§3.3 提取六联；§2.1 DownloaderPort；§4.2 任务机；EXP-001 实测锚点（匿名 64k / Cookie 高音质 / `--print` 纪律）；§5.2 音质枚举族

## 输出
ExtractQueue 编排 + DownloaderAdapter（桌面 Process） + 提取页 UI（解析卡/进度/失败清单）+ 合规声明页 + Cookie 流（SecureStore）+ 注册入库事务

## DoD
1. 合规门禁：未确认声明→状态 gating 拦截 + 引导页；确认后记录 `compliance.acknowledged_at`（REQ-EXT-07/ONB-03 双断言）
2. 解析：真 B 站链接 ≤5s 出标题/UP 主/时长/封面/音质列表（EXP-001 链路小样本）
3. dup：同源 (source_type,source_id) 再提→提示已存在，可跳过/重新提取（REQ-EXT-06）
4. 失败恢复：断网→paused 人话+恢复续传；AUTH_EXPIRED→「登录状态过期」明确不重试（§4.3 上限表）
5. 自动入库：TRANSCODING→REGISTERED 事务；产物先私有目录，注册失败产物隔离（§3.2 不变量）
6. 联动：勾选生成歌词→追加 lyrics_gen_jobs queued（EXT-08）
7. 排队后台：3 链接串行-离开页面不中断（EXT-04；Android 前台服务+桌面独立任务）

## 测试 seam
- 解析/下载/断点：全真链路真环境（EXP-001 链路小样本；断网=真实网络开关；不引入伪造 JSON 样本）（DEC-010）
- Cookie 失效/缺失态：真实应用态操作（真实清除 SecureStore 条目→重授权流程），不注入伪造值

## 规则与禁则
- **Cookie 值不进 drift/日志（C50）**：SecureStorePort 唯一进出；日志层断言（演练期在日志产物上 grep Cookie 键名断言 0 命中）
- 无遥测；下载失败重试 ≤3 次（§4.3）；禁默认无限重试
