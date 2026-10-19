# Deep links

Prism opens app pages from `https://prismwalls.com`, `https://www.prismwalls.com`, and the `prism:` scheme. For example, `https://prismwalls.com/library?tab=downloads` and `prism://library?tab=downloads` open the Downloads tab.

The [route catalog](../../lib/core/router/deep_link_route_catalog.dart) owns paths and query validation. The [route resolver](../../lib/core/router/deep_link_catalog_resolver.dart) loads the arguments that each page needs. Replace example identifiers with real resources and URL-encode each path segment or query value.

## Page catalog

Paths below work with either HTTPS host or the `prism:` scheme. "Sign-in" means the destination resumes after successful sign-in. "Admin" requires an admin account.

| Page family | Path or example | Input and access |
|---|---|---|
| Dashboard and home | `/dashboard`, `/dashboard/home` | Guest browsing is allowed. The app's `/` route also resumes at the dashboard after startup. |
| Search and user search | `/dashboard/search`, `/dashboard/search/users` | Opens the selected search page. |
| Dashboard Rewards and Collection tabs | `/dashboard/rewards`, `/dashboard/collection` | Opens the selected dashboard tab. |
| Onboarding | `/onboarding/v2` | Opens the onboarding flow. Individual steps are internal states. |
| AI wallpapers | `/ai` | Opens the AI page. Generation retains its normal account and purchase checks. |
| Wallpaper detail | `/wallpaper-detail?wallId=wall1&source=prism`, `/wallpaper/wall1?source=prism` | Requires a wallpaper ID. `id` aliases the `wallId` query key. |
| Wall of the day archive | `/wotd-archive` | Opens the archive. |
| Wallpaper download preview | `/download-wallpaper?wallpaperId=wall1&source=prism`, `/wallpaper/wall1/download?source=prism` | Loads the wallpaper and resolves a local file. Without an ID, opens the image picker page. |
| Wallpaper filters | `/wallpaper-filter` | Opens the image picker page. |
| Wallpaper position | `/wallpaper-position?wallpaperId=wall1&source=prism&entryPoint=shared`, `/wallpaper/wall1/position?source=prism` | Loads the wallpaper. Without an ID, opens the image picker page. `entryPoint` is optional. |
| Live wallpaper | `/live-wallpaper?wallpaperId=wall1&source=prism`, `/wallpaper/wall1/live?source=prism` | Loads the wallpaper. Without an ID, opens the image picker page. Platform support still applies. |
| Full photo preview | `/photo-preview?wallpaperId=wall1&source=prism` | Requires a wallpaper ID. For a local image, use `/choose-wallpaper?workflow=photoPreview`. |
| Lock and home screen preview | `/clock-preview?wallpaperId=wall1&source=prism` | Requires a wallpaper ID. For a local image, use `/choose-wallpaper?workflow=clockPreview`. |
| Image picker | `/choose-wallpaper?workflow=uploadWall` | Requires one of the workflow values below. Opens a page with a **Choose image** button. |
| Collection and category feeds | `/collection-view?collectionName=featured`, `/collection/featured`, `/category/Nature` | Requires a collection or category name. `name` aliases `collectionName`. |
| Public profile | `/user/alice` | Requires a profile identifier. |
| Followers and following | `/user/alice/followers`, `/user/alice/following` | Loads the named profile's current relation list. Query forms are `/followers?user=alice` and `/following?user=alice`. `identifier` aliases `user`. |
| Edit profile | `/edit-profile` | Sign-in. |
| Invite and referral page | `/share-prism` | Sign-in. This page differs from accepting a `/refer/...` link. |
| Blocked accounts | `/blocked-accounts` | Sign-in. |
| Settings, theme, and About | `/settings`, `/theme`, `/about` | Opens the selected page. |
| Notifications | `/notifications` | Opens the notification inbox. |
| Favourites, downloads, and history | `/fav-walls`, `/downloads`, `/wallpaper-history` | Opens the selected page. |
| Library tabs | `/library?tab=favourites`, `/library?tab=downloads`, `/library?tab=history` | Defaults to Favourites when `tab` is absent. |
| Upload and edit wallpaper | `/upload-wall`, `/edit-wall` | Opens the image picker page, then requires sign-in for the upload or edit page. |
| Submission review | `/review` | Sign-in. Shows the user's pending and rejected submissions. |
| Rewards and coin history | `/rewards`, `/coin-history` | Opens the selected page. |
| Daily chest and spin wheel | `/daily-chest`, `/spin-wheel` | Sign-in. Opening a page does not open a chest, spin, or spend coins. |
| Shop | `/shop` | Sign-in. Purchases require the normal confirmation. |
| Premium plans | `/premium`, `/paywall` | Opens the Premium page. **View plans** uses the existing native paywall. iOS permits guest purchases. Android requires sign-in. No purchase starts automatically. |
| Drops | `/drops` | Sign-in. Opens the live Drop and vault. |
| Drop detail | `/drops/2026-W42` | Sign-in. Requires a week key that exists in the Drops repository. |
| Drop preview | `/drops/2026-W42/preview/wall1` | Sign-in. Loads the requested week and wall without unlocking it. Missing resources show an unavailable state. |
| Leaderboard and draw | `/leaderboard`, `/draw` | Sign-in. Opening the draw page does not enter a draw. |
| Quick tiles, auto-rotate, and iOS Shortcuts | `/quick-tile-settings`, `/auto-rotate`, `/ios-shortcuts` | Opens the selected page. Device support and permission checks remain in each page. |
| Admin review and swipe review | `/admin-review`, `/admin-review/swipe` | Admin. |
| Admin full image | `/admin-review/image?wallpaperId=wall1&source=prism` | Admin. Requires a wallpaper ID. |
| Firestore telemetry | `/admin-firestore-telemetry` | Admin. |
| Debug pages | `/debug-panel?tab=logs` | Admin. `tab` accepts `logs`, `tools`, `storage`, `app-info`, or `mascot`. Defaults to Logs. |
| Not found | `/not-found` | Opens the unavailable-page destination. Unknown URLs do not select an arbitrary route. |

