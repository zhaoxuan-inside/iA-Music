/// AcoustID 配置（三分离：client key 属配置层）。
///
/// 默认使用 AcoustID 官方文档提供的测试 key（限速但可用）；
/// 正式发布建议在 acoustid.org 注册应用专属 key 并在此覆盖。
library;

const String kAcoustidClientKey = '8XDEGREEwY';
const String kAcoustidLookupUrl = 'https://api.acoustid.org/v2/lookup';
