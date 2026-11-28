/*!
{
  "id": "app.iamusic.podcast",
  "name": "播客 RSS 源",
  "version": "1.0.0",
  "api": 1,
  "capabilities": ["source"],
  "author": "iA-Music",
  "homepage": "https://github.com/zhaoxuan-inside/iA-Music",
  "notes": "RSS 2.0 播客订阅 · 贴 feed 链接即提取全集（订阅落插件沙箱）· 已订阅节目本地检索 · enclosure 直链"
}
*/
// ── 配置（平台知识全部在本文件） ──────────────────────────────────────

var CFG = {
  ua: 'iA-Music/1.0 (https://github.com/zhaoxuan-inside/iA-Music)',
  cacheTtlMs: 6 * 3600 * 1000, // feed 解析缓存 6 小时
  maxEpisodes: 200,
  maxResults: 30,
  // 认领 feed 形 URL：路径含 /feed(s)/、/rss、.xml 结尾（裸音频直链让给宿主 direct 通道）
  feedRe: /(?:\/feed(?:s)?(?:\/|$)|\/rss(?:\/|$)|\.xml$)/i,
  reservedRe: /(^|\/)(wp-|\.)/i
};

// ── 基件：kv 订阅表 / 纯函数 ───────────────────────────────────────────

// 宿主给搜索词固定拼「分p」后缀，剥掉。
function stripFenp(q) {
  return String(q || '').replace(/分p\s*$/i, '').trim();
}

function kvJson(key, fallback) {
  var raw = IA.kvGet(key);
  if (!raw) { return fallback; }
  try {
    return JSON.parse(raw);
  } catch (_) {
    return fallback;
  }
}

// 订阅表：[{ url, title, addedAt }]
function feedList() {
  var v = kvJson('feeds', []);
  return Object.prototype.toString.call(v) === '[object Array]' ? v : [];
}

