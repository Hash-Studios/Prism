# Home widgets (Android)

Prism has two Android home screen widgets: Wall of the Day and Streak.

The Wall of the Day widget shows today's Wall of the Day on the Android home screen. It updates by itself. The user does not need to open Prism.

## What it does

- Shows today's Wall of the Day, with a "Prism" label and a "Set" button.
- Gets the new wall by itself every 3 hours. It does not wait for the user to open Prism.
- Tap the image: Prism opens the detail screen of that wall.
- Tap "Set": Prism sets that wall as the home screen wallpaper. A short message says "Wallpaper set" or "Could not set wallpaper".
- Shows a preview in the widget picker. On Android 12 and later, the corners match the launcher.
- Shows a calm empty state (Prism logo and a short line of text) when there is no image yet.

## How to use it

1. Long-press the Android home screen and tap "Widgets".
2. Find "Wall of the Day" under Prism and drag it to the screen. The minimum size is 2 by 2 cells. The user can resize it.
3. Tap the image to see the wall in Prism. Tap "Set" to use the wall as the wallpaper.

## Platforms and plans

| Platform | Status |
|---|---|
| Android | Supported. |
| iOS | Supported. See [ios-widgets.md](ios-widgets.md). |
| Streak widget | Android: supported. iOS: see [ios-widgets.md](ios-widgets.md). |

The widget is free. It has no Pro gate.

## How it works

Code: `android/app/src/main/kotlin/com/hash/prism/WotdWidgetProvider.kt` (widget), `android/app/src/main/kotlin/com/hash/prism/WotdWidgetLogic.kt` (pure logic), `android/app/src/main/res/layout/wotd_widget.xml`, `android/app/src/main/res/layout/wotd_widget_preview.xml`, `android/app/src/main/res/xml/wotd_widget_info.xml`.

### Update

1. Android calls `onUpdate` at least every 3 hours (`updatePeriodMillis="10800000"`). Prism also asks for an update each time the app caches a new Wall of the Day URL (`QuickSettingsChannel.refreshWotdWidget`).
2. The widget works on a background thread (`goAsync` and an executor). It has a budget of 8.5 seconds, so it ends inside the broadcast time limit. Each network call has a short timeout.
3. The widget reads the Wall of the Day itself from the Firestore REST API, with no sign-in:
   - `GET /v1/projects/<project_id>/databases/(default)/documents/wall_of_the_day/current?key=<api_key>` gives `fields.wallId.stringValue`.
   - `GET .../documents/walls/<wallId>?key=<api_key>` gives `fields.wallpaper_url.stringValue`, the full image URL. The Firestore rules allow this read when the wall has `review == true`.
4. The widget reads `project_id` and `google_api_key` from the string resources that the google-services plugin makes. It looks them up by name with `Resources.getIdentifier`. `res/raw/keep.xml` keeps them in release builds.
5. Each REST call has the headers `X-Android-Package` and `X-Android-Cert` (the SHA-1 of the signing certificate, in uppercase hex). So the call also works when the API key is limited to Android apps.
6. The widget downloads the image and decodes it with `inSampleSize`, so the bitmap has at most 1 million pixels. It keeps a copy of the last image in the cache folder. If the wall did not change, it does not download the image again.

### Fallbacks

- If the REST call fails, the widget uses the URL in the shared preference `flutter.quick_tile.wotd.url`. The Wall of the Day quick tile uses the same value.
- If the image download fails, the widget shows the last image it kept.
- If there is no image at all, the widget shows the empty state.

### Tap and "Set"

- The tap opens `MainActivity` with the link `prism://share?id=<wallId>&source=prism&url=<full image URL>&widget=wotd_android`. When the thumbnail differs from the full image, the link also has `&thumb=<thumbnail URL>` before `&widget=wotd_android`. `DeepLinkParser` turns it into the wall detail screen. If the widget has only the cached URL and no wall id, the tap opens the app home.
- "Set" sends a broadcast to `WotdWidgetProvider` with the action `com.hash.prism.action.WOTD_SET_WALLPAPER`. The `PendingIntent` has an explicit component and `FLAG_IMMUTABLE`. The receiver is not exported, so only the widget can send this broadcast. The broadcast carries the URL of the wall that the widget shows, as an extra that the widget put in the `PendingIntent` when it drew the wall. So "Set" sets the image on screen even after the daily wall changes, and even when the widget could not save its cache. Only when the extra is missing does "Set" use the URL the widget saved, then fetch the current wall, and then use the URL the app stored. The download uses the same deadline-bounded connection as the update. The whole "Set" work (fetch, download, decode) has a budget of 40 seconds, under the limit for a background broadcast. The widget checks that the file is an image, decodes it to the screen size, and calls `WallpaperManager.setBitmap` with `FLAG_SYSTEM`. This runs off the main thread. A second tap is ignored while the first one runs.
- The receiver stays `exported="false"`.
- The layouts use only classes that `RemoteViews` can inflate (`FrameLayout`, `LinearLayout`, `ImageView`, `TextView`). The scrim is an `ImageView` with a gradient drawable. A plain `View` makes the launcher show "Can't load widget". `test/android/widget_layout_test.dart` fails on any other class.

