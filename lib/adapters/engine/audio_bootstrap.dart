/// 后台播放初始化（AndroidX Media3 + audio_service）。
///
/// 纪律：**绝不阻塞首帧**。audio_service 绑定服务在个别机型 / 热重装后会长时间
/// 不返回，若在 `runApp` 之前 await，会一直停在启动图（模拟器实测可复现）。
/// 因此这里做成可重入的后台任务 + 超时；播放引擎在真正 `start` 前再短暂等待。
library;

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';

Future<void>? _future;

/// 幂等启动；多次调用共享同一个 future。
Future<void> ensureAudioService() => _future ??= _init();

/// 播放引擎等待后台服务绑定的上限：内部（JustAudioBackground.init）自带
/// 10s 超时 + 异常兜底，正常总会在此之前返回；此上限只兜内部链路卡死。
const Duration kAudioServiceBind = Duration(seconds: 12);

Future<void> _init() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.hardstone.iamusic.channel.audio',
      androidNotificationChannelName: 'iA-Music',
      androidNotificationOngoing: true,
    ).timeout(const Duration(seconds: 10));
  } on Object catch (e) {
    debugPrint('audio_service init failed: $e');
  }
  try {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());
  } on Object catch (e) {
    debugPrint('audio_session configure failed: $e');
  }
}
