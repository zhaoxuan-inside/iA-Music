/*!
{
  "id": "app.iamusic.bilibili",
  "name": "B 站音频源",
  "version": "1.0.0",
  "api": 1,
  "capabilities": ["source"],
  "author": "iA-Music",
  "homepage": "https://github.com/zhaoxuan-inside/iA-Music",
  "notes": "扫码登录 · wbi 签名站内搜索 · DASH 音频流 · AI 字幕转歌词"
}
*/
// ── 配置（平台知识全部在本文件；端点/常量与原宿主内置版一致） ──────────

var CFG = {
  host: 'https://api.bilibili.com',
  passport: 'https://passport.bilibili.com',
  qrGenerate: '/x/passport-login/web/qrcode/generate',
  qrPoll: '/x/passport-login/web/qrcode/poll',
  wbiNav: '/x/web-interface/nav',
  searchType: '/x/web-interface/wbi/search/type',
  videoInfo: '/x/web-interface/view',
  playurl: '/x/player/playurl',
  playerInfo: '/x/player/wbi/v2',
  fingerSpi: '/x/frontend/finger/spi',
  referer: 'https://www.bilibili.com/',
  ua: 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 ' +
      '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
  qualityIds: [30280, 30232, 30216],
  pollSuccess: 0,
  pollScanned: 86090,
  pollWaiting: 86101,
  pollExpired: 86038
};

// ── 基件：cookie / buvid / HTTP ────────────────────────────────────────

function cookieMap(header) {
  var m = {};
  String(header || '').split(';').forEach(function (p) {
    var i = p.indexOf('=');
    if (i > 0) {
      m[p.slice(0, i).trim()] = p.slice(i + 1).trim();
    }
  });
  return m;
}

function cookieHeaderFrom(map) {
  return Object.keys(map).map(function (k) { return k + '=' + map[k]; }).join('; ');
}

async function ensureBuvid() {
  var cached = await IA.kvGet('buvid');
  if (cached) {
    try {
      var o = JSON.parse(cached);
      return { buvid3: o.b3, buvid4: o.b4 || '' };
    } catch (_) { /* 坏缓存重取 */ }
  }
  var neg = await IA.kvGet('buvidFailAt');
  if (neg && Date.now() - Number(neg) < 60000) {
    return null; // 负缓存：60s 内不再白等
  }
  try {
    var r = await IA.fetch({ url: CFG.host + CFG.fingerSpi, headers: { 'User-Agent': CFG.ua } });
    var d = (JSON.parse(r.body).data) || {};
    if (d.b_3) {
      await IA.kvSet('buvid', JSON.stringify({ b3: d.b_3, b4: d.b_4 || '' }));
      return { buvid3: d.b_3, buvid4: d.b_4 || '' };
    }
  } catch (_) {
    await IA.kvSet('buvidFailAt', String(Date.now()));
  }
  return null;
}

async function effectiveCookie(withBuvid) {
  var map = cookieMap((await IA.kvGet('cookie')) || '');
  if (withBuvid && !map.buvid3) {
    var b = await ensureBuvid();
    if (b && b.buvid3) {
      map.buvid3 = b.buvid3;
      if (b.buvid4) { map.buvid4 = b.buvid4; }
    }
  }
  return Object.keys(map).length ? cookieHeaderFrom(map) : '';
}

// opts: { referer?: bool, cookie?: 'none'|'stored'|'effective' }
async function getJson(url, opts) {
  opts = opts || {};
  var headers = { 'User-Agent': CFG.ua };
  if (opts.referer) { headers['Referer'] = CFG.referer; }
  var mode = opts.cookie === undefined ? 'effective' : opts.cookie;
  if (mode !== 'none') {
    var c = mode === 'stored'
        ? ((await IA.kvGet('cookie')) || '')
        : await effectiveCookie(true);
    if (c) { headers['Cookie'] = c; }
  }
  var r = await IA.fetch({ url: url, headers: headers });
  if (r.status !== 200) {
    throw new Error('B 站请求失败：HTTP ' + r.status);
  }
  return JSON.parse(r.body);
}

