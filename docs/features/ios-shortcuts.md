# iOS Shortcuts

On iPhone, Prism can change your wallpaper on its own. Prism gives the Shortcuts app an action called "Get Prism Wallpaper". You add it to a Shortcuts automation. The automation then sets a new wallpaper on a schedule or a trigger. You do not open Prism.

## What it does

- The action "Get Prism Wallpaper" returns one full-size image. It does not open the app.
- You pick the source:
  - Wall of the Day. Today's pick from Prism. The action reads it from Prism's servers, so it is current even if you did not open the app today.
  - Random favourite. A random wallpaper from your favourites. It avoids the one it gave last, when you have two or more.
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
3. In Shortcuts, tap Automation, then New Automation.
4. Pick when it runs: Time of Day, When I open an app, or Charger.
5. Add the action "Get Prism Wallpaper". Pick a source.
6. Add the action "Set Wallpaper".
7. Turn off "Ask Before Running". Tap Done.

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
- Sign-out clears it in `GoogleAuth.signOutGoogle` (`_clearPersonalization`). This is awaited, so it does not depend on the listener. The listener runs its writes one after another, so a slow save cannot land after a clear. It also clears the list when it starts with a guest session, in case the app restarted before it saw the sign-out.
- The listener writes only after the favourites finish loading for the signed-in user. It does not change favourites.

### Wall of the Day

The Swift code reads Wall of the Day itself from the Firestore REST API. It does not need the user to sign in. It uses `API_KEY` and `PROJECT_ID` from `GoogleService-Info.plist`.

## Limits

- iOS 16 or later. The App Intents API does not exist on iOS 15.
- Prism cannot set the wallpaper on iOS. Apple's "Set Wallpaper" action does that. The user must add it.
- The user must turn off "Ask Before Running", or iOS asks each time.
- iOS decides if and when an automation runs. Time of Day is exact. Other triggers can be late.
- "Random favourite" uses the list that Prism last wrote. Open Prism once after you change favourites on another device.
- The list holds the 200 newest favourites.
- With no favourites, "Random favourite" fails with a message: "No favourites yet. Open Prism and tap the heart on a wallpaper."
- Prism does not have an iOS widget. That needs a WidgetKit extension with its own App ID and provisioning profile (`.github/workflows/testflight.yml`). It is not part of this feature.
- The Swift code is built in CI. Nobody ran this feature on a device for this page.

## How to test

1. Use an iPhone with iOS 16 or later. Sign in. Heart at least 3 wallpapers.
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
