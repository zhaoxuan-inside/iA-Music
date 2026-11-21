/*!
{
  "id": "app.iamusic.demo-source",
  "name": "示例音频源",
  "version": "1.1.0",
  "api": 1,
  "capabilities": ["source"],
  "author": "iA-Music",
  "homepage": "https://github.com/zhaoxuan-inside/iA-Music",
  "notes": "桥协议参考实现：IA.fetch / IA.kv / IA.crypto / IA.log"
}
*/
// ── source 契约实现（docs/PLUGIN.md §3.2） ─────────────────────────────

async function match(url) {
  if (/demo\.example\//.test(url)) {
    return { id: 'demo-1' };
  }
  return null;
}

async function authKind() { return { kind: 'none' }; }
async function authStart() { return {}; }
async function authPoll() { return { state: 'error', message: '无需登录' }; }
async function authImport() { return { ok: false, message: '无需登录' }; }
async function authStatus() { return { loggedIn: true, account: '示例' }; }
async function authLogout() { return {}; }

async function search(query, opts) {
  IA.log('search:', query, opts || {});
  await IA.kvSet('lastQuery', query);
  return {
    items: [
      { id: 'demo-1', url: 'https://demo.example/t/1', title: query + ' — 示例曲一', artist: 'Demo', durationSec: 200 },
      { id: 'demo-2', url: 'https://demo.example/t/2', title: query + ' — 示例曲二', artist: 'Demo', durationSec: 180 }
    ]
  };
}

async function resolve(url) {
  var last = await IA.kvGet('lastQuery');
  return {
    title: '示例曲目（' + (last || url) + '）',
    artist: 'Demo',
    durationSec: 200,
    tracks: [{ id: 'demo-1', title: '示例曲目一', artist: 'Demo' }]
  };
}

async function stream(id) {
  // 真实插件在这里 IA.fetch 解析媒体流直链；示例返回占位直链
  return { url: 'https://example.invalid/stream/' + id, ext: 'mp3', headers: {} };
}

async function lyrics(id) {
  return null;
}

// ── 桥自检（宿主测试/诊断用，非 source 契约） ────────────────────────
// 覆盖四类桥：fetch（异步通道）、kv（凭据沙箱）、crypto（签名）、log。

async function ping(url) {
  var r = await IA.fetch({ url: url });
  await IA.kvSet('lastBody', r.body);
  return {
    status: r.status,
    bodyEcho: r.body,
    md5: IA.md5(r.body),
    kv: await IA.kvGet('lastBody')
  };
}

async function lastQuery() {
  return await IA.kvGet('lastQuery');
}
