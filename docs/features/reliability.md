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
| Offline banner | `HomeTabPage` listens to `ConnectivityService.onConnectionChange`. The red "No Internet" bar slides in 1 s after the app goes offline and hides when it recovers. | `lib/core/network/connectivity_service.dart`, `lib/features/navigation/views/widgets/offline_banner.dart`, `lib/features/navigation/views/pages/home_tab_page.dart` |
| Image cache | One shared disk cache for thumbnails: key `prism_images`, 2000 objects, 14 days stale period. `PrismImageTile` uses it. | `lib/core/cache/prism_image_cache.dart` |
| Sentry `beforeSend` | `dropNetworkNoise` drops `SocketException`, `ClientException`, `TimeoutException`, `HandshakeException`, and Firestore `unavailable`. | `lib/core/monitoring/sentry_before_send.dart`, `lib/main.dart` |
| Non-fatal tracking | The platform and zone handlers log the error and track `AppErrorEvent` (`app_error`) with `errorSource` `platform_dispatcher`, `zone`, or `flutter_framework`. They do not track `AppCrashFatalEvent`. | `lib/main.dart`, `lib/core/monitoring/flutter_error_handler.dart` |
| Ad consent | `AdConsent.ensure()` asks Google UMP for a consent update (10 s timeout), shows the form if required, then reads `canRequestAds`. Ads load only when it is true. | `lib/features/ads/data/ad_consent.dart` |
| Remote Config at startup | The app applies cached values with `activate()` first. It then waits at most 5 s for `fetchAndActivate()`. | `lib/features/startup/data/repositories/startup_repository_impl.dart` |
| Block list | `getBlockedCreatorEmails(waitForInitialLoad: true)` waits at most 3 s, then returns the last known set. A stream error keeps the last known set. | `lib/data/user_blocks/firebase_user_block_repository.dart` |
| `LazyFileCache` | Writes run one after another through a chained future (`_lastWrite`). Two writes cannot overlap. | `lib/core/persistence/store_adapters/lazy_file_cache.dart` |
| Wall of the Day on resume | A resume refetches only when the day changed or 30 min passed. | `lib/features/startup/services/resume_refresh_policy.dart`, `lib/main.dart` |
| iOS badge | The app sets the badge to 0 each time it becomes active. iOS 16 and later use `setBadgeCount(0)`. Older iOS uses `applicationIconBadgeNumber = 0`. | `ios/Runner/AppDelegate.swift` |
| Push tap | `_handlePushTap` wraps routing in try/catch. On failure it opens the inbox (`NotificationRoute`). If that fails, it opens `HomeTabRoute`. | `lib/main.dart` |
| Tab re-tap | A tap on the active tab pops that tab to its root. | `lib/features/navigation/views/widgets/prism_bottom_nav.dart` |

### Details

Ad consent:

- A failed consent update or form does not stop the flow. The app logs a warning and reads the stored consent.
- A refused result is not kept. The next `ensure()` call tries again.
- App start does not wait for consent. `_deferredStartup` runs it in the background. It calls `MobileAds.instance.initialize()` only when `canRequestAds` is true.
- The rewarded ad load (`ads_repository_impl.dart`) calls `ensure()` too. Without consent it ends as failed and skips the load.

Remote Config:

- `fetchTimeout` is 5 s. `minimumFetchInterval` is 1 hour in release builds and zero in other builds.
- A fetch that takes longer than 5 s keeps running. The splash does not wait for it.
- If the fetch fails, the app uses the defaults and the last activated values.

Wall of the Day: `_lastWotdRefresh` starts at app launch. The resume handler refetches when `shouldRefreshWotdOnResume` returns true.

## Limits

- The Swift badge code and the UMP form need a device to confirm. The Swift code was not compiled here.
- No automated test covers the iOS badge clear or the push tap try/catch path.
- A tab re-tap does not scroll to the top. The bottom bar sits above the tab pages, so it cannot reach their scroll controllers.
- The offline banner exists only on the Home tab (`HomeTabPage`).
- The 10 s and 6 s timeouts apply to Wallhaven, Pexels, and the personalized pools. Other calls keep their own limits. The Prism feed repository sets no timeout of its own.
- A failed refresh can still show a cached first page. The rule "no stale page" applies to fetch-more only.

## How to test

1. Turn on airplane mode on the Home tab. Wait 1 s. Make sure the red "No Internet" bar slides up.
2. Turn the network on. Make sure the bar hides.
3. Scroll a feed to page 2 or later, then turn on airplane mode and scroll further. Make sure the feed shows its retry state and does not repeat page 1.
4. Start the app offline. Make sure the splash ends in about 5 s and the app opens.
5. On a fresh install in an EEA region, make sure the consent form shows before ads load. Refuse consent and make sure the rewarded ad does not load.
6. Leave the app in the background past midnight or for 30 min, then open it. Make sure Wall of the Day refreshes.
7. On iOS, get a push with a badge, then open the app. Make sure the badge clears.
8. Open a detail screen from a tab, then tap the active tab icon. Make sure the tab returns to its root.

Automated tests:

- `test/core/monitoring/sentry_before_send_test.dart`
- `test/core/monitoring/flutter_error_handler_test.dart`
- `test/core/persistence/lazy_file_cache_test.dart`
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