## Colours

On Android 12 and later, the widgets use Material You dynamic colours. The colours come from `@android:color/system_*` in `android/app/src/main/res/values-v31/colors.xml` and `android/app/src/main/res/values-night-v31/colors.xml`.

Before Android 12, the widgets use fixed light and dark colours. These come from `android/app/src/main/res/values/colors.xml` and `android/app/src/main/res/values-night/colors.xml`.

The tokens have the same names in every file:

- `prism_widget_surface`: the widget background.
- `prism_widget_on_surface`: the main text.
- `prism_widget_on_surface_variant`: the secondary text.
- `prism_widget_accent`: the filled streak ring.
- `prism_widget_track`: the empty streak ring.
- `prism_widget_accent_container`: the background of the "Set" button.
- `prism_widget_on_accent_container`: the text of the "Set" button.

The launcher applies light or dark from the system setting.

The Wall of the Day image stays full bleed. The "Prism" label has white text on a small, rounded black backing (90% opacity). So you can read it on a white image too. The label uses white, not a token.

The "Set" button uses the accent container colour with its on-colour. So its contrast does not depend on the image.

## Streak widget

The Streak widget shows the streak of the signed-in user.

### What it does

- Compact (1x1 and 2x1): shows the count in a ring. The ring is full when today is kept. It is a light track when not.
- Large (2x2 and up): shows "Streak", the count in a ring, and one status line:
  - "Kept today" when today is kept.
  - "Keep your streak" when today is not kept yet.
  - "Start a streak today" when the count is 0. A lapsed streak shows 0.
- The default size is 2x2. The user can resize the widget to 1x1.
- Signed out: shows "Sign in to track your streak". A tap opens the app.
- Signed in: a tap opens `prism://streak?widget=streak_android`. That link opens Rewards.
- TalkBack reads "12-day streak, kept today" or "12-day streak, not kept yet today".

### How it works

- Code: `android/app/src/main/kotlin/com/hash/prism/StreakWidgetProvider.kt` (widget, snapshot store, midnight alarm), `android/app/src/main/kotlin/com/hash/prism/StreakWidgetLogic.kt` (pure rule), `android/app/src/main/kotlin/com/hash/prism/PrismWidgetHostApiImpl.kt` (Pigeon host API), layouts `android/app/src/main/res/layout/streak_widget_compact.xml`, `android/app/src/main/res/layout/streak_widget_large.xml`, `android/app/src/main/res/layout/streak_widget_signed_out.xml`, `android/app/src/main/res/layout/streak_widget_preview.xml`, and `android/app/src/main/res/xml/streak_widget_info.xml`.
- Data: The widget does not read Firestore. The streak belongs to the signed-in owner. The app writes a snapshot of it:
  - `lib/core/platform/streak_widget_sync.dart` calls `WidgetChannel.setStreak` (`lib/core/platform/widget_channel.dart`).
  - `WidgetChannel.setStreak` calls the Pigeon API `PrismWidgetHostApi.setStreakSnapshot` (`pigeons/prism_widget_api.dart`).
  - The same Dart code writes the iOS snapshot.
- The snapshot has four fields: count, last kept day (yyyy-MM-dd), UTC offset in minutes, and freezes.
- Android keeps the snapshot in the private SharedPreferences file `prism_streak_widget`.
- A null snapshot clears it. Sign-out and account deletion clear it.
- Rule: The widget uses the same rule as `isStreakAlive` in `lib/core/coins/coin_policy.dart`. `StreakWidgetLogic.kt` mirrors that rule.
  - The streak lives while the gap since the last kept day is at most 1 day plus the freezes.
  - Kept today means the gap is 0.
  - Days use the UTC offset of the snapshot. They do not use the time zone of the phone.
  - The shared cases are in `test/fixtures/streak_rule_cases.csv`. Both `test/core/coins/streak_rule_fixture_test.dart` (Dart) and `android/app/src/test/kotlin/com/hash/prism/StreakWidgetLogicTest.kt` (Kotlin) run them.
