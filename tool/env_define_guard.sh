#!/usr/bin/env bash

set -euo pipefail

if command -v rg >/dev/null 2>&1; then
  matches="$(
    rg -n --no-heading "String\\.fromEnvironment\\(" lib test \
      -g '!lib/env/env.dart' \
      -g '!**/*.g.dart' \
      -g '!**/*.freezed.dart' \
      -g '!**/*.gr.dart' \
      -g '!**/*.config.dart' || true
  )"
else
  matches="$(
    grep -rn "String\.fromEnvironment(" lib test \
      --include='*.dart' \
      --exclude='env.dart' \
      --exclude='*.g.dart' \
      --exclude='*.freezed.dart' \
      --exclude='*.gr.dart' \
      --exclude='*.config.dart' || true
  )"
fi

if [[ -n "$matches" ]]; then
  echo "Found forbidden String.fromEnvironment usage outside lib/env/env.dart:"
  echo "$matches"
  exit 1
fi

echo "env_define_guard passed: no forbidden String.fromEnvironment usage found."
