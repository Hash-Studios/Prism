# iOS Shortcuts

On iPhone, Shortcuts can set a wallpaper on a schedule or trigger. Add Prism's "Get Prism Wallpaper" action and Apple's wallpaper action to an automation. Prepare the selected source in Prism before running it.

## What it does

- The action "Get Prism Wallpaper" returns one full-size image. It does not open the app.
- You pick the source:
  - Wall of the Day. Download today's original in Prism first. When the daily pick changes, download the new original before running this source. Downloads use Prism's existing access and payment rules.
  - Random favourite. A random favourite available to Shortcuts. Heart wallpapers in Prism first. Some protected wallpapers may not be available. It avoids the last pick when another favourite is available.
- Apple's "Set Wallpaper" action takes the image and sets it.
- The action also shows as an App Shortcut in Siri and Spotlight. Say "Get a wallpaper from Prism".

## Where to find it

- Settings, section PERSONALISE, row "Change automatically" (iOS 16 or later only). It opens the guide "Change your wallpaper automatically". Code: `lib/features/session/views/pages/settings_screen.dart`.
- Route `IosShortcutsGuideRoute`, path `/ios-shortcuts`. Screen: `lib/features/ios_shortcuts/views/pages/ios_shortcuts_guide_screen.dart`.
- The row reads the iOS version once through `device_info_plus` (`lib/features/ios_shortcuts/data/ios_shortcuts_support.dart`). It stays hidden until the version is known. It does not show on iOS 15 or when the version cannot be read.
- On Android this row does not show. Android uses [auto-rotate.md](auto-rotate.md).

## How to use it

1. Open Prism. Settings, then "Change automatically".
2. Tap "Open Shortcuts".
3. If Shortcuts has an Automation tab, tap it, then New Automation. Otherwise, tap Add (+), then Edit if shown.
4. In the shortcut editor, open Automation if needed. Choose and configure a trigger, such as Time of Day, opening an app, or connecting a charger.
5. Add the action "Get Prism Wallpaper". Pick a source.
6. Add the action "Set Wallpaper".
7. Review the run options shown and save the shortcut or automation. If "Ask Before Running" appears, turn it off for automatic runs.

If Shortcuts does not open, Prism shows "Could not open Shortcuts. Open the app yourself."

## How it works

| Path | Role |
|---|---|
| `lib/features/ios_shortcuts/views/pages/ios_shortcuts_guide_screen.dart` | The guide: four steps, the two sources, the "Open Shortcuts" button (`shortcuts://`). |
| `lib/features/ios_shortcuts/views/widgets/shortcuts_favourites_listener.dart` | On iOS, writes the favourites list when favourites or the session change. Wraps the app in `lib/main.dart`. |
| `lib/features/ios_shortcuts/data/shortcuts_favourites_store.dart` | Builds the JSON and writes it to shared preferences. |
| `lib/features/ios_shortcuts/data/ios_shortcuts_support.dart` | Reads the iOS major version once. Settings shows the row only on iOS 16 or later. |
| `lib/core/persistence/persistence_keys.dart` | Key `shortcutsFavourites` (`shortcuts.favourites`). |
| `ios/Runner/Shortcuts/` | The App Intent in Swift. It reads the list and Wall of the Day. |

Favourites data path:

```text
FavouriteWallsBloc / SessionBloc -> ShortcutsFavouritesListener
  -> ShortcutsFavouritesStore.save -> shared_preferences key shortcuts.favourites
  -> UserDefaults key flutter.shortcuts.favourites -> GetPrismWallpaperIntent
```

### Stored value

- Key: `shortcuts.favourites`. Native key: `flutter.shortcuts.favourites` in `UserDefaults.standard`.
- Value: a JSON string. An array of `{"id": "<wall id>", "url": "<full image url>"}`.
- Newest first. At most 200 items (`ShortcutsFavouritesStore.maxItems`).
- A wall without an id or without an `https` URL is left out. A repeated id is kept once.
- The value is `[]` when the user signs out, switches account, or has no favourites.
- Sign-out clears it in `GoogleAuth.signOutGoogle` (`_clearPersonalization`). This is awaited, so it does not depend on the listener. The store runs all writes one after another. A save that was called before a clear is dropped, so a slow save cannot land after a clear. The listener also clears the list when the session resolves as a guest, in case the app restarted before it saw the sign-out. It does not clear while the session is still loading.
- The listener writes only after the favourites finish loading for the signed-in user. It does not change favourites.

### Wall of the Day

The Swift code reads the current Wall of the Day identity from the Firestore REST API using `API_KEY` and `PROJECT_ID` from `GoogleService-Info.plist`. This metadata lookup does not acquire the original image. The action requires a retained local original for the current daily pick. Open Prism and download that original first. When the pick changes, prepare the new original.

The retained metadata must match the current UTC day and wallpaper identity. During a network outage, the action can use a retained original for today. It rejects yesterday's original, a different wallpaper, or an invalid pointer. If the required original is unavailable, it asks the user to open Prism and download today's original. Shortcuts does not bypass original access or download charges.

## Limits

- iOS 16 or later. The App Intents API does not exist on iOS 15.
- Prism cannot set the wallpaper on iOS. Apple's "Set Wallpaper" action does that. The user must add it.
- Run-confirmation controls depend on the Shortcuts version. If "Ask Before Running" appears, turn it off for automatic runs.
- iOS decides if and when an automation runs.
- Wall of the Day requires today's downloaded original. A previous day's download cannot supply the new daily pick.
- "Random favourite" uses the list that Prism last wrote. Open Prism once after you change favourites on another device.
- The list holds the 200 newest favourites.
- The action fails for an image larger than 40 MiB. Prism saves the download to a temporary file first, so the whole image is not held in memory while it downloads.
- With no favourites, "Random favourite" fails with a message: "No favourites yet. Open Prism and tap the heart on a wallpaper."
- Prism does not have an iOS widget. That needs a WidgetKit extension with its own App ID and provisioning profile (`.github/workflows/testflight.yml`). It is not part of this feature.
- The iOS 27 simulator flow was checked on 2026-10-25. The action was discoverable and returned the expected missing-original error. Successful original output, an enabled trigger, and wallpaper application were not verified. The sole test shortcut was deleted afterward.

## How to test

1. Use an iPhone with iOS 16 or later. Sign in. Download today's Wall of the Day original through Prism's normal flow, and heart at least 3 wallpapers available to Shortcuts.
2. Open Settings. Make sure PERSONALISE shows only "Change automatically". On an iPhone with iOS 15, make sure the row does not show.
3. Tap it. Make sure the four steps and both sources show.
4. Tap "Open Shortcuts". Make sure the Shortcuts app opens.
5. Make an automation with "Get Prism Wallpaper" (Wall of the Day) and "Set Wallpaper". Run it. Make sure the wallpaper changes.
6. Change the source to "Random favourite". Run it three times. Make sure the wallpaper is one of your favourites and does not repeat twice in a row.
7. Sign out of Prism. Run the "Random favourite" action. Make sure it fails with the "No favourites yet" message.
8. On Android, open Settings. Make sure "Change automatically" does not show.

Automated tests:

- `test/features/ios_shortcuts/shortcuts_favourites_store_test.dart`
- `test/features/ios_shortcuts/shortcuts_favourites_listener_test.dart`
- `test/features/ios_shortcuts/ios_shortcuts_guide_screen_test.dart`
- `test/features/session/settings_screen_test.dart`
- `test/auth/sign_out_test.dart`

Command:

```sh
fvm flutter test --no-pub test/features/ios_shortcuts test/features/session/settings_screen_test.dart test/auth/sign_out_test.dart
```
