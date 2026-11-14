/// 契约错误——adapter 与服务的唯一异常出口。
///
/// 纪律：adapter 不抛裸异常、不拼 UI 文案；文案映射在 UI/l10n 层。
sealed class ContractError implements Exception {
  const ContractError({required this.detail});

  /// 面向日志的定位信息（不直接展示给用户）。
  final String detail;

  @override
  String toString() => '$runtimeType($detail)';
}

/// 播放引擎域错误。
final class EngineError extends ContractError {
  const EngineError({required super.detail});
}


/// 元数据解析错误（单文件损坏等，调用方按件兜底）。
final class MetadataError extends ContractError {
  const MetadataError({required super.detail});
}

/// 歌词来源域错误。
final class LyricsError extends ContractError {
  const LyricsError({required super.detail});
}

/// 封面来源域错误。
final class CoverError extends ContractError {
  const CoverError({required super.detail});
}

/// 文件系统/扫描域错误。
final class StorageError extends ContractError {
  const StorageError({required super.detail});
}

/// 来源网络不可达（真网络失败统一入口，便于 UI 区分离线态）。
final class NetworkError extends ContractError {
  const NetworkError({required super.detail});
}
