#!/usr/bin/env bash

set -euo pipefail

matches="$(
  rg -n --no-heading "String\\.fromEnvironment\\(" lib test \
    -g '!lib/env/env.dart' \
    -g '!**/*.g.dart' \
    -g '!**/*.freezed.dart' \
    -g '!**/*.gr.dart' \
    -g '!**/*.config.dart' || true
)"

if [[ -n "$matches" ]]; then
  echo "Found forbidden String.fromEnvironment usage outside lib/env/env.dart:"
  echo "$matches"
  exit 1
fi

echo "env_define_guard passed: no forbidden String.fromEnvironment usage found."
