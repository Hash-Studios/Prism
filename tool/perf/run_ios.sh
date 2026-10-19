#!/usr/bin/env bash
# Usage: run_ios.sh <tag> <Runner.app> [launches=20]. Env: PRISM_IOS_DEVICE (UDID), PRISM_PERF_DIR, PRISM_PERF_SETTLE (s per launch).
# Needs a profile build made with --dart-define=PRISM_PERF_AUTODRIVE=true and an unlocked phone that stays awake.
set -euo pipefail
TAG=${1:?tag}; APP=${2:?app}; N=${3:-20}
DEV=${PRISM_IOS_DEVICE:?set PRISM_IOS_DEVICE}
DIR=${PRISM_PERF_DIR:-/tmp/prism-perf}
SETTLE=${PRISM_PERF_SETTLE:-35}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$DIR"
xcrun devicectl device install app --device "$DEV" "$APP" > /dev/null
launch() { xcrun devicectl device process launch --device "$DEV" --terminate-existing com.hash.prism > /dev/null; }
launch; sleep "$SETTLE"
START=$(python3 -c 'import datetime;print(datetime.datetime.now(datetime.timezone.utc).isoformat())')
for i in $(seq 1 "$N"); do
  launch
  echo "$(date +%H:%M:%S) $TAG launch $i"
  sleep "$SETTLE"
done
xcrun devicectl device process launch --device "$DEV" --terminate-existing com.apple.Preferences > /dev/null 2>&1 || true
xcrun devicectl device copy from --device "$DEV" --domain-type appDataContainer --domain-identifier com.hash.prism \
  --source Documents/performance_probe.ndjson --destination "$DIR/$TAG-probe.ndjson" > /dev/null
python3 "$HERE/parse_ios.py" "$DIR/$TAG-probe.ndjson" "$START" "$DIR/$TAG-samples.json"
