/// 根目录真事件监听：Directory.watch 脏信号 → 防抖 → 增量扫描回调。
///
/// 平台差异兜底：Android 共享存储 watch 可能不支持——失败静默跳过，
/// 手动重扫永远可用。
library;

import 'dart:async';
import 'dart:io';

import '../../data/database.dart';

class RootWatcher {
  RootWatcher(this._db, this._onDirty,
      {this.debounce = const Duration(seconds: 3), this.onWatchError});

  final IaDatabase _db;
  final void Function(int rootId, String rootPath) _onDirty;
  final Duration debounce;

  /// watch 流运行期错误回调——流错误后增量扫描静默失聪，必须留痕。
  final void Function(String rootPath, Object error, StackTrace? st)?
      onWatchError;

  final Map<int, (StreamSubscription<FileSystemEvent>, String)> _subs = {};
  Timer? _timer;
  final Map<int, String> _dirty = {};

  /// 以当前根目录集合重挂监听（diff 式；先改 path 再换监听）。
  Future<void> sync() async {
    final roots = await _db.libraryDao.allRoots();
    final want = {for (final r in roots) r.id: r.path};
    for (final id in _subs.keys.toList()) {
      if (want[id] == null) {
        await _subs.remove(id)?.$1.cancel();
      } else if (_subs[id]!.$2 != want[id]) {
        await _subs.remove(id)?.$1.cancel();
      }
    }
    for (final entry in want.entries) {
      if (_subs.containsKey(entry.key)) {
        continue;
      }
      try {
        final sub = Directory(entry.value)
            .watch(recursive: true)
            .listen((_) => _markDirty(entry.key, entry.value),
                onError: (Object e, StackTrace st) =>
                    onWatchError?.call(entry.value, e, st));
        _subs[entry.key] = (sub, entry.value);
      } on Object catch (e, st) {
        // watch 不可用（平台/挂载点限制）：跳过，不阻断启动——但留痕
        onWatchError?.call(entry.value, e, st);
      }
    }
  }

  void _markDirty(int rootId, String rootPath) {
    _dirty[rootId] = rootPath;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      final pending = Map<int, String>.of(_dirty);
      _dirty.clear();
      for (final e in pending.entries) {
        _onDirty(e.key, e.value);
      }
    });
  }

  Future<void> dispose() async {
    _timer?.cancel();
    for (final s in _subs.values) {
      await s.$1.cancel();
    }
    _subs.clear();
  }
}
