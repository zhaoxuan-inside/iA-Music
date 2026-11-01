// 契约冒烟测试（S0；编译级健在 + 异常↔文案目录完整性）
import 'package:contracts/contracts.dart';
import 'package:test/test.dart';

void main() {
  test('八类契约异常的人话文案非空（DETAILED-DESIGN §2.2 目录）', () {
    for (final e in <ContractException>[
      const EngineCapabilityException(),
      const AuthExpiredException(),
      const DuplicateSourceException(),
      const ChannelAuthFailedException(),
      const DiskFullException(),
      const NetworkLostException(),
      const AsrNoVoiceException(),
      const ModelInvalidException(),
    ]) {
      expect(e.message.trim(), isNotEmpty, reason: '${e.runtimeType} message must be human Chinese');
    }
  });

  test('音质族四档 + 纯音乐判定（§5.2 / REQ-LYRAI-05）', () {
    expect(Quality.values.length, 4);
    const noVoice = AsrResult(segments: []);
    expect(noVoice.isNoVoice, isTrue);
  });
}
