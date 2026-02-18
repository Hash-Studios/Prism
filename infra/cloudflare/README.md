# Prismwalls Deep Links (Cloudflare)

This folder contains the Cloudflare implementation for:
- `POST /api/links` short-link creation
- `GET /api/links/{code}` short-link resolution for app deep-link handler
- `GET /l/{code}` short-link resolution
- `GET /og/{code}.png` social preview image endpoint
- `POST /api/ai/generations` AI wallpaper generation
- `POST /api/ai/generations/{id}/variations` AI variation generation
- `POST /api/ai/metadata/prefill` AI-assisted submit metadata prefill
- `GET /api/ai/health` AI provider health + routing version
- hosted association files for Android App Links and iOS Universal Links

## Worker setup

1. Install Wrangler and authenticate.
2. Create KV namespace and set IDs in `worker/wrangler.toml`.
3. (Optional but recommended) create an R2 bucket for OG images and bind it as `OG_IMAGES`.
4. Set Browser Rendering token (required for generated PNG OG cards):

```bash
cd infra/cloudflare/worker
wrangler secret put BROWSER_RENDERING_API_TOKEN
```

5. Deploy:

```bash
cd infra/cloudflare/worker
wrangler deploy
```

## Static association files

Publish the files in `infra/cloudflare/static` to `https://prismwalls.com` exactly:
- `/.well-known/assetlinks.json`
- `/.well-known/apple-app-site-association`
- `/apple-app-site-association`

## Validation commands

```bash
curl -i https://prismwalls.com/.well-known/assetlinks.json
curl -i https://prismwalls.com/.well-known/apple-app-site-association
curl -i https://prismwalls.com/apple-app-site-association
```

Check that all return `200`, JSON content-type, and no redirect chain.

## Notes

- Replace `REPLACE_WITH_PLAY_APP_SIGNING_SHA256` before release.
- Replace `REPLACE_WITH_CLOUDFLARE_ACCOUNT_ID` in `wrangler.toml`.
- Replace `REPLACE_WITH_AI_STATE_KV_ID` and `REPLACE_WITH_AI_STATE_KV_PREVIEW_ID` in `wrangler.toml`.
- Set AI provider secrets before enabling AI routes:
  - `wrangler secret put FAL_API_KEY`
  - `wrangler secret put GEMINI_API_KEY`
- Worker only accepts canonical URLs on `https://prismwalls.com/{share|user|setup|refer}`.
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
