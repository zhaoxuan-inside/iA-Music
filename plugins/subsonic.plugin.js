/*!
{
  "id": "app.iamusic.subsonic",
  "name": "Subsonic / Navidrome 源",
  "version": "1.0.0",
  "api": 1,
  "capabilities": ["source"],
  "author": "iA-Music",
  "homepage": "https://github.com/zhaoxuan-inside/iA-Music",
  "notes": "自托管曲库 · 登录处粘贴服务器/用户名/密码 · search3 检索 · 专辑整取 · salt+md5 token 鉴权 · lrclib 歌词"
}
*/
// ── 配置（平台知识全部在本文件） ──────────────────────────────────────

var CFG = {
  ver: '1.16.1',
  client: 'ia_music',
  lrclib: 'https://lrclib.net/api/search',
  ua: 'iA-Music/1.0 (https://github.com/zhaoxuan-inside/iA-Music)',
  limitSong: 20,
  limitAlbum: 10,
  // stream 落盘允许的扩展名（其余一律按 mp3 兜底）
  extRe: /^(mp3|m4a|aac|flac|ogg|oga|opus|wav|wma|aiff|alac)$/i
};

// ── 基件：凭据 / Subsonic 公共参数 / HTTP ─────────────────────────────

function creds() {
  var raw = IA.kvGet('creds');
  if (!raw) { return null; }
  try {
    var c = JSON.parse(raw);
    return (c && c.server && c.user && c.password) ? c : null;
  } catch (_) {
    return null;
  }
}

function requireCreds() {
  var c = creds();
  if (!c) {
    throw new Error('Subsonic 未登录——在插件页「登录」处按行粘贴：服务器地址 / 用户名 / 密码');
  }
  return c;
}

// 盐取时间戳+随机（沙箱无 crypto random），token = md5(password + salt)
function authParams(c) {
  var salt = Date.now().toString(16) + Math.floor(Math.random() * 0x100000000).toString(16);
  return 'u=' + encodeURIComponent(c.user) +
    '&t=' + IA.md5(c.password + salt) +
    '&s=' + salt +
    '&v=' + CFG.ver +
    '&c=' + CFG.client +
    '&f=json';
}

function serverRoot(c) {
  return String(c.server).replace(/\/+$/, '');
}

// Subsonic 响应包装：{ "subsonic-response": { status, error? } }
async function apiGet(path, extra) {
  var c = requireCreds();
  var url = serverRoot(c) + '/rest/' + path + '?' + authParams(c) +
    (extra ? '&' + extra : '');
  var r = await IA.fetch({ url: url, headers: { 'User-Agent': CFG.ua, 'Accept': 'application/json' } });
  if (r.status !== 200) {
    throw new Error('Subsonic 请求失败：HTTP ' + r.status + '（' + path + '）');
  }
  var d = JSON.parse(r.body);
  var inner = d && d['subsonic-response'];
  if (!inner) {
    throw new Error('Subsonic 响应无效（' + path + '）——确认服务器地址正确');
  }
  if (inner.status !== 'ok') {
    var err = inner.error || {};
    throw new Error('Subsonic 错误（' + path + '）：' +
      (err.message ? err.message + '（code ' + (err.code || '?') + '）' : '未知'));
  }
  return inner;
}

// 宿主给搜索词固定拼「分p」后缀，剥掉。
function stripFenp(q) {
  return String(q || '').replace(/分p\s*$/i, '').trim();
}

// 数字 / 数字字符串 / "MM:SS" → 秒
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

function songMeta(song) {
  return {
    id: song.id + '|' + (song.suffix || 'mp3'),
    title: song.title || ('曲目 ' + song.id),
    artist: song.artist || ''
  };
}

// ── source 契约实现（docs/PLUGIN.md §3.2） ───────────────────────────

