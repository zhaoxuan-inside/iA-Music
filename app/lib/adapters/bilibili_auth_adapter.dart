/// BilibiliAuthAdapter —— B 站登录域（扫码主路 + Cookie 粘贴兜底）。
///
/// 通道（EXP-2026-10-24 实测）：
/// * 扫码：`passport/qrcode/generate` 出 QR → `passport/qrcode/poll` 轮询
///   （86101=待扫 / 86090=已扫待确认 / 86038=过期 / 0=成功）。成功响应的
///   Set-Cookie 由 BilibiliClient 响应处理自动合池 → 此处持久化 Netscape
///   全量到 SecureStore（键=`bilibili.cookies`，=ExtractQueue.kCookieKey
///   同字面——下载器消费面）。
/// * 账号态：`nav`（携 Cookie）→ isLogin/uname/face/level。
/// * 纪律（C50）：Cookie 值不落 DB/日志；SecureStore 唯一进出。
library;

import 'package:ia_music/adapters/bilibili_client.dart';

/// 扫码会话（QR 内容=url；qrcodeKey=轮询凭据）。
final class BiliQrSession {
  const BiliQrSession({required this.qrContent, required this.qrcodeKey});
  final String qrContent;
  final String qrcodeKey;
}

/// 轮询状态机（UI 直映）。
enum BiliQrState { waiting, scanned, confirmed, expired }

/// 轮询一步的结论（confirmed 携账号；UI 组织人话文案）。
final class BiliQrPoll {
  const BiliQrPoll(this.state, {this.account});
  final BiliQrState state;
  final BiliAccount? account;
}

/// 登录账号面（展示字段；不携任何 Cookie 值）。
final class BiliAccount {
  const BiliAccount({
    required this.isLogin,
    this.uname,
    this.faceUrl,
    this.level = 0,
  });
  final bool isLogin;
  final String? uname;
  final String? faceUrl;
  final int level;

  static const BiliAccount anonymous = BiliAccount(isLogin: false);
}

final class BilibiliAuthAdapter {
  BilibiliAuthAdapter({BilibiliClient? client})
      : _client = client ?? BilibiliClient();

  final BilibiliClient _client;

  BilibiliClient get client => _client;

  /// 出新二维码（过期重出走同一入口）。
  Future<BiliQrSession> createQrLogin() async {
    await _client.ensureBootstrapped();
    final j = await _client.getJson(Uri.parse(
        'https://passport.bilibili.com/x/passport-login/web/qrcode/generate'));
    if (j['code'] != 0) {
      throw FormatException('登录二维码获取失败（${j['code']}）');
    }
    final d = (j['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final url = '${d['url'] ?? ''}';
    final key = '${d['qrcode_key'] ?? ''}';
    if (url.isEmpty || key.isEmpty) {
      throw const FormatException('登录二维码数据不完整');
    }
    return BiliQrSession(qrContent: url, qrcodeKey: key);
  }

  /// 轮询一步（UI 2s 节拍；confirmed 后停）。
  ///
  /// 成功路径：响应 Set-Cookie 已由 getJson 合池 → persistJar 落 SecureStore。
  Future<BiliQrPoll> pollQrLogin(String qrcodeKey) async {
    final j = await _client.getJson(Uri.parse(
        'https://passport.bilibili.com/x/passport-login/web/qrcode/poll?qrcode_key=$qrcodeKey'));
    if (j['code'] != 0) {
      throw FormatException('登录状态查询失败（${j['code']}）');
    }
    final d = (j['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    switch ('${d['code'] ?? 86101}') {
      case '0':
        await _client.persistJar();
        return BiliQrPoll(BiliQrState.confirmed, account: await fetchAccount());
      case '86090':
        return const BiliQrPoll(BiliQrState.scanned);
      case '86038':
        return const BiliQrPoll(BiliQrState.expired);
      default:
        return const BiliQrPoll(BiliQrState.waiting);
    }
  }

  /// Cookie 粘贴导入（`k=v; k2=v2` 或 Netscape 文本）→ 是否含登录键。
  Future<bool> importCookieText(String raw) async {
    await _client.ensureBootstrapped();
    final ok = _client.importCookieText(raw);
    if (ok) {
      await _client.persistJar();
    }
    return ok;
  }

  /// 账号态（nav；携池内 Cookie）。
  Future<BiliAccount> fetchAccount() async {
    await _client.ensureBootstrapped();
    try {
      final j = await _client
          .getJson(Uri.parse('https://api.bilibili.com/x/web-interface/nav'));
      final d = (j['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (d['isLogin'] != true) {
        return BiliAccount.anonymous;
      }
      final level =
          ((d['level_info'] as Map?)?['current_level'] as num?)?.toInt() ?? 0;
      return BiliAccount(
        isLogin: true,
        uname: '${d['uname'] ?? ''}',
        faceUrl: '${d['face'] ?? ''}',
        level: level,
      );
    } on Exception {
      return BiliAccount.anonymous; // 网络失败=按未登录展示（不伪造在线）
    }
  }

  /// 登出。
  Future<void> logout() => _client.clearLoginCookies();
}
