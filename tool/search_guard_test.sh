#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

backends=(grep)
if command -v rg >/dev/null 2>&1; then
  backends=(rg grep)
else
  echo 'rg backend skipped: ripgrep is not installed; coverage is limited to grep' >&2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/work/lib" "$scratch/work/test" "$scratch/rg" "$scratch/grep"
mkdir -p "$scratch/tool/lib"
cp "$root/tool/lib/search.sh" "$scratch/tool/lib/"
for guard in analytics_raw_usage env_define system_ui firestore no_dynamic no_shape_parse; do
  cp "$root/tool/${guard}_guard.sh" "$scratch/tool/"
done
printf 'needle\n' > "$scratch/work/lib/sample.dart"
for backend in "${backends[@]}"; do
  for binary in grep dirname bash; do
    ln -s "$(command -v "$binary")" "$scratch/$backend/$binary"
  done
  if [[ $backend == rg ]]; then
    ln -s "$(command -v rg)" "$scratch/$backend/rg"
  fi
  export SEARCH_HELPER="$root/tool/lib/search.sh"
  for scenario in match no-match missing missing-dart mixed-missing invalid; do
    pattern=needle
    target="$scratch/work/lib"
    [[ $scenario != no-match ]] || pattern=absent
    [[ $scenario != missing ]] || target="$scratch/missing"
    [[ $scenario != missing-dart ]] || target="$scratch/missing.dart"
    [[ $scenario != mixed-missing ]] || target="$scratch/missing"
    [[ $scenario != invalid ]] || pattern='['
    search_status=0
    PATH="$scratch/$backend" /bin/bash -c '
      source "$SEARCH_HELPER"
      if [[ $3 == mixed-missing ]]; then
        search "$1" "${2%/missing}/work/lib" "$2"
      else
        search "$1" "$2"
      fi
    ' \
      _ "$pattern" "$target" "$scenario" > "$scratch/out" 2> "$scratch/err" || search_status=$?
    case $scenario in
      match) [[ $search_status == 0 && -s "$scratch/out" ]] ;;
      no-match) [[ $search_status == 0 && ! -s "$scratch/out" && ! -s "$scratch/err" ]] ;;
      missing|missing-dart|mixed-missing|invalid)
        [[ $search_status == 2 && -s "$scratch/err" ]] || exit 1
        ! grep -q 'command not found' "$scratch/err"
        if [[ $scenario == *missing* ]]; then
          grep -Fq "$target" "$scratch/err"
          grep -Fq 'No such file or directory' "$scratch/err"
        else
          grep -Eiq 'regex|regular expression|brackets? .*not balanced' "$scratch/err"
        fi
        ;;
    esac
  done
  for guard in analytics_raw_usage env_define system_ui firestore no_dynamic no_shape_parse; do
    search_status=0
    (cd "$scratch"; PATH="$scratch/$backend" /bin/bash "$scratch/tool/${guard}_guard.sh") \
      > "$scratch/out" 2> "$scratch/err" || search_status=$?
    [[ $search_status -gt 0 && $search_status -lt 126 && -s "$scratch/err" ]]
    ! grep -q 'command not found' "$scratch/err"
    grep -Fq 'No such file or directory' "$scratch/err"
    grep -Eq 'lib|test' "$scratch/err"
  done
  printf 'analytics.logEvent();\n' > "$scratch/work/lib/sample.dart"
  search_status=0
  (cd "$scratch/work"; PATH="$scratch/$backend" /bin/bash "$scratch/tool/analytics_raw_usage_guard.sh") \
    > "$scratch/out" 2> "$scratch/err" || search_status=$?
  [[ $search_status == 1 && ! -s "$scratch/err" ]]
  grep -Fq 'Forbidden analytics.logEvent usage detected outside analytics internals:' "$scratch/out"
  grep -Fq 'lib/sample.dart:1:analytics.logEvent();' "$scratch/out"
  printf 'needle\n' > "$scratch/work/lib/sample.dart"
done
echo "search guard behavior passed for: ${backends[*]}"
