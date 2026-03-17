#!/usr/bin/env bash
# Fetches Sentry credentials from Doppler and uploads debug symbols via sentry_dart_plugin.
# Usage (called by Makefile):
#   DOPPLER_PROJECT=prism SENTRY_DOPPLER_CONFIG=production DART_CMD="fvm dart" ./tool/sentry_upload.sh

set -euo pipefail

PROJECT="${DOPPLER_PROJECT:-prism}"
CONFIG="${SENTRY_DOPPLER_CONFIG:-production}"
DART_CMD="${DART_CMD:-dart}"

if ! command -v doppler >/dev/null 2>&1; then
  echo "sentry_upload: Doppler CLI not installed — skipping symbol upload."
  exit 0
fi

echo "Fetching Sentry credentials from Doppler ($PROJECT/$CONFIG)..."

fetch_secret() {
  doppler secrets get "$1" --plain --project "$PROJECT" --config "$CONFIG" 2>/dev/null || true
}

export SENTRY_AUTH_TOKEN="${SENTRY_AUTH_TOKEN:-$(fetch_secret SENTRY_AUTH_TOKEN)}"
export SENTRY_ORG="${SENTRY_ORG:-$(fetch_secret SENTRY_ORG)}"
# Try SENTRY_PROJECT first, fall back to SENTRY_PROJECT_PRODUCTION (used in CI workflow)
_project="$(fetch_secret SENTRY_PROJECT)"
if [ -z "$_project" ]; then
  _project="$(fetch_secret SENTRY_PROJECT_PRODUCTION)"
fi
export SENTRY_PROJECT="${SENTRY_PROJECT:-$_project}"

if [ -z "$SENTRY_AUTH_TOKEN" ] || [ -z "$SENTRY_ORG" ] || [ -z "$SENTRY_PROJECT" ]; then
  echo "sentry_upload: missing SENTRY_AUTH_TOKEN, SENTRY_ORG, or SENTRY_PROJECT_PRODUCTION in Doppler $PROJECT/$CONFIG — skipping."
  exit 0
fi

echo "Uploading debug symbols to Sentry (org=$SENTRY_ORG, project=$SENTRY_PROJECT)..."
$DART_CMD run sentry_dart_plugin
