# Web catalogue

The web catalogue gives public pages on prismwalls.com. Search engines can index them. There is a page for each approved wall, each public folder, each hub and each creator. Wall and folder pages have an **Open in Prism** button and store buttons. Visitors can browse and download free images. Walls with a desktop version also have desktop images and two desktop hubs. The pages are in English only, because the site has no translations.

The catalogue uses the links Worker. Its code is in `infra/cloudflare/worker/src/catalog.ts`. The data builder is in `functions/src/webCatalog.ts`.

## Where to find it

| Page | Address | Contents |
|---|---|---|
| Wall | `/wallpaper/<id>` | One approved wall, its details and up to 12 related walls. |
| Wall, desktop mode | `/wallpaper/<id>?view=desktop` | One wall for a computer screen. The desktop version comes first when there is one. |
| Folder | `/folder/<id>` | One public folder and its walls. |
| New walls | `/wallpapers` | The newest walls. |
| Popular walls | `/wallpapers/popular` | The popular walls. |
| Category | `/wallpapers/<category>` | The walls in one category. |
| Creator | `/creator/<username>` | One creator, their public folders and their walls. |
| Desktop wallpapers | `/desktop-wallpapers` | The walls that have a desktop version. |
| Matching sets | `/matching-sets` | The same walls, as phone and desktop pairs. |
| Download | `/api/catalog/download/<id>/<file>.jpg` | One free image. The file is `phone`, `desktop` or `desktop-16x9`. |
| Desktop image | `/api/catalog/desktop/<id>.jpg` | The image in the Desktop tab of a wall page. |
| Sitemap index | `/sitemap.xml` | The list of sitemap files. |

Hub, category and creator pages show 24 walls each. Add `?page=<n>` to open the next page.

## Platforms

| Platform | Support |
|---|---|
| Web | Browse every page. No sign-in is needed. |
| Android | **Open in Prism** uses an intent link. The link opens the app. If the app is not installed, it opens Google Play. |
| iOS | **Open in Prism** uses the page address. The store buttons open Google Play and the App Store. |

## How it works

### Serving

The links Worker builds each page as HTML. It reads a public Firestore projection. It keeps each page in the edge cache. This is option A.

The team did not choose option B, a nightly static Next export. A static export has three limits:

- It cannot return 404 or 410 for a withdrawn wall.
- The web deploy workflow has no Firestore credentials.
- The premium gate depends on Remote Config. A static export cannot read it when a visitor asks for a page.

The Worker reads Firestore through the REST API, with no credentials. The rules make only the catalogue collections public.

### Data

| Document | Written by | Read by | Contents |
|---|---|---|---|
| `webWalls/{shareId}` | `onWallWebCatalog`, when a field that the page shows or its gate uses changes on `walls/{id}` | Anyone, through the rules | One public copy of one wall. |
| `webPages/{key}` | `buildWebCatalog`, every 2 hours at minute 20 UTC | Anyone, through the rules | One list page, folder page, creator page or sitemap file. |
| `webCatalogState/pages` | `buildWebCatalog` | Server only | A hash for each page. The build uses it to skip unchanged pages. |

The keys in `webPages` are:

- `latest~<n>`, `popular~<n>` and `category~<slug>~<n>` for the hubs.
- `creator~<username>~<n>` for creator pages.
  A creator page exists only for a profile that has at least one live wall. A folder page links its owner to the creator page only when that page exists (`owner.hasPage`). Otherwise, the owner name is plain text.
  A creator photo is published only from `raw.githubusercontent.com` (photos uploaded in Prism), `*.googleusercontent.com` (Google account photos) or `firebasestorage.googleapis.com` (the default photo). For other hosts, the page shows the initial of the creator name.
- `folder~<id>` for folder pages.
- `sitemap~<name>-<n>` for sitemap files, and `sitemap~index` for the index.

The number `<n>` starts at 1.

A `webWalls` document holds only these public fields:

- `state`, `updatedAt`, `title`, `description`, `category` and `categorySlug`.
- `tags`, `colors`, `width`, `height` and `createdAt`.
- `creatorName` and `creator`. The `creator` field holds the username and the display name only.
- `thumb`, on live walls only.
- `blur` and `blurKey`, on gated walls only.

The public copy never holds the uid, the email, the original URL, the storage path, moderation data or profile links.

The rules allow public read of `webWalls` and `webPages`. No client can write them. `webCatalogState` has no client access.

### Gate

A wall is `live` only when all of these are true:

1. `review` is `true`.
2. `originalProtected` is `true`.
3. The wall is not streak exclusive.
4. The wall is not in a drop.
5. The wall is not in a premium collection.
6. The wall has a public preview thumbnail.

This is the same gate that public folders use.

| State | When | Page | Indexed |
|---|---|---|---|
| `live` | The wall passes the gate. | 200. Full page with the hero image. | Yes. It is in the sitemaps. |
| `gated` | The wall is approved but fails the gate. | 200. Blurred image, or only a lock placeholder if there is no blur. A **Get it in Prism** button. | No. It is not in the sitemaps. |
| `hidden` | `review` is not `true`, or two approved walls share the id. | 404. | No. |
| `gone` | The wall document is deleted. | 410. | No. |

