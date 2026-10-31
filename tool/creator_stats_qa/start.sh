#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" != demo-prism || "$#" != 1 ]]; then
  echo 'Usage: bash tool/creator_stats_qa/start.sh demo-prism' >&2
  exit 2
fi
cd "$(dirname "$0")/../.."
node tool/creator_stats_qa/prepare.cjs demo-prism
mkdir -p tool/creator_stats_qa/.runtime/config tool/creator_stats_qa/.runtime/gcloud
exec env -i PATH="$PATH" XDG_CONFIG_HOME="$PWD/tool/creator_stats_qa/.runtime/config" \
  CLOUDSDK_CONFIG="$PWD/tool/creator_stats_qa/.runtime/gcloud" GOOGLE_APPLICATION_CREDENTIALS=/dev/null \
  JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}" \
  GCLOUD_PROJECT=demo-prism GOOGLE_CLOUD_PROJECT=demo-prism \
  FIREBASE_CONFIG='{"projectId":"demo-prism"}' \
  FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  firebase emulators:start --project demo-prism --config tool/creator_stats_qa/firebase.json --only auth,firestore,functions
