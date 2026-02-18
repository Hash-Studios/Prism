# Prismwalls Deep Links (Cloudflare)

This folder contains the Cloudflare implementation for:
- `POST /api/links` short-link creation
- `GET /l/{code}` short-link resolution
- hosted association files for Android App Links and iOS Universal Links

## Worker setup

1. Install Wrangler and authenticate.
2. Create KV namespace and set IDs in `worker/wrangler.toml`.
3. Deploy:

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
- Worker only accepts canonical URLs on `https://prismwalls.com/{share|user|setup|refer}`.
