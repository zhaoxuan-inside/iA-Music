/// 封面在线来源契约。
library;

import '../errors.dart';

class CoverQuery {
  const CoverQuery({required this.title, required this.artist, this.album});

  final String title;
  final String artist;
  final String? album;
}

class CoverResult {
  const CoverResult({required this.bytes, required this.contentType});

  final List<int> bytes;
  final String contentType;
}

abstract class CoverFetchPort {
  /// 在线抓取（实现内含限速与多级来源）；未命中返回 null。
  /// 网络不可达 → 抛 [NetworkError]（调用方按曲目冷却，不重试风暴）。
  Future<CoverResult?> fetch(CoverQuery query);
}
