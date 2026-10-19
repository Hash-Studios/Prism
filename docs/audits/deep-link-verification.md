# Deep-link verification

This change gives every AppRouter page a validated URL or an explicit image-picker continuation. The internal splash route remains startup infrastructure. The route census also includes formerly manual reward and preview pages, Premium, and each debug tab. See [the page catalog](../features/deep-links.md) for usable URLs.

External links, push payloads, notification inbox rows, downloaded notifications, and `openPrismLink` enter one dispatcher. Authentication preserves typed arguments and nested parents. Logout and cancellation invalidate queued and in-flight work. Guard acceptance and actual route visibility determine navigation analytics.

## Automated evidence

- Route census: 56 AppRouter pages checked against catalog destinations and picker continuations; 75 catalog URL examples validated in Dart and on both Worker hosts.
- Auth continuation: 22 focused checks, including nested arguments, onboarding stack replacement, guest/back cancellation, admin denial, and logout while root or nested guards are pending.
- Dispatcher and adapters: 93 focused checks, including cold platform delivery, all entry sources, retry provenance, stale hydration cancellation, nested tabs, and notification callbacks.
- Image workflows: 12 widget checks covering destination arguments, picker cancellation/errors, and forbidden side effects.
- Worker: 63 tests, including page landings, parameter parity, association files, encoded arguments, legacy aliases, and short links.
- Full `make ci`: passed with 4,849 Flutter tests passed and 187 existing skips. The gate uses Flutter 3.47.5, CI-mode nonfatal informational lints, and GNU grep for the shell guard fixtures on macOS. Changed Dart files have no analyzer findings.
- Final iOS Simulator and Android debug builds: passed. Build warnings from existing plugins remain; no signing or build configuration change is committed.

The full suite exposed an existing macOS notification test fake without an APNS token method. The fake now supplies a token; exact topic subscription assertions remain unchanged.

## Device evidence

Final debug builds use `SKIP_FIREBASE_INIT=true`. Android was locally signed with the existing release key to update the QA installation; the temporary Gradle signing override and credentials are not part of this change.

| Platform | Entry exercised | Observed destination |
|---|---|---|
| iOS QA simulator | Terminate app, then `prism://about` | About after startup |
| iOS QA simulator | `prism://choose-wallpaper?workflow=photoPreview` | Photo preview chooser; gallery Cancel returns to chooser |
| iOS QA simulator | `prism://premium` | Premium entry with explicit View plans; no purchase initiated |
| Android QA emulator | Force-stop, then `prism://about` | About after startup |
| Android QA emulator | `https://prismwalls.com/dashboard/search/users` VIEW intent | Find creators within the Search tab |
| Android QA emulator | `https://www.prismwalls.com/choose-wallpaper?workflow=photoPreview` VIEW intent | Photo preview chooser |

Screenshots and accessibility trees are retained in the verify-prism runs `20261019T121306Z-1845` and `20261019T121307Z-1843`. Selected screenshots are attached to the PR. Earlier captures during startup or system dialogs are not passing evidence. The Android QA emulator needed a restart after launcher/System UI ANRs; final checks use the recovered emulator.

These checks prove routing and UI behavior. They do not prove real OAuth provider completion, FCM delivery, purchase fulfillment, or every backend resource. Auth and push adapters have automated behavioral proof; no credentials, purchases, uploads, rewards, or real-user notifications were submitted during device checks.

## Release boundary

The Worker and association changes are not deployed. Native registrations require an updated app release. Android HTTPS intents above explicitly target the installed package; they do not establish live OS domain verification. Production AASA/assetlinks, browser-to-app handoff, and real push delivery must be verified after deployment and installation of the released app. Root, privacy, and terms remain website-owned.
