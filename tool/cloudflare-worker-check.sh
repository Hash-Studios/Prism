#!/bin/sh
set -eu

# Requires Node.js 22.6+ for built-in TypeScript stripping; no npm install needed.
if [ "${CI:-false}" = "true" ]; then
  dart run tool/deep_link_contract_check.dart
else
  fvm dart run tool/deep_link_contract_check.dart
fi
node tool/deep_link_contract_check.mjs
node --experimental-strip-types \
  --experimental-loader=./infra/cloudflare/worker/test/resolve-ts-imports.mjs \
  --test ./infra/cloudflare/worker/test/worker.test.mjs
