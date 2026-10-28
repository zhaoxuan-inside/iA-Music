const H = { "Accept": "application/vnd.github+json", "User-Agent": "iA-Music-research" };
async function j(url) {
  const r = await fetch(url, { headers: H });
  if (!r.ok) return { __err: r.status };
  return r.json();
}
const fmt = (r) => [
  r.full_name, String(r.stargazers_count ?? "?").padStart(6),
  (r.language ?? "-").padEnd(10).slice(0, 10),
  r.license ? (r.license.spdx_id ?? "none") : "none",
  r.archived ? "ARCHIVED" : "active", (r.pushed_at ?? "").slice(0, 10),
  (r.description ?? "").replace(/\s+/g, " ").slice(0, 90),
].join(" | ");

const qs = [
  ["metro", "q=Metro+music+player+fork+of+Retro"],
  ["gramophone", "q=gramophone+music+player+android"],
  ["musify", "q=musify+youtube+music+android"],
  ["symphony", "q=symphony+offline+music+player+android"],
  ["lollypop", "q=lollypop+music+player+gnome"],
];
for (const [tag, q] of qs) {
  const d = await j(`https://api.github.com/search/repositories?${q}&sort=stars&order=desc&per_page=5`);
  if (d.__err) { console.log(`\n## ${tag}: ERROR ${d.__err}`); continue; }
  console.log(`\n## ${tag}`);
  for (const it of d.items) console.log(fmt(it));
}
