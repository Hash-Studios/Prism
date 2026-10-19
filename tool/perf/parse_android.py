#!/usr/bin/env python3
"""Merge logcat START lines with the probe file. Usage: parse_android.py <logcat> <probe.ndjson> <am.json> <out.json>"""
import json, re, sys, datetime
logf, probef, amf, outp = sys.argv[1:5]
START=re.compile(r'^\s*(\d+\.\d+).*START u0 .*com\.hash\.prism/\.MainActivity')
def ts(s): return datetime.datetime.fromisoformat(s.replace('Z','+00:00')).timestamp()
starts=sorted(float(m.group(1)) for m in map(START.match,open(logf,errors='replace')) if m)
P=[json.loads(l) for l in open(probef) if l.strip()]
S=[]
for o in P:
    k,n=o['kind'],o['name']
    if k=='firestore' and n.startswith('streamSubscribe'): continue
    if k=='analytics': n=n+':'+str((o.get('extra') or {}).get('surface') or '')
    S.append((k,n,o['ms'],o.get('ok',True)))
cold=0
for i,st in enumerate(starts):
    end=starts[i+1] if i+1<len(starts) else 1e18
    win=[o for o in P if st<=ts(o['ts'])<end]
    def first(name): return next((ts(o['ts']) for o in win if o['name']==name),None)
    br,ff,home=first('startup.binding_ready'),first('startup.first_frame'),first('time_to_home')
    if br and home:
        cold+=1
        S+= [('cold_launch','pre_main',round((br-st)*1000),True),('cold_launch','tap_to_first_frame',round((ff-st)*1000),True),('cold_launch','tap_to_home',round((home-st)*1000),True)]
for r in json.load(open(amf)):
    if r.get('am_total') is not None: S.append(('cold_launch','am_start_total',r['am_total'],True))
json.dump(S,open(outp,'w')); print(len(S),'samples;',len(starts),'starts;',cold,'cold launches')
