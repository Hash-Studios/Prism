# Deep links

Prism opens app pages from `https://prismwalls.com/...`, `https://www.prismwalls.com/...`, and `prism://...`. External links, push taps, and in-app links share `lib/core/router/deep_link_dispatcher.dart`. The parser and route catalog validate URLs; the catalog resolver supplies typed page arguments. Startup waits and `auth_navigation_continuation.dart` preserve destinations across onboarding and sign-in.

## Sub-features

- App pages: `/settings`, `/dashboard/search`, `/dashboard/search/users`, `/dashboard/rewards`, `/library?tab=downloads`, and the other paths in `DeepLinkRouteCatalog.examples`. Confirm the selected nested tab, not just the presence of the dashboard.
- Image workflows: `/wallpaper-filter`, `/upload-wall`, `/edit-wall`, `/download-wallpaper`, `/wallpaper-position`, and `/live-wallpaper` open a gallery chooser when no wallpaper ID is supplied. Local photo/clock previews use `/choose-wallpaper?workflow=photoPreview` or `workflow=clockPreview`. `Choose image` opens the picker; cancelling keeps the chooser open. Wallpaper IDs on supported action/preview routes resolve through provider repositories. External file paths and arbitrary image URL arguments are rejected.
- Collections: `/folder/<id>` (signed-in guard), `/mood/<id>` (open), `/gallery?ids=a,b` (2 to 12 wall IDs; a push with `wall_ids` builds it), and `/library?tab=folders|downloads|history|favourites`. iOS hides History and falls back to Favourites.
- Drops: `/drops`, `/drops/<weekKey>`, and `/drops/<weekKey>/preview/<wallId>`. A week key looks like `week-2026-10-19` (`deep_link_route_catalog.dart`). The router has no guard on these.
- Profiles: `/user/<identifier>` and legacy `fprofile`, `follower-profile`, and `profile` aliases open the requested profile. Relationship links resolve the requested account's followers or following.
- Legacy shares: `/share/<wallId>?source=&url=&thumb=...` or query-only shares require an ID and an image or thumbnail URL. `/wallpaper/<wallId>?source=prism` can resolve a wallpaper by ID. Missing or invalid targets open not-found; they are not silent no-ops.
- Referrals: `/refer/<inviterId>` and `/referral/<inviterId>` save the inviter after bootstrap and open Rewards after startup. Signed-in users attempt an eligible referral claim; signed-out users see a saved-referral message. Use an approved QA fixture because this can affect coin rewards.
- Short links: `/l/<code>` and `/l?code=<code>` resolve through `https://prismwalls.com/api/links/<code>`. Network failures defer one retry until connectivity returns or an online app resume; unavailable codes open not-found.
- Push and inbox taps: URL payloads and legacy route values (`wall`, `wall_of_the_day`, `home`, `ai`, `rewards`, `drops`, `streak_reminder`, `follower`, `announcement`, and admin-only `content_report`) feed the same dispatcher through `notification_route_mapper.dart`. `streak_reminder` opens `/dashboard/rewards`. Unavailable push targets fall back to the inbox. Only `wall_of_the_day` without a usable wall falls back to Home. An in-app inbox row that cannot resolve opens not-found.
- Protected pages: `/shop`, `/leaderboard`, `/draw`, `/coin-history`, `/folder/<id>`, uploads, and other signed-in routes keep their target while sign-in is active. `/drops*` has no guard. Admin pages also need an admin account after sign-in. Cancelling a guarded sign-in clears its continuation.

## How to get to it (user POV)

- Tap an app link in Messages, a browser, or another app with Prism installed.
- Tap an existing QA inbox row or a received QA push carrying the same destination. These exercise different entry adapters; opening a URL directly does not prove push delivery or inbox handling.
- Use the native URL commands below for repeatable warm-process and cold-process checks.

## Driving it with the helper

Run `doctor`, then `launch` for the selected platform and own its helper lock before driving. Use only `Prism QA iPhone 17 Pro` and `emulator-5580`; leave other devices alone. Do not use `launch --fresh` for ordinary cold-process checks because it resets session state. Firebase-free builds can prove local chooser and settings UI; live profiles, referral claims, resource hydration, and push delivery need configured services and QA data.

After the iOS helper has launched, read the device ID from that run's state:

