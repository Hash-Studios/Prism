# Web catalogue proof (Day 26, issue #562)

Local run: Firestore emulator seeded with the public fields of 200 approved walls, the real
`rebuildWebCatalog` builder, and the links Worker under `wrangler dev`. Profiles and the
folder are made up for the seed. Images come from the live preview host and the live
`wallpaperPreview` function.

Widths: mobile 390 x 844 at 3x, desktop 1440 x 900. Layout shift is 0 on every page.

| Page | Mobile | Desktop |
|---|---|---|
| Wall | wall-mobile.png | wall-desktop.png |
| Gated wall | gated-mobile.png | gated-desktop.png |
| Folder | folder-mobile.png | folder-desktop.png |
| Category hub | category-mobile.png | category-desktop.png |
| Creator | creator-mobile.png | creator-desktop.png |
| Removed wall (410) | removed-mobile.png | removed-desktop.png |

Lighthouse 12, wall page: mobile 96 performance, 100 accessibility, 100 best practices,
92 SEO; desktop 100, 100, 100, 92. The SEO miss is the live robots.txt `Content-Signal`
line that Cloudflare adds.

validator.schema.org: 0 errors and 0 warnings for the wall (ImageObject, BreadcrumbList),
folder and category (CollectionPage, BreadcrumbList), and creator (ProfilePage) pages.
