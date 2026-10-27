# Prism Wallpapers Marketing Site

Next.js (App Router) + Tailwind CSS static marketing site for `prismwalls.com`.

## Stack

- Next.js (App Router)
- TypeScript
- Tailwind CSS
- Static export (`next build` with `output: "export"`)
- Cloudflare Workers static assets deployment via Wrangler

## Local development

```bash
cd web
npm install
npm run dev
```

Visit `http://localhost:3000`.

## Build

```bash
cd web
npm run build
```

This outputs static files in `web/out`.

## Deploy to Cloudflare

This repo is configured to deploy the static output from `web/out` through `wrangler.toml`.

A push to `master` that changes `web/`, `CHANGELOG.md` or the Proxima Nova fonts deploys the site
automatically (`.github/workflows/deploy_web.yml`). It needs the `CLOUDFLARE_API_TOKEN` repository
secret. Set the `NEXT_PUBLIC_MIXPANEL_TOKEN` repository variable to build with analytics. Run it by hand
from the Actions tab and select `master`. Every run checks out and builds the latest `master` when it
starts. Running deploys finish, and the concurrency group retains only one pending run. The Cloudflare
account ID comes from `wrangler.toml`. The steps below are for a manual deploy.

### 1) First-time login

```bash
cd web
npx wrangler login
```

### 2) Deploy

```bash
cd web
npm run deploy
```

`npm run deploy` runs `next build` and then `wrangler deploy`.

### 3) Domain check

Confirm custom routes in Cloudflare:

- `prismwalls.com`
- `www.prismwalls.com`

These are already declared in `wrangler.toml`.

## Editing content and links

Update these files:

- `lib/site-config.ts`: app/store links, brand constants

## Images used by the site

- App icon: `public/assets/ios.png`
- Link preview card for every page: `public/assets/og/home.jpg` (1200×630). The link worker uses it as its fallback, and uses `invite-1.jpg` to `invite-3.jpg` on invite cards.
- Screenshot: `public/assets/screenshots/screen4.jpg`

If you want to refresh visuals later, keep the same filenames to avoid changing code references.
