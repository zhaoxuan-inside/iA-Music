/// 契约级异常（DETAILED-DESIGN §2.2：异常 ↔ UI 人话文案一一对应）
library;

/// 契约异常基类。
///
/// [message] 面向日志（可含技术细节，**绝不含 Cookie/凭据值** —— DEC-010 C50）。
sealed class ContractException implements Exception {
  const ContractException(this.message, {this.detail});

  final String message;

  /// 技术细节（可选）；不得包含机密值。
  final String? detail;

  @override
  String toString() => '$runtimeType: $message${detail == null ? '' : ' ($detail)'}';
}

/// 引擎能力不支持（如双端 EQ）——UI：「当前设备音频输出不支持均衡器调节」。
final class EngineCapabilityException extends ContractException {
  const EngineCapabilityException([super.message = '当前设备音频输出不支持均衡器调节']);
}

/// 引擎播放失败（文件载入/解码失败/会话级故障）——UI 映射：
/// 单曲失败→「无法播放该文件（格式或文件损坏），已跳过」；
/// 恢复二次失败→「播放服务异常」（DETAILED-DESIGN §3.6/§4.3；ARCH §3.2）。
final class EngineFailureException extends ContractException {
  const EngineFailureException({String message = '播放服务异常', String? detail})
      : super(message, detail: detail);
}

/// 提取登录态过期——UI：『B 站登录状态过期，请重新扫码』（REQ-EXT-05）。
final class AuthExpiredException extends ContractException {
  const AuthExpiredException([super.message = 'B 站登录状态过期，请重新扫码']);
}

/// 重复来源——UI：『该视频已提取过，可选择重新提取』（REQ-EXT-06）。
final class DuplicateSourceException extends ContractException {
  const DuplicateSourceException([super.message = '该视频已提取过，可选择重新提取']);
}

/// 同步通道授权失败——UI：『授权过期或地址/凭据有误，请重新授权』（REQ-SYNC-01/06）。
final class ChannelAuthFailedException extends ContractException {
  const ChannelAuthFailedException([super.message = '授权过期或地址/凭据有误，请重新授权']);
}

/// 磁盘空间不足——UI：『存储空间不足，已暂停；可用空间足够后继续』。
final class DiskFullException extends ContractException {
  const DiskFullException([super.message = '存储空间不足，已暂停；可用空间足够后继续']);
}

/// 形态不支持（S6 契约增量）：桌面 Process 形态在无工具链环境（如 Android）
/// 拉不起 yt-dlp 进程——与「链接失效/需登录」分属两类人话错误（2026-10-19 实况）。
final class FormUnsupportedException extends ContractException {
  const FormUnsupportedException(
      [super.message = '提取功能当前为桌面端形态（Windows），Android 端将在后续版本支持']);
}

/// 网络中断——UI：『网络连接中断，任务已暂停，本地数据不受影响』（REQ-SYNC-06 原话）。
final class NetworkLostException extends ContractException {
  const NetworkLostException([super.message = '网络连接中断，任务已暂停，本地数据不受影响']);
}

/// ASR 未检出人声——UI：『未检测到人声，未生成歌词文件』（REQ-LYRAI-05）。
///
/// 转写正常返回 `AsrResult` 且 `segments` 为空；本异常仅由歌词域在提交空结果时抛出。
final class AsrNoVoiceException extends ContractException {
  const AsrNoVoiceException([super.message = '未检测到人声，未生成歌词文件']);
}

/// 模型校验失败——UI：『模型文件校验失败，请重新下载』。
final class ModelInvalidException extends ContractException {
  const ModelInvalidException([super.message = '模型文件校验失败，请重新下载']);
}
