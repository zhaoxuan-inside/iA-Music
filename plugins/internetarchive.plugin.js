/*!
{
  "id": "app.iamusic.internetarchive",
  "name": "Internet Archive 音频源",
  "version": "1.0.0",
  "api": 1,
  "capabilities": ["source"],
  "author": "iA-Music",
  "homepage": "https://github.com/zhaoxuan-inside/iA-Music",
  "notes": "公有领域/netlabel/现场录音海量音频 · 条目解析整取 · 直链下载 · lrclib 歌词"
}
*/
// ── 配置（平台知识全部在本文件） ──────────────────────────────────────

var CFG = {
  host: 'https://archive.org',
  ua: 'iA-Music/1.0 (https://github.com/zhaoxuan-inside/iA-Music)',
  lrclib: 'https://lrclib.net/api/search',
  limit: 20,
  // 可提取的音频后缀（IA 文件名小写为主，i 后缀兼容稳妥）
  audioRe: /\.(mp3|m4a|flac|ogg|oga)$/i,
  sampleRe: /(^|\/)(.*_)?sample[^\/]*$/i
};

// ── 基件：HTTP / 纯函数 ────────────────────────────────────────────────

// 宿主给搜索词固定拼「分p」后缀（分P采集提示），第三方 API 不认，剥掉。
function stripFenp(q) {
  return String(q || '').replace(/分p\s*$/i, '').trim();
}

function fetchText(url) {
  return IA.fetch({ url: url, headers: { 'User-Agent': CFG.ua } })
    .then(function (r) {
      if (r.status !== 200) {
        throw new Error('Internet Archive 请求失败：HTTP ' + r.status);
      }
      return r.body;
    });
}

// 数字 / 数字字符串 / "MM:SS" / "HH:MM:SS" → 秒（IA metadata 的 length 两种都出现）
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

// 条目标识（identifier）解析：仅认领 /details/ 条目页
function parseIdentifier(url) {
  var m = /^https?:\/\/([^\/]*\.)?archive\.org\/details\/([^\/\?#]+)/i.exec(String(url || ''));
  return m ? decodeURIComponent(m[2]) : null;
}

// 文件名去后缀、去条目前缀、去纯数字编号 → 展示标题
function fileTitle(name) {
  var t = String(name || '').replace(/\.(mp3|m4a|flac|ogg|oga)$/i, '');
  t = t.replace(/^[\s\d._-]{1,8}(?=[^\s\d._-])/, ''); // "01. " / "07 - " 之类编号前缀
  t = t.replace(/[_]+/g, ' ').replace(/\s+/g, ' ').trim();
  return t || name;
}

function isExtractable(f) {
  if (!f || !f.name) { return false; }
  if (!CFG.audioRe.test(f.name)) { return false; }
  if (CFG.sampleRe.test(f.name)) { return false; } // 试听样带不入库
  return true;
}

// ── source 契约实现（docs/PLUGIN.md §3.2） ───────────────────────────

async function match(url) {
  var id = parseIdentifier(url);
  return id ? { id: id } : null;
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
  // advancedsearch 返回 { response: { numFound, docs: [...] } }
  // creator 字段可能是字符串或数组（多创作者），归一成单个字符串
  var url = CFG.host + '/advancedsearch.php?q=' + encodeURIComponent('(' + q + ') AND mediatype:audio') +
    '&fl%5B%5D=identifier&fl%5B%5D=title&fl%5B%5D=creator&rows=' + CFG.limit +
    '&page=1&output=json';
  var d = JSON.parse(await fetchText(url));
  var docs = (d && d.response && d.response.docs) || [];
  var items = [];
  for (var i = 0; i < docs.length; i++) {
    var doc = docs[i];
    if (!doc || !doc.identifier) { continue; }
    var creator = doc.creator;
    if (Object.prototype.toString.call(creator) === '[object Array]') {
      creator = creator.join(', ');
    }
    items.push({
      id: doc.identifier,
      url: CFG.host + '/details/' + encodeURIComponent(doc.identifier),
      title: doc.title || doc.identifier,
      artist: String(creator || ''),
      durationSec: 0 // 条目级时长未知，resolve 后按文件补
    });
  }
  return { items: items };
}

async function resolve(url) {
  var id = parseIdentifier(url);
  if (!id) {
    throw new Error('不是有效的 Internet Archive 条目页：' + url);
  }
  // metadata 返回 { metadata: {...}, files: [{ name, format, length, title? }] }
  var d = JSON.parse(await fetchText(CFG.host + '/metadata/' + encodeURIComponent(id)));
  if (!d || !d.files) {
    throw new Error('Internet Archive 条目元数据缺失：' + id);
  }
  var meta = d.metadata || {};
  var creator = meta.creator;
  if (Object.prototype.toString.call(creator) === '[object Array]') {
    creator = creator.join(', ');
  }
  var tracks = [];
  var total = 0;
  for (var i = 0; i < d.files.length; i++) {
    var f = d.files[i];
    if (!isExtractable(f)) { continue; }
    var sec = parseDurSec(f.length);
    total += sec;
    tracks.push({
      id: id + '|' + f.name,
      title: (f.title ? String(f.title) : fileTitle(f.name)),
      artist: String(creator || '')
    });
  }
  if (!tracks.length) {
    throw new Error('该条目没有可提取的音频文件：' + id);
  }
  return {
    title: meta.title || id,
    artist: String(creator || ''),
    durationSec: total,
    tracks: tracks
  };
}

async function stream(id) {
  var s = String(id || '');
  var i = s.indexOf('|');
  if (i <= 0) {
    throw new Error('Internet Archive 曲目标识无效：' + s);
  }
  var identifier = s.slice(0, i);
  var name = s.slice(i + 1);
  var ext = (name.match(CFG.audioRe) || ['', 'mp3'])[1].toLowerCase();
  if (ext === 'oga') { ext = 'ogg'; }
  // download 直链会 302 到存储节点，宿主下载器自动跟随
  // 文件名可能含子目录（dir/file.mp3），逐段编码保住分隔符
  var namePath = name.split('/').map(function (seg) { return encodeURIComponent(seg); }).join('/');
  return {
    url: CFG.host + '/download/' + encodeURIComponent(identifier) + '/' + namePath,
    ext: ext,
    headers: { 'User-Agent': CFG.ua }
  };
}

async function lyrics(id) {
  var s = String(id || '');
  var i = s.indexOf('|');
  if (i <= 0) { return null; }
  var name = s.slice(i + 1);
  return await lrclibLyrics(fileTitle(name), '');
}
