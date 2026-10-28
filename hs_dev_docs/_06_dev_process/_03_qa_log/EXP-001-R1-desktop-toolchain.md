# 实验记录 EXP-001：R1 桌面工具链安装与自检（yt-dlp + ffmpeg）

- **时间**：2026-10-17
- **关联**：`PHASE-0-PROBE-SHEET-R1-R3-iA-Music.md` R1「桌面最小验证」；`PLAN-iA-Music-BUILD-1.md` T4；`PHASE-1-ACCEPTANCE-iA-Music.md` §5；`DEC-007` D7-4（安装许可）
- **环境**：开发机 Windows（非管理员 shell，git-bash）；Python 3.14.5rc1（`py` 启动器，安装路径含非 ASCII）；pip 26.1；网络对境外大文件源限速（gyan.dev 直连 900s 仅 3.3MB；默认 PyPI 大文件下载停滞）

## 1. 安装执行

| 组件 | 方法 | 结果 | 备注 |
|---|---|---|---|
| yt-dlp | `py -m pip install -U yt-dlp` | **2026.08.19** 安装成功 | 默认 PyPI；模块方式 `py -m yt_dlp` 调用（免 PATH） |
| ffmpeg | ① gyan.dev 直连 `ffmpeg-release-essentials.zip` → **失败**（900s 超时，仅 3.3MB）② 改 `py -m pip install -U -i https://pypi.tuna.tsinghua.edu.cn/simple imageio-ffmpeg` 成功（wheel 内置 ffmpeg 二进制）③ 复制至 ASCII 路径 | **ffmpeg 7.1-essentials_build (gyan.dev)** @ `C:\Users\hardstone\tools\ffmpeg\ffmpeg.exe`（87.6MB） | Python 安装路径含非 ASCII → bash 变量展开乱码；经 Python `shutil.copy2` 复制到 ASCII 路径规避 |

## 2. 自检证据

```text
$ C:\Users\hardstone\tools\ffmpeg\ffmpeg.exe -version
ffmpeg version 7.1-essentials_build-www.gyan.dev Copyright (c) 2000-2024 the FFmpeg developers

$ ffmpeg.exe -hide_banner -f lavfi -i "sine=frequency=440:duration=1" -codec:a libmp3lame -q:a 4 _selftest.mp3 -y
size=       5KiB time=00:00:01.00 bitrate=  40.9kbits/s speed= 116x
# 输出 C:\Users\hardstone\tools\ffmpeg\_selftest.mp3 存在（5117 bytes）

$ py -m yt_dlp --version
2026.08.19
```

## 3. R1 桌面链路实测（2026-10-17 已执行）

- 样例：B 站公开镇站视频 **av170001**（BV17x411w7KC，公开非敏感，agent 代选；开发者原要求自带链接未附，此处记录替代）
- 命令：`py -m yt_dlp --no-playlist --no-simulate -x --audio-format mp3 --audio-quality 5 --ffmpeg-location C:\Users\hardstone\tools\ffmpeg -o "r1-test/%(id)s.%(ext)s" https://www.bilibili.com/video/BV17x411w7KC/`

| 记录项 | 观察结果 |
|---|---|
| 解析成功率 | 1/1（**匿名无 Cookie**）；元数据：标题/199.4s/选中格式 30216（64kbps 音轨） |
| 输出与产物 | `BV17x411w7KC_p1.mp3` 2,617,169 bytes；ffmpeg 全解码复核通过（Duration 00:03:19.37；mp3 44100Hz 立体声） |
| 耗时 | 元数据秒级；下载+转码约 1 分钟（199s 音频 → 2.6MB） |
| 失败模式 | 无。**匿名上限＝64kbps 音轨**；高音质（128k/192k/Hires）需登录 Cookie —— 印证产品端 B 站登录态（扫码）与失效策略必要性 |
| 工程发现 | `--print` 隐含 `--simulate`（仅探测不下载）；产品实现需探测/下载两段式或显式 `--no-simulate` |

局限：单样例；会员/地区限/风控路径未覆盖；安卓嵌入引擎真机验证仍待（ISS-101）。

## 4. 限制与后续

- 本工具链为**探查用途**（用户级安装，未修改系统 PATH）；产品打包前须按 TECH-04 复核 ffmpeg 构建许可与分发方式（gyan essentials 为 GPL 构建，产品侧可能需 LGPL 位）。
- R3 桌面预检：已完成（模型镜像下载 + SAPI 中文样本生成）→ `EXP-002-R3-desktop-preview.md`；桌面 RTF 计时因 Python 3.14 无 sherpa-onnx 轮子后置（以真机为主）。
- 真机项与百度控制台项仍待开发者安排（`PHASE-1-ACCEPTANCE` ISS-101/102）。
