# iA-Music 插件规范 v0.1

> 原则：宿主不内置任何第三方平台代码；一切外部平台能力由**用户安装的插件**提供。
> 插件 = 单文件 JS 脚本，运行在宿主内的 QuickJS 沙箱，只经能力桥访问受控资源。
> 借鉴：Dify 插件（市场 + 清单）、Legado 书源（用户自备源）、Greasemonkey（单文件分发）。

## 1. 插件包格式

一个插件 = **一个 `.plugin.js` 文件**（本地导入、市场分发、更新替换都是这单个文件）。

文件头部（前 4KB 内）必须有一个 manifest 注释块，宿主**静态解析、不执行代码**即可读取：

```js
/*!
{
  "id": "com.example.bilibili",
  "name": "B 站音频源",
  "version": "1.0.0",
  "api": 1,
  "capabilities": ["source"],
  "author": "someone",
  "homepage": "https://…",
  "notes": "扫码登录 + 站内搜索 + 音频流解析"
}
*/
// …插件代码…
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `id` | ✓ | 全局唯一，反向域名风格（小写字母/数字/点/下划线/连字符）；安装/更新/凭据沙箱都按它隔离 |
| `name` | ✓ | 展示名 |
| `version` | ✓ | semver；更新判定 = 市场版本更高 且 sha256 不同 |
| `api` | ✓ | 宿主桥协议版本（本规范 = 1）；不匹配拒绝激活 |
| `capabilities` | ✓ | 声明的能力列表（见 §2）；宿主只激活**已知**能力 |
| `author` / `homepage` / `notes` |   | 展示用 |

## 2. 能力（capabilities）

宿主按能力激活插件入口函数；未知能力不激活也不报错（诚实降级）。

| 能力 | 入口函数（全局 async） | 状态 |
|---|---|---|
| `source` | `search(query, opts)` / `resolve(id)` / `lyrics(id)` / `auth()` | v1 实现 |
| `lyrics-provider` | 预留 | 未实现 |
| `audio-provider` | 预留 | 未实现 |

`source` 契约：

```js
async function search(query, opts)   // → [{ id, title, artist, durationSec, extra? }]
async function resolve(id)           // → { url, ext, bitrate?, headers? }（直链音频流）
async function lyrics(id)            // → { synced?, plain? } | null
async function auth()                // → { kind: "none" | "qr" | "cookie", … }
//   qr:     { kind:"qr", qrUrl, poll(): Promise<{state:"waiting"|"scanned"|"expired"|"success"|"error", message?}> }
//   cookie: { kind:"cookie", check(header): Promise<{ok, user?}> }
```

## 3. 能力桥（宿主注入的 `IA` 运行时）

沙箱内**没有** `dart:io` / 文件系统 / 原生库。插件只能通过桥做四类事：

| 桥 | 签名 | 实现 |
|---|---|---|
| 网络 | `await IA.fetch({ url, method?, headers?, body? })` → `{ status, headers, body }`（body 为文本） | 宿主 HttpClient（经 download_guard 审计）；二进制流不进沙箱 |
| 加密 | `IA.md5(s)` / `IA.sha256(s)` / `IA.hmacSha256(key, s)` | crypto 包，同步通道 |
| 凭据沙箱 | `await IA.kvGet(key)` / `await IA.kvSet(key, value)` | 每插件独立 KV 文件，**宿主不读取不展示**；凭据自知原则 |
| 日志 | `IA.log(...)` | 诊断流（设置 · 诊断可查） |

实现约束：`fetch`/`kv` 为异步（Promise + 宿主回调完成）；`crypto` 为同步通道。沙箱无 `setTimeout` 计时器注入时轮询由宿主驱动。

## 4. 生命周期与安装来源

- **本地导入**：把 `.plugin.js` 放进应用插件目录（设置 · 插件 → 打开目录），点「扫描导入」；或直接粘贴文件 URL 安装。
- **插件市场**：市场 = 一个**索引 JSON URL**（用户可配置，可指向自建仓库）。格式：

```json
{
  "api": 1,
  "name": "示例插件市场",
  "plugins": [
    { "id": "com.example.bilibili", "name": "B 站音频源", "version": "1.0.0",
      "capabilities": ["source"], "file": "https://…/bilibili.plugin.js",
      "sha256": "…", "homepage": "…", "notes": "…" }
  ]
}
```

安装流程：下载文件 → 校验 `sha256`（索引提供时）→ 静态解析 manifest → 一致性校验 → 写入 `<pluginsDir>/<id>/main.js` → 注册表登记（默认启用）。
- **更新**：市场版本更高即提示；替换文件前校验新 manifest 的 `id` 不变。
- **卸载**：删除插件目录（含 KV 沙箱）+ 注销。
- **禁用**：仅停用，文件与凭据保留。

## 5. 存储布局

```
<applicationSupport>/plugins/
  registry.json              # 已装插件：manifest + enabled + installedAt + file
  market.json                # 最近一次市场索引缓存
  <id>/main.js               # 插件代码
  <id>/kv.json               # 该插件的凭据沙箱
```

## 6. 安全模型（诚实边界）

1. 沙箱 = QuickJS（无 dart:io / 无进程 / 无原生）；插件逃不出能力桥。
2. 能力按 manifest 声明收口；v1 全部能力默认授予（用户主动安装即信任），后续引入逐能力授权 UI。
3. 凭据只存在于插件自己的 KV，宿主 UI 不展示、不导出（沿用「凭据自知」）。
4. 市场索引不带签名也可用；提供 `sha256` 则安装时强校验。供应链责任在市场维护者，宿主诚实呈现来源。
5. 插件崩溃/超时（默认 30s/次调用）不影响宿主，异常进诊断流。

## 7. 宿主集成点

- `collect_service` 提取队列经 `SourcePluginPort` 调插件（替代内置客户端的调用面）。
- 收集页平台行、站内搜索按已装 `source` 插件枚举。
- 宿主自带的 B站/YouTube 内置客户端将在插件运行时于真机验证后移除（迁移期并存）。

## 8. 参考实现

`plugins/` 目录存放参考插件（也是桥协议的活文档）：
- `demo-source.plugin.js` —— 最小 source 插件：fetch 桥 + kv 沙箱 + crypto 签名演示。