### Images

- The hero image of a live wall uses `/api/catalog/preview/<id>.jpg`. This is the `wallpaperPreview` derivative. It fits inside 2560 px. The original file is never served.
- The 540 px thumbnail is in `srcset`. The page uses it when the preview fails to load.
- A gated wall shows a 24 px blurred JPEG as a data URL. It has no image URL.
- If the wall has no valid thumbnail, or if the blur step fails, the projection has no blur. Then the page shows only a lock placeholder.
- The share card is at `/og/wall/<id>.jpg`. The Worker renders it once, with `og_card.ts` and Browser Rendering. It keeps the result in the `prismwalls-og-images` R2 bucket.

### Caching

- The Worker caches each page in the edge Cache API. The cache key is the parsed route. Query strings and the user agent do not change the key. The `page` number is part of the route.
- A page is fresh for 10 minutes. After that, the Worker serves the stale copy for up to one day. One request refreshes the copy in the background.
- Thus the first request after the 10 minutes can still get the old page of a withdrawn wall. The next requests get the 404 or 410. If Firestore fails during the refresh, the old page can stay for up to one day.
- 404 and 410 responses are cached for 5 minutes.
- The HTML is the same for every visitor. For Android, a small inline script changes the **Open in Prism** link to the intent link.
- If Firestore fails, a wall page or a folder page falls back to the old app landing. A hub, creator or sitemap page returns 503 with `retry-after: 60`. If a stored copy exists, the Worker serves it first.

### Sitemaps

- The Worker serves `/sitemap.xml` as the index. It lists `/sitemap-pages.xml` and the shard files. `/sitemap-pages.xml` holds the static Next pages.
- The website also keeps its static `/sitemap.xml`. Before the Worker deploy, crawlers get that file. After the Worker deploy, the Worker route takes `/sitemap.xml`, and the static file is not served. Thus you can deploy the website and the Worker in either order.
- The shard files are `/sitemaps/walls-<n>.xml`, `/sitemaps/categories-<n>.xml`, `/sitemaps/folders-<n>.xml` and `/sitemaps/creators-<n>.xml`.
- Each shard holds at most 3,000 URLs, so that each document stays below the 1 MiB Firestore limit. The limit for one sitemap file is 50,000 URLs.
- Each `lastmod` comes from the projected `updatedAt` of the wall, folder or creator.
- The sitemaps list only live walls, and the folders and creators that have live walls.
- The categories shard also lists `/desktop-wallpapers` and `/matching-sets`, when a live wall has a desktop version.
- `robots.txt` already points at `/sitemap.xml`.

### Build

`buildWebCatalog` runs at minute 20 of every second hour, in UTC. It reads every approved wall again. A missed trigger or a renamed creator heals on the next build. The build writes only the documents that changed. It deletes pages that no longer exist.

### Reads and writes

| Request | Firestore reads, when not cached |
|---|---|
| Wall page | 2. The `webWalls` document and page 1 of its category. |
| Wall page, desktop mode | 2. The same reads as the wall page. |
| `/l/<code>?d=1` | 0. The Worker reads one KV record. |
| Any other page | 1. |
| Any cached page | 0. |

One build reads about 2 documents for each approved wall. It also reads one profile for each creator, one header for each public folder, and up to 60 items for each folder. It reads the popular list and the manifest once.

At 2,534 approved walls and 12 builds a day, the wall reads come to about 61,000 reads a day. The creator, folder and popular reads come on top of that.

## Web downloads and desktop pages

A visitor can download a wallpaper from its wall page. The links are under **Download free**. Each file is a JPEG.

| File | Size | Address |
|---|---|---|
| Phone | The 2560 px preview. It is the same image as the page hero. | `/api/catalog/download/<id>/phone.jpg` |
| Desktop | 1920 x 1200 | `/api/catalog/download/<id>/desktop.jpg` |
| Desktop 16:9 | 1920 x 1080 | `/api/catalog/download/<id>/desktop-16x9.jpg` |

The desktop files exist only for walls with a desktop version. Full quality stays in the Prism app. See [desktop-companions.md](desktop-companions.md) for how a desktop version is made.

The Desktop tab on a wall page shows `/api/catalog/desktop/<id>.jpg`. Its address has a `v` value. The value changes with each new desktop version.

The hubs `/desktop-wallpapers` and `/matching-sets` read one list, `webPages/desktop~<n>`. The first hub shows the desktop versions. The second hub shows the phone and desktop pairs.

### Download checks

The Worker runs these checks on each download, in this order. The download route never uses the page cache.

1. **Referer.** The Referer must be `prismwalls.com` or `www.prismwalls.com`. A request with no Referer must have `Sec-Fetch-Site: same-origin`. Other sites get a 302 to the wall page.
2. **Limit.** Each IP gets 30 downloads per 10 minutes and 300 per day. Over the limit, the Worker returns 429 with `Retry-After: 600`. If the counter fails, the Worker returns 503.
3. **Wall state.** The Worker reads `webWalls/<id>` on every download. Only a `live` wall gets a file. A gated, hidden or gone wall gets 404. A desktop file also needs a desktop version.
4. **Response.** The response is never cached (`Cache-Control: no-store`). It is an attachment (`Content-Disposition: attachment`), named `prism-<title>-<file>.jpg`.

