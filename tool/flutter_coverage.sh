#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-coverage/flutter}"
minimum="${2:-90}"
if [[ "$output_dir" != /* ]]; then
  output_dir="$root/$output_dir"
fi
mkdir -p "$output_dir"
full_lcov="$output_dir/full.lcov"
inventory_lcov="$output_dir/inventory.lcov"
for output in "$full_lcov" "$inventory_lcov"; do
  if [[ -e "$output" || -L "$output" ]]; then
    rm -- "$output"
  fi
done

helper=""
cleanup() {
  if [[ -n "$helper" && ( -e "$helper" || -L "$helper" ) ]]; then
    rm -- "$helper"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

cd "$root"
fvm flutter test --coverage --coverage-path="$full_lcov"

suffix=0
while :; do
  helper="$root/test/coverage_inventory_${$}_${suffix}_test.dart"
  [[ ! -e "$helper" ]] && break
  suffix=$((suffix + 1))
done
python3 tool/test_coverage.py imports "$helper"
fvm flutter test "$helper" --coverage --coverage-path="$inventory_lcov"
python3 tool/test_coverage.py report "$full_lcov" \
  --inventory "$inventory_lcov" \
  --verify-declarations \
  --minimum "$minimum"
