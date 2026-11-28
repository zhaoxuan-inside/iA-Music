/// EmbeddingPort 实现——LiteRT（原 TensorFlow Lite）+ YAMNet 嵌入，
/// 解码/重采样/分帧推理全部在原生侧一段完成（ia_music/embedding 通道），
/// PCM 不落盘不过 Dart。
///
/// 模块定位（与 data 同级的底层能力域）：**只负责推理**——按调用方解析
/// 出的模型文件路径装载并计算，不做任何模型文件管理（下载/存储/校验
/// 全在 data 层 ModelStore，组合根经 [resolveModel] 回调接线）。
/// 两级失败分流（契约见 embedding_port.dart）：
/// * 模型未就绪 / MissingPluginException / 原生 error code "model"
///   （模型加载/签名失败）→ null —— 端口级，调用方会话级禁用；
/// * 原生 error code "embed"（单曲解码/推理失败）→ 原样上抛 —— 曲目级，
///   调用方按曲目记账重试。
library;

import 'package:flutter/services.dart';

import '../app/config/embedding_config.dart';
import '../domain/ports/embedding_port.dart';

class LitertYamnetAdapter implements EmbeddingPort {
  /// [resolveModel] 返回当前模型文件绝对路径（null = 未就绪）；
  /// 模型文件管理在 data 层 ModelStore，由组合根注入回调。
  const LitertYamnetAdapter({required Future<String?> Function() resolveModel})
      : _resolveModel = resolveModel;

  final Future<String?> Function() _resolveModel;

  static const MethodChannel _channel = MethodChannel('ia_music/embedding');

  @override
  Future<AudioEmbedding?> embed(String path, {required int durationMs}) {
    final seconds =
        (durationMs / 1000).ceil().clamp(1, kEmbeddingMaxSeconds);
    return Future.sync(() async {
      final modelPath = await _resolveModel();
      if (modelPath == null) {
        // 模型未就绪（未下载/下载失败）：端口级不可用
        return null;
      }
      try {
        final vec = await _channel.invokeMethod<List<Object?>>('embed', {
          'path': path,
          'modelPath': modelPath,
          'maxSeconds': seconds,
        });
        if (vec == null || vec.isEmpty) {
          return null;
        }
        final values = [for (final v in vec) (v as num).toDouble()];
        if (values.length != kEmbeddingDim) {
          return null;
        }
        return AudioEmbedding(
            model: kEmbeddingModel, dim: kEmbeddingDim, vector: values);
      } on MissingPluginException {
        // 原生侧未注册（Windows 测试宿主等）：端口级不可用
        return null;
      } on PlatformException catch (e) {
        if (e.code == 'model') {
          // 模型加载/签名自检失败：端口级不可用
          return null;
        }
        rethrow; // 曲目级失败（解码/推理），调用方记账重试
      } on Object {
        return null;
      }
    });
  }
}
