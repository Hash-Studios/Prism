#!/usr/bin/env python3
"""Turn an iOS probe file into samples per build.
Usage: parse_ios.py <probe.ndjson> <windows.txt> <out dir>  (windows: lines "<tag> <start ISO> <end ISO>")
Writes <out dir>/<tag>-samples.json for each tag."""
import collections, datetime, json, sys

probef, winf, outd = sys.argv[1:4]
iso = lambda s: datetime.datetime.fromisoformat(s.replace('Z', '+00:00'))
wins = [(t, iso(a), iso(b)) for t, a, b in (l.split() for l in open(winf) if l.strip())]
S = collections.defaultdict(list)
for line in open(probef):
    if not line.strip():
        continue
    o = json.loads(line)
    ts = iso(o['ts'])
    tag = next((t for t, a, b in wins if a <= ts <= b), None)
    if tag is None:
        continue
    k, n = o['kind'], o['name']
    if k == 'firestore' and n.startswith('streamSubscribe'):
        continue
    if k == 'analytics':
        n = n + ':' + str((o.get('extra') or {}).get('surface') or '')
    S[tag].append((k, n, o['ms'], o.get('ok', True)))
for tag, samples in S.items():
    json.dump(samples, open(f'{outd}/{tag}-samples.json', 'w'))
    print(tag, len(samples), 'samples;', sum(1 for s in samples if s[:2] == ('cold_launch', 'pre_main')), 'cold launches')
