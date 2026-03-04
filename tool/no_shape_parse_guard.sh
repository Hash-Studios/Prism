#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TARGETS=(
  "lib/features/wallhaven_feed/data"
  "lib/features/pexels_feed/data"
  "lib/features/prism_feed/data"
  "lib/features/setups/data"
  "lib/features/profile_setups/data"
  "lib/features/profile_walls/data"
  "lib/features/public_profile/data"
  "lib/features/favourite_setups/data"
  "lib/features/favourite_walls/data"
)

EXCLUDE_REGEX='\.g\.dart$|\.freezed\.dart$|\.gr\.dart$|\.config\.dart$'

violations=0

check_pattern() {
  local pattern="$1"
  local title="$2"
  local matches
  matches="$(rg -n "$pattern" "${TARGETS[@]}" 2>/dev/null || true)"
  if [[ -z "$matches" ]]; then
    return
  fi

  while IFS= read -r line; do
    local file
    file="$(echo "$line" | cut -d: -f1)"
    if [[ "$file" =~ $EXCLUDE_REGEX ]]; then
      continue
    fi
    if [[ $violations -eq 0 ]]; then
      echo "No-shape-parse guard violations:"
    fi
    echo "  [$title] $line"
    violations=$((violations + 1))
  done <<< "$matches"
}

check_pattern '\bis\s+Map\b|\bis!\s+Map\b' 'Map type-check'
check_pattern '\bis\s+List\b|\bis!\s+List\b' 'List type-check'
check_pattern '\bObject\?\s+[a-zA-Z_]' 'Object? declaration/parameter'

if [[ $violations -gt 0 ]]; then
  echo "Total no-shape-parse guard violations: $violations"
  exit 1
fi

echo "No-shape-parse guard passed."
