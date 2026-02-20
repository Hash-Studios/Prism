#!/usr/bin/env bash

set -euo pipefail

raw_facade_usage="$(
  rg -n --no-heading "analytics\\.logEvent\\(" lib test \
    -g '!lib/core/analytics/**' \
    -g '!test/core/analytics/**' || true
)"

if [[ -n "$raw_facade_usage" ]]; then
  echo "Forbidden analytics.logEvent usage detected outside analytics internals:"
  echo "$raw_facade_usage"
  exit 1
fi

raw_provider_usage="$(
  rg -n --no-heading "logEvent\\(name:\\s*['\"]" lib test \
    -g '!lib/core/analytics/**' \
    -g '!test/core/analytics/**' || true
)"

if [[ -n "$raw_provider_usage" ]]; then
  echo "Forbidden raw event-name literals detected outside analytics internals:"
  echo "$raw_provider_usage"
  exit 1
fi

echo "analytics_raw_usage_guard passed: no raw analytics event usage found."
