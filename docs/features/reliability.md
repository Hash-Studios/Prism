# Reliability

The app must stay usable on a weak or missing network. These rules limit waiting time, avoid wrong stale data, keep Sentry quiet about network noise, and keep startup fast.

## Where to find it

There is no screen for this feature. The user sees the effects: the "No Internet" banner, error states with Retry, and a fast launch.

## Platforms

Android and iOS. One item is iOS only: the app badge clear. The other items run on both.

## Free and Pro

No gate. All users get the same behavior.

## How it works

| Area | Rule | Code |
|---|---|---|
| Wallhaven and Pexels requests | Each `http.get` times out after 10 s (`_requestTimeout`). | `lib/features/wallhaven_feed/data/repositories/wallhaven_wallpaper_repository_impl.dart`, `lib/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl.dart` |
| Personalized feed | Each source pool times out after 6 s (`_poolTimeout`). One slow pool does not block the feed. | `lib/features/personalized_feed/data/personalized_feed_repository_impl.dart` |
| Feed cache | A fetch-more failure returns an error, not a cached page. The cache is written only on refresh (page 1). A failed refresh can still return the cached first page. | Wallhaven, Pexels, and `lib/features/prism_feed/data/repositories/` |
| Offline banner | `HomeTabPage` listens to `ConnectivityService.onConnectionChange`. The red "No Internet" bar slides in 1 s after the app goes offline and hides when it recovers. The check calls only `https://prismwalls.com/` and `https://firestore.googleapis.com/` every 20 s. One host that answers means online. | `lib/core/network/connectivity_service.dart` (`buildInternetConnectionChecker`), `lib/core/di/injection_module.dart`, `lib/features/navigation/views/widgets/offline_banner.dart`, `lib/features/navigation/views/pages/home_tab_page.dart` |
| Image cache | One shared disk cache for thumbnails: key `prism_images`, 2000 objects, 14 days stale period. `PrismImageTile` uses it. | `lib/core/cache/prism_image_cache.dart` |
| Full image cache | A second disk cache for full-size wallpapers: key `prism_full`, 60 objects, 7 days stale period. "Clear cache" empties it. See "Disk budget" below. | `lib/core/cache/prism_full_image_cache.dart`, `lib/core/persistence/data_sources/cache_maintenance_service.dart` |
| Sentry `beforeSend` | `dropNetworkNoise` drops `SocketException`, `ClientException`, `TimeoutException`, `HandshakeException`, `HttpException`, `TlsException`, and Firebase errors with code `unavailable`, `deadline-exceeded` or `network-request-failed` (this covers Auth and Cloud Functions). It looks inside `FirestoreError.original` first. | `lib/core/monitoring/sentry_before_send.dart`, `lib/main.dart` |
| Non-fatal tracking | The platform and zone handlers log the error and track `AppErrorEvent` (`app_error`) with `errorSource` `platform_dispatcher`, `zone`, or `flutter_framework`. They do not track `AppCrashFatalEvent`. | `lib/main.dart`, `lib/core/monitoring/flutter_error_handler.dart` |
| Ad consent | `AdConsent.ensure()` asks Google UMP for a consent update (10 s timeout), shows the form if required, then reads `canRequestAds`. Ads load only when it is true. | `lib/features/ads/data/ad_consent.dart` |
| Remote Config at startup | The app applies cached values with `activate()` first. It then waits at most 3 s for `fetchAndActivate()`. If the last fetch worked and is less than 24 h old, the splash does not wait at all. The fetch still runs. | `lib/features/startup/data/repositories/startup_repository_impl.dart` |
| Block list | `getBlockedCreatorEmails(waitForInitialLoad: true)` waits at most 3 s, then returns the last known set. A stream error keeps the last known set. | `lib/data/user_blocks/firebase_user_block_repository.dart` |
| `LazyFileCache` | Writes run one after another through a chained future (`_lastWrite`). Two writes cannot overlap. A dirty flag joins changes made in the same tick into one write. | `lib/core/persistence/store_adapters/lazy_file_cache.dart` |
| Wall of the Day on resume | A resume refetches only when the day changed or 30 min passed. | `lib/features/startup/services/resume_refresh_policy.dart`, `lib/main.dart` |
| iOS badge | The app sets the badge to 0 each time it becomes active. iOS 16 and later use `setBadgeCount(0)`. Older iOS uses `applicationIconBadgeNumber = 0`. | `ios/Runner/AppDelegate.swift` |
| Persistence start | `PersistenceBootstrap.initialize()` catches a failed migration, logs it, and goes on with the stored data. The app always starts. | `lib/core/persistence/bootstrap/persistence_bootstrap.dart` |
| Feed snapshot age | `FeedSnapshot.isStale` is true when the snapshot is older than its TTL. The read still returns it, because it is the offline fallback. Scopes older than 30 days are removed when the cache first loads. | `lib/core/persistence/data_sources/feed_cache_local_data_source.dart` |
| Push tap | `_handlePushTap` waits for the end of startup (see "Deep links during startup"), then wraps routing in try/catch. On failure it opens the inbox (`NotificationRoute`). If that fails, it opens `HomeTabRoute`. | `lib/main.dart` |
| Tab re-tap | A tap on the active tab pops that tab to its root. | `lib/features/navigation/views/widgets/prism_bottom_nav.dart` |

