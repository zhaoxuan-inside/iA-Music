import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adapters/engine/audio_bootstrap.dart';
import 'app/app.dart';
import 'state/diagnostics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 先出界面：后台播放初始化在个别环境下会长时间不返回，
  // 任何 await 都不能挡在 runApp 之前（否则会卡在启动图）。
  final container = ProviderContainer();
  // 任何来源的异常（框架/未捕获异步/平台）都进诊断记录，
  // 常驻「设置 · 存储」可读、可复制——真机上不再一闪而过。
  installDiagnostics(container);
  runApp(UncontrolledProviderScope(container: container, child: const IaApp()));

  // 后台播放 / 锁屏 / 耳机键：AndroidX Media3 + audio_service（异步就绪）。
  unawaited(ensureAudioService());
}
