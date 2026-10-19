#!/usr/bin/env bash
# Usage: run_android.sh <tag> <apk> [launches=20]. Env: ANDROID_SERIAL, PRISM_PERF_DIR.
set -euo pipefail
TAG=${1:?tag}; APK=${2:?apk}; N=${3:-20}
export ANDROID_SERIAL=${ANDROID_SERIAL:-emulator-5580}
export PRISM_PERF_DIR=${PRISM_PERF_DIR:-/tmp/prism-perf}
HERE=$(cd "$(dirname "$0")" && pwd)
LOCK=${PRISM_PERF_LOCK:-/tmp/prism-verify-android.lock}
ADB=(adb -s "$ANDROID_SERIAL")
if [ -e "$LOCK" ]; then
  echo "Device lock held:"; cat "$LOCK"; exit 1
fi
mkdir -p "$PRISM_PERF_DIR"
MAX_LOAD=${PRISM_PERF_MAX_LOAD:-$(( $(sysctl -n hw.ncpu) / 2 ))}
until [ "$(sysctl -n vm.loadavg | awk '{printf "%d", $2}')" -le "$MAX_LOAD" ]; do
  echo "load $(sysctl -n vm.loadavg) above $MAX_LOAD, waiting"; sleep 30
done
OWN=0; LOGPID=
cleanup() {
  [ -n "$LOGPID" ] && kill "$LOGPID" 2>/dev/null || true
  [ "$OWN" = 1 ] && rm -f "$LOCK" || true
}
trap cleanup EXIT
if ! ( set -o noclobber; echo "perf-harness $TAG $(date)" > "$LOCK" ) 2>/dev/null; then
  echo "Device lock held:"; cat "$LOCK"; exit 1
fi
OWN=1
if [ "${PRISM_PERF_REBOOT:-1}" = 1 ]; then
  "${ADB[@]}" reboot
  "${ADB[@]}" wait-for-device
  until [ "$("${ADB[@]}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do sleep 2; done
  sleep 60
fi
"${ADB[@]}" install -r "$APK"
"${ADB[@]}" shell am start -W -n com.hash.prism/.MainActivity > /dev/null
sleep 15
"${ADB[@]}" shell am force-stop com.hash.prism
"${ADB[@]}" shell run-as com.hash.prism rm -f app_flutter/performance_probe.ndjson
"${ADB[@]}" logcat -c
"${ADB[@]}" logcat -v epoch > "$PRISM_PERF_DIR/$TAG-logcat.txt" &
LOGPID=$!
python3 "$HERE/drive_android.py" "$TAG" "$N" --shots
"${ADB[@]}" exec-out run-as com.hash.prism cat app_flutter/performance_probe.ndjson > "$PRISM_PERF_DIR/$TAG-probe.ndjson"
python3 "$HERE/parse_android.py" "$PRISM_PERF_DIR/$TAG-logcat.txt" "$PRISM_PERF_DIR/$TAG-probe.ndjson" "$PRISM_PERF_DIR/android_${TAG}_am.json" "$PRISM_PERF_DIR/$TAG-samples.json"
