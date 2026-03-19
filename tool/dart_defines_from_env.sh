#!/usr/bin/env bash
# Reads a .env file and emits --dart-define flags for each non-empty variable.
# Usage: tool/dart_defines_from_env.sh [path/to/.env]
#   Returns a single line of --dart-define=KEY=VALUE flags separated by spaces.

set -euo pipefail

ENV_FILE="${1:-.env}"

if [ ! -f "$ENV_FILE" ]; then
  exit 0
fi

DEFINES=""
while IFS= read -r line || [ -n "$line" ]; do
  # Skip comments and blank lines
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  # Extract KEY=VALUE
  key="${line%%=*}"
  value="${line#*=}"
  # Skip if key is empty or value is empty
  [[ -z "$key" || -z "$value" ]] && continue
  DEFINES="$DEFINES --dart-define=$key=$value"
done < "$ENV_FILE"

echo "$DEFINES"
