#!/usr/bin/env bash

set -euo pipefail

PROJECT="${DOPPLER_PROJECT:-prism}"
CONFIG="${DOPPLER_CONFIG:-dev}"

if ! command -v doppler >/dev/null 2>&1; then
  echo "Doppler CLI is not installed."
  echo "Install: https://docs.doppler.com/docs/install-cli"
  exit 1
fi

if [[ -z "${DOPPLER_TOKEN:-}" ]]; then
  if ! doppler me >/dev/null 2>&1; then
    echo "No active Doppler login found. Opening Doppler login..."
    doppler login
  fi
fi

if [[ ! -f .doppler.yaml ]]; then
  echo "Configuring local Doppler context for this repo..."
  doppler setup --project "$PROJECT" --config "$CONFIG"
fi

DOPPLER_PROJECT="$PROJECT" DOPPLER_CONFIG="$CONFIG" DOPPLER_REQUIRED=true ./tool/doppler_check.sh

echo "Doppler local setup is complete."
echo "Next step: make run"
