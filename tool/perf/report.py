#!/usr/bin/env python3
"""Usage: report.py --col LABEL=samples.json [--col ...] [--ios-summary summary-reviewed.json] --md out.md --html out.html"""
import json, math, collections, html, argparse
ap = argparse.ArgumentParser()
ap.add_argument('--col', action='append', default=[])
ap.add_argument('--ios-summary')
ap.add_argument('--md', required=True)
ap.add_argument('--html', required=True)
A = ap.parse_args()
def pct(v, p):
    v = sorted(v); k = (len(v) - 1) * p; f = math.floor(k); c = math.ceil(k)
    return v[f] if f == c else v[f] * (c - k) + v[c] * (k - f)
def load(f):
    g = collections.defaultdict(list)
    for k, n, ms, ok in json.load(open(f)):
        if ok: g[(k, n)].append(ms)
    return g
# each column: (label, lookup(k,n) -> (p50, p99, n) or None)
def sample_col(f):
    g = load(f)
    return lambda key: (pct(g[key], .5), pct(g[key], .99), len(g[key])) if g.get(key) else None
def ios_col(f):
    g = {(r['kind'], r['name']): r for r in json.load(open(f)) if r['ok']}
    return lambda key: (g[key]['p50'], g[key]['p99'], g[key]['n']) if key in g else None
cols = []
if A.ios_summary: cols.append(('iOS sim · debug', ios_col(A.ios_summary)))
named = []
for c in A.col:
    label, path = c.split('=', 1)
    named.append((label, sample_col(path)))
cols += named
G = [
("Opening the app",[
 ("cold_launch","tap_to_grid","Launch → wallpapers on the home grid"),
 ("cold_launch","tap_to_home","Launch → home feed shown"),
 ("cold_launch","tap_to_first_frame","Launch → first Flutter frame"),
 ("cold_launch","pre_main","Launch → Dart main() (engine boot)"),
 ("cold_launch","am_start_total","Launch → first Android frame (am start)"),
 ("startup","time_to_home","Dart main() → home route"),
 ("startup","firebase_init","Firebase init"),
 ("startup","persistence_and_monitoring","Local storage + Sentry init (blocking)"),
 ("startup","economy_config.load","Economy config load (blocks splash)"),
 ("startup","remote_config","Remote Config fetch"),
 ("startup","ad_consent","Ad consent check"),
 ("network","connectivity.has_connection","Connectivity check"),
]),
("Rewards and coins (Cloud Functions)",[
 ("callable","checkBadges","Check badges"),
 ("callable","syncSubscription","Sync subscription"),
 ("callable","progressQuest","Progress quest"),
 ("callable","claimDailyStreak","Claim daily streak"),
 ("callable","reconcileRankRewards","Reconcile rank rewards"),
 ("callable","recordWallpaperView","Record wallpaper view"),
 ("callable","openDailyChest","Open daily chest"),
 ("callable","spinWheel","Spin the wheel"),
 ("firestore","docGet.coins.bootstrap","Coin balance first load"),
 ("firestore","docGet.coins.refresh_balance","Coin balance refresh"),
]),
("Loading content",[
 ("analytics","surface_content_loaded:home_wallpaper_grid","Home grid content loaded"),
 ("image.thumb","decoded","Thumbnail tile → image shown"),
 ("firestore","queryGet.personalized.taste","For You: taste query"),
 ("firestore","queryGet.personalized.gems","For You: gems query"),
 ("firestore","queryGet.personalized.fresh","For You: fresh query"),
 ("firestore","queryGet.personalized.creator_chunk_1","For You: creators query"),
 ("firestore","queryGet.trending.week.walls","Trending walls query"),
 ("firestore","docGet.wotd.fetchToday.pointer","Wall of the Day"),
 ("firestore","docGet.PrismWallpaperRepository.fetchByDocumentId","Wallpaper by id"),
 ("firestore","queryGet.notifications.latest","Notifications latest"),
 ("firestore","set.fcm_token.sync","FCM token write"),
 ("search","wallpaper.search","Search (merged sources)"),
 ("firestore","queryGet.PrismWallSearch.tags","Prism search: tags"),
 ("http","wallhaven.search","Wallhaven search"),
 ("http","pexels.search","Pexels search"),
]),
("Opening a screen (push → first frame)",[
 ("route_first_frame","DashboardRoute","Dashboard"),
 ("route_first_frame","WallpaperDetailRoute","Wallpaper detail"),
 ("route_first_frame","SearchRoute","Search"),
]),
]
def f(ms): return '–' if ms is None else (f"{ms/1000:.2f}s" if ms>=1000 else f"{round(ms)}ms")
def cls(ms): return '' if ms is None else 'bad' if ms>=3000 else 'warn' if ms>=1000 else ''
def cell(r):
    if not r: return "<td class=n><span class=mut>–</span></td>"
    a, b, n = r
    thin = f' <span class=thin>n={n}</span>' if n < 10 else ''
    return f"<td class=n><b class='{cls(a)}'>{f(a)}</b> <span class='p99 {cls(b)}'>{f(b)}</span>{thin}</td>"
