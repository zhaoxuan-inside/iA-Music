/// AcoustID 配置（三分离：client key 属配置层）。
///
/// 默认使用 AcoustID 官方 webservice 文档的示例 key——**文档原文：仅供
/// 初步测试，数日后自动过期**；过期后服务端回 code 4（invalid API key），
/// 指纹链软失败自动降级文字链，补全不会瘫。正式使用请在
/// acoustid.org/new-application 注册应用专属 key（免费、永久）并在此覆盖。
/// 注意：/v2/lookup 只收表单编码（client/duration/fingerprint/meta），
/// JSON 请求一律 HTTP 400——曾经的黑屏级教训写进注释防回归。
library;

const String kAcoustidClientKey = '9JoOPij_5Ak';
const String kAcoustidLookupUrl = 'https://api.acoustid.org/v2/lookup';