- Updates: The widget updates when the app writes a new snapshot. It also updates at its midnight alarm, after a restart of the phone, after an app update, and after a change to the clock or the time zone. Each update sets the next alarm again.
  - The midnight alarm is set only when a widget shows a streak that is more than 0. When you sign out, or when the streak lapses, the widget cancels the alarm. It also cancels the alarm when you remove the last Streak widget.
  - `updatePeriodMillis` is 0. The widget has no periodic update.
  - The midnight alarm uses `AlarmManager.setWindow` with `RTC`, not a wakeup alarm. It never wakes a sleeping phone. The widget redraws when the phone next wakes.
  - The window is 1 minute. Android 12 and later can make it 10 minutes. So the ring can empty up to 10 minutes after midnight.
  - A lapsed streak shows 0. The widget follows the Dart rule for all inputs, also for a last kept day after today and for odd freeze values.
  - The update reads only SharedPreferences. It does no network work.
- PendingIntents: The tap and the midnight alarm use explicit components, with `FLAG_IMMUTABLE` and `FLAG_UPDATE_CURRENT`. The receiver is `exported="false"`.

### Analytics

- The event `widget_tapped` has the `kind` `wotd_android` or `streak_android`.
- `DeepLinkDispatcher` records it from the `widget` query value.

## Limits

- Emulator proof (2026-10-29, API 36, Pixel launcher):
  - The widget was added from the widget picker.
  - It loads today's wall. This wall is protected, so the widget shows the preview. `original_url` is empty.
  - Tap the image. The wall detail screen opens.
  - Tap "Set" on a protected wall. The app opens at the wall. There is no public original to set.
  - Day change: seed a fake "yesterday" cache key and image. Then force `APPWIDGET_UPDATE` as root (`adb root`, `am broadcast -n com.hash.prism/.WotdWidgetProvider`). Offline, the widget keeps the cached image. Online, it fetches today's wall.
  - With no cache and offline, the empty state reads "Today's wallpaper appears here when you are online".
- Android and the launcher decide when the widget updates. A launcher can run the update later than 3 hours, mainly when the battery saver is on.
- The widget needs the Firebase resources `project_id` and `google_api_key`. A local build without `google-services.json` does not have them. Then the widget uses the cached URL.
- "Set" changes the home screen wallpaper only. It does not change the lock screen.
- The widget shows a wall that the Firestore rules let anyone read. A wall that is not reviewed does not show.
- If the `walls` read rule is changed to signed-in only, this widget and the iOS widget ([ios-widgets.md](ios-widgets.md)) both stop showing new walls.
- The Streak widget shows the last snapshot the app wrote on this phone. A claim on another device shows after Prism opens on this phone.
- Device proof (Streak widget and colours): not done yet. On 2026-11-11 no Simlock Android device was available. The unit tests and the resource tests cover the rule, the strings and the colour files. The look on a real launcher, in light, dark and Material You, is not checked.

## How to test

Wall of the Day widget:

1. Use an Android phone or emulator. Add the "Wall of the Day" widget to the home screen without you opening Prism first (clear the app data first). Wait a few seconds. Make sure the image appears.
2. Tap the image. Make sure Prism opens the wall detail screen.
3. Tap "Set". Make sure a "Wallpaper set" message shows and the home screen wallpaper changes.
4. Turn on airplane mode and tap "Set". Make sure "Could not set wallpaper" shows and nothing crashes.
5. Resize the widget. Make sure the image fills it and the corners match the launcher.
6. Open the widget picker. Make sure the preview shows.
7. Clear the app data, turn on airplane mode, and add the widget. Make sure the empty state shows.

Streak widget:

1. Sign in to Prism. Open Rewards and note the streak count.
2. Add the "Streak" widget to the home screen. Make sure that the widget count matches the count in Rewards.
3. Tap the widget. Make sure that Rewards opens.
4. Sign out. Make sure that the widget shows "Sign in to track your streak".
5. Switch the phone between light and dark mode. On Android 12 and later, also change the wallpaper. Make sure that the widget colours change.

Automated tests:

- `android/app/src/test/kotlin/com/hash/prism/WotdWidgetLogicTest.kt` checks the REST JSON parsing, the URL builder, the share link, the sample sizes, the timeouts, and the certificate hex format. CI runs it with `:app:testDebugUnitTest` (`make native-android-check`).
- `android/app/src/test/kotlin/com/hash/prism/PrismNativeTest.kt` checks the widget bitmap sample size.
- `test/android/manifest_test.dart` checks the receiver, the 3 hour update period, the preview files and the strings.
- `android/app/src/test/kotlin/com/hash/prism/StreakWidgetLogicTest.kt` runs the shared streak rule cases in `test/fixtures/streak_rule_cases.csv`.
- `test/core/coins/streak_rule_fixture_test.dart` runs the same streak rule cases in Dart.
- `test/core/platform/streak_widget_sync_test.dart` checks the streak snapshot that the app writes.
- `test/android/widget_layout_test.dart` checks the layouts of the Wall of the Day and Streak widgets.
