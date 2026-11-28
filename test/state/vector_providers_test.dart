/// 向量相似检索纯函数测试：余弦排序口径（点积即余弦——落库向量已归一化）。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ia_music/state/vector_providers.dart';

void main() {
  test('余弦排序：同向 > 近似 > 正交 > 反向；排除自身；limit 截断', () {
    final vecs = <int, Float32List>{
      1: Float32List.fromList([1, 0]), // 种子
      2: Float32List.fromList([1, 0]), // 同向 dot=1
      3: Float32List.fromList([0, 1]), // 正交 dot=0
      4: Float32List.fromList([-1, 0]), // 反向 dot=-1
      5: Float32List.fromList([0.7, 0.714]), // 近似同向 dot≈0.7
    };
    expect(vectorTopK(1, vecs), [2, 5, 3, 4]);
    expect(vectorTopK(1, vecs, limit: 2), [2, 5], reason: 'limit 截断');
  });

  test('种子无向量 → 空表（UI 引导先跑补全）', () {
    final vecs = <int, Float32List>{
      2: Float32List.fromList([1, 0]),
    };
    expect(vectorTopK(1, vecs), isEmpty);
    expect(vectorTopK(2, vecs), isEmpty, reason: '只剩自身时同样为空');
  });
}