### Details

Ad consent:

- A failed consent update or form does not stop the flow. The app logs a warning and reads the stored consent.
- A refused result is not kept. The next `ensure()` call tries again.
- App start does not wait for consent. `_deferredStartup` runs it in the background. It calls `MobileAds.instance.initialize()` only when `canRequestAds` is true.
- The rewarded ad load (`ads_repository_impl.dart`) calls `ensure()` too. Without consent it ends as failed and skips the load.

Remote Config:

- `fetchTimeout` is 3 s. `minimumFetchInterval` is 1 hour in release builds and zero in other builds.
- A fetch that takes longer than 3 s keeps running. The splash does not wait for it.
- If `lastFetchStatus` is success and `lastFetchTime` is less than 24 h ago, the splash does not wait for the fetch. New values apply on the next launch.
- If the fetch fails, the app uses the defaults and the last activated values.

Startup budget:

- `main()` waits only for persistence, monitoring, Firebase and DI before `runApp`.
- `_restoreLoginStatus` saves the user, sets the Sentry scope and starts the coin sync first. The RevenueCat premium check runs after that, with an 8 s limit, and does not hold up the rest.
- The futures that start in `initState` (login restore, launch notification, launch push) log their errors. They do not reach the zone handler.

Deep links during startup:

- `DeepLinkStartupGate` (`lib/core/router/deep_link_startup_gate.dart`) holds a link until the config has loaded and the splash and onboarding are gone from the router stack. It re-checks on every router change, so a long onboarding does not drop the link.
- A referral link pushes no route. It runs as soon as the config has loaded, so the toast and the saved inviter work during onboarding.
- A tapped push waits for the same gate. There is no time limit.
- A short link (`/l/<code>`) that fails because of the network (no connection, timeout, 502, 503 or 504) shows "No connection. We will open this link when you are back online." The app tries again once, when the connection returns or the app resumes with a connection.
- Any other failure shows "This link is no longer available." and opens the Not found screen. The app never opens the link host in the browser.

Session ended:

- `_MyApp` listens to `FirebaseAuth.idTokenChanges()` once Firebase is ready (`SessionEndWatcher`).
- If Firebase reports no user while the app is signed in, and the state stays that way for 5 s, the app runs the normal sign-out cleanup (`signOutGoogle`).
- Then it shows one bottom sheet: "Your session ended. Sign in again." with "Not now" and "Sign in". "Sign in" opens the usual sign-in sheet.
- A sign-out that the user starts does not show the sheet. The app clears its signed-in flag first.

Notification channels:

- `createNotificationChannels` (`lib/core/startup/notification_channels.dart`) creates `followers`, `recommendations`, `posts`, `downloads`, `wall_of_the_day`, `streak_reminder` and `moderation`.
- `followers`, `wall_of_the_day`, `streak_reminder` and `moderation` use high importance, to match `priority: high` on the server.
- Android keeps the importance of a channel that already exists. The new importance reaches new installs only.

Notification pre-prompt:

- Before the system prompt, the app shows "Get the Wall of the Day and streak reminders?" with "Not now" and "Turn on". Only "Turn on" calls `requestPermission()`.
- `StartupModalSlot` (`lib/core/startup/startup_sheet.dart`) lets only one startup sheet show per session. The session ended sheet takes the slot too. If the slot is taken, the pre-prompt does not show.
- "Not now" does not mark the prompt as done. The next session can ask again after a download or a set.

Disk budget:

- `PrismFullImageCache` keeps 60 full-size wallpapers for 7 days. The default manager keeps 200 for 30 days, which can reach about 1 GB.
- The class exists and "Clear cache" empties it. The detail screen, `WallpaperService` and the live wallpaper preparer must load images through it to use it. The Settings byte count must include the folder `prism_full`.

Wall of the Day: `_lastWotdRefresh` starts at app launch. The resume handler refetches when `shouldRefreshWotdOnResume` returns true.