function qs(obj) {
  return Object.keys(obj).map(function (k) {
    return encodeURIComponent(k) + '=' + encodeURIComponent(obj[k]);
  }).join('&');
}

// ── wbi 签名（mixin key 固定重排表 + md5） ─────────────────────────────

var MIXIN_TAB = [
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
  33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40,
  61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11,
  36, 20, 34, 44, 52
];

function wbiSign(params, imgKey, subKey) {
  var raw = imgKey + subKey;
  var mixin = '';
  for (var i = 0; i < MIXIN_TAB.length; i++) {
    if (MIXIN_TAB[i] < raw.length) { mixin += raw.charAt(MIXIN_TAB[i]); }
  }
  var salt = mixin.substring(0, 32);
  var all = {};
  Object.keys(params).forEach(function (k) { all[k] = String(params[k]); });
  all.wts = String(Math.floor(Date.now() / 1000));
  var keys = Object.keys(all).sort();
  var q = keys.map(function (k) {
    return encodeURIComponent(k) + '=' + encodeURIComponent(String(all[k]).replace(/[!'()*]/g, ''));
  }).join('&');
  all.w_rid = IA.md5(q + salt);
  return all;
}

async function wbiKeys() {
  var cached = await IA.kvGet('wbiKeys');
  if (cached) {
    try {
      var o = JSON.parse(cached);
      if (o.img && o.sub && Date.now() - o.at < 3600000) {
        return { img: o.img, sub: o.sub };
      }
    } catch (_) { /* 重取 */ }
  }
  var json = await getJson(CFG.host + CFG.wbiNav, { cookie: 'effective' });
  var w = (json.data && json.data.wbi_img) || {};
  var img = String(w.img_url || '').split('/').pop().split('.')[0];
  var sub = String(w.sub_url || '').split('/').pop().split('.')[0];
  if (!img || !sub) {
    return { img: '', sub: '' };
  }
  await IA.kvSet('wbiKeys', JSON.stringify({ img: img, sub: sub, at: Date.now() }));
  return { img: img, sub: sub };
}

// ── 工具 ───────────────────────────────────────────────────────────────

function stripEm(s) { return String(s || '').replace(/<\/?em[^>]*>/g, ''); }

function parseDur(s) {
  var sec = 0;
  String(s || '').split(':').forEach(function (p) { sec = sec * 60 + (parseInt(p, 10) || 0); });
  return sec;
}

function qsParam(url, name) {
  var m = new RegExp('[?&]' + name + '=([^&#]*)').exec(url);
  return m ? decodeURIComponent(m[1].replace(/\+/g, ' ')) : null;
}

function accountFromUrl(url) {
  var names = ['DedeUserID', 'mid'];
  for (var i = 0; i < names.length; i++) {
    var v = qsParam(url, names[i]);
    if (v) { return v; }
  }
  return null;
}

function bvidOf(url) {
  var m = /BV[0-9A-Za-z]{10}/.exec(url);
  return m ? m[0] : null;
}

/// 分 P 名 → 歌名/歌手（「001.周杰伦-爱在西元前」；拆不出回退不丢信息）。
function parsePageMeta(part, fallbackTitle, fallbackArtist) {
  var s = String(part || '').trim();
  if (!s) { return { title: fallbackTitle, artist: fallbackArtist }; }
  s = s.replace(/^\d+[.、]\s*/, '');
  if (!s) { return { title: fallbackTitle, artist: fallbackArtist }; }
  if (/^\d+$/.test(s)) {
    return { title: fallbackTitle + ' - ' + s, artist: fallbackArtist };
  }
  var m = /^(.+?)\s*[-–—]\s*(.+)$/.exec(s);
  if (!m) { return { title: s, artist: fallbackArtist }; }
  var artist = m[1].trim().replace(/_/g, ' / ');
  var title = m[2].trim();
  if (!artist || !title) { return { title: s, artist: fallbackArtist }; }
  return { title: title, artist: artist };
}

// ── source 契约实现（docs/PLUGIN.md §3.2） ─────────────────────────────

async function match(url) {
  if (bvidOf(url) || /bilibili\.com\/|b23\.tv\//.test(url)) {
    return { id: bvidOf(url) || url };
  }
  return null;
}

async function authKind() { return { kind: 'qr' }; }

async function authStart() {
  var r = await IA.fetch({ url: CFG.passport + CFG.qrGenerate, headers: { 'User-Agent': CFG.ua } });
  var d = JSON.parse(r.body).data;
  await IA.kvSet('qrKey', d.qrcode_key);
  return { qrUrl: d.url, lifetimeSec: 180, hint: '打开 B 站 App → 扫一扫 → 确认登录' };
}

async function authPoll() {
  var key = await IA.kvGet('qrKey');
  if (!key) { return { state: 'error', message: '请重新生成二维码' }; }
  var r = await IA.fetch({ url: CFG.passport + CFG.qrPoll + '?qrcode_key=' + key, headers: { 'User-Agent': CFG.ua } });
  var d = (JSON.parse(r.body).data) || {};
  var code = d.code;
  if (code === CFG.pollSuccess) {
    var map = {};
    (d.cookies || []).forEach(function (c) { if (c && c.name) { map[c.name] = c.value; } });
    var url = d.url || '';
    ['SESSDATA', 'bili_jct', 'DedeUserID', 'DedeUserID__ckMd5'].forEach(function (n) {
      var v = qsParam(url, n);
      if (v) { map[n] = v; }
    });
    // Set-Cookie 兜底：响应头是逗号拼接串，只认已知登录 cookie 名
    var sc = (r.headers && (r.headers['set-cookie'] || r.headers['Set-Cookie'])) || '';
    String(sc).split(',').forEach(function (seg) {
      var kv = seg.split(';')[0].trim();
      var i = kv.indexOf('=');
      if (i > 0) {
        var n = kv.slice(0, i).trim();
        if (['SESSDATA', 'bili_jct', 'DedeUserID', 'DedeUserID__ckMd5'].indexOf(n) >= 0) {
          map[n] = kv.slice(i + 1).trim();
        }
      }
    });
    if (!Object.keys(map).length) {
      return { state: 'error', message: '登录成功但未取到 cookie——请重新扫码' };
    }
    var b = await ensureBuvid();
    if (b && b.buvid3) { map.buvid3 = b.buvid3; if (b.buvid4) { map.buvid4 = b.buvid4; } }
    var merged = cookieMap((await IA.kvGet('cookie')) || '');
    Object.keys(map).forEach(function (k) { merged[k] = map[k]; });
    await IA.kvSet('cookie', cookieHeaderFrom(merged));
    var account = accountFromUrl(url);
    var name = account ? 'B 站用户 ' + account : 'B 站账号';
    await IA.kvSet('account', name);
    return { state: 'success', account: name };
  }
  if (code === CFG.pollScanned) { return { state: 'scanned' }; }
  if (code === CFG.pollWaiting) { return { state: 'waiting' }; }
  if (code === CFG.pollExpired) { return { state: 'expired' }; }
  return { state: 'error', message: 'code=' + code };
}

async function authImport() {
  return { ok: false, message: '本插件仅支持扫码登录' };
}

async function authStatus() {
  var c = await IA.kvGet('cookie');
  var loggedIn = !!(c && c.length);
  return { loggedIn: loggedIn, account: loggedIn ? ((await IA.kvGet('account')) || '') : '' };
}

async function authLogout() {
  await IA.kvSet('cookie', null);
  await IA.kvSet('account', null);
  await IA.kvSet('qrKey', null);
  return {};
}

async function search(q, opts) {
  var wbi = await wbiKeys();
  var page = String((opts && opts.page) || 1);
  var signed = wbiSign({ search_type: 'video', keyword: q, page: page }, wbi.img, wbi.sub);
  var json = await getJson(CFG.host + CFG.searchType + '?' + qs(signed), { referer: true });
  var list = (json.data && json.data.result) || [];
  var items = [];
  list.forEach(function (r) {
    if (r && r.type === 'video' && r.bvid) {
      items.push({
        id: r.bvid,
        url: 'https://www.bilibili.com/video/' + r.bvid,
        title: stripEm(r.title),
        artist: r.author || '',
        durationSec: parseDur(r.duration)
      });
    }
  });
  return { items: items };
}

async function resolve(url) {
  var bvid = bvidOf(url);
  if (!bvid) {
    throw new Error('不是有效的 B 站视频链接：' + url);
  }
  var json = await getJson(CFG.host + CFG.videoInfo + '?bvid=' + bvid, { referer: true });
  if (json.code !== 0) {
    throw new Error('B 站视频信息获取失败：' + (json.message || json.code));
  }
  var d = json.data || {};
  var aid = d.aid === undefined || d.aid === null ? '' : String(d.aid);
  var owner = (d.owner && d.owner.name) || '';
  var pages = (d.pages || []).map(function (p, i) {
    var meta = parsePageMeta(p && p.part, d.title || bvid, owner);
    return {
      id: bvid + '|' + aid + '|' + (p && p.cid) + '|' + (i + 1),
      title: meta.title,
      artist: meta.artist
    };
  });
  if (!pages.length) {
    pages = [{ id: bvid + '|' + aid + '|' + (d.cid || 0) + '|1', title: d.title || bvid, artist: owner }];
  }
  return {
    title: d.title || bvid,
    artist: owner,
    durationSec: d.duration || 0,
    tracks: pages
  };
}

async function stream(id) {
  var parts = String(id).split('|');
  var bvid = parts[0];
  var aid = parts[1] || '';
  var cid = parts[2] || '0';
  var qsStr = 'bvid=' + bvid + '&cid=' + cid + '&fnval=16&qn=0' + (aid ? '&aid=' + aid : '');
  var json = await getJson(CFG.host + CFG.playurl + '?' + qsStr, { referer: true });
  if (json.code !== 0) {
    throw new Error('B 站播放地址获取失败：' + (json.message || json.code));
  }
  var audio = ((json.data && json.data.dash && json.data.dash.audio) || []);
  if (!audio.length) {
    throw new Error('该视频没有可提取的音频流');
  }
  var pick = null;
  for (var i = 0; i < CFG.qualityIds.length && !pick; i++) {
    for (var j = 0; j < audio.length; j++) {
      if (audio[j] && audio[j].id === CFG.qualityIds[i]) { pick = audio[j]; break; }
    }
  }
  if (!pick) { pick = audio[0]; }
  var mime = pick.mimeType || 'audio/mp4';
  return {
    url: pick.baseUrl || pick.base_url,
    ext: mime.indexOf('mp4') >= 0 ? 'm4a' : 'mp3',
    headers: { 'Referer': CFG.referer, 'User-Agent': CFG.ua }
  };
}

async function lyrics(id) {
  var parts = String(id).split('|');
  var aid = parts[1] || '';
  var cid = parts[2] || '';
  if (!aid || !cid) { return null; }
  var json = await getJson(CFG.host + CFG.playerInfo + '?aid=' + aid + '&cid=' + cid, { referer: true });
  var subs = ((json.data && json.data.subtitle && json.data.subtitle.subtitles) || []);
  if (!subs.length) { return null; }
  var surl = subs[0].subtitle_url || '';
  if (!surl) { return null; }
  if (surl.indexOf('//') === 0) { surl = 'https:' + surl; }
  var r = await IA.fetch({ url: surl, headers: { 'User-Agent': CFG.ua, 'Referer': CFG.referer } });
  try {
    var items = JSON.parse(r.body).body || [];
    var out = [];
    items.forEach(function (it) {
      if (typeof it.from === 'number' && typeof it.content === 'string') {
        var m = Math.floor(it.from / 60);
        var s = (it.from - m * 60).toFixed(2);
        var pad = s.length < 5 ? ('0' + s) : s;
        out.push('[' + (m < 10 ? '0' + m : m) + ':' + pad + ']' + it.content);
      }
    });
    return out.length ? { synced: out.join('\n') + '\n' } : null;
  } catch (_) {
    return null;
  }
}
