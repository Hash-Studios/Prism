# prismwalls.com — Landing Page

Static landing page for [Prism](https://github.com/Hash-Studios/Prism), deployed on [Cloudflare Workers](https://workers.cloudflare.com/).

## Structure

```
web/
├── public/
│   ├── index.html          ← full page (edit copy here)
│   ├── style.css           ← all styles
│   ├── script.js           ← scroll animations & drag-scroll
│   └── assets/
│       ├── icon.svg        ← placeholder — replace with icon.png (real app icon)
│       ├── og-image.png    ← add a 1200×630 Open Graph preview image
│       └── screenshots/
│           ├── screen1.svg ← placeholder — replace with screen1.png
│           ├── screen2.svg ← placeholder — replace with screen2.png
│           ├── screen3.svg ← placeholder — replace with screen3.png
│           ├── screen4.svg ← placeholder — replace with screen4.png
│           └── screen5.svg ← placeholder — replace with screen5.png
├── wrangler.toml
└── package.json
```

## Before deploying — checklist

- [ ] Replace `assets/icon.svg` with `assets/icon.png` (real Prism app icon, 512×512 recommended)
  - Update `index.html`: change all `icon.svg` → `icon.png` (3 occurrences)
  - Update `<link rel="icon">` type to `image/png`
- [ ] Replace `assets/screenshots/screen*.svg` with real PNG screenshots (390×844 px)
  - Update `index.html`: change `screen1.svg` → `screen1.png` (etc.) in the screenshots section
- [ ] Add `assets/og-image.png` (1200×630 px) for social sharing previews
- [ ] Replace `#TESTFLIGHT_URL` in `index.html` (2 occurrences) with your real TestFlight invite link
  - Search for `#TESTFLIGHT_URL` in index.html — it appears on the nav CTA and the bottom CTA

## Local development

```bash
cd web
npm install
npm run dev        # starts wrangler dev at localhost:8787
```

## Deploy to Cloudflare Workers

```bash
cd web
npm install
npx wrangler login        # first time only
npm run deploy
```

Then in the Cloudflare dashboard:
- Workers & Pages → prismwalls → Settings → Domains & Routes → Custom Domains
- Add `prismwalls.com` (make sure your DNS is pointed at Cloudflare)
