# Search landing pages

Two static pages for people who search for an Android wallpaper app:

| Route | File | Purpose |
|---|---|---|
| `/amoled-wallpapers` | `app/amoled-wallpapers/page.tsx` | Six first-party AMOLED walls, with the AMOLED app theme. Replaces the old generic page. |
| `/open-source-android-wallpaper-app` | `app/open-source-android-wallpaper-app/page.tsx` | The open-source app: licence, features, free and Pro, repository. |

## Shape

Each page is its own static server component. The generic `SeoLandingPage` template still renders `/4k-wallpapers`
and `/collections`. Extending its schema would add optional fields and branches for a gallery and screenshots that
only one page uses.

- `lib/seo-pages.ts`: `topicPages` holds the title, description and nav label of every topic page.
  `seoRouteOrder` drives both sitemaps (`app/sitemap.ts`, `app/sitemap-pages.xml/route.ts`), the related links,
  and `seoMetadata()` (canonical, Open Graph, Twitter).
- `lib/amoled-walls.ts`: the audited wall list. Fixed metadata, no build-time requests.
- `components/seo/topic-links.tsx`: related links on both new pages.
- Homepage links: the Browse chips and the resources nav in `app/page.tsx`.

## Claims and sources

Checked on 2026-11-08.

| Claim | Source |
|---|---|
| Free to download. Prism Pro is an optional subscription. | Google Play listing (updated 2026-11-07). |
| Pro adds premium wallpapers and collections, free downloads and premium filters, and auto-rotate on Android. | Play listing Pro list; `README.md` Prism Pro lines. No prices on the pages. |
| Browse and search by word, colour or tag; favourites; set on home screen, lock screen or both. | Play listing; `setScreenTargetBoth` and `wallpaperPreviewSetHome` at tag `v3.17.0+356`. 3.17.0 was at 100% on Play on 2026-11-02 (`docs/deploys/2026-11-deploy-train.md`). |
| Free AMOLED theme with a black background. | `lib/theme/prism_theme_options.dart`: the AMOLED option has no `shopItemId`, at `v3.17.0+356` too. `kDarkTheme2` uses `Colors.black`. |
| BSD 3-Clause covers the code, not the wallpapers. | `LICENSE.txt`. |
| Prism Studio is the Hash Studios account. | `functions/src/studio/account.ts`, `docs/features/wall-credits.md`. |

Not used: ratings, install counts, prices, testimonials, minimum Android version, ad claims, and the "2M+" figure
from the Play promo art.

## AMOLED walls

`OUUKGMD2GF DPDKYZKHQ4 PJ5XLPYRKQ ZLOHKQ3MLH PGEULKSP1E KHQ6OSMHDS`. Each public record
(`/api/v1/wallpapers/{id}`) was `live`, category Dark, tagged `amoled`, creator `PrismStudio`, original
1440 × 3200. The descriptions come from looking at each preview.

- Images load from `/api/catalog/preview/{id}.jpg`. The links Worker checks wall visibility when it refreshes the cached response.
  Previews have a 600-second fresh cache and stale-while-revalidate, so takedowns are not immediate. No static copies are in the repository.
- Each preview is 1152 × 2560 JPEG, 84 to 309 KB (1.07 MB for all six). No smaller checked rendition exists. The
  cards show them at 125 to 340 CSS px. Only the first image loads eagerly.

## Screenshots

| File | Source | Processing |
|---|---|---|
| `public/assets/screenshots/android-set-wallpaper-sheet.webp` (506 × 315, 48.7 KB) | Branch `qa/screenshots`, commit `d04e373cf` ("Flutter 3.47.8 smoke proof (PR #736)"), `flutter-3478-2026-10-29/android-4-set-screen.jpg`. Android emulator, 540 × 1200. | Crop `506x315+17+842` to the sheet's edges, saved as lossless WebP. No other edits. The four rounded corners show a few pixels of a third-party wall; the page hides them with a matching `border-radius`. |
| `public/assets/screenshots/themes-iphone.jpg` (440 × 956, 25.8 KB) | Byte copy of `demo/screens/theme-manager.jpg`, an iPhone capture from the PR #438 redesign QA. | None. Captioned as iPhone. The Themes page has no platform branches, so the caption says Android shows the same screen. |