## Limits

- The Swift badge code and the UMP form need a device to confirm. The Swift code was not compiled here.
- No automated test covers the iOS badge clear or the push tap try/catch path.
- A tab re-tap does not scroll to the top. The bottom bar sits above the tab pages, so it cannot reach their scroll controllers.
- The offline banner exists only on the Home tab (`HomeTabPage`).
- The 10 s and 6 s timeouts apply to Wallhaven, Pexels, and the personalized pools. Other calls keep their own limits. The Prism feed repository sets no timeout of its own.
- A failed refresh can still show a cached first page. The rule "no stale page" applies to fetch-more only.
- A snapshot past its TTL is still returned. Nothing reads `isStale` yet.
- The session ended sheet shows after a lost session on a device that is running. If the app starts with no Firebase user while the saved state says signed in, the app resets to a guest without a sheet.
- The notification channel importance changes reach new installs only.
- `PrismFullImageCache` is not used by the detail screen, `WallpaperService` or the live wallpaper preparer until those files adopt it.
- The app does not remove expired entries from the thumbnail cache at startup. `flutter_cache_manager` has no public call for that, and does it by itself after the next stored image.

## How to test

1. Turn on airplane mode on the Home tab. Wait 1 s. Make sure the red "No Internet" bar slides up.
2. Turn the network on. Make sure the bar hides.
3. Scroll a feed to page 2 or later, then turn on airplane mode and scroll further. Make sure the feed shows its retry state and does not repeat page 1.
4. Start the app offline. Make sure the splash ends in about 3 s and the app opens.
5. Start the app twice on a good network. On the second start, make sure the splash does not wait for Remote Config.
6. Block `dummyapi.online`, `jsonplaceholder.typicode.com` and `fakestoreapi.com` on the network. Make sure the offline banner does not show and AI generation still works.
7. On a new install, open a wallpaper share link, then go through onboarding. Make sure the wallpaper opens after onboarding ends.
8. Turn on airplane mode, open a short link (`prismwalls.com/l/<code>`), then turn it off. Make sure the toast shows and the wallpaper opens once the connection returns. Open a short link with a wrong code. Make sure "This link is no longer available." shows.
9. Delete the account on a second device. Wait for the first device to refresh its token. Make sure the "Your session ended" sheet shows once.
10. On a new install, set a wallpaper. Make sure the one-line notification question shows before the system prompt, and "Not now" shows no system prompt.
11. On a fresh install in an EEA region, make sure the consent form shows before ads load. Refuse consent and make sure the rewarded ad does not load.
12. Leave the app in the background past midnight or for 30 min, then open it. Make sure Wall of the Day refreshes.
13. On iOS, get a push with a badge, then open the app. Make sure the badge clears.
14. Open a detail screen from a tab, then tap the active tab icon. Make sure the tab returns to its root.

Automated tests:

- `test/core/monitoring/sentry_before_send_test.dart`
- `test/core/monitoring/flutter_error_handler_test.dart`
- `test/core/persistence/lazy_file_cache_test.dart`
- `test/core/persistence/feed_cache_local_data_source_test.dart`
- `test/core/persistence/persistence_bootstrap_test.dart`
- `test/core/persistence/cache_maintenance_service_test.dart`
- `test/core/network/connectivity_service_test.dart`
- `test/core/router/deep_link_startup_gate_test.dart`
- `test/core/router/short_link_retry_test.dart`
- `test/core/router/short_link_resolver_test.dart`
- `test/core/startup/session_end_watcher_test.dart`
- `test/core/startup/notification_channels_test.dart`
- `test/features/startup/services/notification_permission_prompt_service_test.dart`
- `test/features/ads/ad_consent_test.dart`
- `test/features/startup/remote_config_prepare_test.dart`
- `test/features/startup/resume_refresh_policy_test.dart`
- `test/features/user_blocks/firebase_user_block_repository_test.dart`
- `test/features/navigation/offline_banner_test.dart`
- `test/features/navigation/prism_bottom_nav_test.dart`
- `test/core/router/push_tap_startup_test.dart`
- `test/features/wallhaven_feed/data/repositories/wallhaven_wallpaper_repository_impl_test.dart`
- `test/features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl_test.dart`
- `test/features/prism_feed/data/repositories/prism_wallpaper_repository_impl_test.dart`
- `test/features/personalized_feed/data/personalized_feed_repository_impl_test.dart`

Command:

```sh
fvm flutter test --no-pub test/core/monitoring test/core/persistence/lazy_file_cache_test.dart test/features/ads/ad_consent_test.dart test/features/startup test/features/user_blocks test/features/navigation
```
