# chromaprint-ffi — vendored 说明

本目录是对 pub 包 `chromaprint 0.2.1` 的 **vendored 修补版**，主工程以
path 依赖引用（`pubspec.yaml` → `path: third_party/chromaprint-ffi`）。

## 为什么 vendor

pub 发布包 `chromaprint 0.2.1` 的 **C++ 源码缺失**（其 `chromaprint/`
子目录为空壳，gradle 原生构建直接失败）。Dart 侧（FFI 绑定）与平台壳
（android/ios/linux/macos/windows 的构建配置）完好且可用。

## 组装方式

| 部分 | 来源 | 说明 |
| --- | --- | --- |
| Dart 绑定 / 平台壳 / `src/`（CMake + config.h） | pub 包 `chromaprint-0.2.1` 原样复制 | 排除其 `chromaprint/`（残缺）与 `android/.cxx`（构建缓存） |
| `chromaprint/src/`（389 文件） | chromaprint **v1.5.1** 上游 `src/` 全量 | 核心指纹算法源码 |
| `chromaprint/src/3rdparty/kissfft/` | kissfft **master** 整组 6 文件 | `kiss_fft.{c,h}`、`kiss_fftr.{c,h}`、`_kiss_fft_guts.h`、`kiss_fft_log.h` |

## 硬约束

1. **kissfft 必须整组同版本**——master 版的 `kiss_fftr.*` 引用
   `KISS_FFT_API` / `KISS_FFT_ERROR` / `kiss_fft_log.h`，与 chromaprint
   1.5.1 自带的旧版 `kiss_fft.h` 混搭会编译失败（本仓库已趟平）。
2. **无需 ffmpeg**——`audio_processor.cpp` 使用 chromaprint 内部
   avresample（`USE_INTERNAL_AVRESAMPLE=1`），不依赖 libav*。
3. **PCM 由 mpv 提供**——适配器（`lib/adapters/fingerprint/`）经
   mpv_audio_kit 的 aformat 滤镜 tap 输出 mono/11025/s16，chromaprint
   只做指纹计算；`audio_processor.cpp` 仅作为可编译单元存在。
4. `src/config.h` 声明版本号 1.6（upstream 壳自带），实际算法源码为
   1.5.1——纯元数据，不影响行为。

## 原生产物

`android/build.gradle` → `externalNativeBuild` 指向 `src/CMakeLists.txt`
→ 产出 `libchromaprint.so`（arm64-v8a / armeabi-v7a / x86_64），随 APK
分发；Dart 侧 `DynamicLibrary.open('libchromaprint.so')` 直接绑定 C API
（chromaprint_new/start/feed/finish/get_fingerprint）。
