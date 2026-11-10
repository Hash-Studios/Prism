# Deep links

Prism opens app pages from `https://prismwalls.com`, `https://www.prismwalls.com`, and the `prism:` scheme. For example, `https://prismwalls.com/library?tab=downloads` and `prism://library?tab=downloads` open the Downloads tab.

The [route catalog](../../lib/core/router/deep_link_route_catalog.dart) owns paths and query validation. The [route resolver](../../lib/core/router/deep_link_catalog_resolver.dart) loads the arguments that each page needs. Replace example identifiers with real resources and URL-encode each path segment or query value.

## Page catalog

Paths below work with either HTTPS host or the `prism:` scheme. "Sign-in" means the destination resumes after successful sign-in. "Admin" requires an admin account. The [Access table](#access) gives the rule of each route.

| Page family | Path or example | Input and access |
|---|---|---|
| Dashboard and home | `/dashboard`, `/dashboard/home` | Guest browsing is allowed. The app's `/` route also resumes at the dashboard after startup. |
| Home feed tab | `/dashboard/home?feed=latest` | `feed` accepts `forYou`, `following`, `trending`, `latest` or `popular`. Another value is rejected. The link saves the tab first, so it wins over the remembered tab. See [layout.md](layout.md). |
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
| Gallery | `/gallery?ids=wall1,wall2&source=push`, `/gallery?ids=wall1,wall2,wall3&source=link` | Requires 2 to 12 wall IDs in `ids`, separated by commas. IDs use letters, digits, `_` and `-`. Other query keys are refused. Opens `GalleryScreen`. |
| Public profile | `/user/alice` | Requires a profile identifier. |
| Followers and following | `/user/alice/followers`, `/user/alice/following` | Sign-in. Loads the named profile's current relation list. Query forms are `/followers?user=alice` and `/following?user=alice`. `identifier` aliases `user`. |
| Edit profile | `/edit-profile` | Sign-in. |
| Invite and referral page | `/share-prism` | Sign-in. This page differs from accepting a `/refer/...` link. |
| Blocked accounts | `/blocked-accounts` | Sign-in. |
| Settings, theme, and About | `/settings`, `/theme`, `/about` | Opens the selected page. |
| Notifications | `/notifications` | Opens the notification inbox. |
| Favourites and downloads | `/fav-walls`, `/downloads` | Opens the selected page. |
| Library tabs | `/library?tab=favourites`, `/library?tab=folders`, `/library?tab=downloads`, `/library?tab=history`, `/wallpaper-history` | Opens the Library on the selected tab. Defaults to Favourites when `tab` is absent. Other `tab` values are rejected. `/wallpaper-history` opens the History tab on both platforms. |
| Upload and edit wallpaper | `/upload-wall`, `/edit-wall` | Opens the image picker page, then requires sign-in for the upload or edit page. |
| Submission review | `/review` | Sign-in. Shows the user's pending and rejected submissions. |
| Rewards and coin history | `/rewards`, `/coin-history` | Opens the selected page. |
| Redeem a promo code | `/redeem?code=ABCDEFGH23`, `/redeem` | Sign-in. Opens Rewards with the redeem sheet open and the code filled in. The user must tap Redeem; the link never redeems by itself. `code` is the only query key. See [promo-codes.md](promo-codes.md). |
| Daily chest and spin wheel | `/daily-chest`, `/spin-wheel` | Sign-in. Opening a page does not open a chest, spin, or spend coins. |
| Shop | `/shop` | Sign-in. Purchases require the normal confirmation. |
| Premium plans | `/premium`, `/paywall` | Opens the Premium page. **View plans** uses the existing native paywall. iOS permits guest purchases. Android requires sign-in. No purchase starts automatically. |
| Drops | `/drops` | Opens the live Drop and vault. Buying asks for sign-in. |
| Drop detail | `/drops/2026-W42` | Requires a week key that exists in the Drops repository. |
| Drop preview | `/drops/2026-W42/preview/wall1` | Loads the requested week and wall without unlocking it. Missing resources show an unavailable state. |
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

Catalog validation limits folder IDs to ASCII letters, digits, `_` and `-` (1 to 128 characters), and wallpaper IDs to ASCII letters, digits, `.`, `_` and `-` (1 to 200 characters). General identifiers may contain Unicode but are limited to 1,500 UTF-8 bytes, cannot contain path separators or control characters, and cannot equal `.` or `..`. Short-link codes contain 7 to 10 ASCII letters or digits. Folder invite query values must be exactly 10 ASCII letters or digits; malformed, repeated, or path-conflicting invite queries are refused.

## Access

`lib/core/router/route_access.dart` gives each app route one access rule. `PlatformAccountGuard` reads this table when AutoRoute invokes the guard; it does not run for every tab selection. The dashboard shell is guarded when entered, so a signed-out Android user is stopped there. An iOS guest can select Rewards, where `RewardsPage` shows its own sign-in prompt.

A standalone `/rewards` deep link still passes through the global access guard. A route without a row needs an account. `test/core/router/route_access_test.dart` fails when a route has no row, or when a row names no route.

| Rule | Who can open the route |
|---|---|
| Open | Anyone. This includes a signed-out Android user. Only startup, sign-in, About and Not found use it. |
| Public | Guests can open it on iOS. Android has no guests, so a signed-out Android user goes to sign-in. Actions on the content (save, favourite, follow, comment, Set) ask for sign-in when the guest taps them. |
| Account | Any signed-in user. A guest goes to sign-in. After sign-in, the app opens the route. |
| Owner | The signed-in user's own data. The guard needs an account. The Firestore rules and the page check the owner. |
| Admin | Admins. The route also keeps its `AdminGuard`. |

A Public route needs `firestore.rules` to let a signed-out user read what the page shows. A guest can read `profiles/{uid}`, `usernames/{name}`, `publicFolders/{id}` and its `items`, `folderTrending` and `creatorDirectory`. These hold only public projections. A signed-in reader still does not see a public Folder of a creator they block, or who blocks them. Follower lists, private `folders` and every write need sign-in.

| Route | Deep link targets | Shows | Rule | Why |
|---|---|---|---|---|
| `/` | `splash` | Startup | Open | Startup must run before sign-in. |
| `/onboarding/v2` | `onboarding` | Welcome and sign-in | Open | This is the sign-in page. |
| `/about` | `about` | About Prism | Open | Legal and app information. |
| `/not-found` | `notFound` | Unavailable page | Open | Unknown links land here. |
| `/dashboard` | `dashboard` | App shell | Public | Guests browse on iOS. |
| `/dashboard/home` | `home` | Home feed | Public | Walls are public. The creators and folders rows show for guests too. |
| `/dashboard/search` | `searchTab` | Search | Public | Walls are public. |
| `/dashboard/search/users` | `userSearch` | Creator search | Public | The page shows its own sign-in prompt to a guest. Creator search is not open to guests. |
| `/dashboard/collection` | `collectionTab` | Curated collections | Public | `collections` is public. |
| `/dashboard/rewards` | `rewardsTab` | Coins and streak | Owner | The user's own coins. |
| `/wallpaper-detail` | `wallpaperDetail` | One wall | Public | Reviewed walls are public. Save, favourite and Set ask for sign-in. |
| `/wotd-archive` | `wotdArchive` | Wall of the day archive | Public | `wall_of_the_day` is public. |
| `/share-in` | none | Share to Prism sheet | Public | The sheet asks a guest to sign in before it saves. |
| `/premium` | `premium` | Premium plans | Public | iOS guests can see plans. Purchase asks for sign-in. |
| `/clock-preview` | `clockPreview` | Lock screen preview | Public | Passive preview. Save asks for sign-in. |
| `/settings`, `/layout`, `/theme` | `settings`, `layoutSettings`, `theme` | Device settings | Public | Local settings only. |
| `/collection-view` | `collectionView` | One collection or category | Public | Walls are public. |
| `/mood/:moodId` | `mood` | One mood | Public | `moods` is public. |
| `/editors-choice` | `editorsChoice` | Editors' Choice | Public | Reviewed walls are public. |
| `/gallery` | `gallery` | A set of walls | Public | Walls are public. |
| `/requests` | `wallRequests` | Wall requests | Public | `listWallRequests` serves guests. Vote and Ask ask for sign-in. |
| `/challenges/:challengeId` | `weeklyChallenge` | Weekly challenge | Public | `weeklyChallenges` is public. Entry asks for sign-in. |
| `/drops`, `/drops/:weekKey`, `/drops/:weekKey/preview/:wallId` | `drops`, `dropDetail`, `dropPreview` | Weekly Drop | Public | `drops` is public. Buying asks for sign-in. |
| `/user/:identifier` | `profile` | Creator profile | Public | `profiles` and `usernames` are public reads. Follow, Gift, Block and Report ask for sign-in. Tip is hidden from guests. A guest's own profile shows the sign-in prompt. |
| `/followers`, `/following` | `followers`, `following` | Follower lists | Account | `profiles/*/followers` and `profiles/*/following` need sign-in. A guest relation link opens the public profile. |
| `/creators` | `creators` | Creator directory | Public | `creatorDirectory` is a public read. Follow asks for sign-in. |
| `/folders` | `foldersDiscover` | Discover folders | Public | `folderTrending` and `publicFolders` are public reads. Follow asks for sign-in. A guest has no saves, so "Like your saves" shows its empty message. |
| `/folder/:folderId` | `folder` | One folder | Public | A guest sees the public folder. Follow asks for sign-in. A private folder shows only to its owner and members; a guest gets "This folder is private or no longer exists". |
| `/folder/invite/:code` | `folderInvite` | Folder invite | Account | An invite joins a private folder. |
| `/ai` | `ai` | AI wallpapers | Account | Generation spends coins. |
| `/download-wallpaper`, `/wallpaper-filter`, `/choose-wallpaper`, `/photo-preview` | `downloadWallpaperInput`, `wallpaperFilterInput`, `chooseImage`, `photoPreview` | Wallpaper tools | Account | These save or edit images. |
| `/wallpaper-position`, `/live-wallpaper` | `wallpaperPositionInput`, `liveWallpaperInput` | Set tools | Account | These set a wallpaper. |
| `/upload-wall` | `uploadInput` | Upload | Account | Uploads belong to an account. |
| `/quick-tile-settings`, `/auto-rotate`, `/ios-shortcuts` | `quickTileSettings`, `autoRotate`, `iosShortcuts` | Set automation | Account | These set wallpapers from the user's folders. |
| `/daily-moment`, `/daily-chest`, `/spin-wheel` | `dailyMoment`, `dailyChest`, `spinWheel` | Daily rewards | Account | Rewards go to an account. |
| `/shop`, `/leaderboard`, `/draw` | `shop`, `leaderboard`, `draw` | Coin economy | Account | `boosts`, `leaderboards` and `draws` need sign-in. |
| `/rewards`, `/coin-history` | `rewards`, `redeemCode`, `coinHistory` | Coins | Owner | The user's own coins. |
| `/edit-profile`, `/share-prism`, `/blocked-accounts` | `editProfile`, `sharePrism`, `blockedAccounts` | Account settings | Owner | The user's own account. |
| `/fav-walls`, `/downloads`, `/library` | `favourites`, `downloads`, `library`, `wallpaperHistory` | Library | Owner | The user's own saves. |
| `/edit-wall`, `/review`, `/creator-stats` | `editWallInput`, `review`, `creatorStats` | Creator tools | Owner | The user's own walls. |
| `/notifications` | `notifications` | Inbox | Owner | The user's own notifications. |
| `/wrapped` | `wrapped` | Wrapped | Owner | The user's own year. |
| `/admin-review`, `/admin-review/swipe`, `/admin-review/image`, `/admin-firestore-telemetry`, `/admin-promo-codes`, `/debug-panel` | `adminReview`, `swipeReview`, `adminImage`, `adminTelemetry`, `adminPromoCodes`, `debugPanel` | Admin tools | Admin | Admins only. |

Redirects use the rule of their target. `/paywall` uses `/premium`. `/streak` and `/coin-transactions` use `/rewards`.

To add a route, add a row to `routeAccess`. Choose the most strict rule that the Firestore rules let the page read.

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

## Shares from other apps

Native code turns a share into a `prism://share-in` link. Android uses `ShareTargetActivity`. iOS uses the Share Extension. The dispatcher handles this link like any other link. It waits for startup, then records `deep_link_received` with `target_type` `shared_item`. For the share flow, see [share-to-prism.md](share-to-prism.md).

## Preserved aliases and intents

| Link | Destination or behavior |
|---|---|
| `/share/wall1?source=prism&thumb=ENCODED_HTTPS_IMAGE_URL` | Legacy wallpaper-share intent. The wall ID is required; image and thumbnail URLs are optional. `id` can supply the ID in the query. `source`, `provider`, and `wallpaper_provider` can supply the source. `url`, `wallpaperUrl`, and `wallpaper_url` can supply the image URL. `thumb`, `thumbUrl`, `thumbnail`, `thumbnailUrl`, and `wallpaper_thumb` can supply a thumbnail. The detail page resolves the wall by ID. |
| `/profile/alice`, `/fprofile/alice`, `/follower-profile/alice`, `/user?username=alice` | User-profile intent. Roots are `profile`, `fprofile`, `follower-profile`, and `user`. The identifier can also come from `identifier`, `username`, `user`, or `email`. The `/user/alice` page route is handled by the page catalog. |
| `/setup`, `/share-setup` | Setup intent. Shows the unavailable-setup message and opens the Home tab. |
| `/refer/INVITER_ID`, `/referral/INVITER_ID` | Referral intent. Saves the referral and opens the Dashboard Rewards tab. |
| `/l/SHORT_CODE`, `/l?code=SHORT_CODE` | Short-code intent. Resolves the code, then validates its canonical URL through the same parser. Network failures can defer one retry. |
| `prism://share-in?id=ID`, `prism://share-in?text=TEXT` | Share-in intent from another app. Only the `prism:` scheme is accepted. Supply either a 36-character lowercase hex-and-hyphen `id` or non-empty `text` up to 2,048 characters. See [share-to-prism.md](share-to-prism.md). |

The `share`, profile, setup, referral, short-code, and share-in entries are legacy intents parsed by `DeepLinkParser`. They are not additional `AppRouter` pages. `/paywall`, `/coin-transactions`, `/streak`, and `/dashboard/streak` are actual `RedirectRoute`s. Their access rules match their destinations. The router's `*` redirect sends unmatched paths to `/not-found`.

Short links with `type: "page"` accept only catalogued app paths and preserve validated query parameters. Canonical paths with invalid queries cannot fall through to permissive legacy aliases.

A short link can end in `?d=1`. Only Prism wall shares add it. The website uses it to open desktop mode. See [web-catalogue.md](web-catalogue.md#desktop-mode). The app ignores the `d` key, so on a phone with Prism the app opens the wall as before.

## Website and release checks

The website keeps `/`, `/privacy`, and `/terms` under Next.js. Cloudflare receives app paths, short links, association files, and API paths. App page landings show an **Open in Prism** link on mobile and the matching store links. They do not redirect visitors automatically.

Cloudflare matches the query string as part of the request URL. App path patterns therefore end in `*`; unrelated prefix matches such as `/shopper` pass through to the website origin. Worker-owned API paths and unsupported app-link methods retain their 404 response.

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
