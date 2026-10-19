#!/usr/bin/env python3
"""Cold-launch + flow driver for Prism. Usage: drive_android.py <tag> <launches> [--no-flows] [--shots]
Env: ANDROID_SERIAL (default emulator-5580), PRISM_PERF_DIR (default /tmp/prism-perf)."""
import argparse, json, os, re, subprocess, sys, time
from pathlib import Path
S=os.environ.get('ANDROID_SERIAL','emulator-5580'); PKG='com.hash.prism'; ACT=PKG+'/.MainActivity'
OUT=Path(os.environ.get('PRISM_PERF_DIR','/tmp/prism-perf'))
ap=argparse.ArgumentParser(); ap.add_argument('tag'); ap.add_argument('launches',type=int)
ap.add_argument('--no-flows',action='store_true'); ap.add_argument('--shots',action='store_true')
A=ap.parse_args(); tag=A.tag; N=A.launches
def sh(*a, t=60): return subprocess.run(['adb','-s',S,'shell',*a],capture_output=True,text=True,timeout=t).stdout
def log(m): print(time.strftime('%H:%M:%S'),m,flush=True)
def swipe(x1,y1,x2,y2,ms=250): sh('input','swipe',str(x1),str(y1),str(x2),str(y2),str(ms))
def shot(n):
    if SHOTS: subprocess.run(f'adb -s {S} exec-out screencap -p > {OUT}/shots/drv-{tag}-{n}.png',shell=True)
def on_home():
    import io
    from PIL import Image
    png=subprocess.run(['adb','-s',S,'exec-out','screencap','-p'],capture_output=True).stdout
    im=Image.open(io.BytesIO(png)).convert('RGB')
    return all(min(im.getpixel(p))>245 for p in [(700,200),(300,200),(540,120)])
def on_home_nav():
    import io
    from PIL import Image
    png=subprocess.run(['adb','-s',S,'exec-out','screencap','-p'],capture_output=True).stdout
    im=Image.open(io.BytesIO(png)).convert('RGB')
    return min(im.getpixel((470,2238)))>230
def back_home():
    for _ in range(4):
        if on_home(): return True
        tap(80,215); time.sleep(1.5)
    return on_home()
def tap(x,y): sh('input','tap',str(x),str(y))
W,H=[int(v) for v in re.search(r'(\d+)x(\d+)',sh('wm','size')).groups()]
SHOTS=A.shots
(OUT/'shots').mkdir(parents=True,exist_ok=True)
NAV=None if A.no_flows else json.load(open(Path(__file__).parent/'android_nav.json'))
MAX_LOAD1=float(os.environ.get('PRISM_PERF_MAX_LOAD1','10'))
res=[]
for i in range(N):
    sh('am','force-stop',PKG); time.sleep(2)
    for _ in range(60):
        if os.getloadavg()[0] <= MAX_LOAD1: break
        time.sleep(10)
    out=sh('am','start','-W','-n',ACT)
    tt=re.search(r'TotalTime:\s*(\d+)',out); ws=re.search(r'WaitTime:\s*(\d+)',out)
    r={'i':i,'am_total':int(tt.group(1)) if tt else None,'am_wait':int(ws.group(1)) if ws else None}
    r['load1']=round(os.getloadavg()[0],1)
    log(f'{tag} launch {i} {r}'); res.append(r)
    time.sleep(9)
    if NAV:
        tap(*NAV['tile']); time.sleep(3); shot(f'{i}-detail')
        if not back_home(): log('not home, skip flows'); continue
        for _ in range(4): swipe(W//2,int(H*.75),W//2,int(H*.3)); time.sleep(1.0)
        swipe(W//2,int(H*.4),W//2,int(H*.55)); time.sleep(1.5)
        if not on_home_nav(): log('nav hidden, skip'); continue
        tap(*NAV['search']); time.sleep(2.5)
        if i%2==0:
            tap(*NAV['chips'][(i//2)%len(NAV['chips'])]); time.sleep(4); shot(f'{i}-chip')
        else:
            tap(*NAV['colours'][(i//2)%len(NAV['colours'])]); time.sleep(4); shot(f'{i}-colour')
        tap(*NAV['rewards']); time.sleep(3); shot(f'{i}-rewards')
        tap(*NAV['home']); time.sleep(1.5)
json.dump(res,open(OUT/f'android_{tag}_am.json','w'))
