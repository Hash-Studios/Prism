# iOS Shortcuts

On iPhone, Shortcuts can set a wallpaper on a schedule or trigger. Add Prism's "Get Prism Wallpaper" action and Apple's "Set Wallpaper" action to an automation. Prepare the selected source in Prism before running it.

## What it does

- The action "Get Prism Wallpaper" returns one full-size image. It does not open the app.
- You pick one of four sources:
  - Wall of the Day. Download today's original in Prism first. When the daily pick changes, download the new original before running this source. Downloads use Prism's existing access and payment rules.
  - Random favourite. A random favourite that Shortcuts can use. Heart wallpapers in Prism first. Some protected wallpapers may not be available.
  - Rotation folder. Shuffles the folder that you pick in Prism.
  - Folder. Shuffles a folder that you pick in the action. The Folder field shows only for this source.
- Random favourite, Rotation folder and Folder use a shuffle. Each wall shows once before any wall repeats.
- Apple's "Set Wallpaper" action takes the image and sets it.
- The action also shows as App Shortcuts in Siri and Spotlight. Say "Get a wallpaper from Prism" or "Shuffle my Prism wallpaper".

## Where to find it

- Settings, section PERSONALISE, row "Change automatically" (iOS 16 or later only). It opens the guide "Change automatically". Code: `lib/features/session/views/pages/settings_screen.dart`.
- Route `IosShortcutsGuideRoute`, path `/ios-shortcuts`. Screen: `lib/features/ios_shortcuts/views/pages/ios_shortcuts_guide_screen.dart`.
- Folder menu, item "Rotate this folder daily" (iOS 16 or later only). It sets that folder as the rotation folder, then opens the guide. Code: `lib/features/folders/views/pages/folder_screen.dart`.
- Auto-rotate screen. On iPhone it shows a card that opens the guide. Code: `lib/features/auto_rotate/views/pages/auto_rotate_screen.dart`.
- The row reads the iOS version once through `device_info_plus` (`lib/features/ios_shortcuts/data/ios_shortcuts_support.dart`). It stays hidden until the version is known. It does not show on iOS 15 or when the version cannot be read.
- On Android this row does not show. Android uses [auto-rotate.md](auto-rotate.md).

## How to use it

1. Open Prism. Go to Settings, then tap "Change automatically".
2. Rotation folder card, above the steps: tap "Pick a folder", then choose a folder. To change it later, tap "Change". To clear it, tap "Stop".
3. Step 1, add the shortcut: if the iCloud button shows, tap "Add the shortcut". Then add the shortcut in Shortcuts.
4. If the iCloud button does not show, tap "Open Shortcuts". Tap + to make a new shortcut.
5. Add the action "Get Prism Wallpaper". Set Source to Rotation folder.
6. Add the action "Set Wallpaper Photo". Tap its arrow, then turn off Show Preview.
7. Name the shortcut "Prism Wallpaper".
8. Step 2, run it every day: in Shortcuts, tap Automation, then tap +.
9. If "Create Personal Automation" shows, tap it.
10. Tap Time of Day. Pick a time, then choose Daily.
11. Choose Run Immediately, then tap Next.
12. Pick "Prism Wallpaper" to run.
13. If there is no Automation tab, open "Prism Wallpaper", tap Edit, then tap Automation.
14. If "Ask Before Running" appears, turn it off for automatic runs.
15. Step 3, test it now: in the guide, tap "Run the shortcut". Check that the wallpaper changes.

If Shortcuts does not open, Prism shows "Could not open Shortcuts. Open the app yourself."

## How it works

| Path | Role |
|---|---|
| `lib/features/ios_shortcuts/views/pages/ios_shortcuts_guide_screen.dart` | The guide: the rotation folder card, three steps, the source list, and the "Open Shortcuts" and "Run the shortcut" buttons (`shortcuts://`). |
| `lib/features/ios_shortcuts/views/widgets/shortcuts_favourites_listener.dart` | On iOS, writes the favourites list when favourites or the session change. Wraps the app in `lib/main.dart`. |
| `lib/features/ios_shortcuts/views/widgets/shortcuts_folders_listener.dart` | On iOS, writes the folders snapshot on app open and on folder changes. Wraps the app in `lib/main.dart`. |
| `lib/features/ios_shortcuts/data/shortcuts_favourites_store.dart` | Builds the favourites JSON and writes it to shared preferences. |
| `lib/features/ios_shortcuts/data/shortcuts_folders_store.dart` | Builds the folders JSON, reuses items for unchanged folders, and stores the rotation folder. |
| `lib/features/ios_shortcuts/data/ios_shortcuts_support.dart` | Reads the iOS major version once. Settings shows the row only on iOS 16 or later. Holds the Remote Config key and the shortcut name. |
| `lib/core/persistence/persistence_keys.dart` | Keys `shortcutsFavourites` (`shortcuts.favourites`), `shortcutsFolders` (`shortcuts.folders`), `shortcutsRotationFolder` (`shortcuts.rotation_folder`) and `shortcutsShuffleBags` (`shortcuts.shuffle_bags`). |
| `lib/auth/google_auth.dart` | Clears the favourites and folders on sign-out. |
| `lib/core/account/local_account_data_cleaner.dart` | Clears the favourites and folders on account deletion. |
| `ios/Runner/Shortcuts/GetPrismWallpaperIntent.swift` | The App Intent in Swift. It has the four sources and the error messages. |
| `ios/Runner/Shortcuts/PrismShortcuts.swift` | The App Shortcut phrases. Their translations are in `ios/Runner/<locale>.lproj/AppShortcuts.strings`. |
| `ios/Runner/Shortcuts/Core/PrismShortcutFolders.swift` | Parses the folders snapshot, resolves the folder, and runs the shuffle bags. |
| `ios/Runner/Shortcuts/Core/PrismShortcutFavourites.swift` | Parses the favourites list. |