async function match(url) {
  var m = /^subsonic:\/\/(song|album)\/([^\?#]+)/i.exec(String(url || ''));
  if (m) {
    return { id: m[1].toLowerCase() + ':' + m[2] };
  }
  return null;
}

async function authKind() { return { kind: 'cookie' }; }
async function authStart() { return {}; }
async function authPoll() { return { state: 'error', message: '本插件使用服务器凭据导入登录' }; }

// cookie 导入页复用为凭据粘贴入口：三行——服务器地址 / 用户名 / 密码。
// 粘完现场 ping 一次验连通与鉴权（拒绝坏凭据入库）。
async function authImport(text) {
  var lines = String(text || '').split(/\r?\n/).map(function (s) { return s.trim(); })
    .filter(function (s) { return s.length > 0; });
  if (lines.length < 3) {
    return {
      ok: false,
      message: '每行粘贴三项：① 服务器地址（如 http://nas:4533）② 用户名 ③ 密码'
    };
  }
  var server = lines[0];
  var user = lines[1];
  var password = lines[2]; // 第三行为密码，多余行忽略
  if (!/^https?:\/\//i.test(server)) {
    return { ok: false, message: '服务器地址要以 http:// 或 https:// 开头（Subsonic API 口径）' };
  }
  var c = { server: server, user: user, password: password };
  // 鉴权连通性验证
  try {
    var url = serverRoot(c) + '/rest/ping.view?' + authParams(c);
    var r = await IA.fetch({ url: url, headers: { 'User-Agent': CFG.ua, 'Accept': 'application/json' } });
    if (r.status !== 200) {
      return { ok: false, message: '连接失败：HTTP ' + r.status + '——确认地址可访问' };
    }
    var d = JSON.parse(r.body);
    var inner = d && d['subsonic-response'];
    if (!inner || inner.status !== 'ok') {
      var err = (inner && inner.error) || {};
      var msg = err.message || '鉴权失败';
      if (err.code === 40 || /wrong|credential|password|user/i.test(msg)) {
        return { ok: false, message: '用户名或密码不对（' + msg + '）' };
      }
      return { ok: false, message: '登录被拒：' + msg };
    }
  } catch (e) {
    return { ok: false, message: '连接失败：' + (e && e.message ? e.message : e) };
  }
  await IA.kvSet('creds', JSON.stringify(c));
  var host = server.replace(/^https?:\/\//i, '').replace(/\/.*$/, '');
  var account = user + '@' + host;
  await IA.kvSet('account', account);
  return { ok: true, account: account };
}

async function authStatus() {
  var c = creds();
  return { loggedIn: !!c, account: c ? (IA.kvGet('account') || '') : '' };
}

async function authLogout() {
  await IA.kvSet('creds', null);
  await IA.kvSet('account', null);
}

async function search(query, opts) {
  var q = stripFenp(query);
  requireCreds();
  if (!q) { return { items: [] }; }
  var inner = await apiGet('search3',
    'query=' + encodeURIComponent(q) +
    '&songCount=' + CFG.limitSong + '&albumCount=' + CFG.limitAlbum +
    '&artistCount=0');
  var res = inner.searchResult3 || {};
  var items = [];
  var songs = res.song || [];
  for (var i = 0; i < songs.length; i++) {
    var s = songs[i];
    items.push({
      id: String(s.id),
      url: 'subsonic://song/' + encodeURIComponent(s.id),
      title: s.title || ('曲目 ' + s.id),
      artist: s.artist || '',
      durationSec: parseDurSec(s.duration),
      album: s.album || null
    });
  }
  var albums = res.album || [];
  for (var j = 0; j < albums.length; j++) {
    var a = albums[j];
    items.push({
      id: String(a.id),
      url: 'subsonic://album/' + encodeURIComponent(a.id),
      title: (a.name || '专辑') + '（整张）',
      artist: a.artist || '',
      durationSec: parseDurSec(a.duration)
    });
  }
  return { items: items };
}

async function resolve(url) {
  var m = await match(url);
  if (!m) {
    throw new Error('不是有效的 Subsonic 链接（支持 subsonic://song/<id> 与 subsonic://album/<id>）：' + url);
  }
  var kind = m.id.split(':')[0];
  var rawId = m.id.split(':')[1];

  if (kind === 'song') {
    var inner = await apiGet('getSong', 'id=' + encodeURIComponent(rawId));
    var song = inner.song;
    if (!song) {
      throw new Error('Subsonic 找不到该曲目：' + rawId);
    }
    return {
      title: song.title || ('曲目 ' + rawId),
      artist: song.artist || '',
      durationSec: parseDurSec(song.duration),
      tracks: [songMeta(song)]
    };
  }

  // 专辑整取：getAlbum 返回内嵌 songs
  var inner2 = await apiGet('getAlbum', 'id=' + encodeURIComponent(rawId));
  var album = inner2.album;
  if (!album) {
    throw new Error('Subsonic 找不到该专辑：' + rawId);
  }
  var songs2 = album.song || [];
  if (!songs2.length) {
    throw new Error('该专辑没有曲目：' + (album.name || rawId));
  }
  var tracks = [];
  var total = 0;
  for (var i = 0; i < songs2.length; i++) {
    total += parseDurSec(songs2[i].duration);
    tracks.push(songMeta(songs2[i]));
  }
  return {
    title: album.name || ('专辑 ' + rawId),
    artist: album.artist || '',
    durationSec: parseDurSec(album.duration) || total,
    tracks: tracks
  };
}

async function stream(id) {
  var c = requireCreds();
  var s = String(id || '');
  var i = s.indexOf('|');
  var songId = i > 0 ? s.slice(0, i) : s;
  var suffix = i > 0 ? s.slice(i + 1) : 'mp3';
  if (!songId) {
    throw new Error('Subsonic 曲目标识无效：' + s);
  }
  if (!CFG.extRe.test(suffix.toLowerCase())) {
    suffix = 'mp3';
  }
  // /rest/stream 原始字节流响应，宿主直下（f=json 只影响元数据端点）
  return {
    url: serverRoot(c) + '/rest/stream?' + authParams(c) + '&id=' + encodeURIComponent(songId),
    ext: suffix.toLowerCase(),
    headers: { 'User-Agent': CFG.ua }
  };
}

async function lyrics(id) {
  var s = String(id || '');
  var i = s.indexOf('|');
  var songId = i > 0 ? s.slice(0, i) : s;
  var song;
  try {
    var inner = await apiGet('getSong', 'id=' + encodeURIComponent(songId));
    song = inner.song;
  } catch (_) {
    return null;
  }
  if (!song) { return null; }
  return await lrclibLyrics(song.title, song.artist);
}
