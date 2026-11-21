/*!
{
  "id": "app.iamusic.youtube",
  "name": "YouTube 音频源",
  "version": "1.0.0",
  "api": 1,
  "capabilities": ["source"],
  "author": "iA-Music",
  "homepage": "https://github.com/zhaoxuan-inside/iA-Music",
  "notes": "InnerTube 站内搜索 · ANDROID 语境流解析 · Cookie 登录导入"
}
*/
// ── 配置（InnerTube 公开客户端语境；与原宿主内置版一致） ───────────────

var CFG = {
  innerTube: 'https://music.youtube.com/youtubei/v1',
  webRemixKey: 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30',
  webRemixName: 'WEB_REMIX',
  webRemixVersion: '1.20240401.01.00',
  androidName: 'ANDROID',
  androidVersion: '19.09.37',
  androidSdk: '30',
  ua: 'com.google.android.apps.youtube.music/19.09.37 (Linux; U; Android 13) gzip',
  requiredCookies: ['SAPISID', '__Secure-3PAPISID']
};

function cookieMap(header) {
  var m = {};
  String(header || '').split(';').forEach(function (p) {
    var i = p.indexOf('=');
    if (i > 0) { m[p.slice(0, i).trim()] = p.slice(i + 1).trim(); }
  });
  return m;
}

function webRemixContext() {
  return { client: { clientName: CFG.webRemixName, clientVersion: CFG.webRemixVersion, hl: 'zh-CN', gl: 'CN' } };
}

function androidContext() {
  return { client: { clientName: CFG.androidName, clientVersion: CFG.androidVersion, androidSdkVersion: CFG.androidSdk, hl: 'zh-CN', gl: 'CN' } };
}

async function postJson(url, body, withCookies) {
  var headers = {
    'Content-Type': 'application/json',
    'User-Agent': CFG.ua
  };
  if (withCookies) {
    var c = (await IA.kvGet('cookie')) || '';
    if (c) { headers['Cookie'] = c; }
  }
  var r = await IA.fetch({ url: url, method: 'POST', headers: headers, body: body });
  if (r.status !== 200) {
    throw new Error('YouTube 请求失败：HTTP ' + r.status);
  }
  return JSON.parse(r.body);
}

// 深度遍历 JSON 树。
function walk(node, visit) {
  visit(node);
  if (node && typeof node === 'object') {
    if (Array.isArray(node)) {
      for (var i = 0; i < node.length; i++) { walk(node[i], visit); }
    } else {
      Object.keys(node).forEach(function (k) { walk(node[k], visit); });
    }
  }
}

function parseDur(s) {
  var sec = 0;
  String(s || '').split(':').forEach(function (p) { sec = sec * 60 + (parseInt(p, 10) || 0); });
  return sec;
}

function videoIdOf(url) {
  var m = /(?:v=|youtu\.be\/|shorts\/|embed\/)([0-9A-Za-z_-]{11})/.exec(url);
  if (m) { return m[1]; }
  if (/^[0-9A-Za-z_-]{11}$/.test(String(url || '').trim())) {
    return String(url).trim();
  }
  return null;
}

// ── source 契约实现（docs/PLUGIN.md §3.2） ─────────────────────────────

async function match(url) {
  if (videoIdOf(url) || /youtube\.com\/|youtu\.be\//.test(url)) {
    return { id: videoIdOf(url) || url };
  }
  return null;
}

async function authKind() { return { kind: 'cookie' }; }

async function authStart() { return {}; }

async function authPoll() { return { state: 'error', message: '本插件使用 Cookie 导入登录' }; }

async function authImport(header) {
  var map = cookieMap(header);
  if (!Object.keys(map).length) {
    return { ok: false, message: '没有解析到任何 cookie' };
  }
  var hasLogin = CFG.requiredCookies.some(function (n) { return map[n]; });
  if (!hasLogin) {
    return { ok: false, message: '缺少 SAPISID——请粘贴已登录 YouTube 的浏览器 Cookie 头' };
  }
  await IA.kvSet('cookie', String(header || '').split(';')
      .map(function (s) { return s.trim(); })
      .filter(function (s) { return s.length > 0; })
      .join('; '));
  await IA.kvSet('account', '已登录账号');
  return { ok: true, account: '已登录账号' };
}

async function authStatus() {
  var c = await IA.kvGet('cookie');
  var loggedIn = !!(c && c.length);
  return { loggedIn: loggedIn, account: loggedIn ? ((await IA.kvGet('account')) || '') : '' };
}

async function authLogout() {
  await IA.kvSet('cookie', null);
  await IA.kvSet('account', null);
  return {};
}

