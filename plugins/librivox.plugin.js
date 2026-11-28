/*!
{
  "id": "app.iamusic.librivox",
  "name": "LibriVox 有声书源",
  "version": "1.0.0",
  "api": 1,
  "capabilities": ["source"],
  "author": "iA-Music",
  "homepage": "https://github.com/zhaoxuan-inside/iA-Music",
  "notes": "公有领域有声书 · 精确标题/作者检索 + 全站模糊搜索兜底 · 整本书分节提取 · 文件在 archive.org 托管"
}
*/
// ── 配置（平台知识全部在本文件） ──────────────────────────────────────

var CFG = {
  site: 'https://librivox.org',
  ua: 'iA-Music/1.0 (https://github.com/zhaoxuan-inside/iA-Music)',
  limit: 20,
  // 项目页路径里不作为有声书认领的保留前缀
  reservedRe: /^\/(api|rss|pages|search|readers?|authors?|genres?|browse|new-uploads|about|blog|wp-)/i
};

// ── 基件：HTTP / 纯函数 ────────────────────────────────────────────────

// 宿主给搜索词固定拼「分p」后缀（分P采集提示），第三方 API 不认，剥掉。
function stripFenp(q) {
  return String(q || '').replace(/分p\s*$/i, '').trim();
}

async function fetchText(url) {
  var r = await IA.fetch({ url: url, headers: { 'User-Agent': CFG.ua } });
  if (r.status !== 200) {
    throw new Error('LibriVox 请求失败：HTTP ' + r.status);
  }
  return r.body;
}

// audiobooks feed API：有匹配返回 { books: [...] }，无匹配返回
// { error } + HTTP 404——统一归成空数组
async function apiBooks(params) {
  var qs = '?format=json&extended=1';
  var names = Object.keys(params || {});
  for (var i = 0; i < names.length; i++) {
    qs += '&' + names[i] + '=' + encodeURIComponent(params[names[i]]);
  }
  var r = await IA.fetch({ url: CFG.site + '/api/feed/audiobooks' + qs, headers: { 'User-Agent': CFG.ua } });
  if (r.status !== 200) {
    return [];
  }
  var d = JSON.parse(r.body);
  return (d && d.books) || [];
}

function authorNames(book) {
  var authors = (book && book.authors) || [];
  var names = [];
  for (var i = 0; i < authors.length; i++) {
    var a = authors[i];
    var full = [a && a.first_name, a && a.last_name].filter(Boolean).join(' ').trim();
    if (full) { names.push(full); }
  }
  return names.join(', ');
}

function bookUrl(book) {
  return (book && book.url_librivox) || (CFG.site + '/' + (book && book.id ? 'rss/' + book.id : ''));
}

// slug 形如 "xxx-by-author-name" → 估计作者名（仅 WP 模糊搜索兜底结果用）
function artistFromSlug(slug) {
  var m = /-by-([a-z0-9-]+)$/i.exec(String(slug || ''));
  if (!m) { return ''; }
  return m[1].split('-').map(function (w) {
    return w ? w.charAt(0).toUpperCase() + w.slice(1) : w;
  }).join(' ');
}

// 项目页 HTML → RSS id（页面固定带 <link href="…/rss/<id>"> 形态锚点）
function rssIdFromPage(html) {
  var m = /librivox\.org\/rss\/(\d+)/.exec(String(html || ''));
  return m ? parseInt(m[1], 10) : 0;
}

// ── source 契约实现（docs/PLUGIN.md §3.2） ───────────────────────────

