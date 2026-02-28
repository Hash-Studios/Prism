#!/usr/bin/env bash

set -euo pipefail

# When given a workspace path (e.g. from tests), cd there first so rg searches the right tree
if [[ -n "${1:-}" ]]; then
  cd "$1"
fi

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

direct_mixpanel_imports="$(
  rg -n --no-heading "package:mixpanel_flutter/mixpanel_flutter\\.dart" lib test \
    -g '!lib/core/analytics/**' \
    -g '!test/core/analytics/**' || true
)"

if [[ -n "$direct_mixpanel_imports" ]]; then
  echo "Forbidden direct mixpanel_flutter import detected outside analytics internals:"
  echo "$direct_mixpanel_imports"
  exit 1
fi

direct_mixpanel_usage="$(
  rg -n --no-heading "\\bmixpanel\\.(track|identify|reset|registerSuperProperties|getPeople|set|setOnce)" lib test \
    -g '!lib/core/analytics/**' \
    -g '!test/core/analytics/**' || true
)"

if [[ -n "$direct_mixpanel_usage" ]]; then
  echo "Forbidden direct Mixpanel client usage detected outside analytics internals:"
  echo "$direct_mixpanel_usage"
  exit 1
fi

direct_firebase_analytics_usage="$(
  rg -n --no-heading "FirebaseAnalytics\\.(instance|observer)|FirebaseAnalyticsObserver\\(" lib test \
    -g '!lib/core/analytics/**' \
    -g '!test/core/analytics/**' || true
)"

if [[ -n "$direct_firebase_analytics_usage" ]]; then
  echo "Forbidden direct Firebase analytics usage detected outside analytics internals:"
  echo "$direct_firebase_analytics_usage"
  exit 1
fi

echo "analytics_raw_usage_guard passed: no raw analytics event usage found."
