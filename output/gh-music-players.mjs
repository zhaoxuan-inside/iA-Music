// 一次性脚本：从 GitHub API 拉取开源音乐播放器概览（搜索 + 指定仓库核验）
const H = { "Accept": "application/vnd.github+json", "User-Agent": "iA-Music-research" };

async function j(url) {
  const r = await fetch(url, { headers: H });
  if (!r.ok) return { __err: r.status };
  return r.json();
}

const searches = [
  ["topic-general", "https://api.github.com/search/repositories?q=topic:music-player&sort=stars&order=desc&per_page=25"],
  ["topic-android", "https://api.github.com/search/repositories?q=topic:music-player+topic:android&sort=stars&order=desc&per_page=15"],
  ["topic-compose", "https://api.github.com/search/repositories?q=topic:music-player+topic:jetpack-compose&sort=stars&order=desc&per_page=10"],
  ["topic-qt", "https://api.github.com/search/repositories?q=topic:music-player+topic:qt&sort=stars&order=desc&per_page=10"],
  ["topic-electron", "https://api.github.com/search/repositories?q=topic:music-player+topic:electron&sort=stars&order=desc&per_page=10"],
  ["local-player", "https://api.github.com/search/repositories?q=offline+local+music+player&sort=stars&order=desc&per_page=15"],
];

const known = [
  // Android 本地播放
  "metro-kloud/Metro", "fast4x/RiMusic", "OxygenCobalt/Auxio", "CompilerTree/gramophone",
  "vanilla-music/vanilla", "SimpleMobileTools/Simple-Music-Player", "Outerfield/InnerTune",
  "z-huang/InnerTune", "kosdn/musify",
  // 桌面（Windows/Linux）
  "fooyin/fooyin", "strawberry-music-player/strawberry", "Taiko2k/TauonMusicBox",
  "digimezzo/dopamine", "qier222/YesPlayMusic", "listen1/listen1_desktop",
  "quodlibet/quodlibet", "KDE/elisa", "gnumdk/lollypop", "bertob/amberol",
  "jeffvli/feishin", "ciderapp/Cider", "nukeop/nuclear",
];

const fmt = (r) => [
  r.full_name,
  String(r.stargazers_count ?? "?").padStart(6),
  (r.language ?? "-").padEnd(12).slice(0, 12),
  r.license ? (r.license.spdx_id ?? "none") : "none",
  (r.archived ? "ARCHIVED" : "active"),
  (r.pushed_at ?? "").slice(0, 10),
  (r.description ?? "").replace(/\s+/g, " ").slice(0, 90),
].join(" | ");

console.log("===== SEARCHES =====");
for (const [tag, url] of searches) {
  const d = await j(url);
  if (d.__err) { console.log(`\n## ${tag}: ERROR ${d.__err}`); continue; }
  console.log(`\n## ${tag} (total ${d.total_count})`);
  for (const it of d.items) console.log(fmt(it));
}

console.log("\n===== KNOWN REPOS =====");
for (const full of known) {
  const r = await j(`https://api.github.com/repos/${full}`);
  if (r.__err) { console.log(`${full} | ERROR ${r.__err}`); continue; }
  console.log(fmt(r));
}
