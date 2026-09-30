#!/usr/bin/env bash
# Shared by the guard scripts. search PATTERN PATH... prints file:line:text
# for Dart files, with ripgrep when installed and grep otherwise. Patterns must
# be POSIX ERE so both tools agree. A missing ripgrep must never look like
# "no matches".

search() {
  local pattern="$1"
  shift
  if command -v rg >/dev/null 2>&1; then
    rg -n --no-heading -g '*.dart' -e "$pattern" "$@" 2>/dev/null || true
  else
    grep -rnE --include='*.dart' -e "$pattern" "$@" 2>/dev/null || true
  fi
}