Not used: the Play promo images (marketing art, AI art, and a collage with old UI and the unverified "2M+" figure),
the README widget renders (live wallpaper, auto-rotate, Pro wallpaper), QA captures that show third-party walls or a
real user's name, and the shop capture with coin prices.

## Analytics

`components/analytics.tsx` sends to the existing Mixpanel project only. Events:

| Event | When | Extra properties |
|---|---|---|
| `web_landing_viewed` | Page view | none |
| `web_store_clicked` | Exact Play or App Store link | `store` |
| `web_download_clicked` | Link to `/download` | none |
| `web_apk_clicked` | The `/download` APK button (`data-analytics-apk`) | `target` (`apk_file` or `releases_page`), `apk_version` |
| `web_qr_viewed` | QR reveal | `store` |

Every event has `path` and `entry_path` (the first page of the tab session). Both come from an allowlist; any other
path is sent as `other`. Validated `utm_*` tags are kept for the session. No full URL, other query value, referrer or
account data is sent. Do Not Track or Global Privacy Control stops all browser events. The privacy page section
"This Website" describes this, plus the server-side `web_wallpaper_downloaded` count from the links Worker.

A new page reports `other` until its path is added to `pagePaths` in `components/analytics.tsx`.

## Tests

Verified locally on November 8, 2026. Production build and TypeScript checks pass, along with 40 Node tests and
45 Playwright tests. Browser inspection of the static export confirmed loaded previews, correct canonicals and
no horizontal overflow. The local preview server served the audited live preview bytes without changing the HTML.

- [Open-source page, desktop](evidence/search-landing-pages/open-source-desktop.png)
- [AMOLED collection, mobile](evidence/search-landing-pages/amoled-mobile.png)

- `node --test test/analytics.test.cjs`: entry attribution, APK version only, path allowlist, tampered entry,
  DNT and GPC.
- `npx playwright test test/e2e/landing-pages.spec.ts`: metadata and content without JavaScript, image attributes and
  sources, links, both sitemaps, no sideways scroll at 360 and 1280 px, lazy previews, the click flow with
  intercepted Mixpanel payloads, GPC, and the privacy text.

## After deploy (manual)

1. Open both routes on `prismwalls.com` and `www.prismwalls.com`. Check the status, the canonical, and that all six
   previews return `200 image/jpeg`.
2. Check `https://prismwalls.com/sitemap.xml` lists `/sitemap-pages.xml`, and that file lists both routes.
3. Recheck the six walls: `curl -s https://prismwalls.com/api/v1/wallpapers/<id>` shows `"state":"live"`. If one is
   gone, remove it from `lib/amoled-walls.ts`, update the description in `lib/seo-pages.ts`, and deploy with approval. Until then its card has a broken image.
4. Search Console and Bing Webmaster Tools: inspect both URLs and request indexing. The owner does this.
5. Mixpanel Live View: open `/open-source-android-wallpaper-app?utm_source=qa`, click "Download the APK", then the APK
   button. Expect `web_landing_viewed`, `web_download_clicked`, `web_landing_viewed` on `/download` with
   `entry_path` of the landing page, and `web_apk_clicked` with `apk_version`. With GPC on, expect no events.
6. Before you edit claims, read the current Play listing again.

## Open points

- The website analytics notice has its own update date. The shared policy effective date stays unchanged.
- The set-sheet capture is from 2026-10-29, before the `v3.17.0+356` tag. The same strings are in that tag.

Website clicks measure interest, not attributed app installs. Verify supported Play Console acquisition reports separately.
These search topics are hypotheses; no search volume or ranking outcome has been established.
