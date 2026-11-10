# Deep links

Prism opens app pages from `https://prismwalls.com`, `https://www.prismwalls.com`, and the `prism:` scheme. For example, `https://prismwalls.com/library?tab=downloads` and `prism://library?tab=downloads` open the Downloads tab.

The [route catalog](../../lib/core/router/deep_link_route_catalog.dart) owns paths and query validation. The [route resolver](../../lib/core/router/deep_link_catalog_resolver.dart) loads the arguments that each page needs. Replace example identifiers with real resources and URL-encode each path segment or query value.

## Page catalog

Paths below work with either HTTPS host or the `prism:` scheme. "Sign-in" means the destination resumes after successful sign-in. "Admin" requires an admin account. The [Access table](#access-table) gives the rule of each route.

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
| Library tabs | `/library?tab=favourites`, `/library?tab=folders`, `/library?tab=downloads`, `/library?tab=history`, `/wallpaper-history` | Opens the Library on the selected tab. Defaults to Favourites when `tab` is absent. Other `tab` values are rejected. `/wallpaper-history` opens the History tab. On iOS, which has no History tab, the history targets open Favourites. |
| Upload and edit wallpaper | `/upload-wall`, `/edit-wall` | Opens the image picker page, then requires sign-in for the upload or edit page. |
| Submission review | `/review` | Sign-in. Shows the user's pending and rejected submissions. |
| Rewards and coin history | `/rewards`, `/coin-history` | Opens the selected page. |
| Redeem a promo code | `/redeem?code=ABCDEFGH23`, `/redeem` | Sign-in. Opens Rewards with the redeem sheet open and the code filled in. The user must tap Redeem; the link never redeems by itself. `code` is the only query key. See [promo-codes.md](promo-codes.md). |
| Daily chest and spin wheel | `/daily-chest`, `/spin-wheel` | Sign-in. Opening a page does not open a chest, spin, or spend coins. |
| Shop | `/shop` | Sign-in. Purchases require the normal confirmation. |
| Premium plans | `/premium`, `/paywall` | Opens the Premium page. **View plans** uses the existing native paywall. iOS permits guest purchases. Android requires sign-in. No purchase starts automatically. |
| Drops | `/drops` | Opens the live Drop and vault. |
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

## Access table

Each route has one access rule.

| Access | Meaning |
|---|---|
| public | A guest on iOS can view the page. The content is public on the web too. |
| account | The page needs sign-in. |
| owner | The page needs sign-in and shows only the data of the signed-in user. |
| admin | The page needs an admin account. |

An action on public content still asks for sign-in at the moment of the action. Save to a Folder, Follow, Favourite, Comment and Set are actions. They use `requireSignedInAction`.

Android has no guests. A signed-out Android user can open only `/`, `/onboarding/v2`, `/about` and `/not-found`. Each other route opens sign-in first and resumes after it.

The Guard column gives the guard in `AppRouter`:

- `none`: no route guard.
- `guests on iOS`: `SignedInGuard(allowGuests: true)`, on the route or on its parent.
- `sign-in`: `SignedInGuard`. Sign-in opens first. The page opens after it.
- `prompt`: no route guard. A guest sees a sign-in prompt in place of the content.
- `admin`: `AdminGuard`.

"Needs rules change" marks a page whose content is public on the web, but `firestore.rules` refuses the read of a signed-out user. Such a page keeps its guard until the rules change. Without the guard, a guest gets an empty page.

`test/core/router/route_guards_test.dart` reads this table. The test fails when a route in `AppRouter` or a target in the route catalog has no row, and when a row does not agree with the guard. A new route must add a row.

| Route | Deep link targets | Shows | Guard | Access | Why |
|---|---|---|---|---|---|
| `/` | `splash` | Startup. Then the dashboard, or sign-in on Android. | none | public | Startup holds no user data. |
| `/onboarding/v2` | `onboarding` | Sign-in and onboarding. | none | public | This is the sign-in page. |
| `/dashboard` | `dashboard` | The app shell. | guests on iOS | public | Guest browsing on iOS (#768). |
| `/dashboard/home` | `home` | The Home feed. | guests on iOS | public | Walls are public on the web. |
| `/dashboard/search` | `searchTab` | Wallpaper search. | guests on iOS | public | Walls are public on the web. |
| `/dashboard/search/users` | `userSearch` | Creator search. | prompt | account | Needs rules change: `usernames` and `profiles` reads need sign-in. A guest sees the sign-in prompt on the page. |
| `/dashboard/rewards` | `rewardsTab` | The user's coins, streak and rewards. | sign-in | owner | Data of one user. |
| `/dashboard/collection` | `collectionTab` | The Collections tab. | guests on iOS | public | Collections are public on the web. |
| `/ai` | `ai` | AI wallpaper generation. | sign-in | account | Generation spends the user's coins. |
| `/wallpaper-detail` | `wallpaperDetail` | One wallpaper. | none | public | Walls are public on the web. Set, Save and Favourite ask for sign-in. |
| `/wotd-archive` | `wotdArchive` | Past Wall of the Day picks. | none | public | Anyone can read the picks. |
| `/download-wallpaper` | `downloadWallpaperInput` | The download preview. | sign-in | account | A download is an action. |
| `/wallpaper-filter` | `wallpaperFilterInput` | The filter editor. | sign-in | account | An edit is an action. |
| `/choose-wallpaper` | `chooseImage`, `uploadInput`, `editWallInput` | The image picker page. | sign-in | account | Each workflow is an action. |
| `/share-in` | - | A share from another app. Only the `prism:` scheme opens it. | none | public | The page shows the item that the user shared. See [share-to-prism.md](share-to-prism.md). |
| `/premium` | `premium` | The Premium plans. | none | public | iOS permits guest purchases. |
| `/photo-preview` | `photoPreview` | The full photo preview. | sign-in | account | It is a step of Set and Download. |
| `/clock-preview` | `clockPreview` | The lock and home screen preview. | none | public | A preview changes nothing. |
| `/edit-profile` | `editProfile` | The user's profile editor. | sign-in | owner | Data of one user. |
| `/share-prism` | `sharePrism` | The user's referral page. | sign-in | owner | Data of one user. |
| `/settings` | `settings` | Settings. | none | public | Device settings. Account rows ask for sign-in. |
| `/layout` | `layoutSettings` | Layout settings. | none | public | Device settings. |
| `/blocked-accounts` | `blockedAccounts` | The user's blocked accounts. | sign-in | owner | Data of one user. |
| `/about` | `about` | About Prism. | none | public | No user data. Android also opens it signed out. |
| `/fav-walls` | `favourites` | The user's favourites. | sign-in | owner | Data of one user. |
| `/downloads` | `downloads` | The user's downloads. | sign-in | owner | Data of one user. |
| `/library` | `library`, `wallpaperHistory` | The user's Library. | sign-in | owner | Data of one user. |
| `/folder/:folderId` | `folder` | One Folder. | sign-in | account | Needs rules change: `publicFolders/{id}` and its `items` need sign-in. A public Folder is public on the web. A private Folder stays with its owner and editors. |
| `/folder/invite/:code` | `folderInvite` | The join page of a Folder invite. | none | public | The invite code is the key. **Join folder** asks for sign-in. |
| `/upload-wall` | - | The upload form. | sign-in | owner | The user's own upload. |
| `/edit-wall` | - | The edit form of a submitted wall. | sign-in | owner | The user's own wall. |
| `/creator-stats` | `creatorStats` | The user's creator stats. | sign-in | owner | Data of one user. |
| `/review` | `review` | The user's pending and rejected submissions. | sign-in | owner | Data of one user. |
| `/theme` | `theme` | Themes. | none | public | Device settings. |
| `/notifications` | `notifications` | The user's inbox. | sign-in | owner | Data of one user. |
| `/collection-view` | `collectionView` | One collection or category. | none | public | Collections are public on the web. |
| `/mood/:moodId` | `mood` | One mood. | none | public | Anyone can read moods. |
| `/editors-choice` | `editorsChoice` | Editors' Choice walls. | none | public | Walls are public on the web. |
| `/gallery` | `gallery` | A set of 2 to 12 walls. | none | public | Walls are public on the web. |
| `/requests` | `wallRequests` | Wall requests. | none | public | The list callable needs no sign-in. A vote or a request asks for sign-in. |
| `/creators` | `creators` | The creator directory. | sign-in | account | Needs rules change: `creatorDirectory` needs sign-in. The web has no creator directory page. |
| `/folders` | `foldersDiscover` | Discover Folders. | sign-in | account | Needs rules change: `folderTrending` and `publicFolders` need sign-in. The page is public on the web. |
| `/wrapped` | `wrapped` | The user's Wrapped. | sign-in | owner | Data of one user. |
| `/challenges/:challengeId` | `weeklyChallenge` | One weekly challenge. | none | public | Anyone can read challenges. A submission asks for sign-in. |
| `/user/:identifier` | `profile` | One creator profile. | prompt | account | Needs rules change: `profiles` and `usernames` need sign-in. A guest sees the sign-in prompt on the page. The profile is public on the web. |
| `/followers` | `followers` | The followers of one profile. | sign-in | account | Needs rules change: `profiles/{uid}/followers` needs sign-in. |
| `/following` | `following` | The accounts that one profile follows. | sign-in | account | Needs rules change: `profiles/{uid}/following` needs sign-in. |
| `/admin-review` | `adminReview` | The admin review queue. | admin | admin | Admin work. |
| `/admin-review/swipe` | `swipeReview` | The swipe review. | admin | admin | Admin work. |
| `/admin-review/image` | `adminImage` | The full image of a wall in review. | admin | admin | Admin work. |
| `/admin-firestore-telemetry` | `adminTelemetry` | Firestore telemetry. | admin | admin | Admin work. |
| `/admin-promo-codes` | `adminPromoCodes` | Promo codes. | admin | admin | Admin work. |
| `/debug-panel` | `debugPanel` | The debug pages. | admin | admin | Admin work. |
| `/quick-tile-settings` | `quickTileSettings` | The user's quick tile setup. | sign-in | owner | It uses the user's Library. |
| `/auto-rotate` | `autoRotate` | The user's auto-rotate setup. | sign-in | owner | It uses the user's Library. |
| `/ios-shortcuts` | `iosShortcuts` | The user's Shortcuts guide. | sign-in | owner | It uses the user's Folders. |
| `/wallpaper-position` | `wallpaperPositionInput` | The position editor. | sign-in | account | It is a step of Set. |
| `/live-wallpaper` | `liveWallpaperInput` | The live wallpaper editor. | sign-in | account | It is a step of Set. |
| `/rewards` | `rewards`, `redeemCode` | The user's rewards. | sign-in | owner | Data of one user. |
| `/daily-moment` | `dailyMoment` | The user's daily moment. | sign-in | owner | Data of one user. |
| `/coin-history` | `coinHistory` | The user's coin history. | sign-in | owner | Data of one user. |
| `/daily-chest` | `dailyChest` | The user's daily chest. | sign-in | owner | Data of one user. |
| `/spin-wheel` | `spinWheel` | The user's spin wheel. | sign-in | owner | Data of one user. |
| `/shop` | `shop` | The coin shop. | sign-in | account | A purchase spends the user's coins. |
| `/drops` | `drops` | The live Drop and the vault. | none | public | Anyone can read Drops. A purchase asks for sign-in. |
| `/drops/:weekKey` | `dropDetail` | One Drop. | none | public | Anyone can read Drops. |
| `/drops/:weekKey/preview/:wallId` | `dropPreview` | One Drop wall, with a watermark. | none | public | A preview unlocks nothing. |
| `/leaderboard` | `leaderboard` | The leaderboard. | sign-in | account | `leaderboards` needs sign-in. |
| `/draw` | `draw` | The weekly draw. | sign-in | account | `draws` needs sign-in. |
| `/not-found` | `notFound` | The unavailable page. | none | public | No user data. Android also opens it signed out. |

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
| `/l/SHORT_CODE`, `/l?code=SHORT_CODE` | Resolves the short code, then validates its canonical URL through the same parser. |
| `prism://share-in?id=ID`, `prism://share-in?text=TEXT` | A share from another app. Only the `prism:` scheme. See [share-to-prism.md](share-to-prism.md). |

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
