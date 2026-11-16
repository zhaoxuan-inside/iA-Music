/// B 站扫码登录的落库事务：cookie 汇源 → 归一化 → 读回校验。
///
/// 独立于页面：登录页的成功分支、返回时的兜底轮询、测试共用同一条路径，
/// 避免出现「界面以为登录成功、磁盘其实没写」的两套逻辑。
library;

import 'bilibili_client.dart';
import 'platform_store.dart';

/// 落库结果（[cookieHeader] 为读回校验后的真实内容）。
class BiliLoginCommit {
  const BiliLoginCommit({required this.ok, this.cookieHeader, this.account});

  final bool ok;
  final String? cookieHeader;
  final PlatformAccount? account;
}

/// 把一次成功轮询的 cookie 持久化。
///
/// 失败返回 `ok = false`，且不覆盖本机已有的登录态——
/// 避免「一次异常轮询把原来的登录态冲掉」。
Future<BiliLoginCommit> commitBiliLogin({
  required BilibiliClient client,
  required PlatformStore store,
  required BiliQrPoll poll,
}) async {
  final cookies = poll.cookies ?? const <String, String>{};
  if (cookies.isEmpty) {
    return const BiliLoginCommit(ok: false);
  }

  // buvid 一并入库：登录态 + 设备指纹同源，后续 api 域请求不被 -412。
  final merged = <String, String>{...cookies};
  final buvid = await client.anonymousBuvid();
  if (buvid != null) {
    merged.addAll(buvid);
  }
  await store.saveCookies(PlatformId.bilibili, client.cookieHeaderFrom(merged));

  // 读回校验：只有真的落库才算成功。
  final readBack = await store.cookies(PlatformId.bilibili);
  if (readBack == null || readBack.isEmpty) {
    return const BiliLoginCommit(ok: false);
  }

  final mid = poll.message; // 'mid=xxx'
  final account = PlatformAccount(
    name: mid != null && mid.startsWith('mid=')
        ? 'B 站用户 ${mid.substring(4)}'
        : 'B 站账号',
    extra: const {},
  );
  await store.saveAccount(PlatformId.bilibili, account);
  return BiliLoginCommit(ok: true, cookieHeader: readBack, account: account);
}
