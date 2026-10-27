# Home widget (Android)

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

- The tap opens `MainActivity` with the link `prism://share?id=<wallId>&source=prism&url=<full image URL>`. `DeepLinkParser` turns it into the wall detail screen. If the widget has only the cached URL and no wall id, the tap opens the app home.
- "Set" sends a broadcast to `WotdWidgetProvider` with the action `com.hash.prism.action.WOTD_SET_WALLPAPER`. The `PendingIntent` has an explicit component and `FLAG_IMMUTABLE`. The receiver is not exported, so only the widget can send this broadcast. The broadcast carries the URL of the wall that the widget shows, as an extra that the widget put in the `PendingIntent` when it drew the wall. So "Set" sets the image on screen even after the daily wall changes, and even when the widget could not save its cache. Only when the extra is missing does "Set" use the URL the widget saved, then fetch the current wall, and then use the URL the app stored. The download uses the same deadline-bounded connection as the update. The whole "Set" work (fetch, download, decode) has a budget of 40 seconds, under the limit for a background broadcast. The widget checks that the file is an image, decodes it to the screen size, and calls `WallpaperManager.setBitmap` with `FLAG_SYSTEM`. This runs off the main thread. A second tap is ignored while the first one runs.
- The receiver stays `exported="false"`.
- The layouts use only classes that `RemoteViews` can inflate (`FrameLayout`, `LinearLayout`, `ImageView`, `TextView`). The scrim is an `ImageView` with a gradient drawable. A plain `View` makes the launcher show "Can't load widget". `test/android/widget_layout_test.dart` fails on any other class.

## Limits

- The Kotlin and the layouts were not compiled here and were not run on a device. CI compiles them and runs the JVM unit tests. How the widget looks on a real launcher is not checked.
- Android and the launcher decide when the widget updates. A launcher can run the update later than 3 hours, mainly when the battery saver is on.
- The widget needs the Firebase resources `project_id` and `google_api_key`. A local build without `google-services.json` does not have them. Then the widget uses the cached URL.
- "Set" changes the home screen wallpaper only. It does not change the lock screen.
- The widget shows a wall that the Firestore rules let anyone read. A wall that is not reviewed does not show.
- If the `walls` read rule is changed to signed-in only, this widget and the iOS widget ([ios-widgets.md](ios-widgets.md)) both stop showing new walls.

## How to test

1. Use an Android phone or emulator. Add the "Wall of the Day" widget to the home screen without you opening Prism first (clear the app data first). Wait a few seconds. Make sure the image appears.
2. Tap the image. Make sure Prism opens the wall detail screen.
3. Tap "Set". Make sure a "Wallpaper set" message shows and the home screen wallpaper changes.
4. Turn on airplane mode and tap "Set". Make sure "Could not set wallpaper" shows and nothing crashes.
5. Resize the widget. Make sure the image fills it and the corners match the launcher.
6. Open the widget picker. Make sure the preview shows.
7. Clear the app data, turn on airplane mode, and add the widget. Make sure the empty state shows.

Automated tests:

- `android/app/src/test/kotlin/com/hash/prism/WotdWidgetLogicTest.kt` checks the REST JSON parsing, the URL builder, the share link, the sample sizes, the timeouts, and the certificate hex format. CI runs it with `:app:testDebugUnitTest` (`make native-android-check`).
- `android/app/src/test/kotlin/com/hash/prism/PrismNativeTest.kt` checks the widget bitmap sample size.
- `test/android/manifest_test.dart` checks the receiver, the 3 hour update period, the preview files and the strings.
