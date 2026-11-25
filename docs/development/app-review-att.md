# App Tracking Transparency (ATT) and App Review

Prism asks for ATT because AdMob can show personalized ads on iOS when the user allows tracking. The App Store privacy
label declares tracking (Device ID, Advertising Data). This page is the source for the App Review note, the reply to
App Review, and the owner's recording script.

History: build 360 had no prompt (#869). Build 372 asked in one 10 s window, and an iPad review missed it (#908).
Build 379 asked on every activation, and App Review still did not find it on an iPad Air 11-inch (M3), iPadOS
27.2.1, on 2026-11-24. What the simulator runs proved, and what changed after 379, is under "Why a reviewer can miss
the prompt".

## Launch timeline (fresh install, iPadOS 27.2)

| Time | What runs | Can it collect tracking data before the ATT answer? |
| --- | --- | --- |
| `didFinishLaunching` | `AppDelegate` adds the ATT observers for scene activation (`UIScene.didActivateNotification`) and app activation (`UIApplication.didBecomeActiveNotification`). | No data. |
| Scene connects | `FlutterSceneDelegate` loads the Flutter view. Dart `main()` starts. | No data. |
| Dart `main()` | `Firebase.initializeApp`. Google Analytics for Firebase starts and logs `first_open` and `session_start`. Info.plist sets `GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE`, `..._AD_USER_DATA` and `..._AD_PERSONALIZATION_SIGNALS` to false, so Analytics reads no IDFA and sends nothing for ads. | No. App analytics only. |
| Dart `main()` | Sentry starts (`sendDefaultPii = false`). Crash and performance data, no advertising identifier, no IP address. | No. |
| First scene activation | Native ATT attempt: wait 250 ms, then ask once while the status is `notDetermined` and a scene is `foregroundActive`. Ask again only if iOS returns the request without an answer (dropped), or on the next activation. **The prompt shows here, when the scene is active. It can show over the launch screen or over the first Flutter screen (onboarding or sign-in). It is modal, so the user answers it before they can use that screen.** | n/a |
| First Flutter frame | `AdConsent.requestTracking()` joins the same native attempt. RevenueCat `configure` (no `collectDeviceIdentifiers`, no AdServices token). | RevenueCat: no. It keeps an anonymous app user id. |
| After Firebase is ready | Mixpanel starts (`trackAutomaticEvents: false`). Mixpanel Swift 6 uses a random distinct id and never reads the IDFA. | No. |
| After the final ATT answer | Google UMP `requestConsentInfoUpdate` and the consent form, then `MobileAds.initialize` and the first ad request. `GADDelayAppMeasurementInit` keeps the Google Mobile Ads SDK from starting app measurement before that. | Only after the answer. |
| After "Allow" only | `FirebaseAnalytics.setConsent` grants ad storage, ad user data and ad personalization. AdMob requests personalized ads. | Yes, only after "Allow". |
| After "Ask App Not to Track" | Ads stay non-personalized (`nonPersonalizedAds: true`). `setConsent` sets the three Analytics ad consents to denied. This runs on every launch, so a later change in Settings is applied on the next launch. | No. |
| After the ATT answer | The push permission prompt can show (it waits for ATT). | n/a |

Identifiers:

- IDFA (advertising identifier): iOS returns zeros until the status is `authorized`. Only the Google Mobile Ads SDK
  and Google Analytics (with ad storage granted) can read it. Both wait for "Allow".
- IDFV (identifier for vendor): Google Analytics and Sentry device context can use it. It is not shared across
  companies, so it is not tracking. The debug panel shows it in debug builds only.
- Device id: Prism has no device id of its own. Firebase Installations, FCM and RevenueCat use per-install ids.
- Crashlytics: not in the app.

## States that stop the prompt

| State | Status the app reads | What the user sees |
| --- | --- | --- |
| Settings > Privacy & Security > Tracking > "Allow Apps to Request to Track" is off | `denied` at once | No prompt. iOS does not let any app ask. |
| Managed Apple Account, a child account, or a device profile (MDM) that blocks tracking | `restricted` or `denied` | No prompt. The switch is off and can be grey. |
| The user answered before (this install) | `authorized` or `denied` | No prompt. Delete the app and install it again to ask again. |
| Another alert is on screen (a system permission, an unanswered ATT alert left from an earlier install) | `notDetermined`, scene `foregroundInactive` | No prompt yet. The app does not ask while no scene is foreground-active. It asks when the other alert closes and the scene activates. |
| The scene is not `foregroundActive` (Slide Over going away, app switcher, Control Center open, locked screen) | `notDetermined`, request dropped | No prompt yet. The next scene activation asks again. |
| A request made from `application(_:didBecomeActive...)` in a UIScene app | That method never runs with scenes | Never asks. Prism does not use it; it observes the scene and app notifications. |

## Why a reviewer can miss the prompt

Simulator runs on 2026-11-24, iPad Air 11-inch (M3), iPadOS 27.0 (the iPadOS 27.2 simulator runtime would not
download on this Mac), debug build with the `prd` Doppler config, fresh install each time:

- Build 379 logic (master `dd99b2729`): the prompt shows, about 3 s after launch, over the sign-in screen. The first
  request came from the Flutter first-frame call. The native activation observer was added only when the Flutter
  engine started, so it missed the first activation. While the alert was up, the app sent about 40 more
  `requestTrackingAuthorization` calls (one every 250 ms).
- This change: the first request comes from the scene activation (`scene #1 ... scenes=[0] ask=true`), so the prompt
  shows on the launch screen, before Flutter draws anything. One request per prompt. Portrait and landscape
  show it. A relaunch after an answer sends no request.
- An unanswered ATT alert from an earlier install keeps the new launch `foregroundInactive` (`scenes=[1]`). No app can
  show its own prompt until that alert closes.

The simulator never reproduced a launch with no prompt. The states in the table above are the ones that do: the
"Allow Apps to Request to Track" switch off, a managed or child account, or another alert that stays on screen. The
review note now tells the reviewer where the switch is, and to reinstall Prism to see the prompt again.

What changed after 379, so the request no longer depends on Flutter timing or on repeated calls:

- `AppDelegate` adds the observers in `didFinishLaunching`, before the Flutter engine exists, for the scene activation
  (`UIScene.didActivateNotification`) and the app activation (`UIApplication.didBecomeActiveNotification`).
- Each request needs a `foregroundActive` scene (`TrackingPrompt.shouldAsk`). `UIApplication.applicationState` is not
  used.
- The next request waits for the callback of the last one, or for the scene or app to lose the foreground, so the app
  never calls on top of a visible alert.
- Each attempt writes to the unified log (`com.hash.prism`, category `ATT`), so a device recording can be matched
  with Console.app.

## Notes for App Review (paste into App Store Connect)

```text
App Tracking Transparency: Prism shows the App Tracking Transparency prompt as soon as the app is active on the
first launch. It can show over the first screen (onboarding or sign-in), and the user must answer it before they can
use that screen. It shows before the notification prompt and before every ad. It shows again on every
launch until the user answers.

The prompt can only show when Settings > Privacy & Security > Tracking > "Allow Apps to Request to Track" is on. If
that switch is off, or the device uses a managed or child account, iOS does not let any app show the prompt.

To see the prompt again: delete Prism and install it again.

Before the user answers, Prism loads no ads, does not start Google's consent form, and reads no advertising
identifier. Google Analytics has ad storage and ad personalization turned off until the user taps "Allow". If the
user taps "Ask App Not to Track", ads stay non-personalized.

A screen recording from a physical device is attached to our reply in the Resolution Center.
```

## Reply to App Review (Resolution Center)

```text
Hello,

Thank you for the review. We attached a screen recording from a physical device. It shows:

1. Settings > Privacy & Security > Tracking, with "Allow Apps to Request to Track" turned on.
2. A fresh install of Prism.
3. The App Tracking Transparency prompt as soon as the app opens, before the user can use any screen.
4. The flow after the answer, and a second launch with no prompt.

Where the prompt shows: on the first launch, as soon as the app is active, before any other alert and before any ad.
Until the user answers, it shows again every time the app becomes active.

When it does not show: iOS shows the prompt only when Settings > Privacy & Security > Tracking > "Allow Apps to
Request to Track" is on. If the switch is off, or the device has a managed or child account, iOS answers for the
app and no app can show the prompt. To see it again, delete Prism and install it again.

Data before the answer: Prism loads no ads, does not start Google's consent form, and reads no advertising
identifier until the user answers. Google Analytics ad storage and ad personalization stay off until the user taps
"Allow".

In this build we also made the request follow the iPad scene life cycle, so it shows reliably on iPadOS 27.

Thank you.
```

## Recording script (physical device, owner only)

Use a test iPad or iPhone, not a device with data you do not want on screen. Use the build from TestFlight with a
build number above 379. Turn off notifications banners (Focus) so nothing covers the prompt.

1. Open Settings > Privacy & Security > Tracking. Turn "Allow Apps to Request to Track" on.
2. If Prism is installed, delete it: touch and hold the icon > Remove App > Delete App.
3. Open Control Center. Touch and hold Screen Recording. Set Microphone off. Tap Start Recording.
4. Open Settings > Privacy & Security > Tracking. Hold the screen for 2 s so the switch is readable.
5. Open TestFlight. Install Prism (the new build). Wait for the install to finish.
6. Tap Open. The ATT prompt shows. Hold for 3 s so the prompt text is readable.
7. Tap "Ask App Not to Track". Onboarding shows. Scroll the first screen.
8. Swipe up to the app switcher and close Prism. Open Prism again. No prompt shows.
9. Open Settings > Privacy & Security > Tracking. Prism is in the list with the switch off.
10. Stop the recording from Control Center. The video is in Photos.
11. Optional: record the same steps on an iPad in landscape.

To show "Allow" instead, do step 1 and 2 again, and tap "Allow" in step 7. Then Prism shows on in step 9.

Debug builds print `ATT status: <status>` in the Flutter log. All builds write `com.hash.prism` / `ATT` lines to the
unified log. To read them on a Mac: connect the device, open Console.app, select the device, and filter for
`subsystem:com.hash.prism category:ATT`.
