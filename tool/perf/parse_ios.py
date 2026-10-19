#!/usr/bin/env python3
"""Turn an iOS probe file into samples per build.
Usage: parse_ios.py <probe.ndjson> <windows.txt> <out dir>  (windows: lines "<tag> <start ISO> <end ISO>")
Writes <out dir>/<tag>-samples.json for each tag. A launch whose launch → Dart main exceeds PRISM_PERF_MAX_PRE_MAIN
(default 400ms) ran on a throttled phone; all its samples are dropped, for both builds alike."""
import collections, datetime, json, os, sys

probef, winf, outd = sys.argv[1:4]
iso = lambda s: datetime.datetime.fromisoformat(s.replace('Z', '+00:00'))
wins = [(t, iso(a), iso(b)) for t, a, b in (l.split() for l in open(winf) if l.strip())]
max_pre_main = int(os.environ.get('PRISM_PERF_MAX_PRE_MAIN', '400'))
S = collections.defaultdict(list)
dropped = collections.Counter()
hot = True
rows = sorted((json.loads(l) for l in open(probef) if l.strip()), key=lambda o: o['ts'])
for o in rows:
    ts = iso(o['ts'])
    tag = next((t for t, a, b in wins if a <= ts <= b), None)
    if tag is None:
        continue
    if o['kind'] == 'cold_launch' and o['name'] == 'pre_main':
        hot = o['ms'] > max_pre_main
        if hot:
            dropped[tag] += 1
    if hot:
        continue
    k, n = o['kind'], o['name']
    if k == 'firestore' and n.startswith('streamSubscribe'):
        continue
    if k == 'analytics':
        n = n + ':' + str((o.get('extra') or {}).get('surface') or '')
    S[tag].append((k, n, o['ms'], o.get('ok', True)))
for tag, samples in S.items():
    json.dump(samples, open(f'{outd}/{tag}-samples.json', 'w'))
    launches = sum(1 for s in samples if s[:2] == ('cold_launch', 'pre_main'))
    print(tag, len(samples), 'samples;', launches, 'cold launches;', dropped[tag], 'dropped as thermally throttled')
