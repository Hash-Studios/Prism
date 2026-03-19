#!/usr/bin/env bash
# Fetches Sentry credentials from Doppler and uploads an AAB to Sentry for size analysis.
# Usage (called by Makefile):
#   DOPPLER_PROJECT=prism SENTRY_DOPPLER_CONFIG=prd AAB_PATH=build/app/outputs/bundle/release/app-release.aab ./tool/sentry_size_upload.sh

set -euo pipefail

PROJECT="${DOPPLER_PROJECT:-prism}"
CONFIG="${SENTRY_DOPPLER_CONFIG:-prd}"
AAB_PATH="${AAB_PATH:-build/app/outputs/bundle/release/app-release.aab}"

if ! command -v sentry-cli >/dev/null 2>&1; then
  echo "sentry_size_upload: sentry-cli not installed — skipping size analysis upload."
  echo "Install it with: curl -sL https://sentry.io/get-cli/ | sh"
  exit 0
fi

if ! command -v doppler >/dev/null 2>&1; then
  echo "sentry_size_upload: Doppler CLI not installed — skipping size analysis upload."
  exit 0
fi

if [ ! -f "$AAB_PATH" ]; then
  echo "sentry_size_upload: AAB not found at $AAB_PATH — did you run make build-aab first?"
  exit 1
fi

echo "Fetching Sentry credentials from Doppler ($PROJECT/$CONFIG)..."

fetch_secret() {
  local result
  result=$(doppler secrets get "$1" --plain --project "$PROJECT" --config "$CONFIG" 2>&1) || {
    echo "sentry_size_upload: doppler fetch failed for $1: $result" >&2
    echo ""
    return 0
  }
  echo "$result"
}

export SENTRY_AUTH_TOKEN="${SENTRY_AUTH_TOKEN:-$(fetch_secret SENTRY_AUTH_TOKEN)}"
export SENTRY_ORG="${SENTRY_ORG:-$(fetch_secret SENTRY_ORG)}"
_project="$(fetch_secret SENTRY_PROJECT)"
if [ -z "$_project" ]; then
  _project="$(fetch_secret SENTRY_PROJECT_PRODUCTION)"
fi
export SENTRY_PROJECT="${SENTRY_PROJECT:-$_project}"

if [ -z "$SENTRY_AUTH_TOKEN" ] || [ -z "$SENTRY_ORG" ] || [ -z "$SENTRY_PROJECT" ]; then
  echo "sentry_size_upload: missing SENTRY_AUTH_TOKEN, SENTRY_ORG, or SENTRY_PROJECT in Doppler $PROJECT/$CONFIG — skipping."
  exit 0
fi

echo "Uploading $AAB_PATH to Sentry size analysis (org=$SENTRY_ORG, project=$SENTRY_PROJECT)..."
sentry-cli build upload "$AAB_PATH" \
  --org "$SENTRY_ORG" \
  --project "$SENTRY_PROJECT" \
  --build-configuration Release
echo "Size analysis upload complete."
