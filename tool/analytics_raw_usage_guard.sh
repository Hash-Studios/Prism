#!/usr/bin/env bash

set -euo pipefail

# When given a workspace path (e.g. from tests), cd there first so the search covers the right tree
if [[ -n "${1:-}" ]]; then
  cd "$1"
fi

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/search.sh"

forbid() {
  local pattern="$1"
  local message="$2"
  local matches
  matches="$(search "$pattern" lib test | grep -Ev '^(lib|test)/core/analytics/' || true)"

  if [[ -n "$matches" ]]; then
    echo "$message"
    echo "$matches"
    exit 1
  fi
}

forbid 'analytics\.logEvent\(' \
  "Forbidden analytics.logEvent usage detected outside analytics internals:"
forbid 'analytics\.logShare\(' \
  "Forbidden analytics.logShare usage detected outside analytics internals:"
forbid 'analytics\.logLogin\(' \
  "Forbidden analytics.logLogin usage detected outside analytics internals:"
forbid 'analytics\.logScreenView\(' \
  "Forbidden analytics.logScreenView usage detected outside analytics internals:"
forbid "logEvent\\(name:[[:space:]]*['\"]" \
  "Forbidden raw event-name literals detected outside analytics internals:"
forbid 'package:mixpanel_flutter/mixpanel_flutter\.dart' \
  "Forbidden direct mixpanel_flutter import detected outside analytics internals:"
forbid '(^|[^A-Za-z0-9_])mixpanel\.(track|identify|reset|registerSuperProperties|getPeople|set|setOnce)' \
  "Forbidden direct Mixpanel client usage detected outside analytics internals:"
forbid 'FirebaseAnalytics\.(instance|observer)|FirebaseAnalyticsObserver\(' \
  "Forbidden direct Firebase analytics usage detected outside analytics internals:"

echo "analytics_raw_usage_guard passed: no raw analytics event usage found."