async function registerFeed(url, title) {
  var list = feedList();
  for (var i = 0; i < list.length; i++) {
    if (list[i].url === url) {
      if (title && title !== list[i].title) {
        list[i].title = title;
        await IA.kvSet('feeds', JSON.stringify(list));
      }
      return;
    }
  }
  list.unshift({ url: url, title: title || '', addedAt: Date.now() });
  await IA.kvSet('feeds', JSON.stringify(list));
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

// enclosure 字节长度按 128kbps 估算秒数（RSS 常缺 itunes:duration）
function estSec(bytes) {
  var b = parseInt(bytes, 10);
  if (!b || b <= 0) { return 0; }
  return Math.round(b * 8 / 128000);
}

// 后缀/type → 扩展名（host 直接下载落盘）
function extOf(url, type) {
  var m = /\.(mp3|m4a|m4b|aac|flac|ogg|oga|opus|wav)(?:\?|$)/i.exec(String(url || ''));
  var ext = m ? m[1].toLowerCase() : '';
  if (!ext) {
    var t = String(type || '').toLowerCase();
    if (t.indexOf('mpeg') >= 0 || t.indexOf('mp3') >= 0) { ext = 'mp3'; }
    else if (t.indexOf('m4a') >= 0 || t.indexOf('mp4') >= 0) { ext = 'm4a'; }
    else if (t.indexOf('aac') >= 0) { ext = 'aac'; }
    else if (t.indexOf('ogg') >= 0 || t.indexOf('opus') >= 0) { ext = 'ogg'; }
    else if (t.indexOf('flac') >= 0) { ext = 'flac'; }
    else { ext = 'mp3'; } // 播客托管以 mp3 绝对主流
  }
  if (ext === 'm4b') { ext = 'm4a'; }
  if (ext === 'oga') { ext = 'ogg'; }
  return ext;
}

// ── RSS 解析（RSS 2.0，含 CDATA；Atom 不在本版范围） ──────────────────

function cdata(s) {
  return String(s || '').replace(/^\s*<!\[CDATA\[/, '').replace(/\]\]>\s*$/, '').trim();
}

function tagText(itemXml, tagName) {
  var re = new RegExp('<' + tagName + '(?:\\s[^>]*)?>([\\s\\S]*?)</' + tagName + '>', 'i');
  var m = re.exec(itemXml);
  return m ? cdata(m[1]) : '';
}

function attrOf(tag, name) {
  var m = new RegExp(name + '="([^"]*)"', 'i').exec(tag);
  return m ? m[1] : '';
}

// 解析 feed XML → { title, episodes: [{ title, url, type, bytes, durationSec }] }
function parseFeed(xml) {
  var s = String(xml || '');
  var chanTitle = '';
  var head = s.slice(0, s.indexOf('<item') >= 0 ? s.indexOf('<item') : s.length);
  var chanM = /<channel[^>]*>([\s\S]*?)(?:<\/channel>|$)/i.exec(head);
  if (chanM) {
    chanTitle = cdata(tagText(chanM[1], 'title'));
  }
  var episodes = [];
  var itemRe = /<item(?:\s[^>]*)?>([\s\S]*?)<\/item>/gi;
  var m;
  while ((m = itemRe.exec(s)) && episodes.length < CFG.maxEpisodes) {
    var body = m[1];
    var title = cdata(tagText(body, 'title'));
    var encM = /<enclosure\b[^>]*/i.exec(body);
    if (!encM || !title) { continue; }
    var url = attrOf(encM[0], 'url');
    if (!url || !/^https?:\/\//i.test(url)) { continue; }
    var type = attrOf(encM[0], 'type');
    var bytes = attrOf(encM[0], 'length');
    var durationSec = parseDurSec(tagText(body, 'itunes:duration')) || estSec(bytes);
    episodes.push({ title: title, url: url, type: type, durationSec: durationSec });
  }
  return { title: chanTitle, episodes: episodes };
}

async function loadFeed(feedUrl) {
  // 解析缓存 6h：订阅检索每次打远端太重
  var cache = kvJson('cache:' + feedUrl, null);
  if (cache && cache.at && (Date.now() - cache.at) < CFG.cacheTtlMs && cache.parsed) {
    return cache.parsed;
  }
  var r = await IA.fetch({ url: feedUrl, headers: { 'User-Agent': CFG.ua } });
  if (r.status !== 200) {
    throw new Error('播客 feed 请求失败：HTTP ' + r.status);
  }
  var parsed = parseFeed(r.body);
  await IA.kvSet('cache:' + feedUrl, JSON.stringify({ at: Date.now(), parsed: parsed }));
  return parsed;
}

// ── source 契约实现（docs/PLUGIN.md §3.2） ───────────────────────────

async function match(url) {
  var s = String(url || '');
  if (/^podcast:\/\//i.test(s)) {
    return { id: s };
  }
  if (!/^https?:\/\//i.test(s)) { return null; }
  // 裸音频直链（.mp3 等）不认领——让宿主 direct 通道直接下载
  if (/\.(mp3|m4a|aac|flac|ogg|oga|opus|wav)(\?|$)/i.test(s)) { return null; }
  if (CFG.reservedRe.test(s)) { return null; }
  if (CFG.feedRe.test(s)) {
    return { id: s };
  }
  return null;
}

async function authKind() { return { kind: 'none' }; }
async function authStart() { return {}; }
async function authPoll() { return { state: 'error', message: '无需登录' }; }
async function authImport() { return { ok: false, message: '无需登录' }; }
async function authStatus() {
  var n = feedList().length;
  return { loggedIn: true, account: n ? '已订阅 ' + n + ' 档节目' : '未订阅节目' };
}
async function authLogout() {
  await IA.kvSet('feeds', null); // 仅清订阅表；单 feed 缓存随覆盖/过期自然失效
}

async function search(query, opts) {
  var q = stripFenp(query);
  if (!q) { return { items: [] }; }
  var list = feedList();
  var items = [];
  var needle = q.toLowerCase();
  for (var i = 0; i < list.length && items.length < CFG.maxResults; i++) {
    var parsed;
    try {
      parsed = await loadFeed(list[i].url);
    } catch (_) {
      continue; // 单档 feed 失效不拖垮整体检索
    }
    var title = list[i].title || parsed.title || list[i].url;
    var eps = parsed.episodes || [];
    for (var j = 0; j < eps.length && items.length < CFG.maxResults; j++) {
      var ep = eps[j];
      if ((ep.title || '').toLowerCase().indexOf(needle) < 0) { continue; }
      items.push({
        id: ep.url,
        url: 'podcast://ep?url=' + encodeURIComponent(ep.url) +
          '&title=' + encodeURIComponent(ep.title) +
          '&type=' + encodeURIComponent(extOf(ep.url, ep.type)),
        title: ep.title,
        artist: title,
        durationSec: ep.durationSec || 0
      });
    }
  }
  return { items: items };
}

async function resolve(url) {
  var s = String(url || '');

  // 形态一：podcast://ep?url=…（来自本插件搜索结果）
  if (/^podcast:\/\//i.test(s)) {
    var m = /[?&]url=([^&]+)/.exec(s);
    if (!m) {
      throw new Error('播客曲目标识无效：' + s);
    }
    var epUrl = decodeURIComponent(m[1]);
    var tM = /[?&]title=([^&]*)/.exec(s);
    return {
      title: tM ? decodeURIComponent(tM[1]) : '播客单集',
      artist: '',
      durationSec: 0,
      tracks: [{ id: epUrl, title: tM ? decodeURIComponent(tM[1]) : '播客单集', artist: '' }]
    };
  }

  // 形态二：贴 feed 链接 → 全集提取（订阅登记是副作用）
  var parsed = await loadFeed(s);
  if (!parsed.episodes.length) {
    throw new Error('该 feed 没有可提取的单集（仅支持 RSS 2.0 enclosure）：' + s);
  }
  await registerFeed(s, parsed.title);
  var feedTitle = parsed.title || '';
  var tracks = [];
  for (var i = 0; i < parsed.episodes.length; i++) {
    var ep = parsed.episodes[i];
    tracks.push({
      id: ep.url,
      title: ep.title,
      artist: feedTitle
    });
  }
  return {
    title: feedTitle || s,
    artist: '播客 RSS',
    durationSec: 0,
    tracks: tracks
  };
}

async function stream(id) {
  var u = String(id || '');
  if (!/^https?:\/\//i.test(u)) {
    throw new Error('播客单集直链无效：' + u);
  }
  return { url: u, ext: extOf(u, ''), headers: { 'User-Agent': CFG.ua } };
}

async function lyrics(id) {
  return null; // 播客是谈话内容，不做歌词
}
