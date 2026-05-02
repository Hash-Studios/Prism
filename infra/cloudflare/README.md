# Prismwalls Deep Links (Cloudflare)

This folder contains the Cloudflare implementation for:
- `POST /api/links` short-link creation
- `GET /api/links/{code}` short-link resolution for app deep-link handler
- `GET /l/{code}` short-link resolution
- `GET /og/{code}.png` social preview image endpoint
- `GET /.well-known/assetlinks.json` (Android App Links association)
- `GET /.well-known/apple-app-site-association` (iOS Universal Links association)
- `GET /apple-app-site-association` (iOS fallback association endpoint)
- `POST /api/ai/generations` AI wallpaper generation
- `POST /api/ai/generations/{id}/variations` AI variation generation
- `POST /api/ai/metadata/prefill` AI-assisted submit metadata prefill
- `GET /api/ai/health` AI provider health + routing version

## Deep-link canonical URL rules

Worker accepts and normalizes canonical URLs to a stable format:
- Share: `https://prismwalls.com/share?...` (query-based)
- User: `https://prismwalls.com/user/<identifier>`
- Setup: `https://prismwalls.com/setup/<name>`
- Refer: `https://prismwalls.com/refer/<inviterId>`

Legacy canonical query forms are accepted for compatibility and normalized:
- `/user?username=...` → `/user/<identifier>`
- `/setup?name=...` → `/setup/<name>`
- `/refer?userId=...` → `/refer/<inviterId>`

`GET /api/links/{code}` response remains backward-compatible and now includes:
- `route` (legacy route string)
- `route_v2` (typed route template, for example `/user/:identifier`)
- `canonical_identifier` (identifier extracted from canonical URL for user/setup/refer)

## Worker setup

1. Install Wrangler and authenticate:

```bash
npm i -g wrangler
wrangler login
```

2. Ensure KV namespace IDs and optional R2 bindings are set in `worker/wrangler.toml`.
3. Ensure route bindings include:
  - `prismwalls.com/.well-known/*`
  - `prismwalls.com/apple-app-site-association`
  - existing API/deeplink routes
4. Set required secrets:

```bash
cd infra/cloudflare/worker
wrangler secret put BROWSER_RENDERING_API_TOKEN
wrangler secret put FAL_API_KEY
wrangler secret put GEMINI_API_KEY
```

5. Deploy:

```bash
cd infra/cloudflare/worker
wrangler deploy
```

## Association file source of truth

Worker serves association payloads directly; no separate static hosting step is required.

Source reference files must stay in sync with worker-served payloads:
- `infra/cloudflare/static/.well-known/assetlinks.json`
- `infra/cloudflare/static/.well-known/apple-app-site-association`
- `infra/cloudflare/static/apple-app-site-association`

Before deploying, verify values:
- Android package name: `com.hash.prism`
- Android SHA-256 fingerprint: Play App Signing fingerprint (production)
- iOS appID: `X2955Z4CKQ.com.hash.prism`

## Deploy + validation runbook

1. Deploy worker from `infra/cloudflare/worker` with `wrangler deploy`.
2. Purge cache for association endpoints:
  - `https://prismwalls.com/.well-known/assetlinks.json`
  - `https://prismwalls.com/.well-known/apple-app-site-association`
  - `https://prismwalls.com/apple-app-site-association`
3. Validate association endpoints:

```bash
curl -i https://prismwalls.com/.well-known/assetlinks.json
curl -i https://prismwalls.com/.well-known/apple-app-site-association
curl -i https://prismwalls.com/apple-app-site-association
```

Expected:
- HTTP `200`
- `content-type: application/json; charset=utf-8`
- no `Location` redirect header

4. Validate short-link API behavior:

```bash
curl -i -X POST https://prismwalls.com/api/links \
  -H "content-type: application/json" \
  -d '{"type":"user","canonical_url":"https://prismwalls.com/user/test_user"}'
```

Then resolve:

```bash
curl -i https://prismwalls.com/api/links/<code>
```

Verify response contains `route`, `route_v2`, and `canonical_identifier`.

5. Validate app-link association on device:
- Android:
  - `adb shell pm verify-app-links --re-verify com.hash.prism`
  - `adb shell pm get-app-links com.hash.prism`
- iOS:
  - uninstall/reinstall app
  - open a Prism link (`/l/*`, `/share/*`, `/user/*`, `/setup/*`, `/refer/*`) from Notes/WhatsApp and verify direct app open

6. Rollback (if needed):
- rollback to previous worker deployment in Cloudflare
- purge the same three association endpoints again

## Troubleshooting

1. Association endpoint returns non-200:
- confirm Worker routes include both `/.well-known/*` and `/apple-app-site-association`
- confirm DNS for `prismwalls.com` is proxied via Cloudflare
- confirm SSL/TLS mode supports valid edge cert for `prismwalls.com`

2. Association endpoint redirects:
- check Cloudflare Redirect Rules/Page Rules/Transform Rules
- exempt the three association paths from redirects and rewrites

3. Android app links not verified:
- confirm `assetlinks.json` has Play App Signing SHA-256 (not local debug keystore)
- run `adb shell pm get-app-links com.hash.prism` and inspect verification status

4. iOS universal links not opening app:
- confirm `apple-app-site-association` payload appID matches Team ID + bundle ID
- verify both paths (`/.well-known/...` and `/apple-app-site-association`) return `200` JSON without redirect

## Notes

- Replace `REPLACE_WITH_PLAY_APP_SIGNING_SHA256` before release.
- Replace `REPLACE_WITH_CLOUDFLARE_ACCOUNT_ID` in `wrangler.toml`.
- Replace `REPLACE_WITH_AI_STATE_KV_ID` and `REPLACE_WITH_AI_STATE_KV_PREVIEW_ID` in `wrangler.toml`.
- Set Firebase auth verification vars:
  - `FIREBASE_PROJECT_ID` (for Prism this is `prism-wallpapers`)
  - Optional debug logs: `FIREBASE_AUTH_DEBUG=true` in non-prod only
- If Browser Rendering is unavailable, `og:image` falls back to source image URL.

## AI routing config

The active AI routing config is read from KV key `ai:routing:active` (JSON).  
If missing/invalid, a safe default config is used.

Config supports:
- provider enablement (`fal`, `gemini`)
- provider weights (weighted primary routing)
- quality tier model mapping (`fast`, `balanced`, `quality`)
- per-provider daily/monthly budget caps
- timeout + fallback order
- hard user daily cap
- automatic cost guardrails:
  - `70%` usage: route fallbacks to cheaper providers first
  - `85%` usage: pick cheapest provider as primary, downgrade `quality -> balanced`
  - `95%` usage: aggressively downgrade `balanced -> fast` and avoid near-exhausted provider when alternatives exist

## AI watermark backfill

To migrate existing AI community walls to watermarked publish URLs:

```bash
node tool/backfill_ai_watermarked_walls.mjs --dry-run
node tool/backfill_ai_watermarked_walls.mjs
```

The script is idempotent and marks migrated records with `aiWatermarkMigratedAt`.