Wallpaper `source` accepts `prism`, `wallhaven`, or `pexels` and defaults to `prism`. `provider` aliases `source`. If both are present, `source` takes precedence. Preview and action routes fetch the canonical resource and accept trusted HTTPS image hosts for that provider. They do not accept file paths, raw image URLs, serialized entities, or client-sent prices.

The picker workflows are `uploadWall`, `editWall`, `wallpaperFilter`, `downloadWallpaper`, `wallpaperPosition`, `liveWallpaper`, `clockPreview`, and `photoPreview`. The picker opens only after the user taps **Choose image**. Canceling the gallery leaves the picker page open, with no upload, download, wallpaper change, or purchase. Picker errors expose a retry action.

The catalog rejects unknown query keys, repeated query keys, missing required resources, and unsupported selector values. The optional `utm_source`, `utm_medium`, and `utm_campaign` keys are accepted and removed before navigation.

## Shared entry pipeline

External app links, push taps, and in-app links use `DeepLinkDispatcher`. The dispatcher waits for startup and onboarding, resolves typed route arguments, applies route guards, and checks that the destination became visible.

Push payloads can name any catalog page through `data.url`:

```json
{
	"data": {
		"url": "https://prismwalls.com/drops/2026-W42/preview/wall1"
	}
}
```

A recognized `data.url` takes precedence over legacy `route` metadata. Existing push forms such as `wall`, `wall_of_the_day`, `follower`, and `streak_reminder` still map to the same typed navigation pipeline. In-app content uses `openPrismLink(context, url)` from `lib/core/utils/url_launcher_compat.dart`. Ordinary web links, including Prism's `/privacy` and `/terms`, open in the browser.

Sign-in keeps the exact pending destination across the onboarding stack replacement. Canceling sign-in, logging out, or deleting the account discards that destination. Admin links do not grant admin access. Their guard rejects unauthorized users.

Analytics record receipt, resolution, and the navigation result separately through `deep_link_received`, `deep_link_resolved`, and `deep_link_navigation_result`. Results distinguish `navigated`, `blocked`, `cancelled`, and `failure`. A resolved route alone does not count as visible navigation. Opening `/premium` records navigation to the Premium page. Native paywall impressions begin after **View plans**.

A network failure during short-code resolution can defer the request until connectivity returns or the app resumes online. The scheduler retries each queued code once. A retry keeps the original entry source and does not record another receipt. Deferred attempts do not record a final navigation result until retry or cancellation. Cancellation discards queued requests and prevents late lookups from navigating.

## Preserved aliases

| Alias | Destination or behavior |
|---|---|
| `/streak`, `/coin-transactions` | Standalone Rewards page. |
| `/dashboard/streak` | Dashboard Rewards tab. |
| `/paywall` | Premium page. |
| `/share/wall1?source=prism&thumb=ENCODED_HTTPS_IMAGE_URL` | Legacy wallpaper share. Requires an ID and an image or thumbnail value. The detail page resolves the wallpaper by ID. |
| `/profile/alice`, `/fprofile/alice`, `/follower-profile/alice` | Public profile. Existing profile query aliases remain in `DeepLinkParser`. |
| `/setup`, `/share-setup` | Reports that home screen setups are unavailable and opens Home. |
| `/refer/INVITER_ID`, `/referral/INVITER_ID` | Saves the referral and opens Rewards. A signed-out user can sign in later to claim an eligible reward. |
| `/l/SHORT_CODE` | Resolves the short code, then validates its canonical URL through the same parser. |

Short links with `type: "page"` accept only catalogued app paths and preserve validated query parameters. Canonical paths with invalid queries cannot fall through to permissive legacy aliases.

## Website and release checks

The website keeps `/`, `/privacy`, and `/terms` under Next.js. Cloudflare receives app paths, short links, association files, and API paths. App page landings show an **Open in Prism** link on mobile and the matching store links. They do not redirect visitors automatically.

Run the contract and worker checks from the repository root:

```sh
node tool/deep_link_contract_check.mjs
make cloudflare-worker-check
```

The contract check reads the current `AppRouter`, route catalog examples, native alias roots, AASA paths, and Cloudflare route declarations. Worker tests make local GET requests for every catalog example on both hosts, plus query-bearing aliases. They check that unsupported query values fall back to the store. A new route needs matching native association declarations and Worker routing. Android icon aliases each declare the same verified hosts and app paths.

Deploying the Worker remains a separate release step. After review and approval, use:

```sh
cd infra/cloudflare/worker && npx wrangler deploy
```

Then verify the deployed AASA and asset-links files on both hosts, open representative app-page and short links on iOS and Android, and confirm `/`, `/privacy`, and `/terms` still render from the website. The installed app must also contain the updated route code. A Worker deploy cannot add pages to an older app build. Local checks do not prove hosted CI, deployed Worker routing, device link handling, or live store behavior.
