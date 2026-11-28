/*!
{
  "id": "app.iamusic.audius",
  "name": "Audius 音乐源",
  "version": "1.0.0",
  "api": 1,
  "capabilities": ["source"],
  "author": "iA-Music",
  "homepage": "https://github.com/zhaoxuan-inside/iA-Music",
  "notes": "去中心化音乐平台 · 艺术家自主上传 · 站内搜索 · 内容节点 320k 直链 · lrclib 歌词"
}
*/
// ── 配置（平台知识全部在本文件） ──────────────────────────────────────

var CFG = {
  // api.audius.co 既是节点索引也是可用的 discovery 节点（2026-11 实测：
  // search / track 均可达）；流直链取 track 对象内嵌 stream.url（内容节点 CID 地址）
  api: 'https://api.audius.co',
  appName: 'ia_music',
  ua: 'iA-Music/1.0 (https://github.com/zhaoxuan-inside/iA-Music)',
  lrclib: 'https://lrclib.net/api/search',
  limit: 20
};

// ── 基件：HTTP / 纯函数 ────────────────────────────────────────────────

// 宿主给搜索词固定拼「分p」后缀（分P采集提示），第三方 API 不认，剥掉。
function stripFenp(q) {
  return String(q || '').replace(/分p\s*$/i, '').trim();
}

async function apiGet(path, params) {
  var qs = '?app_name=' + encodeURIComponent(CFG.appName);
  var names = Object.keys(params || {});
  for (var i = 0; i < names.length; i++) {
    qs += '&' + names[i] + '=' + encodeURIComponent(params[names[i]]);
  }
  var r = await IA.fetch({
    url: CFG.api + path + qs,
    headers: { 'User-Agent': CFG.ua, 'Accept': 'application/json' }
  });
  if (r.status !== 200) {
    throw new Error('Audius 请求失败：HTTP ' + r.status);
  }
  var d = JSON.parse(r.body);
  if (d && d.data) { return d.data; }
  return d;
}

// 数字 / 数字字符串 / "MM:SS" / "HH:MM:SS" → 秒
function parseDurSec(x) {
  var s = String(x == null ? '' : x).trim();
  if (!s) { return 0; }
  if (/^\d+(\.\d+)?$/.test(s)) { return Math.round(parseFloat(s)); }
  var parts = s.split(':');
  var n = 0;
  for (var i = 0; i < parts.length; i++) {
    var v = parseInt(parts[i], 10);
    if (isNaN(v)) { return 0; }
    n = n * 60 + v;
  }
  return n;
}

// 歌词回退：lrclib.net（免登录，社区歌词库）。
async function lrclibLyrics(title, artist) {
  try {
    var q = CFG.lrclib + '?track_name=' + encodeURIComponent(title || '');
    if (artist) { q += '&artist_name=' + encodeURIComponent(artist); }
    var r = await IA.fetch({ url: q, headers: { 'User-Agent': CFG.ua } });
    if (r.status !== 200) { return null; }
    var list = JSON.parse(r.body);
    if (!list || !list.length) { return null; }
    // 有逐行同步歌词优先，其次纯文本；找不到不硬造
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].syncedLyrics) { return { synced: list[i].syncedLyrics }; }
    }
    for (var j = 0; j < list.length; j++) {
      if (list[j] && list[j].plainLyrics) { return { plain: list[j].plainLyrics }; }
    }
    return null;
  } catch (_) {
    return null; // 歌词是软需求，失败不拖垮提取
  }
}

// permalink（/handle/slug-<trackId>）→ 数字 track_id
// 实测 slug 尾段恒为数字 track_id（2026-11）；解析失败回 0
function trackIdFromUrl(url) {
  var m = /^https?:\/\/([^\/]*\.)?audius\.co\/[^\/]+\/([^\?#]+)/i.exec(String(url || ''));
  if (!m) { return 0; }
  var t = /(\d+)$/.exec(decodeURIComponent(m[2]));
  return t ? parseInt(t[1], 10) : 0;
}

function trackToItem(t) {
  return {
    id: String(t.track_id || t.id || ''),
    url: 'https://audius.co' + (t.permalink || ('/' + (t.user && t.user.handle ? t.user.handle : 'x') + '/' + t.slug)),
    title: t.title || '未知曲目',
    artist: (t.user && t.user.name) || '',
    durationSec: parseDurSec(t.duration)
  };
}

// 取单曲完整对象（含 stream.url）；id 接受数字 track_id
async function fetchTrack(trackId) {
  var t = await apiGet('/v1/tracks/' + encodeURIComponent(String(trackId)));
  if (!t || !t.track_id) {
    throw new Error('Audius 找不到该曲目：' + trackId);
  }
  return t;
}

// ── source 契约实现（docs/PLUGIN.md §3.2） ───────────────────────────

async function match(url) {
  var id = trackIdFromUrl(url);
  return id ? { id: String(id) } : null;
}

async function authKind() { return { kind: 'none' }; }
async function authStart() { return {}; }
async function authPoll() { return { state: 'error', message: '无需登录' }; }
async function authImport() { return { ok: false, message: '无需登录' }; }
async function authStatus() { return { loggedIn: true, account: '免登录' }; }
async function authLogout() { return {}; }

async function search(query, opts) {
  var q = stripFenp(query);
  if (!q) { return { items: [] }; }
  var list = await apiGet('/v1/tracks/search', { query: q });
  var arr = Object.prototype.toString.call(list) === '[object Array]' ? list : [];
  var items = [];
  for (var i = 0; i < arr.length && items.length < CFG.limit; i++) {
    var t = arr[i];
    // 不可流播放的（下架/封禁/纯下载向）不给用户选
    if (t && t.is_streamable === false) { continue; }
    items.push(trackToItem(t));
  }
  return { items: items };
}

async function resolve(url) {
  var trackId = trackIdFromUrl(url);
  if (!trackId) {
    throw new Error('不是有效的 Audius 曲目链接：' + url);
  }
  var t = await fetchTrack(trackId);
  return {
    title: t.title || String(trackId),
    artist: (t.user && t.user.name) || '',
    durationSec: parseDurSec(t.duration),
    tracks: [{
      id: String(t.track_id),
      title: t.title || String(trackId),
      artist: (t.user && t.user.name) || ''
    }]
  };
}

async function stream(id) {
  var trackId = String(id || '').trim();
  if (!/^\d+$/.test(trackId)) {
    throw new Error('Audius 曲目标识无效：' + trackId);
  }
  var t = await fetchTrack(trackId);
  if (t.is_stream_gated) {
    throw new Error('Audius 该曲目需要订阅/持有解锁，暂不支持提取');
  }
  if (t.is_streamable === false || !t.stream || !t.stream.url) {
    throw new Error('Audius 该曲目不可流播放');
  }
  // stream.url 为内容节点 CID 直链（mp3 320k 为主）；每次现取，规避节点迁移
  return {
    url: t.stream.url,
    ext: 'mp3',
    headers: { 'User-Agent': CFG.ua }
  };
}

async function lyrics(id) {
  var t;
  try {
    t = await fetchTrack(String(id || '').trim());
  } catch (_) {
    return null;
  }
  return await lrclibLyrics(t.title, t.user && t.user.name);
}