async function match(url) {
  var s = String(url || '');
  var m = /^https?:\/\/(www\.)?librivox\.org(\/[^\/\?#]+)\/?$/i.exec(s);
  if (!m) { return null; }
  var path = m[2] || '/';
  if (CFG.reservedRe.test(path)) { return null; }
  return { id: path.slice(1) };
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
  var seen = {};
  var items = [];

  function push(book) {
    if (!book || !book.id || seen[book.id]) { return; }
    seen[book.id] = true;
    items.push({
      id: String(book.id),
      url: bookUrl(book),
      title: book.title || ('LibriVox ' + book.id),
      artist: authorNames(book),
      durationSec: parseInt(book.totaltimesecs, 10) || 0
    });
  }

  // 检索口径一：audiobooks feed API——title/author 都是整串精确匹配（实测），
  // 命中即返回结构化结果
  var byTitle = await apiBooks({ title: q, limit: CFG.limit });
  for (var i = 0; i < byTitle.length; i++) { push(byTitle[i]); }
  if (items.length < CFG.limit) {
    var byAuthor = await apiBooks({ author: q, limit: CFG.limit });
    for (var j = 0; j < byAuthor.length && items.length < CFG.limit; j++) { push(byAuthor[j]); }
  }

  // 检索口径二（兜底）：全站 WordPress 模糊搜索（?s=）——相关性一般但可发现书
  if (!items.length) {
    var html = await fetchText(CFG.site + '/?s=' + encodeURIComponent(q));
    var re = /<a href="https?:\/\/(?:www\.)?librivox\.org\/([a-z0-9-]{15,})\/?"[^>]*>([^<]{4,90})</g;
    var m;
    var slugSeen = {};
    while ((m = re.exec(html)) && items.length < CFG.limit) {
      var slug = m[1];
      if (CFG.reservedRe.test('/' + slug) || slugSeen[slug]) { continue; }
      slugSeen[slug] = true;
      items.push({
        id: slug,
        url: CFG.site + '/' + slug + '/',
        title: m[2].trim(),
        artist: artistFromSlug(slug),
        durationSec: 0
      });
    }
  }
  return { items: items };
}

// resolve：项目页 → rss/<id> → audiobooks API 按 id 取整本书（sections 内含
// archive.org 直链 listen_url 与 playtime 秒数，无需解析 RSS XML）
async function resolve(url) {
  var m = await match(url);
  if (!m) {
    throw new Error('不是有效的 LibriVox 项目页：' + url);
  }
  var html = await fetchText(CFG.site + '/' + m.id + '/');
  var bookId = rssIdFromPage(html);
  if (!bookId) {
    throw new Error('LibriVox 页面里找不到 RSS 标识（可能是非项目页）：' + m.id);
  }
  var books = await apiBooks({ id: bookId });
  if (!books.length) {
    throw new Error('LibriVox API 找不到该书：' + bookId);
  }
  var book = books[0];
  var artist = authorNames(book);
  var sections = book.sections || [];
  if (!sections.length) {
    throw new Error('该书没有可提取的章节：' + book.title);
  }
  var tracks = [];
  var total = 0;
  for (var i = 0; i < sections.length; i++) {
    var s = sections[i];
    if (!s || !s.listen_url) { continue; }
    var sec = parseInt(s.playtime, 10) || 0;
    total += sec;
    var num = parseInt(s.section_number, 10) || (i + 1);
    tracks.push({
      id: bookId + '|' + s.listen_url,
      title: '第' + num + '节 ' + (s.title || '').trim(),
      artist: artist
    });
  }
  if (!tracks.length) {
    throw new Error('该书章节没有音频直链：' + book.title);
  }
  return {
    title: book.title || ('LibriVox ' + bookId),
    artist: artist,
    durationSec: parseInt(book.totaltimesecs, 10) || total,
    tracks: tracks
  };
}

async function stream(id) {
  var s = String(id || '');
  var i = s.indexOf('|');
  if (i <= 0) {
    throw new Error('LibriVox 曲目标识无效：' + s);
  }
  var fileUrl = s.slice(i + 1);
  if (!/^https?:\/\//i.test(fileUrl)) {
    throw new Error('LibriVox 章节直链无效：' + fileUrl);
  }
  var extM = /\.(mp3|m4a|m4b|flac|ogg|oga)(?:\?|$)/i.exec(fileUrl);
  var ext = extM ? extM[1].toLowerCase() : 'mp3';
  if (ext === 'm4b') { ext = 'm4a'; }
  if (ext === 'oga') { ext = 'ogg'; }
  // listen_url 指向 archive.org/download/…，302 到存储节点，宿主自动跟随
  return { url: fileUrl, ext: ext, headers: { 'User-Agent': CFG.ua } };
}

async function lyrics(id) {
  return null; // 有声书内容，不做歌词
}
