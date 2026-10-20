#!/usr/bin/env bash
# Reads secrets from Doppler and emits --dart-define flags.
# Usage:
#   DOPPLER_PROJECT=prism DOPPLER_CONFIG=dev ./tool/dart_defines_from_doppler.sh

set -euo pipefail

PROJECT="${DOPPLER_PROJECT:-prism}"
CONFIG="${DOPPLER_CONFIG:-dev}"

if ! command -v doppler >/dev/null 2>&1; then
  echo "dart_defines_from_doppler failed: Doppler CLI not installed." >&2
  echo "Install: https://docs.doppler.com/docs/install-cli" >&2
  exit 1
fi

if ! env_payload="$(doppler secrets download --no-file --format env --project "$PROJECT" --config "$CONFIG")"; then
  echo "dart_defines_from_doppler failed: unable to download secrets for $PROJECT/$CONFIG." >&2
  exit 1
fi

defines=""
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

  key="${line%%=*}"
  value="${line#*=}"

  [[ -z "$key" || -z "$value" ]] && continue
  [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
  case "$key" in
    GH_TOKEN|R2_ACCESS_KEY_ID|R2_SECRET_ACCESS_KEY|R2_ACCOUNT_ID|R2_PRIVATE_BUCKET|R2_PREVIEW_BUCKET) continue ;;
  esac

  token="--dart-define=$key=$value"
  defines="$defines $(printf '%q' "$token")"
done <<<"$env_payload"

echo "$defines"
