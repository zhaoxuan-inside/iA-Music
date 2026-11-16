/// 下载循环 + 停滞看门狗。
///
/// 移动网络/代理链路常见「流不关也不来字节」的半死连接：
/// [stall] 时间内没有新字节即判网络中断并抛错（任务转 failed，可重试），
/// 而不是永远挂在 await-for 上。
library;

import 'dart:async';
import 'dart:io';

/// 把 [source] 泵进 [sink]，返回收到的总字节数。
///
/// * [onChunk] 每收到一段调用一次（可用于进度上报；可异步）。
/// * 超过 [stall] 无新字节 → 抛停滞异常；来源流自身出错 → 原样上抛。
/// * 两种失败路径都不再触碰 sink——半截文件留给调用方处置（重跑会重写）。
Future<int> pumpDownload({
  required Stream<List<int>> source,
  required IOSink sink,
  required Future<void> Function(int received)? onChunk,
  Duration stall = const Duration(seconds: 30),
}) async {
  var received = 0;
  var last = DateTime.now();
  Object? stallError;
  final watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
    if (DateTime.now().difference(last) >= stall && stallError == null) {
      stallError = Exception('下载停滞超过 ${stall.inSeconds}s——网络中断');
    }
  });
  try {
    final body = () async {
      await for (final chunk in source) {
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
        return received;
      }
      if (stallError != null) {
        throw stallError!;
      }
    }
  } finally {
    watchdog.cancel();
  }
}
