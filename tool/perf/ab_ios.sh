#!/usr/bin/env bash
# Usage: ab_ios.sh <tagA> <A.app> <tagB> <B.app> [blocks=6] [per_block=3]
# Alternates two profile builds on one iPhone so heat and background work hit both equally. Waits for the phone to
# cool (launch to Dart main under PRISM_PERF_COOL_MS) before starting. Env: PRISM_IOS_DEVICE, PRISM_PERF_DIR.
set -euo pipefail
TA=${1:?}; AA=${2:?}; TB=${3:?}; AB=${4:?}; BLOCKS=${5:-6}; PER=${6:-3}
DEV=${PRISM_IOS_DEVICE:?set PRISM_IOS_DEVICE}
DIR=${PRISM_PERF_DIR:-/tmp/prism-perf}
GAP=${PRISM_PERF_SETTLE:-50}
COOL=${PRISM_PERF_COOL_MS:-300}
HERE=$(cd "$(dirname "$0")" && pwd)
WIN="$DIR/ab-$TA-$TB-windows.txt"; : > "$WIN"
PROBE="$DIR/ab-$TA-$TB-probe.ndjson"; : > "$PROBE"
now() { python3 -c 'import datetime;print(datetime.datetime.now(datetime.timezone.utc).isoformat())'; }
launch() { xcrun devicectl device process launch --device "$DEV" --terminate-existing com.hash.prism > /dev/null; }
pull() {
  xcrun devicectl device copy from --device "$DEV" --domain-type appDataContainer --domain-identifier com.hash.prism \
    --source Documents/performance_probe.ndjson --destination "$PROBE.part" > /dev/null
  touch "$PROBE"; python3 -c "
import sys
seen=set(open('$PROBE').read().splitlines())
new=[l for l in open('$PROBE.part').read().splitlines() if l and l not in seen]
open('$PROBE','a').write(''.join(x+'\\n' for x in new))"
}
last_pre_main() { python3 -c "
import json,sys
v=[json.loads(l)['ms'] for l in open('$PROBE') if '\"pre_main\"' in l]
print(v[-1] if v else 99999)"; }
xcrun devicectl device install app --device "$DEV" "$AA" > /dev/null
until launch && sleep 20 && pull && [ "$(last_pre_main)" -le "$COOL" ]; do
  echo "$(date +%H:%M:%S) cooling, launch to main $(last_pre_main)ms"; sleep 90
done
for b in $(seq 1 "$BLOCKS"); do
  for arm in A B; do
    if [ $arm = A ]; then TAG=$TA; APP=$AA; else TAG=$TB; APP=$AB; fi
    xcrun devicectl device install app --device "$DEV" "$APP" > /dev/null
    launch; sleep 20
    S=$(now)
    for i in $(seq 1 "$PER"); do launch; echo "$(date +%H:%M:%S) block $b $TAG launch $i"; sleep "$GAP"; done
    echo "$TAG $S $(now)" >> "$WIN"
    pull
  done
done
pull
python3 "$HERE/parse_ios.py" "$PROBE" "$WIN" "$DIR"
