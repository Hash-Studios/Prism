# Web catalogue

The web catalogue gives public pages on prismwalls.com. Search engines can index them. There is a page for each approved wall, each public folder, each hub and each creator. Wall and folder pages have an **Open in Prism** button and store buttons. Visitors can browse. Web downloads come in a later release. The pages are in English only, because the site has no translations.

The catalogue uses the links Worker. Its code is in `infra/cloudflare/worker/src/catalog.ts`. The data builder is in `functions/src/webCatalog.ts`.

## Where to find it

| Page | Address | Contents |
|---|---|---|
| Wall | `/wallpaper/<id>` | One approved wall, its details and up to 12 related walls. |
| Folder | `/folder/<id>` | One public folder and its walls. |
| New walls | `/wallpapers` | The newest walls. |
| Popular walls | `/wallpapers/popular` | The popular walls. |
| Category | `/wallpapers/<category>` | The walls in one category. |
| Creator | `/creator/<username>` | One creator, their public folders and their walls. |
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
| `gated` | The wall is approved but fails the gate. | 200. Blurred image and a **Get it in Prism** button. | No. It is not in the sitemaps. |
| `hidden` | `review` is not `true`, or two approved walls share the id. | 404. | No. |
| `gone` | The wall document is deleted. | 410. | No. |

### Images

- The hero image of a live wall uses `/api/catalog/preview/<id>.jpg`. This is the `wallpaperPreview` derivative. It fits inside 2560 px. The original file is never served.
- The 540 px thumbnail is in `srcset`. The page uses it when the preview fails to load.
- A gated wall shows a 24 px blurred JPEG as a data URL. It has no image URL.
- The share card is at `/og/wall/<id>.jpg`. The Worker renders it once, with `og_card.ts` and Browser Rendering. It keeps the result in the `prismwalls-og-images` R2 bucket.

### Caching

- The Worker caches each page in the edge Cache API. The cache key is the parsed route. Query strings and the user agent do not change the key. The `page` number is part of the route.
- A page is fresh for 10 minutes. After that, the Worker serves the stale copy for up to one day. One request refreshes the copy in the background.
- 404 and 410 responses are cached for 5 minutes.
- The HTML is the same for every visitor. For Android, a small inline script changes the **Open in Prism** link to the intent link.
- If Firestore fails, a wall page or a folder page falls back to the old app landing. A hub, creator or sitemap page returns 503 with `retry-after: 60`. If a stored copy exists, the Worker serves it first.

### Sitemaps

- `/sitemap.xml` is the index. It lists `/sitemap-pages.xml` and the shard files. `/sitemap-pages.xml` holds the static Next pages. It was at `/sitemap.xml` before.
- The shard files are `/sitemaps/walls-<n>.xml`, `/sitemaps/categories-<n>.xml`, `/sitemaps/folders-<n>.xml` and `/sitemaps/creators-<n>.xml`.
- Each shard holds at most 5,000 URLs. The limit for one sitemap file is 50,000 URLs.
- Each `lastmod` comes from the projected `updatedAt` of the wall, folder or creator.
- The sitemaps list only live walls, and the folders and creators that have live walls.
- `robots.txt` already points at `/sitemap.xml`.

### Build

`buildWebCatalog` runs at minute 20 of every second hour, in UTC. It reads every approved wall again. A missed trigger or a renamed creator heals on the next build. The build writes only the documents that changed. It deletes pages that no longer exist.

### Reads and writes

| Request | Firestore reads, when not cached |
|---|---|
| Wall page | 2. The `webWalls` document and page 1 of its category. |
| Any other page | 1. |
| Any cached page | 0. |

One build reads about 2 documents for each approved wall. It also reads one profile for each creator, one header for each public folder, and up to 60 items for each folder. It reads the popular list and the manifest once.

At 2,534 approved walls and 12 builds a day, the wall reads come to about 61,000 reads a day. The creator, folder and popular reads come on top of that.

## Limits

- A new public folder or a renamed creator appears at the next build, up to 2 hours later.
- A hub page can show a withdrawn wall until the next build. The wall page returns 404 or 410 within about 10 minutes.
- Creator profiles become public on the open web. This shows the name, username, bio and photo. This is a new exposure. It needs product sign-off before release.
- The pages use system fonts, not Manrope.
- Wallhaven and Pexels walls are not in the catalogue. Their links keep the app landing.

## Deploy order

Nothing in this change is deployed. Deploy in this order:

1. Deploy the Firestore rules with `firebase deploy --only firestore:rules`.
2. Deploy the functions with `make functions-deploy`. This deploys `onWallWebCatalog` and `buildWebCatalog`.
3. In Cloud Scheduler, run `buildWebCatalog` once with **Run now**. This writes the `webWalls` and `webPages` documents.
4. Deploy the links Worker with `npx wrangler deploy` in `infra/cloudflare/worker`. This adds the routes `/creator/*`, `/sitemap.xml` and `/sitemaps/*`.
5. Deploy the website with `deploy_web.yml`. After this, the website stops serving `/sitemap.xml`.

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
