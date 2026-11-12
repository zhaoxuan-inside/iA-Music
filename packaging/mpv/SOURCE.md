# 随仓库分发的 mpv 运行库

`mpv_audio_kit` 的 hook（pubspec `hooks.user_defines.libmpv`）从这里取运行库，
避免构建时访问 GitHub release（v1 实证直连超时）。

| 文件 | 用途 | SHA-256 |
|---|---|---|
| `libmpv_android-arm64-v8a.so` | Android arm64 产物 | 与 hook `libmpv-r19` 钉值一致（hook 本地资产免校验，以本表为准） |
| `libmpv_windows-x86_64.dll` | **仅测试宿主**：本机 `flutter test` 的 native assets 构建；不随产品分发 | `5ce6d0975febebbd3ad3a508a6949a074dfef793db724d455a8ca45b18656872` |

来源：https://github.com/ales-drnz/mpv_audio_kit/releases/tag/libmpv-r19
（android .so 为 v1 时期 vendored 的 libmpv-r17 件，已与本仓验证对齐。）
