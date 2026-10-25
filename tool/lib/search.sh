#!/usr/bin/env bash
# Shared by the guard scripts. search PATTERN PATH... prints file:line:text
# for Dart files, with ripgrep when installed and grep otherwise. Patterns must
# be POSIX ERE so both tools agree. A missing ripgrep must never look like
# "no matches".

require_search_paths() {
  local target
  for target in "$@"; do
    if [[ ! -e "$target" ]]; then
      printf 'search: %s: No such file or directory\n' "$target" >&2
      return 2
    fi
  done
}

search() {
  local pattern="$1"
  local search_status=0
  shift
  require_search_paths "$@" || return $?
  if command -v rg >/dev/null 2>&1; then
    rg -n --no-heading -g '*.dart' -e "$pattern" "$@" || search_status=$?
  else
    grep -rnE --include='*.dart' -e "$pattern" "$@" || search_status=$?
  fi
  if (( search_status > 1 )); then return "$search_status"; fi
}
