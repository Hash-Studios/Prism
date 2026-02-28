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

raw_share_wrapper_usage="$(
  rg -n --no-heading "analytics\\.logShare\\(" lib test \
    -g '!lib/core/analytics/**' \
    -g '!test/core/analytics/**' || true
)"

if [[ -n "$raw_share_wrapper_usage" ]]; then
  echo "Forbidden analytics.logShare usage detected outside analytics internals:"
  echo "$raw_share_wrapper_usage"
  exit 1
fi

raw_login_wrapper_usage="$(
  rg -n --no-heading "analytics\\.logLogin\\(" lib test \
    -g '!lib/core/analytics/**' \
    -g '!test/core/analytics/**' || true
)"

if [[ -n "$raw_login_wrapper_usage" ]]; then
  echo "Forbidden analytics.logLogin usage detected outside analytics internals:"
  echo "$raw_login_wrapper_usage"
  exit 1
fi

raw_screen_wrapper_usage="$(
  rg -n --no-heading "analytics\\.logScreenView\\(" lib test \
    -g '!lib/core/analytics/**' \
    -g '!test/core/analytics/**' || true
)"

if [[ -n "$raw_screen_wrapper_usage" ]]; then
  echo "Forbidden analytics.logScreenView usage detected outside analytics internals:"
  echo "$raw_screen_wrapper_usage"
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