A `HEAD` request to a download or image route gets 405, so it costs no Firestore read and no function call.

The Referer check stops hotlinks from other sites. It does not stop scripts, because a script can send any Referer. The limit is per IP, so visitors that share one IP share the allowance.

Each download counts as `web_wallpaper_downloaded` in the website's Mixpanel project. The Worker sends the event with no IP. The count needs the `MIXPANEL_TOKEN` variable on the Worker. Without it, downloads are not counted.

## Desktop mode

Desktop mode shows a wall on a computer screen. The app share sheet has **Open on computer**. That target opens desktop mode. See [desktop-companions.md](desktop-companions.md) for desktop versions.

### Short link

The short link `/l/<code>?d=1` opens desktop mode. Only Prism wall shares use `d=1`. The Worker reads only the KV record. It does not read Firestore. It answers 302 to the relative path `/wallpaper/<id>?view=desktop`, with `cache-control: no-store`. Crawlers still get the preview HTML. Other link types, and other `d` values, get the old landing page.

### Desktop page

The page `/wallpaper/<id>?view=desktop` has three cases:

- **Live wall with a desktop version.** The desktop version comes first, in a monitor frame. The phone wall is on its right. On a narrow screen, the phone wall is below it. The download block starts with **Download 1920 x 1200**. Then it shows 1920 x 1080 and the phone file. A note says that the full 2560 x 1600 file is in Prism.
- **Live wall without a desktop version.** The phone wall and the normal downloads appear. A short **Use it on your computer** note gives the steps. On Windows, right-click the file, then choose Set as desktop background. On a Mac, Control-click the file in Finder, then choose Set Desktop Picture.
- **Gated wall.** The normal gated page appears. It has no image and no download links.

Hidden walls get 404 and gone walls get 410, as before.

The web size stays at 1920 x 1200. Tablets get the 2560 x 1600 file in Prism, at the set price.

### Canonical URL and cache

The canonical URL stays `/wallpaper/<id>`. The edge cache key is `wall/<id>/desktop`. It is separate from the key `wall/<id>`. Other query keys do not change the key. A `view` value other than `desktop` gives the normal page.

## Limits

- A new public folder or a renamed creator appears at the next build, up to 2 hours later.
- A hub page can show a withdrawn wall until the next build. The wall page returns 404 or 410 at the first refresh after 10 minutes. If Firestore fails, the old wall page can stay for up to one day.
- Creator profiles become public on the open web. This shows the name, username, bio and photo. The product owner approved this on 2026-11-01. A profile opt-out is not available yet.
- The pages use system fonts, not Manrope.
- Wallhaven and Pexels walls are not in the catalogue. Their links keep the app landing.

## Deploy order

The website deploys automatically when the change merges to `master`, because `deploy_web.yml` runs on each push that changes `web/**`. The website change is safe before the other steps: it only adds `/sitemap-pages.xml`. Deploy the backend in this order:

1. Deploy the Firestore rules with `firebase deploy --only firestore:rules`.
2. Deploy the functions with `make functions-deploy`. This deploys `onWallWebCatalog` and `buildWebCatalog`.
3. In Cloud Scheduler, run `buildWebCatalog` once with **Run now**. This writes the `webWalls` and `webPages` documents.
4. Deploy the links Worker with `npx wrangler deploy` in `infra/cloudflare/worker`. This adds the routes `/creator/*`, `/sitemap.xml`, `/sitemaps/*`, `/desktop-wallpapers*` and `/matching-sets*`. The desktop steps are in [desktop-companions.md](desktop-companions.md).
5. After step 4, add a **Wallpapers** link to the website header (`web/components/sections/header.tsx`) that goes to `/wallpapers`. Do not add it before step 4: until then, `/wallpapers` returns 404.

No new Firestore index is needed.

## How to test

### Run locally

1. Start the Firestore emulator. The Worker reads it at `http://127.0.0.1:8080`.
2. Seed the emulator with test walls.
3. Run `rebuildWebCatalog` once against the emulator.
4. Start the Worker with `npx wrangler dev --local --host prismwalls.com --var FIREBASE_PROJECT_ID:demo-prism --var CATALOG_FIRESTORE_ORIGIN:http://127.0.0.1:8080`.

### Run the tests

Run this from the repository root:

```bash
node --experimental-strip-types --experimental-loader=./infra/cloudflare/worker/test/resolve-ts-imports.mjs --test ./infra/cloudflare/worker/test/worker.test.mjs ./infra/cloudflare/worker/test/catalog.test.mjs
```

Run this in `functions`:

```bash
npx tsc -p . && node --test lib/__tests__/webCatalog.test.js
```

Run this in `web`:

```bash
npx playwright test test/e2e/desktop-mode.spec.ts
```
