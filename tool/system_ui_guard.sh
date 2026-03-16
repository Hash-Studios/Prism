#!/usr/bin/env bash

set -euo pipefail

if command -v rg >/dev/null 2>&1; then
  matches="$({
    rg -n --no-heading "statusBarColor\\s*:" lib test \
      -g '!**/*.g.dart' \
      -g '!**/*.freezed.dart' \
      -g '!**/*.gr.dart' \
      -g '!**/*.config.dart' \
      -g '!**/edge_to_edge_overlay_style.dart' || true
    rg -n --no-heading "systemNavigationBarColor\\s*:" lib test \
      -g '!**/*.g.dart' \
      -g '!**/*.freezed.dart' \
      -g '!**/*.gr.dart' \
      -g '!**/*.config.dart' \
      -g '!**/edge_to_edge_overlay_style.dart' || true
    rg -n --no-heading "systemNavigationBarDividerColor\\s*:" lib test \
      -g '!**/*.g.dart' \
      -g '!**/*.freezed.dart' \
      -g '!**/*.gr.dart' \
      -g '!**/*.config.dart' \
      -g '!**/edge_to_edge_overlay_style.dart' || true
  } | sort -u)"
else
  matches="$(
    grep -rn --include='*.dart' \
      -e 'statusBarColor\s*:' \
      -e 'systemNavigationBarColor\s*:' \
      -e 'systemNavigationBarDividerColor\s*:' \
      lib test \
      | grep -v 'edge_to_edge_overlay_style.dart' || true
  )"
fi

if [[ -n "$matches" ]]; then
  echo "Found forbidden SystemUiOverlayStyle color fields (edge-to-edge guard):"
  echo "$matches"
  exit 1
fi

echo "system_ui_guard passed: no forbidden overlay color fields found."
