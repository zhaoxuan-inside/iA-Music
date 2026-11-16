/// 平台账号存取：B 站 / YouTube 登录凭据的持久化与读取。
///
/// 三分离：凭据是用户数据，落 settings KV（键集中在 SettingKeys）；
/// 服务层只经本类读写，不直接触键名。
library;

import '../settings/settings_service.dart';

/// 平台标识。
enum PlatformId { bilibili, youtube }

abstract final class PlatformKeys {
  static String of(PlatformId id) => switch (id) {
        PlatformId.bilibili => 'platform.bilibili.cookies',
        PlatformId.youtube => 'platform.youtube.cookies',
      };

  static String accountOf(PlatformId id) => switch (id) {
        PlatformId.bilibili => 'platform.bilibili.account',
        PlatformId.youtube => 'platform.youtube.account',
      };
}

/// 已登录账号快照（展示用：昵称等；无敏感字段）。
class PlatformAccount {
  const PlatformAccount({required this.name, required this.extra});

  final String name;
  final Map<String, dynamic> extra;

  Map<String, dynamic> toJson() => {'name': name, ...extra};

  static PlatformAccount? fromJson(Map<String, dynamic>? json) {
    if (json == null || json['name'] is! String) {
      return null;
    }
    final name = json.remove('name') as String;
    return PlatformAccount(name: name, extra: json);
  }
}

class PlatformStore {
  PlatformStore(this._settings);

  final SettingsService _settings;

  /// cookie 头字符串（键值拼接形式，与浏览器 Cookie 头同形）。
  Future<String?> cookies(PlatformId id) =>
      _settings.getString(PlatformKeys.of(id));

  Future<void> saveCookies(PlatformId id, String cookieHeader) async {
    // 归一化：去空白键值、去重复
    final parts = <String>[];
    for (final raw in cookieHeader.split(';')) {
      final kv = raw.trim();
      if (kv.isNotEmpty) {
        parts.add(kv);
      }
    }
    await _settings.setString(PlatformKeys.of(id), parts.join('; '));
  }

  Future<void> clearCookies(PlatformId id) =>
      _settings.setString(PlatformKeys.of(id), '');

  Future<PlatformAccount?> account(PlatformId id) async {
    final json = await _settings.getJsonObject(PlatformKeys.accountOf(id));
    return PlatformAccount.fromJson(json);
  }

  Future<void> saveAccount(PlatformId id, PlatformAccount account) =>
      _settings.setJsonObject(PlatformKeys.accountOf(id), account.toJson());

  Future<void> clearAccount(PlatformId id) =>
      _settings.setString(PlatformKeys.accountOf(id), '');

  Future<bool> loggedIn(PlatformId id) async {
    final c = await cookies(id);
    return c != null && c.isNotEmpty;
  }

  /// cookie 头 → Map（请求侧便利）。
  static Map<String, String> cookieMap(String header) {
    final out = <String, String>{};
    for (final part in header.split(';')) {
      final i = part.indexOf('=');
      if (i > 0) {
        out[part.substring(0, i).trim()] = part.substring(i + 1).trim();
      }
    }
    return out;
  }
}
