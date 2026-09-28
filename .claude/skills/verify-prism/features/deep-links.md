# Deep links

Prism accepts `https://prismwalls.com/...` universal/app links on both platforms, plus a custom `prism://` scheme (`lib/core/router/deep_link_navigation.dart`). Parsing is in `lib/core/router/deep_link_parser.dart`, route mapping in `deep_link_navigation.dart`. Confirmed intent filters: `android/app/src/main/AndroidManifest.xml` (`pathPrefix` for `/share`, `/user`, `/setup`, `/refer`, `/l`, host `prismwalls.com`). Confirmed iOS: `ios/Runner/Runner.entitlements` has `applinks:prismwalls.com`; `ios/Runner/Info.plist` registers the `prism` URL scheme.

## Sub-features

- `share` (`/share/<wallId>?source=&url=&thumb=...` or query-only): opens `WallpaperDetailRoute` (see `features/wallpaper-detail.md`). Requires a wall id and at least a wallpaper or thumbnail URL; missing both falls through to `UnknownIntent` (no navigation).
- `user` / `fprofile` / `follower-profile` / `profile` roots: opens `ProfileRoute(profileIdentifier: ...)` (see `features/profile.md`). Identifier comes from the second path segment or `identifier`/`username`/`user`/`email` query params.
- `setup` / `share-setup` roots: opens `ShareSetupViewRoute(setupName: ...)` (see `features/setups.md`).
- `refer` / `referral` roots: parsed into a `ReferLinkIntent`, but `_mapActionToRoute` currently returns `null` for it, no navigation happens yet even though the intent parses.
- `l` root (short codes, e.g. `/l/<code>`): resolved via `https://prismwalls.com/api/links` before re-mapping to one of the above; needs network.
- Push-notification routing is a separate mapper, `lib/core/router/notification_route_mapper.dart` (see `features/notifications.md`); it uses `route` values (`wall`, `wall_of_the_day`, `streak_reminder`, `follower`, `announcement`), not URL paths.

## How to get to it (user POV)

- Tap a real `https://prismwalls.com/...` link (Messages, browser, another app) with the app installed.
- Open it directly in the simulator/emulator (see below) without needing a real link source.

## Driving it with the helper

Preconditions:

- App installed and, for `/l/<code>`, network access (it calls the real `prismwalls.com/api/links` endpoint).

- **iOS.** Universal links do not reliably open from `xcrun simctl openurl` inside a plain debug build; open the URL from the Simulator's own Safari and tap the smart-app banner, or use `xcrun simctl openurl <udid> "https://prismwalls.com/share/<id>?url=<encoded>"` and confirm it routes (fall back to the custom scheme `prism://share/<id>?...` if the universal link does not trigger, since `Runner.entitlements` covers `applinks:prismwalls.com` but the association file on the real domain is out of this skill's control).
- **Android.** `adb -s emulator-5580 shell am start -a android.intent.action.VIEW -d "https://prismwalls.com/share/<id>?url=<encoded>" com.hash.prism`.
- **Share.** Open a `/share/<id>` link with a `url` or `thumb` query param; assert `WallpaperDetailRoute` opens for that id. Try one with neither and confirm it is a no-op (`UnknownIntent`), not a crash.
- **User.** Open `/user/<identifier>`; assert `ProfileRoute` opens for that identifier.
- **Setup.** Open `/setup/<name>`; assert `ShareSetupViewRoute` opens.
- **Refer.** Open `/refer/<id>`; today this is a documented no-op (parses, does not navigate). Confirm that stays true rather than assuming it is broken.
- **Short code.** Open `/l/<code>` for a code you know resolves; confirm it re-maps to the right screen. Confirm an unknown code degrades to a no-op, not a crash.
- **Proof.** Snapshot the state before opening the link (Home) and after (the destination screen), plus the exact link tested.

## Gotchas

- `refer`/`referral` links parse successfully but intentionally do not navigate anywhere yet (`_mapActionToRoute` returns `null` for `ReferLinkIntent`). Do not report that as a bug without checking this file first; it may be a known gap, not a regression.
- `/l/<code>` calls a real backend endpoint; it needs network and will not resolve under an offline or heavily mocked test run.
- `deep_link_parser.dart` accepts several aliases for the same root (`user`, `fprofile`, `follower-profile`, `profile` all mean "profile"; `setup` and `share-setup` both mean "setup"). Test at least one alias per group, do not assume they behave identically without checking.