def mdcell(r): return '–' if not r else f"{f(r[0])} / {f(r[1])}"
def delta(key):
    if len(named) < 2: return ''
    a, b = named[0][1](key), named[-1][1](key)
    if not a or not b or not a[0]: return ''
    return f"{round((b[0] - a[0]) / a[0] * 100):+d}%"
HEAD = """<!doctype html><html><head><meta charset=utf-8><style>
body{font:13.5px/1.4 var(--font-sans);margin:0;padding:4px 0;color:var(--foreground)}
h2{font-size:12px;margin:20px 0 6px;text-transform:uppercase;letter-spacing:.04em;color:var(--muted-foreground)}
p.sub{margin:0;color:var(--muted-foreground);font-size:12.5px}
table{width:100%;border-collapse:collapse;table-layout:fixed}
th{text-align:left;font-size:11px;color:var(--muted-foreground);font-weight:600;padding:6px 0;border-bottom:1px solid color-mix(in oklab,var(--foreground) 15%,transparent)}
th:first-child{width:37%} th:nth-child(n+2),td.n{text-align:right}
td{padding:6px 0;border-bottom:1px solid color-mix(in oklab,var(--foreground) 8%,transparent)}
td.n{font-variant-numeric:tabular-nums;white-space:nowrap} td.n b{font-weight:650}
.p99{color:var(--muted-foreground);font-size:12px} .mut{color:var(--muted-foreground)}
.warn{color:var(--warning)} .bad{color:var(--destructive)}
.thin{font-size:10px;color:var(--muted-foreground)}
</style></head><body>
<p class=sub>Each cell: <b>p50</b> then p99. Orange ≥ 1s, red ≥ 3s. "n=" marks fewer than 10 samples. Δ p50 is the last column vs the first --col column.</p>
"""
h, md = [], []
heads = [c[0] for c in cols]
for t, items in G:
    h.append(f"<h2>{t}</h2><table><thead><tr><th>Metric</th>" + ''.join(f"<th>{html.escape(x)}</th>" for x in heads) + "<th>Δ p50</th></tr></thead><tbody>")
    md.append(f"\n### {t}\n\n| Metric | " + ' | '.join(f"{x} p50 / p99" for x in heads) + " | Δ p50 |\n|---|" + '---|' * (len(heads) + 1))
    for k, n, label in items:
        rs = [c[1]((k, n)) for c in cols]
        d = delta((k, n))
        h.append(f"<tr><td>{html.escape(label)}</td>{''.join(cell(r) for r in rs)}<td class=n>{d}</td></tr>")
        md.append(f"| {label} | " + ' | '.join(mdcell(r) for r in rs) + f" | {d} |")
    h.append("</tbody></table>")
open(A.html, 'w').write(HEAD + ''.join(h) + "</body></html>")
open(A.md, 'w').write('\n'.join(md) + '\n')
