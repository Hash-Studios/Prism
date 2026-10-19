#!/usr/bin/env python3
"""Turn an iOS probe file into samples. Usage: parse_ios.py <probe.ndjson> <run start ISO time> <out.json>"""
import datetime, json, sys

probef, start, outp = sys.argv[1:4]
since = datetime.datetime.fromisoformat(start)
S = []
launches = 0
for line in open(probef):
    if not line.strip():
        continue
    o = json.loads(line)
    if datetime.datetime.fromisoformat(o['ts'].replace('Z', '+00:00')) < since:
        continue
    k, n = o['kind'], o['name']
    if k == 'firestore' and n.startswith('streamSubscribe'):
        continue
    if k == 'analytics':
        n = n + ':' + str((o.get('extra') or {}).get('surface') or '')
    if k == 'cold_launch' and n == 'pre_main':
        launches += 1
    S.append((k, n, o['ms'], o.get('ok', True)))
json.dump(S, open(outp, 'w'))
print(len(S), 'samples;', launches, 'cold launches')
