# 打包工具

`build.ps1` 是统一的打包入口，负责切换到 `app/` 后调用 Flutter：

```powershell
pwsh packaging/build.ps1 -Target windows -Mode release
pwsh packaging/build.ps1 -Target apk -Mode debug
```

构建产物由 Flutter 写入 `app/build/` 或 `app/output/`，这些目录已被 Git 忽略。诊断探针和测试夹具生成器不属于打包流程。
