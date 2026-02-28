#!/usr/bin/env bash

set -euo pipefail

PROJECT="${DOPPLER_PROJECT:-prism}"
CONFIG="${DOPPLER_CONFIG:-dev}"
REQUIRED="${DOPPLER_REQUIRED:-true}"

if ! command -v doppler >/dev/null 2>&1; then
  if [[ "$REQUIRED" == "true" ]]; then
    echo "doppler_check failed: Doppler CLI is not installed."
    echo "Install: https://docs.doppler.com/docs/install-cli"
    exit 1
  fi
  echo "doppler_check skipped: Doppler CLI not installed and DOPPLER_REQUIRED=false."
  exit 0
fi

if [[ -z "${DOPPLER_TOKEN:-}" ]]; then
  if ! doppler me >/dev/null 2>&1; then
    if [[ "$REQUIRED" == "true" ]]; then
      echo "doppler_check failed: no DOPPLER_TOKEN and not logged in."
      echo "Run: make doppler-login"
      exit 1
    fi
    echo "doppler_check skipped: unauthenticated and DOPPLER_REQUIRED=false."
    exit 0
  fi
fi

if ! env_dump="$(doppler secrets download --no-file --format env --project "$PROJECT" --config "$CONFIG")"; then
  echo "doppler_check failed: cannot access $PROJECT/$CONFIG."
  exit 1
fi

if command -v rg >/dev/null 2>&1; then
  required_keys="$(
    rg -No "String\\.fromEnvironment\\('([^']+)'" lib/env/env.dart -r '$1' \
      | sort -u
  )"
else
  required_keys="$(
    grep -o "String\.fromEnvironment('[^']*'" lib/env/env.dart \
      | sed -E "s/String\\.fromEnvironment\\('([^']*)'/\\1/" \
      | sort -u
  )"
fi
available_keys="$(
  printf "%s\n" "$env_dump" \
    | awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=/{print $1}' \
    | sort -u
)"

missing_count=0
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  if ! grep -Fxq "$key" <<<"$available_keys"; then
    echo "doppler_check failed: missing key in Doppler config: $key"
    missing_count=$((missing_count + 1))
  fi
done <<<"$required_keys"

if [[ "$missing_count" -gt 0 ]]; then
  echo "doppler_check failed: add missing keys to Doppler project '$PROJECT' config '$CONFIG'."
  exit 1
fi

echo "doppler_check passed: $PROJECT/$CONFIG is accessible and contains required keys."
