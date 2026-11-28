/*!
{
  "id": "app.iamusic.jamendo",
  "name": "Jamendo 音乐源",
  "version": "1.0.0",
  "api": 1,
  "capabilities": ["source"],
  "author": "iA-Music",
  "homepage": "https://github.com/zhaoxuan-inside/iA-Music",
  "notes": "CC 授权独立音乐 · client_id 登录（developer.jamendo.com 免费注册）· 站内搜索 · 专辑整取 · lrclib 歌词"
}
*/
// ── 配置（平台知识全部在本文件） ──────────────────────────────────────

var CFG = {
  api: 'https://api.jamendo.com/v3.0',
  site: 'https://www.jamendo.com',
  ua: 'iA-Music/1.0 (https://github.com/zhaoxuan-inside/iA-Music)',
  lrclib: 'https://lrclib.net/api/search',
  limit: 20
};

// ── 基件：client_id / HTTP / 纯函数 ───────────────────────────────────

// 宿主给搜索词固定拼「分p」后缀（分P采集提示），第三方 API 不认，剥掉。
function stripFenp(q) {
  return String(q || '').replace(/分p\s*$/i, '').trim();
}

function clientId() {
  return IA.kvGet('client_id') || '';
}

function requireClientId() {
  var id = clientId();
  if (!id) {
    throw new Error('Jamendo 需要免费 client_id——在插件页「登录」处粘贴（developer.jamendo.com 注册应用即得）');
  }
  return id;
}

function getJson(path, params) {
  var qs = '?client_id=' + encodeURIComponent(clientId()) + '&format=json';
  var names = Object.keys(params || {});
  for (var i = 0; i < names.length; i++) {
    qs += '&' + names[i] + '=' + encodeURIComponent(params[names[i]]);
  }
  return IA.fetch({ url: CFG.api + path + qs, headers: { 'User-Agent': CFG.ua } })
    .then(function (r) {
      if (r.status !== 200) {
        throw new Error('Jamendo 请求失败：HTTP ' + r.status);
      }
      var d = JSON.parse(r.body);
      // Jamendo 包装层：{ headers: { status, code, error_message }, results: [...] }
      if (!d || !d.headers || d.headers.status !== 'ok') {
        throw new Error('Jamendo API 错误：' +
          ((d && d.headers && d.headers.error_message) || '未知错误'));
      }
      return d.results || [];
    });
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

function trackToItem(t) {
  return {
    id: String(t.id),
    url: CFG.site + '/track/' + t.id,
    title: t.name || ('曲目 ' + t.id),
    artist: t.artist_name || '',
    durationSec: parseDurSec(t.duration),
    album: t.album_name || null
  };
}

function trackMeta(t) {
  return { id: String(t.id), title: t.name || ('曲目 ' + t.id), artist: t.artist_name || '' };
}

// ── source 契约实现（docs/PLUGIN.md §3.2） ───────────────────────────

async function match(url) {
  var m = /^https?:\/\/(www\.)?jamendo\.com\/(track|album)\/(\d+)/i.exec(String(url || ''));
  if (m) {
    return { id: 'jamendo:' + m[2].toLowerCase() + ':' + m[3] };
  }
  return null;
}

async function authKind() { return { kind: 'cookie' }; }
async function authStart() { return {}; }
async function authPoll() { return { state: 'error', message: '本插件使用 client_id 导入登录' }; }

// cookie 导入页复用为 client_id 粘贴入口（校验规则由插件定义）。
async function authImport(text) {
  var t = String(text || '').trim();
  if (!/^[a-f0-9]{32}$/i.test(t)) {
    return {
      ok: false,
      message: '请粘贴 Jamendo client_id（32 位十六进制）——' +
        'developer.jamendo.com 免费注册应用即得'
    };
  }
  await IA.kvSet('client_id', t.toLowerCase());
  await IA.kvSet('account', 'client_id 已配置');
  return { ok: true, account: 'client_id 已配置' };
}

async function authStatus() {
  return { loggedIn: !!clientId(), account: clientId() ? 'client_id 已配置' : '' };
}

async function authLogout() {
  await IA.kvSet('client_id', null);
  await IA.kvSet('account', null);
}

async function search(query, opts) {
  var q = stripFenp(query);
  requireClientId();
  if (!q) { return { items: [] }; }
  var list = await getJson('/tracks/', { search: q, limit: CFG.limit });
  return { items: list.map(trackToItem) };
}

async function resolve(url) {
  var m = await match(url);
  if (!m) {
    throw new Error('不是有效的 Jamendo 链接：' + url);
  }
  var kind = m.id.split(':')[1];
  var numId = m.id.split(':')[2];

  if (kind === 'track') {
    var list = await getJson('/tracks/', { id: numId });
    if (!list.length) {
      throw new Error('Jamendo 找不到该曲目：' + numId);
    }
    var t = list[0];
    return {
      title: t.name || ('曲目 ' + numId),
      artist: t.artist_name || '',
      durationSec: parseDurSec(t.duration),
      tracks: [trackMeta(t)]
    };
  }

  // 专辑整取：/tracks/?album_id 优先，/albums/tracks 兜底（两代参数口径）
  var sub = [];
  try {
    sub = await getJson('/tracks/', { album_id: numId, limit: 200 });
  } catch (_) {
    sub = [];
  }
  if (!sub.length) {
    try {
      var albums = await getJson('/albums/tracks/', { id: numId, limit: 200 });
      // /albums/tracks 返回专辑对象、曲目内嵌 tracks；直接曲目数组也兜住
      if (albums.length && albums[0] && albums[0].tracks) {
        sub = albums[0].tracks || [];
      } else if (albums.length && albums[0] && albums[0].duration != null) {
        sub = albums;
      }
    } catch (_) {
      sub = [];
    }
  }
  if (!sub.length) {
    throw new Error('Jamendo 该专辑没有可取的曲目：' + numId);
  }
  var total = 0;
  var metas = [];
  for (var i = 0; i < sub.length; i++) {
    total += parseDurSec(sub[i].duration);
    metas.push(trackMeta(sub[i]));
  }
  return {
    title: (sub[0] && sub[0].album_name) || ('专辑 ' + numId),
    artist: (sub[0] && sub[0].artist_name) || '',
    durationSec: total,
    tracks: metas
  };
}

async function stream(id) {
  var list = await getJson('/tracks/', { id: String(id) });
  if (!list.length) {
    throw new Error('Jamendo 找不到该曲目：' + id);
  }
  // audiodownload 是完整音质文件（收集落盘语义），audio 是预览流
  var u = list[0].audiodownload || list[0].audio;
  if (!u) {
    throw new Error('Jamendo 该曲目没有可下载的音频');
  }
  return { url: u, ext: 'mp3', headers: { 'User-Agent': CFG.ua } };
}

async function lyrics(id) {
  var list;
  try {
    list = await getJson('/tracks/', { id: String(id) });
  } catch (_) {
    return null;
  }
  if (!list.length) { return null; }
  return await lrclibLyrics(list[0].name, list[0].artist_name);
}
