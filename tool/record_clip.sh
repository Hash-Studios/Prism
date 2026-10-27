#!/usr/bin/env bash
# Usage: tool/record_clip.sh ios|android [out.mp4] [--trim START-END]
# Records Prism from the booted iOS Simulator or Android emulator; Ctrl-C stops. Output is 1080x1920 MP4.
# With more than one booted iOS Simulator, set IOS_SIM=<udid>. With more than one Android device, set ANDROID_SERIAL.
set -euo pipefail

usage() { echo "usage: tool/record_clip.sh ios|android [out.mp4] [--trim START-END]" >&2; exit 2; }
die() { echo "record_clip: $*" >&2; exit 1; }

[ $# -ge 1 ] || usage
platform=$1; shift
case "$platform" in ios | android) ;; *) usage ;; esac

out=""; trim=""; remote=""; stopping=0
while [ $# -gt 0 ]; do
  case "$1" in
    --trim) [ $# -ge 2 ] && [ -n "$2" ] || usage; trim=$2; shift 2 ;;
    -*) usage ;;
    *) [ -z "$out" ] || usage; out=$1; shift ;;
  esac
done
[ -n "$out" ] || out="prism-$platform-$(date +%Y%m%d-%H%M%S).mp4"

trim_args=()
if [ -n "$trim" ]; then
  [[ $trim =~ ^[0-9:.]+-[0-9:.]+$ ]] || die "--trim needs START-END timestamps, got: $trim"
  start=${trim%%-*}; end=${trim#*-}
  trim_args=(-ss "$start" -to "$end")
fi

command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg not found. Install it (brew install ffmpeg)."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"; [ -z "$remote" ] || adb shell rm -f "$remote" >/dev/null 2>&1 || true' EXIT

if [ "$platform" = ios ]; then
  simctl=$(xcrun -f simctl 2>/dev/null) || die "simctl not found. Install Xcode and its command line tools."
  devices=$("$simctl" list devices booted) || die "could not list iOS Simulators"
  booted=$(printf '%s\n' "$devices" | awk '/^-- /{ios=($2=="iOS")} ios' | sed -n 's/.*(\([^()]*\)) (Booted)[[:space:]]*$/\1/p')
  count=$(printf '%s\n' "$booted" | grep -c . || true)
  [ "$count" -ge 1 ] || die "no booted iOS Simulator"
  sim=${IOS_SIM:-booted}
  if [ "$sim" = booted ]; then
    [ "$count" -eq 1 ] || die "$count simulators are booted. Set IOS_SIM=<udid>."
    sim=$booted
  else
    [[ $sim != *$'\n'* ]] || die "IOS_SIM must be a booted simulator UDID"
    printf '%s\n' "$booted" | grep -Fxi -- "$sim" >/dev/null || die "IOS_SIM is not a booted simulator UDID: $sim"
  fi
  stop() { stopping=1; kill -INT "$rec" 2>/dev/null || true; }
  "$simctl" io "$sim" recordVideo --codec h264 --force "$tmp/raw.mp4" &
  rec=$!
  trap stop INT
  echo "Recording. Press Ctrl-C to stop." >&2
else
  command -v adb >/dev/null 2>&1 || die "adb not found. Install Android platform-tools."
  [ "$(adb get-state 2>/dev/null)" = device ] || die "need exactly one Android device or emulator (set ANDROID_SERIAL)"
  remote=/sdcard/prism_clip_$$.mp4
  stop() { stopping=1; adb shell pkill -INT -f "$remote" >/dev/null 2>&1 || true; }
  adb shell screenrecord "$remote" &
  rec=$!
  trap stop INT
  echo "Recording. Press Ctrl-C to stop. Android stops itself at 3 minutes." >&2
fi
while kill -0 "$rec" 2>/dev/null; do wait "$rec" || true; done
rc=0; wait "$rec" || rc=$?
[ "$rc" -eq 0 ] || { [ "$stopping" -eq 1 ] && [ "$rc" -eq 130 ]; } || die "recorder failed (exit $rc)"
trap - INT
if [ "$platform" = android ]; then
  sleep 1; adb pull -q "$remote" "$tmp/raw.mp4"
fi
[ -s "$tmp/raw.mp4" ] || die "recording is empty"

ffmpeg -hide_banner -loglevel error -y -i "$tmp/raw.mp4" "${trim_args[@]+"${trim_args[@]}"}" \
  -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=30" \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart -abort_on empty_output -an "$out" || {
  rm -f "$out"; mv "$tmp/raw.mp4" "${out%.*}-raw.mp4"
  die "conversion failed. The raw recording is kept at ${out%.*}-raw.mp4"
}
echo "$out"
