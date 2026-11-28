/// 音频向量相似检索的纯计算面（内存余弦索引）。
///
/// 个人库规模（≤1 万首 × 1024 维 ≈ 内存 20MB）点积查询 <1ms；
/// 10 万首天花板再上 sqlite-vec（自编译 sqlite3.c 可并编 sqlite-vec.c，
/// vec0 虚拟表 + KNN SQL）——见 ARCHITECTURE.md 数据节。
library;

import 'dart:typed_data';

/// 余弦 top-K（纯函数，可测）：落库向量已 L2 归一化——点积即相似度。
/// [vecs] = trackId → 向量；种子无向量 → 空表（UI 引导先跑补全）。
List<int> vectorTopK(int seedId, Map<int, Float32List> vecs,
    {int limit = 24}) {
  final seed = vecs[seedId];
  if (seed == null) {
    return const [];
  }
  final scored = <(int, double)>[];
  vecs.forEach((id, vec) {
    if (id == seedId) {
      return;
    }
    var dot = 0.0;
    for (var i = 0; i < seed.length && i < vec.length; i++) {
      dot += seed[i] * vec[i];
    }
    scored.add((id, dot));
  });
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final (id, _) in scored.take(limit)) id];
}
