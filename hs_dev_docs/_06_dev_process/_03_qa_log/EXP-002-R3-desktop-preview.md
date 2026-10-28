# 实验记录 EXP-002：R3 桌面预检（模型获取通路 + 语音样本）

- **时间**：2026-10-17
- **关联**：`PHASE-0-PROBE-SHEET-R1-R3-iA-Music.md` R3；`PLAN-iA-Music-BUILD-1.md` T4；`TECH-SELECTION-iA-Music.md` §3.E；`DEC-007` D7-4
- **结论摘要**：① hf-mirror.com 模型获取通路可用且快（239MB 约 2 分钟）→ 支撑「模型下载镜像策略」；② 本机 Python 仅 3.14 系（3.14t/3.14），sherpa-onnx 无 cp314 轮子 → 桌面 RTF 计时未执行（转真机为主）；③ 已用 Windows SAPI（Microsoft Huihui zh-CN）生成约 30s 中文语音样本，供真机/后续 RTF 实测使用，无需外部内容。

## 1. 模型获取（SenseVoiceSmall int8 · 2024-07-17）

| 项 | 值 |
|---|---|
| 源 | `https://hf-mirror.com/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/{model.int8.onnx,tokens.txt}` |
| 结果 | `model.int8.onnx` 239,233,841 bytes；`tokens.txt` 315,894 bytes；全程约 2 分钟（≈2MB/s） |
| 位置 | `C:\Users\hardstone\tools\r3\sensevoice\`（用户级目录，未入库） |
| 意义 | 产品「首次使用下载模型」可走 hf-mirror/ModelScope 类镜像；2 分钟级 + 断点下载（background_downloader）+ sha256 校验可保障体验（C34/C48） |

## 2. 语音样本生成（SAPI，零外部依赖）

- 命令：`py <Temp>\r3\gen_sample_ps.py`（生成 utf-8-sig 的 PS 脚本 → PowerShell `System.Speech`）
- 可用语音：`Microsoft Huihui Desktop (zh-CN)`、`Microsoft Zira Desktop (en-US)`；选用 Huihui
- 输出：`C:\Users\hardstone\tools\r3\zh-sample.wav`（1,380,726 bytes，16-bit，约 30s 中文朗读）
- 备注：pyttsx3 路线因 Python 3.14 无相关轮子未采用；改走 PowerShell SAPI 零依赖路径（不影响结论）

## 3. 限制与后续

- `py -m pip install sherpa-onnx` 在本机 Python 3.14.5rc1 失败（`failed-wheel-build-for-install`，无 cp314 轮子；`py -0p` 仅有 3.14t/3.14）。
- 备选路径：另装 Python 3.12/3.13（需开发者许可）或使用官方预编译 CLI（GitHub 资产，网络受限未尝试）；当前接受「RTF 以真机/公开基准为准」（公开多源：最差 0.436 RTF RK3588 A55 单线程；桌面 x86 0.07–0.13）。
- 真机 R3 完整验证（RTF/峰值内存/模型下载体验）仍待开发者安排（ISS-101）。
