/// SecureStorePort —— 机密存取契约（flutter_secure_storage：Keystore/DPAPI/libsecret）。
///
/// 红线（C50）：凭据/流通 Cookie 只进本 Port；任何 DB/日志/Serializable 输出不得包含其实值。
library;

abstract class SecureStorePort {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  /// 键是否存在（隐私面板/Cookie 态展示；只读）。
  Future<bool> containsKey(String key);
}
