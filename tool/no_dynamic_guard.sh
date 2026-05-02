#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Paths excluded from the dynamic-type check.
# - lib/core/firestore/: raw Firestore boundary — dynamic is expected there.
# - Generated files: *.g.dart, *.freezed.dart, *.gr.dart, *.config.dart
EXCLUDED_PATHS_REGEX='^lib/core/firestore/|\.g\.dart$|\.freezed\.dart$|\.gr\.dart$|\.config\.dart$'

violations=0

check_pattern() {
  local pattern="$1"
  local title="$2"
  local matches
  matches="$(rg -n "$pattern" lib test 2>/dev/null || true)"
  if [[ -z "$matches" ]]; then
    return
  fi

  while IFS= read -r line; do
    local file
    file="$(echo "$line" | cut -d: -f1)"
    if [[ ! "$file" =~ $EXCLUDED_PATHS_REGEX ]]; then
      if [[ $violations -eq 0 ]]; then
        echo "No-dynamic guard violations:"
      fi
      echo "  [$title] $line"
      violations=$((violations + 1))
    fi
  done <<< "$matches"
}

check_pattern ': dynamic\b' ': dynamic'
check_pattern 'List<dynamic>' 'List<dynamic>'
check_pattern 'Map<dynamic, dynamic>' 'Map<dynamic, dynamic>'
check_pattern ' as dynamic\b' 'as dynamic'

if [[ $violations -gt 0 ]]; then
  echo "Total no-dynamic guard violations: $violations"
  exit 1
fi

echo "No-dynamic guard passed."
