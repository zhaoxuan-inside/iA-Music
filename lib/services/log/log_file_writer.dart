/// 追踪日志文件写入器：追加到 `<logsDir>/trace.log`。
///
/// 滚动策略（docs/PLUGIN.md 无关，属诊断域）：
/// * 单文件上限 [maxBytes]（默认 100MB）——达到即滚动：
///   trace.log → trace.1.log（只保留一代，更旧的直接删除）；
/// * 磁盘占用封顶 ≈ 2×maxBytes；
/// * 写入串行化（链式 Future）保证多来源并发时行序不乱。
/// 读写失败一律静默——日志系统自身绝不阻断主流程。
library;

import 'dart:async';
import 'dart:io';

class LogFileWriter {
  LogFileWriter({required this.dir, this.maxBytes = 100 * 1024 * 1024});

  /// 日志目录（CacheDirs.logs）。
  final String dir;

  /// 单文件上限（滚动阈值），测试可注入小值。
  final int maxBytes;

  Future<void>? _pending;

  File get _current =>
      File('$dir${Platform.pathSeparator}trace.log');

  File get _backup =>
      File('$dir${Platform.pathSeparator}trace.1.log');

  String get currentPath => _current.path;

  /// 追加一段日志文本（串行化保序）。
  Future<void> writeLine(String line) {
    _pending = _pending?.then((_) => _write(line)) ?? _write(line);
    return _pending!;
  }

  Future<void> _write(String line) async {
    try {
      await Directory(dir).create(recursive: true);
      final f = _current;
      if (await f.exists() && await f.length() >= maxBytes) {
        // 滚动：当前 → 备份（旧的备份删除），新文件从零开始
        final backup = _backup;
        if (await backup.exists()) {
          await backup.delete();
        }
        await f.rename(backup.path);
      }
      await f.writeAsString('$line\n',
          mode: FileMode.append, flush: false);
    } on Object {
      // 日志写入失败静默：不影响被记录的业务流程
    }
  }
}