Favourites data path:

```text
FavouriteWallsBloc / SessionBloc -> ShortcutsFavouritesListener
  -> ShortcutsFavouritesStore.save -> shared_preferences key shortcuts.favourites
  -> UserDefaults key flutter.shortcuts.favourites -> GetPrismWallpaperIntent
```

Folders data path:

```text
FoldersBloc / SessionBloc -> ShortcutsFoldersListener
  -> ShortcutsFoldersStore.sync -> shared_preferences key shortcuts.folders
  -> UserDefaults key flutter.shortcuts.folders -> PrismShortcutFolders.parse
  -> GetPrismWallpaperIntent (Rotation folder or Folder source)
```

### Stored value

- Key: `shortcuts.favourites`. Native key: `flutter.shortcuts.favourites` in `UserDefaults.standard`.
- Value: a JSON string. An array of `{"id": "<wall id>", "url": "<full image url>"}`.
- Newest first. At most 200 items (`ShortcutsFavouritesStore.maxItems`).
- A wall without an id or without an `https` URL is left out. A repeated id is kept once.
- The value is `[]` when the user signs out, switches account, or has no favourites.
- Sign-out clears it in `GoogleAuth.signOutGoogle` (`_clearPersonalization`). This is awaited, so it does not depend on the listener. The store runs all writes one after another. A save that was called before a clear is dropped, so a slow save cannot land after a clear. The listener also clears the list when the session resolves as a guest, in case the app restarted before it saw the sign-out. It does not clear while the session is still loading.
- The listener writes only after the favourites finish loading for the signed-in user. It does not change favourites.

### Folders snapshot

- Key: `shortcuts.folders`. Native key: `flutter.shortcuts.folders` in `UserDefaults.standard`.
- Value: a JSON string: `{"ownerId": "<user id>", "folders": [{"id", "name", "itemCount", "updatedAt", "items": [{"id", "url"}]}]}`. `updatedAt` is a time in milliseconds since the epoch.
- At most 50 folders (`ShortcutsFoldersStore.maxFolders`). At most 200 items for each folder (`ShortcutsFoldersStore.maxItems`), newest first.
- The rotation folder always makes the cut, even when the account has more than 50 folders.
- A wall without an id or without an `https` URL is left out. A repeated id is kept once.
- A folder whose update time and item count did not change keeps its items. The app reads only changed folders.
- When a folder read fails, the folder keeps its old items. Its update time is set to epoch 0, so the next sync reads it again.
- The snapshot is written on app open and when folders load. A folder edit writes it 2 seconds after the last edit.
- The rotation folder is stored at `shortcuts.rotation_folder` (native `flutter.shortcuts.rotation_folder`). Prism removes it when the folder is gone from the account.
- The offline copy paths for the folder items are grouped as `folders` in `NativeAssetPathsStore`.
- The snapshot is cleared on sign-out (`GoogleAuth`), on account deletion (step "iOS folders mirror" in `LocalAccountDataCleaner`), on a guest session, and on an account switch. Clearing writes `{"folders":[]}`. It also removes the rotation folder and the shuffle bags. A sync that started before the clear is dropped.

### Shuffle bag

- A shuffle bag keeps the walls that a pass has shown. It is stored at `shortcuts.shuffle_bags` (native `flutter.shortcuts.shuffle_bags`).
- Each pool has its own bag. The pools are `favourites` and `folder:<id>`.
- Each wall shows once before any wall repeats. Then a new pass starts.
- A wall that you add joins the current pass. A wall that you remove leaves it.
- A new pass does not start with the wall that ended the last pass.
- The pass moves on only after the image loads. A failed run does not use up a wall.

### Remote Config key

