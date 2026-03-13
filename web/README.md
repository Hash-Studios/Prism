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
- `lib/marketing-content.ts`: homepage copy, feature lists, FAQ, credibility items

## Images used by the site

- App icon: `public/assets/ios.png`
- Screenshots: `public/assets/screenshots/screen1.jpg` to `screen5.jpg`

If you want to refresh visuals later, keep the same filenames to avoid changing code references.