```sh
PRISM_QA_UDID=$(sed -n 's/^device_id=//p' /tmp/prism-verify-ios.state)
xcrun simctl openurl "$PRISM_QA_UDID" 'prism://settings'
```

On Android:

```sh
adb -s emulator-5580 shell am start -a android.intent.action.VIEW -d 'prism://settings' com.hash.prism
```

The T3 device tool also opens links: `agent-device open com.hash.prism '<url>'`. On 2026-10-29 the iOS QA sim opened `https://prismwalls.com/...` links in the app. A not-found link shows `This page does not exist` and `Go home`. `prism://mood/dreamy` opens the Dreamy mood page.

Repeat these checks on each platform, using `describe`, labeled taps, and `snapshot --tag <case>` from the helper:

1. **Warm settings and tabs.** With Prism already on Home, open `prism://settings`, then `prism://dashboard/search/users` and `prism://dashboard/rewards`. Assert Settings, user search, and Rewards respectively. Repeat one destination from a real QA inbox link and a received QA push when available.
2. **Cold settings.** While still owning the lock, terminate only Prism with `xcrun simctl terminate "$PRISM_QA_UDID" com.hash.prism` or `adb -s emulator-5580 shell am force-stop com.hash.prism`, then open the settings URL. After bootstrap and any mandatory onboarding, Settings must become visible instead of being lost when the startup stack is replaced. Retain the existing session; do not clear app data.
3. **Chooser.** Open `prism://wallpaper-filter`. Assert `Choose image` and no automatic picker. Tap it, cancel the native picker, and assert the chooser remains. Repeat with a known QA gallery image and assert the filter tool shows that image. Do not save, upload, purchase, or set a wallpaper during this navigation smoke.
4. **Auth pending and success.** From a browsable signed-out session, open `prism://shop`. Assert onboarding appears and Shop stays absent. Let the human complete real sign-in and onboarding; assert Shop opens once after bootstrap. For a cold signed-out launch, repeat the URL and check that mandatory onboarding also preserves the target. Never automate credentials or treat injected session flags as sign-in proof.
5. **Auth cancellation.** From a browsable guest session, repeat the guarded Shop link. Cancel the provider flow and assert Shop has not opened. Back out of the pushed sign-in screen, or complete the iOS guest path, and assert the protected destination is discarded. A later unrelated human sign-in must not reopen it. Android has no guest onboarding path; report that case as unavailable when no browsable signed-out baseline exists.
6. **Failures and retry.** Open an invalid app URL such as `prism://wallpaper-filter?filePath=%2Ftmp%2Fwall.jpg` and assert not-found. With an approved short-code fixture, test successful resolution, an unavailable code, and an offline network failure followed by reconnect. The network case should retain the link and retry once. For push fallback, use an existing QA notification whose target is unavailable and assert the inbox.

Capture the before state, the resulting screen, and the exact URL or payload with platform, warm/cold state, and auth state. A protected or data-backed case without its preconditions is skipped with that specific reason. Finish with the helper's platform cleanup; keep the artifacts.

## Gotchas

- Custom-scheme success proves local app navigation. It does not prove universal/app links, production association files, push transport, hosted CI, or a store release.
- HTTPS opening depends on the installed app's signed capabilities, Android certificate, OS association cache, and deployed AASA/asset-links files on both hosts. Test real HTTPS links separately. If Safari or a store opens, record that behavior; do not relabel a successful `prism://` fallback as association proof. A package-targeted Android intent likewise does not prove unqualified OS association.
- Local association and Worker edits require a separately approved deployment. After deployment, check both hosts' association responses and real HTTPS opening; `/`, `/privacy`, and `/terms` remain website pages. Do not deploy as part of this recipe.
- Legacy `setup`/`share-setup` links open Home with an unavailable-feature message. Invalid URLs dispatched as app links open not-found; website-only HTTPS links stay external. Unavailable push targets use the inbox fallback. Check the adapter and payload before comparing outcomes.
- A protected target held by startup is distinct from an auth continuation created by a guard. Cancelling a provider leaves onboarding active; leaving a guard's sign-in screen cancels that continuation. Logout and signed-in account switches discard old session navigation and deferred retries.
- Test encoded identifiers and at least one legacy alias without replacing them with a simpler URL. Avoid a real inviter, upload, coin spend, or user notification unless that effect is explicitly authorized.
