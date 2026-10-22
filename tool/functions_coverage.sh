#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../functions"
printf '%s\n' 'Coverage includes all first-party Functions sources. The gate is 90% lines; branches and functions are reported.'
npm run build
npm exec --yes --package=c8@12.0.0 -- c8 \
  --all --src lib --include 'lib/**/*.js' --exclude 'lib/__tests__/**' \
  --check-coverage --lines 90 \
  --reporter text --reporter json-summary --reporter lcov \
  --reports-dir "${1:-../coverage/functions}" \
  node --enable-source-maps --test --test-concurrency=2 'lib/__tests__/*.test.js'
