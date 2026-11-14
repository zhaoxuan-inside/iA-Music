/// NLP 噪声词表与模式（三分离：词表属配置层，可随语料扩充）。
/// 用途：原始标题串分词后，识别并剔除「非歌名」token。
library;

/// 媒体/来源噪声关键词（不区分大小写，子串命中即判噪声）。
const List<String> kNlpNoiseKeywords = [
  'official', 'mv', 'audio', 'video', 'live', 'hd', '4k', '8k', '60fps',
  'remaster', 'remastered', 'lyrics', '歌词', '歌词版', '字幕', '完整版',
  '高清', '蓝光', '无损', 'flac', 'ape', 'mp3', 'wav', 'hq', 'sq',
  'instrumental', '伴奏', '纯音乐', '翻唱', 'cover', 'cover版', 'pv',
  '现场', 'live版', 'concert', '自取', '自存', '备份', '存档',
];

/// 来源站特征（来源标识，非歌曲名的一部分）。
const List<String> kNlpSourceHints = [
  'bilibili', 'b站', '哔哩哔哩', 'youtube', 'yt', '油管',
  '网易云', '网易云音乐', 'qq音乐', 'QQ音乐', '酷狗', '酷我',
  '抖音', 'tiktok', 'snd', 'acfun', 'music.163',
];

/// 纯数字 token（曲号/清晰度/分辨率等）视为噪声。
bool kNlpIsNumericToken(String token) =>
    RegExp(r'^\d+$').hasMatch(token);
