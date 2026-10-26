# Prismwalls Deep Links (Cloudflare)

This folder contains the Cloudflare implementation for:
- `POST /api/links` short-link creation
- `GET /api/links/{code}` short-link resolution for app deep-link handler
- `GET /l/{code}` short-link resolution
- `GET /og/{code}.jpg` link preview card (the old `.png` path serves the same card)
- `GET /.well-known/assetlinks.json` (Android App Links association)
- `GET /.well-known/apple-app-site-association` (iOS Universal Links association)
- `GET /apple-app-site-association` (iOS fallback association endpoint)
- `POST /api/ai/generations` AI wallpaper generation
- `POST /api/ai/generations/{id}/variations` AI variation generation
- `POST /api/ai/metadata/prefill` AI-assisted submit metadata prefill
- `GET /api/ai/health` AI provider health + routing version
- `POST /api/ai/studio/generations` internal daily content generation (header `x-studio-secret`)
- `PUT /api/ai/studio/assets/{key}` internal studio image upload (header `x-studio-secret`)
- `DELETE /api/ai/studio/assets/{key}` internal studio image delete (header `x-studio-secret`)

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
wrangler secret put STUDIO_SECRET
wrangler secret put STUDIO_FAL_API_KEY  # optional: a separate fal account for Studio
```

Without `STUDIO_SECRET`, the studio routes return `503 service_disabled`. Their spend has its own caps: `STUDIO_DAILY_BUDGET_USD` and `STUDIO_MONTHLY_BUDGET_USD` in `wrangler.toml`. They call fal with `STUDIO_FAL_API_KEY` if it is set, else with `FAL_API_KEY`.

5. Deploy:

```bash
cd infra/cloudflare/worker
wrangler deploy
```

## Association file source of truth

Worker serves association payloads directly from `worker/src/association_files.ts`; no separate static hosting step is required.

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
- If Browser Rendering is unavailable, `og:image` falls back to the source image, else to `OG_FALLBACK_IMAGE` (the website home card).

## Link preview cards

- `src/og_card.ts` holds the card HTML. Browser Rendering takes a 1200x630 JPEG of it once per link, and the worker stores it.
- Wallpaper, setup and profile links get the data card. Invite links get the showcase card.
- Wallpaper cards read views, favourites and downloads from the public `wallpaper_stats` document. The app sends the creator, resolution, profile counts and gallery.
- Fonts, the logo and the invite wallpapers load from `master` on GitHub (`assets/` and `web/public/assets/og/`). Merge them before you deploy.
- To change the design, edit `src/og_card.ts` and increase `OG_CARD_VERSION` in `src/index.ts`. Old links then render the new card on their next preview request, under a new image URL.

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

The default consumer models are Z-Image Turbo for `fast`, Meta Muse Image for `balanced`, and GPT Image 2.5 Sunburst for `quality`. KV can override these defaults. A known model gets its request body, size rules, and cost estimate from `FAL_MODELS` in `worker/src/ai.ts`:

- Z-Image Turbo accepts the requested size and seed. Its estimate is $0.005 per megapixel, calculated from the dimensions sent to fal, not a flat $0.015.
- Muse accepts an aspect ratio, has no seed input, and returns its own size of about 2.5 MP. Its estimate is $0.01 per image. The consumer response uses the returned dimensions.
- GPT Image 2.5 uses `high` quality, has no seed input, and applies its model-specific size limits. Its estimate is $0.07 per image.

An unknown fal model configured in KV gets the generic `prompt`, `image_size`, and `seed` body and the configured cost estimate. Unknown model names that contain `seedream` keep the legacy Seedream size limits. Other unknown models use the requested size.

The Studio route still permits only GPT Image 2.5, Seedream 4.5, and Seedream 5 Lite. Z-Image and Muse are consumer-only and are rejected before a Studio provider call or budget reservation. Studio accepts JPEG output, but that does not add a model to its approved list. Its gates require a portrait image with a short edge of at least 1400, a long edge of at least 3000, and a height-to-width ratio from 2.0 to 2.4. Muse's output of about 2.5 MP is too small for those gates.

Automatic cost guardrails use the cost estimate for the requested size:

- `70%` usage: route fallbacks to cheaper providers first.
- `85%` usage: pick the cheapest provider as primary and consider `quality -> balanced`.
- `95%` usage: also consider `balanced -> fast` and avoid a near-exhausted provider when alternatives exist.

A tier downgrade applies only if it does not increase the cost estimate for the requested size. For example, Balanced stays on Muse when Z-Image would cost more. Paid requests are never downgraded.

### Consumer request deadlines

Generation and variation requests start a shared 50-second provider deadline before authentication. Fal generation, response-body reads, and image download share that deadline. Fallback attempts use the time left, not a new 50 seconds. A model's minimum timeout can raise the configured timeout, but cannot extend the shared deadline.

Inline watermark work has a separate deadline 55 seconds after the same request start. If no watermark is ready by then, the worker records deferred work instead of waiting for another render attempt.

These deadlines do not bound authentication, KV, Durable Object, or R2 calls. They are not a hard 60-second end-to-end response guarantee.

## AI watermark backfill

To migrate existing AI community walls to watermarked publish URLs:

```bash
node tool/backfill_ai_watermarked_walls.mjs --dry-run
node tool/backfill_ai_watermarked_walls.mjs
```

The script is idempotent and marks migrated records with `aiWatermarkMigratedAt`.
