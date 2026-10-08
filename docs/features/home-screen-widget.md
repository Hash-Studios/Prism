# Home-screen widget

The Wall of the Day widget shows today's Wall of the Day on the Android home screen. A tap opens Prism.

## Where to find it

- Long-press the Android home screen, tap "Widgets", find "Wall of the Day" under Prism, and drag it to the screen.
- The widget has a minimum size of 2 by 2 cells. The user can resize it.
- Code: `android/app/src/main/kotlin/com/hash/prism/WotdWidgetProvider.kt`, `android/app/src/main/res/layout/wotd_widget.xml`, `android/app/src/main/res/xml/wotd_widget_info.xml`.

## Platforms and plans

| Platform | Status |
|---|---|
| Android | Supported. |
| iOS | Not available. |

The widget is free. It has no Pro gate.

## How it works

1. Prism caches the Wall of the Day image URL in the shared preference `flutter.quick_tile.wotd.url`. The Wall of the Day quick tile uses the same value. `QuickTileConfigService.pushWotdUrl` writes it.
2. When the widget updates (`onUpdate`), it reads that URL on a background thread.
3. It downloads the image with `PrismImageTransfer`. It decodes the image with `inSampleSize` so the bitmap has at most 1 million pixels. This keeps the widget under the Android `RemoteViews` size limit.
4. It shows the image with a small "Prism" label. A tap on the widget opens `MainActivity` (a `PendingIntent` with `FLAG_IMMUTABLE`).
5. If there is no URL, the widget shows the Prism logo and the text "Open Prism for today's wallpaper".
6. The receiver is registered with `exported="false"`.

### When the widget updates

- Android updates the widget about every 24 hours (`updatePeriodMillis="86400000"`).
- Each time Prism caches a new Wall of the Day URL, Prism also asks the widget to redraw. `pushWotdUrl` calls `QuickSettingsChannel.refreshWotdWidget` (channel `prism/quick_settings`, method `refreshWotdWidget`). The widget then updates at once.

## Limits

- The Kotlin and the layout were not compiled here and were not run on a device. CI compiles them. How the widget looks on a real launcher is not checked.
- The widget shows the last URL that Prism cached. The user must open Prism once a day for a new image. Without that, the widget can show yesterday's image until the next open.
- If the download fails, the widget keeps what it shows now. It tries again at the next update.
- A launcher can limit how often a widget updates.
- The widget has no second tap target. It does not apply the wallpaper.

## How to test

1. Use an Android phone or emulator. Open Prism once so it caches today's Wall of the Day.
2. Add the "Wall of the Day" widget to the home screen. Make sure it shows today's image and the "Prism" label.
3. Tap the widget. Make sure Prism opens.
4. Resize the widget. Make sure the image still fills it.
5. Clear the app data and add the widget before you open Prism. Make sure it shows the logo and "Open Prism for today's wallpaper". Open Prism, wait a few seconds, and go back to the home screen. Make sure the image appears.
6. Turn on airplane mode, then remove and add the widget. Make sure the logo shows and nothing crashes.

Automated tests:

- `test/android/manifest_test.dart` checks the receiver and the update period.
- `android/app/src/test/kotlin/com/hash/prism/PrismNativeTest.kt` checks the bitmap sample size.
