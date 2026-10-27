# iOS widgets

Prism has Home Screen and Lock Screen widgets on iPhone and iPad. They show the Wall of the Day and the user's streak.

## What it does

| Widget | Sizes | Shows | Tap opens |
|---|---|---|---|
| Wall of the Day | Small, Medium, Large (Home Screen) | Today's wall, full bleed, with a small Prism mark. Medium and Large add the title, or "by" and the creator, in one line. | That wall |
| Wall of the Day | Rectangular (Lock Screen) | The mark, "New wall today", and the title or creator. | That wall |
| Streak | Circular (Lock Screen) | The streak count in a ring. The ring is full when today is kept. | Rewards |
| Streak | Inline (Lock Screen) | "12-day streak". | Rewards |

- Signed out, the streak widgets show "Open Prism".
- The tone is calm. No warning icons and no countdown.
- In tinted and clear Home Screen modes, the photo is desaturated (`widgetAccentedRenderingMode(.desaturated)`). The text and the mark are in the accent group.

## Where to find it

- Settings, section PERSONALISE, row "Widgets". It opens the guide sheet.
- Wall of the Day screen ("Past picks"): a card "Wall of the Day on your Home Screen". It shows one time. Close it, or tap "Show me how", and it does not show again (key `ios_widgets.wotd_card_dismissed`).
- Both entry points show only on iOS 17 or later. The extension needs iOS 16.2, and the version check reads only the major number. They do not show on Android. Android has its own widget, see [home-widget.md](home-widget.md).
- The guide has two tabs, Home Screen and Lock Screen. Each tab has a phone picture and 3 steps.

## How it works

| Path | Role |
|---|---|
| `ios/PrismLiveActivities/PrismWidgets.swift` | The two widgets, their timeline providers, the Wall of the Day fetch and cache. |
| `ios/PrismLiveActivities/PrismLiveActivitiesBundle.swift` | Adds the widgets to the existing extension. There is no new target. |
| `ios/PrismLiveActivities/Localizable.xcstrings` | Widget text in en, de, es, hi, id, pt-BR. |
| `ios/Runner/Shortcuts/Core/PrismWidgetCore.swift` | Shared logic: timeline schedule, "kept today" rule, REST parsing, links, the streak store. Plain Foundation, so tests compile it. |
| `ios/Runner/PrismWidgetHostApiImpl.swift` | Writes the streak snapshot and reloads timelines. |
| `pigeons/prism_widget_api.dart` | Pigeon API `PrismWidgetHostApi`. Run `make pigeon-gen` after a change. |
| `lib/core/platform/ios_widget_channel.dart` | Dart calls. No-op off iOS. Never throws. |
| `lib/core/platform/streak_widget_sync.dart` | Writes the streak snapshot on app open and on each streak change. |
| `lib/features/ios_widgets/` | Guide sheet and the Wall of the Day card. |

### Wall of the Day data

```text
widget timeline -> GoogleService-Info.plist of Prism.app (API_KEY, PROJECT_ID)
  -> Firestore REST wall_of_the_day/current (header X-Ios-Bundle-Identifier)
  -> Firestore REST walls/{wallId} -> wallpaper_thumb
  -> App Group cache Library/Caches/WallOfTheDayWidget (wall.json, image)
  -> decode at the widget's pixel size -> view
```

- The widget downloads `wallpaper_thumb` only. It never downloads the original. A wall without a thumbnail keeps the cached wall.
- The download stops at 15 MiB. The image is decoded with ImageIO at the widget's pixel size, at most 718,080 pixels (`PrismWotdImageBudget`), and cropped to fill. This keeps the extension under its memory limit and under WidgetKit's image size limit.
- Two sizes that refresh at the same time share one download. The cache writes the image first, then a manifest that names it, so the wall and its image always match.
- When the fetch fails, the widget shows the cached wall.
- Refresh: the server picks a new wall at 03:30 UTC (`functions/src/wallOfTheDay.ts`). The widget reloads at 03:40 UTC. If the fetch fails, or the server has not picked yet, it tries again after 30 minutes, but never later than 03:40 UTC.
- The app also reloads the widget each time it becomes active (`AppDelegate`), and when a Wall of the Day push arrives in the foreground (`lib/notifications/local_notification.dart`).
- The tap link is the share link the app already parses, plus `widget=<kind>`: `prism://share?id=<wall id field>&source=prism&thumb=<thumb>&widget=wotd_medium`. Streak taps open `prism://streak?widget=streak_circular`.

### Streak data

- The streak is owner-only data. The widget does not read Firestore for it.
- The app writes a snapshot to App Group `UserDefaults` (`group.com.hash.prism`, key `widget.streak`): count, last kept day (`yyyy-MM-dd`), UTC offset in minutes, freezes.
- The widget works out the display from the snapshot and the date. It uses the same rule as `isStreakAlive` in `lib/core/coins/coin_policy.dart`. The streak lives while the gap since the last kept day is at most 1 day plus the freezes. Kept today means the last kept day is today in the snapshot's time zone.
- The timeline has an entry now and at each of the next 4 local midnights. So the ring empties at midnight, and a lapsed streak goes to 0, without the app.
- The snapshot is cleared on sign-out (`GoogleAuth._clearPersonalization`, and the sync when the streak resets) and on account deletion (`LocalAccountDataCleaner`).

### Analytics

- `widget_tapped` with `kind`: `wotd_small`, `wotd_medium`, `wotd_large`, `wotd_lock`, `streak_circular`, `streak_inline`. `DeepLinkDispatcher.openUri` records it from the `widget` query value.
- `widget_guide_opened` with `source`: `settings`, `wall_of_the_day`.

## Limits

- The widgets read `wall_of_the_day` and `walls` without a signed-in user. `firestore.rules` allows this today (`wall_of_the_day` is public, and reviewed `walls` are public). **If the `walls` read rule is changed to signed-in only, the iOS widget and the Android widget both stop showing new walls.** Change both widgets before you tighten that rule.
- The widget needs `GoogleService-Info.plist` in the app bundle. Without it the widget shows the cache only.
- iOS decides when a timeline reload runs. The 03:40 UTC reload can come late.
- The streak widget shows the last snapshot the app wrote. A claim on another device shows after Prism opens on this device.
- Checked on the iOS 27 simulator on 2026-10-27: all sizes, tinted mode, Lock Screen widgets, taps, and the guide. Not checked on a real device.

## How to test

1. Run Prism on an iPhone with iOS 17 or later. Sign in.
2. Long-press the Home Screen, tap Edit, then Add Widget. Add Prism, Wall of the Day, in all 3 sizes. Make sure each shows today's wall.
3. Tap a widget. Make sure the app opens that wall.
4. Customize the Lock Screen. Add "Wall of the Day" (rectangular) and "Streak" (circular and inline). Make sure the count matches Rewards.
5. Sign out. Make sure the streak widgets show "Open Prism".
6. Settings, then Widgets. Make sure the guide shows both tabs.

Automated tests:

```sh
cd ios && swift test --filter PrismWidgetCoreTests
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=<simulator>' -parallel-testing-enabled NO -only-testing:RunnerTests/PrismWidgetCoreTests
fvm flutter test --no-pub test/core/platform/ios_widget_channel_test.dart test/core/platform/streak_widget_sync_test.dart \
  test/features/ios_widgets test/core/router/deep_link_dispatcher_test.dart test/auth/sign_out_test.dart
```
