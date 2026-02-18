# Prismwalls Deep Links (Cloudflare)

This folder contains the Cloudflare implementation for:
- `POST /api/links` short-link creation
- `GET /api/links/{code}` short-link resolution for app deep-link handler
- `GET /l/{code}` short-link resolution
- `GET /og/{code}.png` social preview image endpoint
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
- Worker only accepts canonical URLs on `https://prismwalls.com/{share|user|setup|refer}`.
- If Browser Rendering is unavailable, `og:image` falls back to source image URL.
