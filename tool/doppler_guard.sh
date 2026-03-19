#!/usr/bin/env bash

set -euo pipefail

if command -v rg >/dev/null 2>&1; then
  has_match() {
    rg -n --no-heading "$1" "$2" >/dev/null
  }
else
  has_match() {
    grep -En "$1" "$2" >/dev/null
  }
fi

if has_match "ENV_DART_DEFINES[[:space:]]*\\?=[[:space:]]*\\$\\(shell ./tool/dart_defines_from_env.sh\\)" Makefile; then
  echo "doppler_guard failed: Makefile still uses .env as the runtime secret source."
  exit 1
fi

if ! has_match "ENV_DART_DEFINES[[:space:]]*\\?=[[:space:]]*\\$\\(shell .*dart_defines_from_doppler.sh\\)" Makefile; then
  echo "doppler_guard failed: Makefile is not wired to dart_defines_from_doppler.sh."
  exit 1
fi

for target in run build build-ios build-ipa; do
  if ! has_match "^$target:.*doppler-check" Makefile; then
    echo "doppler_guard failed: target '$target' does not depend on doppler-check."
    exit 1
  fi
done

if ! has_match "^secrets-guard:" Makefile; then
  echo "doppler_guard failed: secrets-guard target is missing."
  exit 1
fi

if ! has_match "^ci:.*secrets-guard" Makefile; then
  echo "doppler_guard failed: ci target does not include secrets-guard."
  exit 1
fi

echo "doppler_guard passed: Doppler-first Makefile wiring is in place."