- Key: `ios_shortcut_link` (Firebase Remote Config). It holds the iCloud link of the shared shortcut.
- Only an `https` link counts. An empty or invalid value hides the iCloud button. The guide then shows the manual steps and the "Open Shortcuts" button.

## Owner setup: shared shortcut

Do these steps after a TestFlight build has this feature.

1. Open the TestFlight build on an iPhone with iOS 16 or later.
2. In Shortcuts, make a shortcut. Add "Get Prism Wallpaper" with Source set to Rotation folder.
3. Add "Set Wallpaper Photo" with Show Preview turned off.
4. Name the shortcut exactly "Prism Wallpaper".
5. Share the shortcut as an iCloud link. Copy the link.
6. In Firebase Remote Config, set `ios_shortcut_link` to the link. Publish the change.
7. An empty value hides the iCloud button.

## Limits

- iOS 16 or later. The App Intents API does not exist on iOS 15.
- Prism cannot set the wallpaper on iOS. Apple's "Set Wallpaper" action does that. The user must add it.
- Run-confirmation controls depend on the Shortcuts version. If "Ask Before Running" appears, turn it off for automatic runs.
- iOS decides if and when an automation runs.
- Wall of the Day requires today's downloaded original. A previous day's download cannot supply the new daily pick.
- "Random favourite" uses the list that Prism last wrote. Open Prism once after you change favourites on another device.
- The favourites list holds the 200 newest favourites.
- "Rotation folder" and "Folder" use the folders snapshot that Prism last wrote. Open Prism once after you change folders on another device.
- The folders snapshot holds at most 50 folders and 200 walls for each folder.
- The action fails for an image larger than 40 MiB. Prism saves the download to a temporary file first, so the whole image is not held in memory while it downloads.
- With no favourites, "Random favourite" fails with a message: "No favourites yet. Open Prism and tap the heart on a wallpaper."
- With no rotation folder, "Rotation folder" fails with a message: "No rotation folder yet. Open Prism, open a folder, and tap Rotate this folder daily."
- With an empty folder, the action fails with a message: "This folder is empty. Open Prism and save wallpapers to it."
- When Prism cannot find the folder, the action fails with a message: "Prism cannot find this folder. Open Prism to refresh your folders, then pick the folder again."
- iOS widgets are a separate feature. See [ios-widgets.md](ios-widgets.md).
- The iOS 27 simulator flow was checked on 2026-10-25. The action was discoverable and returned the expected missing-original error. Successful original output, an enabled trigger, and wallpaper application were not verified. The sole test shortcut was deleted afterward.

## How to test

1. Use an iPhone with iOS 16 or later. Sign in. Download today's Wall of the Day original through Prism's normal flow. Heart at least 3 wallpapers available to Shortcuts. Pick a rotation folder with at least 3 walls.
2. Open Settings. Make sure PERSONALISE shows only "Change automatically". On an iPhone with iOS 15, make sure the row does not show.
3. Tap it. Make sure the rotation folder card, the three steps and the four sources show.
4. Tap "Open Shortcuts". Make sure the Shortcuts app opens.
5. Make the "Prism Wallpaper" shortcut with "Get Prism Wallpaper" (Rotation folder) and "Set Wallpaper Photo". Make the daily automation. Run it. Make sure the wallpaper changes.
6. Change the source to "Random favourite". Run it three times. Make sure the wallpaper is one of your favourites and does not repeat before every favourite shows.
7. Change the source to "Folder". Pick a folder in the action. Run it. Make sure the wallpaper comes from that folder.
8. Tap "Stop" on the rotation folder card. Run the "Rotation folder" source. Make sure it fails with the "No rotation folder yet" message.
9. Sign out of Prism. Run the "Random favourite" action. Make sure it fails with the "No favourites yet" message.
10. On Android, open Settings. Make sure "Change automatically" does not show.

Automated tests:

- `test/features/ios_shortcuts/shortcuts_favourites_store_test.dart`
- `test/features/ios_shortcuts/shortcuts_favourites_listener_test.dart`
- `test/features/ios_shortcuts/shortcuts_folders_store_test.dart`
- `test/features/ios_shortcuts/shortcuts_folders_listener_test.dart`
- `test/features/ios_shortcuts/ios_shortcuts_guide_screen_test.dart`
- `test/features/session/settings_screen_test.dart`
- `test/features/folders/views/folder_screen_test.dart`
- `test/auth/sign_out_test.dart`
- `test/core/account/local_account_data_cleaner_test.dart`
- `ios/RunnerTests/PrismShortcutFoldersTests.swift`
- `ios/RunnerTests/PrismShortcutsTests.swift`

Commands:

```sh
fvm flutter test --no-pub test/features/ios_shortcuts test/features/session/settings_screen_test.dart test/features/folders/views/folder_screen_test.dart test/auth/sign_out_test.dart test/core/account/local_account_data_cleaner_test.dart
cd ios && swift test
```
