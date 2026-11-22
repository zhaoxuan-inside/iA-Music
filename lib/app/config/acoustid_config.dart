/// AcoustID 配置（三分离：client key 属配置层）。
///
/// client key = 应用专属 key（acoustid.org/new-application 注册，免费、
/// 永久）——标识的是「应用」而非用户，随版本打包给所有 C 端用户共用；
/// 官方文档示例键数日后自动过期，不可作正式 key（v0.0.12 曾因此指纹链
/// 全灭，教训写进历史）。
/// 注意：/v2/lookup 只收表单编码（client/duration/fingerprint/meta），
/// JSON 请求一律 HTTP 400——曾经的黑屏级教训写进注释防回归。
library;

const String kAcoustidClientKey = 'v4KQKpMdRD';
const String kAcoustidLookupUrl = 'https://api.acoustid.org/v2/lookup';
