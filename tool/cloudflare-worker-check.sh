#!/bin/sh
set -eu

# Requires Node.js 22.6+ for built-in TypeScript stripping; no npm install needed.
node --experimental-strip-types \
  --experimental-loader=./infra/cloudflare/worker/test/resolve-ts-imports.mjs \
  --test ./infra/cloudflare/worker/test/worker.test.mjs
