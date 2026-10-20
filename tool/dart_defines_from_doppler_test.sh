#!/usr/bin/env bash
set -euo pipefail

doppler() {
  printf '%s\n' 'GH_TOKEN=server-github' 'R2_ACCESS_KEY_ID=server-access' \
    'R2_SECRET_ACCESS_KEY=server-secret' 'R2_ACCOUNT_ID=server-account' \
    'R2_PRIVATE_BUCKET=server-private' 'R2_PREVIEW_BUCKET=server-preview' \
    'R2_PREVIEW_BASE_URL=https://images.example.com' 'GH_USERNAME=owner'
}
export -f doppler

result="$(bash tool/dart_defines_from_doppler.sh)"
[[ "$result" != *server-* ]]
[[ "$result" == *'--dart-define=R2_PREVIEW_BASE_URL=https://images.example.com'* ]]
[[ "$result" == *'--dart-define=GH_USERNAME=owner'* ]]
echo 'Doppler app defines exclude R2 credentials and private configuration.'
