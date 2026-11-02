# Prism verification map

This directory is the maintained source for verifying user-facing behavior of the Prism app on **iOS Simulator** and **Android emulator**. Read this index before driving, then use the matching feature file as the recipe.

## Baseline preconditions

- Our devices only: iOS simulator `Prism QA iPhone 17 Pro`, Android AVD `Prism_QA_API36` on port 5580 (`emulator-5580`). See `SKILL.md` for how to create/boot them and why other booted devices are off-limits.
- `axe` >= 1.7 on PATH for iOS. `adb` and `emulator` on PATH for Android.
- App built and installed: `com.hash.prism`, built with `--dart-define=SKIP_FIREBASE_INIT=true` for UI-only proof, or with Doppler dev secrets when a feature reads real Firestore/RevenueCat/Sentry data.
- Run `.claude/skills/verify-prism/bin/verify-prism doctor` and require a clean exit before driving.
- Never drive a device this run did not lock (`/tmp/prism-verify-ios.lock` / `/tmp/prism-verify-android.lock`).

Default cold state after `launch --fresh`: **Welcome / onboarding** (`lib/features/onboarding_v2`, route `/onboarding/v2`), because there is no stored session yet. A signed-out user hitting a `_signedInGuard` route is redirected here by `lib/core/router/route_guards.dart`.

## Driving conventions

- Start every recipe from the baseline unless its preconditions say otherwise.
- Prefer accessibility labels (iOS `Semantics(label: ...)`, `tooltip:`) or view text/content-desc (Android) from live Dart source over coordinates. Confirm on device with `describe` before trusting a label from this map; source drifts.
- Never type real credentials. Sign-in is real Google/Apple OAuth; ask the human to sign in, or stick to signed-out flows.
- Following, blocking, or reporting a real account, or anything that pushes a notification to a real user, needs the human's go-ahead first.
- Restore nothing global except what the feature file lists. Do not delete proof artifacts.

## Proof and skip reporting

- Capture the user action and the resulting state (screenshot + tree via `snapshot --tag ...`).
- Record the feature id, platform, and entry point with every artifact.
- An unreachable path (needs sign-in, needs Doppler data, needs an admin account) is reported with the attempted label and the unmet precondition. Do not report a skipped entry as verified through a different path.

## Feature entry contract

Each feature file starts with an H1 and one paragraph. It then uses exactly four H2 sections in this order:

1. `Sub-features`
2. `How to get to it (user POV)`
3. `Driving it with the helper`
4. `Gotchas`

## Features

- [Onboarding and sign-in](./onboarding-signin.md): `/onboarding/v2`, Google/Apple OAuth, interests, starter pack, first wallpaper.
- [Home feed](./home-feed.md): For you/Following/Trending/Latest/Popular tabs, Tune your feed, carousel, Moods, hold menu, Collections tab.
- [Wallpaper detail](./wallpaper-detail.md): favourite, share sheet, edit, save/download, Set screen, phone preview, details, report.
- [Search](./search.md): wallpaper search, filters, colour filter, discovery, Find creators.
- [Profile and edit profile](./profile.md): own profile, public profile, followers/following, edit profile.
- [Rewards and coins](./rewards.md): Rewards tab, streak, quests, earn and spend tiles, coin history, leaderboard.
- [AI wallpaper](./ai-wallpaper.md): `/ai` page from Create or Rewards, prompt, style, quality, result actions.
- [Notifications inbox](./notifications.md): in-app notification list, tap-through routing.
- [Settings](./settings.md): grouped rows, themes, toggles, storage, purchases, log out/delete account.
- [Deep links](./deep-links.md): `prismwalls.com` and `prism://` pages, share/user/refer/short links, push routing.
- [Library and Folders](./library-folders.md): Library tabs, Folders, Save to folder.
- [Drops, Shop and Premium](./drops-shop-premium.md): Weekly Drop, drop preview, Shop, Premium page and paywall.
- [Upload](./upload.md): Create sheet, photo pick, edit, upload screen, review status.
