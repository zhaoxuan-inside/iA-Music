// 契约用法示例（S0）：仅示意 Port 消费形态，不含业务实现。
import 'package:contracts/contracts.dart';

void main() {
  // 双态引擎的调用方视角（实现注入，AMPI 工程于 S3 落地）
  // final EnginePort engine = resolve<EnginePort>();
  // engine.loadAndPlay(QueueSnapshot(items: [...], startIndex: 0), 0);

  // 音质族（§5.2）与纯音乐判定（REQ-LYRAI-05）
  const qualities = Quality.values;
  assert(qualities.length == 4);
  const result = AsrResult(segments: []);
  assert(result.isNoVoice);
}
