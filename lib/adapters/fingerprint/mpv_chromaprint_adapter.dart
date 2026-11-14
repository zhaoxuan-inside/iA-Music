/// FingerprintPort 实现——mpv 解码（任意格式→PCM tap）+ chromaprint FFI 计算。
///
/// 链路：独立 mpv 实例（静音 AO，常速解码）→ af 链 aformat 强制
/// mono/11025/s16 → FilterTap 吐 Float32 PCM → 下混 Int16 喂
/// chromaprint.start/feed → finish → 压缩指纹（base64，AcoustID /v2 直接可用）。
///
/// 采集上限 110s 音频（AcoustID 惯例：指纹只取前 ~2 分钟，查询用全时长）。
/// 解码为常速（rate 1.0）：4 分钟曲目约 4 分钟完成——批次任务后台运行。
/// 原生 libchromaprint 由 chromaprint FFI 插件随包分发（android/ios/linux/macos）；
/// 缺失时 FFI 抛错 → 返回 null（调用方回退 NLP+文字链）。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:chromaprint/chromaprint.dart' as cp;
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../domain/ports/fingerprint_port.dart';

class MpvChromaprintAdapter implements FingerprintPort {
  MpvChromaprintAdapter();

  /// 采集上限（秒）：AcoustID 指纹惯例只取前 ~110s。
  static const int _maxTapSeconds = 110;

  /// tap 输出采样率（aformat 滤镜强制）。
  static const int _tapRate = 11025;

  @override
  Future<AudioFingerprint?> fingerprint(String path,
      {required int durationMs}) async {
    Player? player;
    final chromaprint = cp.Chromaprint();
    final mono = <int>[];
    final cap = _maxTapSeconds * _tapRate;
    var done = false;

    try {
      player = Player(configuration: PlayerConfiguration(
        autoPlay: false,
        initialVolume: 100, // 音量在 AO 前作用于 tap；静音靠 setMute（AO 层）
        resumePlayback: false,
      ));

      // aformat 直通滤镜：强制 mono/11025/s16——chromaprint 的标准输入
      await player.setAudioEffects([
        AformatEffect(
          enabled: true,
          sampleFmts: 's16',
          sampleRates: '$_tapRate',
          channelLayouts: 'mono',
        ),
      ]);

      final pl = player;
      final tapSub = pl.stream
          .tap(AudioFilter.aformat, side: TapSide.post)
          .listen((frame) {
        if (done) {
          return;
        }
        final samples = frame.samples;
        for (var i = 0; i < samples.length; i++) {
          final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
          mono.add(v);
          if (mono.length >= cap) {
            done = true;
            unawaited(pl.stop());
            break;
          }
        }
      });
      final completedSub =
          player.stream.completed.listen((_) => done = true);

      await player.open(Media(Uri.file(path).toString()), play: false);
      unawaited(player.play());

      // 等采集满 / 播完 / 超时墙钟（常速解码 = 时长约等于墙钟 + 60s 余量）
      final deadline =
          DateTime.now().add(Duration(milliseconds: durationMs + 60000));
      while (!done &&
          mono.length < cap &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      done = true;
      await tapSub.cancel();
      await completedSub.cancel();
      unawaited(player.stop());

      // 指纹计算：mono/11025/s16 → Int16 feed（分块，避免一次性大分配）
      chromaprint.start(_tapRate, 1);
      final pcm = Int16List.fromList(mono);
      const chunk = 8192;
      for (var off = 0; off < pcm.length; off += chunk) {
        final end = (off + chunk) < pcm.length ? (off + chunk) : pcm.length;
        chromaprint.feed(
          Int16List.sublistView(pcm, off, end),
        );
      }
      chromaprint.finish();
      final fp = chromaprint.getFingerprint();

      return AudioFingerprint(
        fingerprint: fp,
        durationMs: durationMs > 0 ? durationMs : 0,
      );
    } on Object {
      return null;
    } finally {
      chromaprint.dispose();
      try {
        await player?.dispose();
      } on Object {
        // 清理容错
      }
    }
  }
}
