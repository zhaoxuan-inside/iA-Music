/// 收集域配置：平台 API 端点 / 客户端语境 / 预置目录 / 命名规则。
///
/// 三分离：端点与常量只活在本文件；服务层按需引用，禁止在业务代码里散落 URL。
/// 这里只有配置，没有任何预置内容数据。
library;

/// Android 预置候选目录（存在才可选；真实扫描入库走 ScanService）。
const List<String> kPresetMusicDirs = [
  '/storage/emulated/0/Music',
  '/storage/emulated/0/Download',
];

/// 目录浏览器起点（Android 共享存储根）。
const String kDirectoryBrowserRoot = '/storage/emulated/0';

/// 下载文件命名：'{artist} - {title}.{ext}'（artist 为空时 '{title}.{ext}'）。
const String kDownloadNamePattern = '@artist - @title';

/// ── B 站 ────────────────────────────────────────────────────────────

abstract final class KBili {
  static const String host = 'https://api.bilibili.com';

  /// 扫码登录走 passport 域（api 域对 passport 路由返回 404）。
  static const String passportHost = 'https://passport.bilibili.com';

  /// 端点路径（client 按 host 组装；测试注入本地服务地址复用同一套路径）。
  static const String qrGeneratePath = '/x/passport-login/web/qrcode/generate';
  static const String qrPollPath = '/x/passport-login/web/qrcode/poll';
  static const String wbiNavPath = '/x/web-interface/nav';
  static const String searchTypePath = '/x/web-interface/wbi/search/type';
  static const String videoInfoPath = '/x/web-interface/view';
  static const String playurlPath = '/x/player/playurl';
  static const String playerInfoPath = '/x/player/wbi/v2';

  /// 匿名设备指纹（buvid3/buvid4）：无 buvid 的 api 请求常被 -412。
  static const String fingerSpiPath = '/x/frontend/finger/spi';

  /// 音频流请求 Referer（防盗链必需）。
  static const String referer = 'https://www.bilibili.com/';

  /// 客户端 UA。
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';

  /// DASH 音频档位 id（质量从高到低）。
  static const List<int> audioQualityIds = [30280, 30232, 30216];

  /// 登录轮询状态码（data.code；官方口径）：
  /// 0=成功（附 cookies）；86090=已扫码待确认；86101=未扫码；86038=二维码已失效。
  static const int pollSuccess = 0;
  static const int pollScanned = 86090;
  static const int pollWaiting = 86101;
  static const int pollExpired = 86038;

  /// 二维码有效期：B 站登录页为 180s，超时后 poll 返回 86038。
  /// 客户端按此倒计时到点即换新码，86038 仅作服务端兜底。
  static const Duration qrLifetime = Duration(seconds: 180);
}

/// ── YouTube（InnerTube 公开客户端语境） ──────────────────────────────

abstract final class KYt {
  static const String innerTube =
      'https://music.youtube.com/youtubei/v1';

  static const String search = '$innerTube/search?prettyPrint=false';
  static const String player = '$innerTube/player?prettyPrint=false';

  /// WEB_REMIX（YT Music Web）公开 API key——搜索无需登录。
  static const String webRemixKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  static const String webRemixName = 'WEB_REMIX';
  static const String webRemixVersion = '1.20240401.01.00';

  /// ANDROID 客户端语境——播放流通常无需解密签名。
  static const String androidName = 'ANDROID';
  static const String androidVersion = '19.09.37';
  static const String androidSdk = '30';
  static const String androidUserAgent =
      'com.google.android.apps.youtube.music/19.09.37 '
      '(Linux; U; Android 13) gzip';

  /// 登录采用 cookie 导入（浏览器登录后粘贴 Cookie 头）。
  /// 校验依据：包含 SAPISID 或 __Secure-3PAPISID。
  static const List<String> requiredCookieNames = [
    'SAPISID',
    '__Secure-3PAPISID',
  ];
}