async function search(q) {
  var json = await postJson(
      CFG.innerTube + '/search?prettyPrint=false&key=' + CFG.webRemixKey,
      JSON.stringify({ context: webRemixContext(), query: q }),
      false);
  var items = [];
  walk(json, function (node) {
    if (node && typeof node === 'object' && !Array.isArray(node) &&
        node.musicResponsiveListItemRenderer) {
      var row = parseSearchRow(node.musicResponsiveListItemRenderer);
      if (row) { items.push(row); }
    }
  });
  return { items: items.slice(0, 20) };
}

function parseSearchRow(r) {
  var title = '';
  var artist = '';
  var album = null;
  var dur = 0;
  var flex = r.flexColumns || [];
  for (var i = 0; i < flex.length; i++) {
    var col = flex[i];
    if (!col || typeof col !== 'object') { continue; }
    var meta = col.musicResponsiveListItemFlexColumnRenderer;
    var runs = meta && meta.text && meta.text.runs;
    if (!runs || !runs.length) { continue; }
    var first = runs[0];
    var text = (typeof first.text === 'string') ? first.text : '';
    var nav = first.navigationEndpoint && first.navigationEndpoint.watchEndpoint;
    if (nav && typeof nav.videoId === 'string') {
      title = text;
      continue;
    }
    if (text && !artist) {
      var segs = text.split(' • ');
      if (segs.length) { artist = segs[0].trim(); }
      if (segs.length > 1) { album = segs[1].trim(); }
      dur = parseDur(segs[segs.length - 1].trim());
    }
  }
  var videoId = null;
  walk(r, function (node) {
    if (videoId) { return; }
    if (node && typeof node === 'object' && !Array.isArray(node) &&
        node.watchEndpoint && typeof node.watchEndpoint.videoId === 'string') {
      videoId = node.watchEndpoint.videoId;
    }
  });
  if (!videoId || !title) { return null; }
  return {
    id: videoId,
    url: 'https://www.youtube.com/watch?v=' + videoId,
    title: title,
    artist: artist,
    durationSec: dur,
    album: album
  };
}

async function resolve(url) {
  var videoId = videoIdOf(url);
  if (!videoId) {
    throw new Error('不是有效的 YouTube 链接：' + url);
  }
  // ANDROID 语境一次 player 调用同时给出元数据与流；resolve 只取元数据，
  // stream() 再取流（InnerTube 幂等，两次调用换契约清晰性）。
  var json = await postJson(
      CFG.innerTube + '/player?prettyPrint=false',
      JSON.stringify({ context: androidContext(), videoId: videoId, contentCheckOk: true, racyCheckOk: true }),
      true);
  var status = json.playabilityStatus && json.playabilityStatus.status;
  if (status !== 'OK') {
    var reason = (json.playabilityStatus && json.playabilityStatus.reason) || status;
    throw new Error('YouTube 播放不可用：' + reason);
  }
  var details = json.videoDetails || {};
  var author = String(details.author || '').replace(/ - Topic$/, '').trim();
  return {
    title: details.title || videoId,
    artist: author,
    durationSec: parseInt(details.lengthSeconds, 10) || 0,
    tracks: [{ id: videoId, title: details.title || videoId, artist: author }]
  };
}

async function stream(id) {
  var videoId = String(id).trim();
  if (!/^[0-9A-Za-z_-]{11}$/.test(videoId)) {
    throw new Error('不是有效的 YouTube videoId：' + id);
  }
  var json = await postJson(
      CFG.innerTube + '/player?prettyPrint=false',
      JSON.stringify({ context: androidContext(), videoId: videoId, contentCheckOk: true, racyCheckOk: true }),
      true);
  var status = json.playabilityStatus && json.playabilityStatus.status;
  if (status !== 'OK') {
    var reason = (json.playabilityStatus && json.playabilityStatus.reason) || status;
    throw new Error('YouTube 播放不可用：' + reason);
  }
  var formats = (json.streamingData && json.streamingData.adaptiveFormats) || [];
  var best = null;
  for (var i = 0; i < formats.length; i++) {
    var f = formats[i];
    if (!f || typeof f !== 'object') { continue; }
    var mime = f.mimeType || '';
    if (mime.indexOf('audio/') !== 0) { continue; }
    if (!f.url) { continue; }
    var bitrate = f.bitrate || 0;
    if (!best || bitrate > best.bitrate) {
      best = {
        bitrate: bitrate,
        result: {
          url: f.url,
          ext: mime.indexOf('webm') >= 0 ? 'webm' : 'm4a',
          headers: { 'User-Agent': CFG.ua }
        }
      };
    }
  }
  if (!best) {
    throw new Error('音频流需要签名解密——本片暂不支持提取');
  }
  return best.result;
}

async function lyrics() {
  return null;
}
