# iA-Music

项目按职责拆分，便于单独提交和发布：

- `lib/`：应用代码（Flutter/Dart）。
- `android/`、`windows/`、`linux/`：Flutter 平台工程。
- `test/`：单元、集成和黄金测试，以及测试夹具。
- `tool/fixtures/`：测试数据生成器。
- `tool/probes/`：本地诊断探针，不参与正式构建。
- `tool/runtime/`：运行时辅助脚本（例如 ASR）。
- `packaging/`：图标生成和打包入口。
- `native/`：需要随应用编译的原生源码与库。

正式构建请在仓库根目录执行 Flutter 构建命令；生成物统一写入构建目录，不会混入源码提交。
