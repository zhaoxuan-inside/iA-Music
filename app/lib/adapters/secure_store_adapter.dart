/// SecureStorePort 三端 adapter（flutter_secure_storage 直桥）。
///
/// * Android=Keystore / Windows=DPAPI+AES-GCM / Linux=libsecret keyring（未装 keyring
///   时插件报平台异常——顶部提示用户初始化 keyring，不做明文降级）。
/// * C50：本类是 Cookie/凭据唯一出入点；调用方禁止把返回值写盘/写日志。
/// * S1 安装=代码级契约一致（implements SecureStorePort）；**运行时验证在 S2 开机集成 + S8 同步链路真用**（DEC-010 不做替身）。
library;

import 'package:contracts/contracts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStoreAdapter implements SecureStorePort {
  SecureStoreAdapter({FlutterSecureStorage? storage}) : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _s.delete(key: key);

  @override
  Future<bool> containsKey(String key) => _s.containsKey(key: key);
}
