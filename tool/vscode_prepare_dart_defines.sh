#!/usr/bin/env bash

set -euo pipefail

DOPPLER_PROJECT="${DOPPLER_PROJECT:-prism}"
DOPPLER_CONFIG="${DOPPLER_CONFIG:-dev}"
DOPPLER_REQUIRED="${DOPPLER_REQUIRED:-true}"
export DOPPLER_PROJECT DOPPLER_CONFIG DOPPLER_REQUIRED

./tool/doppler_check.sh

mkdir -p .dart_tool/vscode
tmp_path=".dart_tool/vscode/dart_defines.generated.json.tmp"
out_path=".dart_tool/vscode/dart_defines.generated.json"

doppler secrets download --no-file --format json --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" > "$tmp_path"

python3 - "$tmp_path" "$out_path" <<'PY'
import json
import os
import sys

tmp_path = sys.argv[1]
out_path = sys.argv[2]

with open(tmp_path, "r", encoding="utf-8") as source_file:
    data = json.load(source_file)

if not os.path.exists("android/app/google-services.json"):
    data["SKIP_FIREBASE_INIT"] = "true"

for key in ("SENTRY_ENV", "SENTRY_RELEASE", "SENTRY_DIST", "SENTRY_ENABLED"):
    value = os.environ.get(key)
    if value:
      data[key] = value

with open(out_path, "w", encoding="utf-8") as output_file:
    json.dump(data, output_file)

os.remove(tmp_path)
PY
