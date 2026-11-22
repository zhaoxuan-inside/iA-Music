/// 下载循环 + 停滞看门狗 + 取消令牌。
///
/// 移动网络/代理链路常见「流不关也不来字节」的半死连接：
/// [stall] 时间内没有新字节即判网络中断并抛错（任务转 failed，可重试），
/// 而不是永远挂在 await-for 上。
library;

import 'dart:async';
import 'dart:io';

/// 任务被用户暂停/删除——区分于网络失败（后者标 failed 可重试）。
class CollectCancelledException implements Exception {
  const CollectCancelledException();

  @override
  String toString() => '任务已取消（暂停/删除）';
}

/// 清理某任务的临时残留（下载半截件/歌词暂存——文件名嵌 taskId）。
/// 取消/删除/失败路径共用；清理失败不阻断（下次路径再清）。
Future<void> cleanupTaskTmp(String cacheDir, int taskId) async {
  try {
    final dir = Directory(cacheDir);
    if (!dir.existsSync()) {
      return;
    }
    for (final f in dir.listSync()) {
      if (f is! File) {
        continue;
      }
      final name = f.uri.pathSegments.last;
      if ((name.startsWith('dl_') || name.startsWith('lrc_')) &&
          name.contains('_$taskId.')) {
        await f.delete();
      }
    }
  } on Object {
    // 清理失败不阻断主流程
  }
}

/// 把 [source] 泵进 [sink]，返回收到的总字节数。
///
/// * [onChunk] 每收到一段调用一次（可用于进度上报；可异步）。
/// * [cancelled] 取消令牌：每个 chunk 与每个看门狗 tick 都检查一次，
///   触发即抛 [CollectCancelledException]（运行中暂停/删除任务的通道）。
/// * 超过 [stall] 无新字节 → 抛停滞异常；来源流自身出错 → 原样上抛。
/// * 失败/取消路径都不再触碰 sink——半截文件留给调用方处置（清理/重写）。
Future<int> pumpDownload({
  required Stream<List<int>> source,
  required IOSink sink,
  required Future<void> Function(int received)? onChunk,
  bool Function()? cancelled,
  Duration stall = const Duration(seconds: 30),
}) async {
  var received = 0;
  var last = DateTime.now();
  Object? abortError;
  void checkAbort() {
    if (abortError != null) {
      return;
    }
    if (cancelled?.call() ?? false) {
      abortError = const CollectCancelledException();
    }
  }

  final watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
    checkAbort();
    if (DateTime.now().difference(last) >= stall && abortError == null) {
      abortError = Exception('下载停滞超过 ${stall.inSeconds}s——网络中断');
    }
  });
  try {
    final body = () async {
      await for (final chunk in source) {
        checkAbort();
        if (abortError != null) {
          break;
        }
        last = DateTime.now();
        sink.add(chunk);
        received += chunk.length;
        await onChunk?.call(received);
      }
    }();
    // 双监听：race 用 tracked，bodyFuture 的错误由 catchError 兜底防止野错误
    final tracked = body.then((_) => 'body');
    unawaited(body.catchError((Object e, StackTrace st) {}));
    while (true) {
      final completed = await Future.any<Object>([
        tracked,
        Future<Object>.delayed(const Duration(seconds: 5), () => 'tick'),
      ]);
      if (completed == 'body') {
        // body 结束可能正是取消 break（非正常收尾）——补一次检查
        checkAbort();
        if (abortError != null) {
          throw abortError!;
        }
        return received;
      }
      if (abortError != null) {
        throw abortError!;
      }
    }
  } finally {
    watchdog.cancel();
  }
}
