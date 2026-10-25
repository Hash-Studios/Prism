#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/search.sh"
require_search_paths lib test

if command -v rg >/dev/null 2>&1; then
  matches="$(
    rg -n --no-heading '(statusBarColor|systemNavigationBarColor|systemNavigationBarDividerColor)[[:space:]]*:' lib test \
      -g '!**/*.g.dart' \
      -g '!**/*.freezed.dart' \
      -g '!**/*.gr.dart' \
      -g '!**/*.config.dart' \
      -g '!**/edge_to_edge_overlay_style.dart' || [[ $? == 1 ]]
  )"
else
  matches="$(
    grep -rnE --include='*.dart' \
      --exclude='*.g.dart' --exclude='*.freezed.dart' \
      --exclude='*.gr.dart' --exclude='*.config.dart' \
      --exclude='edge_to_edge_overlay_style.dart' \
      -e '(statusBarColor|systemNavigationBarColor|systemNavigationBarDividerColor)[[:space:]]*:' \
      lib test || [[ $? == 1 ]]
  )"
fi

if [[ -n "$matches" ]]; then
  echo "Found forbidden SystemUiOverlayStyle color fields (edge-to-edge guard):"
  echo "$matches"
  exit 1
fi

echo "system_ui_guard passed: no forbidden overlay color fields found."
