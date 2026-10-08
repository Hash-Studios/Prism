# Quick tiles

Quick tiles are Android Quick Settings tiles. They set a wallpaper with one tap: a random wallpaper from a category, today's Wall of the Day, or a random favourite.

## Where to find it

- Settings, section PERSONALISE, row "Quick tiles" (route `QuickTileSettingsRoute`, screen title "Quick Tile Settings"). Code: `lib/features/session/views/pages/settings_screen.dart`.
- On Android 13 and newer, each tile section has an "Add to Quick Settings" button. The system then asks the user to confirm.
- On older Android versions, the user adds the tiles by hand from the notification shade. The screen explains how: pull the shade down twice, tap the edit icon, drag the Prism tiles to the active tiles.

## Platforms

| Platform | Status |
|---|---|
| Android | Supported. The tiles are Kotlin `TileService` classes. |
| iOS | Not available. The Settings row shows on Android only. |

## Free and Pro

The code has no Pro gate for quick tiles. The Settings row and the three tiles work for free users.

## How it works

| Path | Role |
|---|---|
| `lib/features/quick_tiles/views/quick_tile_settings_screen.dart` | Settings screen. Saves on every change. |
| `lib/features/quick_tiles/data/quick_tile_defaults.dart` | Default settings and the Wallhaven category mirror. |
| `lib/core/platform/quick_tile_config_service.dart` | Writes the tile settings to shared preferences. |
| `lib/features/favourite_walls/views/widgets/favourite_quick_tile_listener.dart` | Keeps the favourites list for the tile up to date. |
| `android/app/src/main/kotlin/com/hash/prism/WallpaperTileService.kt` | Base class. Tile state and apply flow. |
| `android/app/src/main/kotlin/com/hash/prism/MyTileService.kt` | Shuffle Wallpaper tile. |
| `android/app/src/main/kotlin/com/hash/prism/WotdTileService.kt` | Wall of the Day tile. |
| `android/app/src/main/kotlin/com/hash/prism/FavsTileService.kt` | Random Favourite tile. |

Data path:

```text
Flutter settings screen -> QuickTileConfigService -> shared preferences (flutter.quick_tile.*)
  -> Kotlin TileService reads the preferences when the user taps the tile
```

### Settings auto-save and defaults

- The old Save button is gone. Each change (category or "Apply to") saves at once.
- When the screen opens, `QuickTileDefaults.seedMissing` saves a default for each tile that has no settings. The tiles then work before the user changes anything.

| Tile | Default |
|---|---|
| Shuffle Wallpaper | First category in `categoryDefinitions` ("AI Art", source Pexels), apply to Both |
| Wall of the Day | Apply to Both |
| Random Favourite | Apply to Both |

- A saved setting is never replaced by a default.
- A save error shows the toast "Failed to save settings".

### Shuffle tile

- It picks a random wallpaper from the chosen category.
- It honours the Wallhaven category setting `WHcategories`. Prism copies the value to the raw preference `quick_tile.wallhaven.categories`. This happens when the tile screen opens, on each save, and when the user changes the content filter in Settings on Android.
- The tile reads the copy. A value of 110 or more gives `categories=110`. Any other value gives `categories=100`.
- Wallhaven query also sends `purity=100`, `ratios=portrait`, and `sorting=random`.
- Pexels query sends `orientation=portrait` and a random `page` from 1 to 5.
- For Pexels, the tile now uses the `large2x` image when it exists. It falls back to `original`. This change was not in the original list of fixes.

### Add to Quick Settings

- The button shows only on Android 13 (API 33) and newer. Prism asks the native side for the SDK version (`prism/quick_settings`, method `sdkInt`). On iOS and older Android, the button is hidden.
- A tap calls `StatusBarManager.requestAddTileService`. The system shows its own confirm dialog. Prism does not add the tile without the user.
- Prism shows a snackbar for each result:

| Result | Snackbar |
|---|---|
| Added | "Tile added to Quick Settings." |
| Already added | "This tile is already in Quick Settings." |
| Not added (user said no) | "Tile not added. You can add it any time." |
| Error or not supported | "Could not add the tile. Add it by hand from the Quick Settings edit screen." |

- Each tap sends the analytics event `quick_tile_add_requested` with `tile` (`shuffle`, `wotd` or `favs`) and `result` (`added`, `alreadyAdded`, `notAdded`, `unsupported` or `error`).
- Code: `lib/core/platform/quick_settings_channel.dart` and `android/app/src/main/kotlin/com/hash/prism/PrismSystemChannels.kt`.

### Tile messages

The tile shows a short fixed message in a toast. It no longer shows raw error text. The strings are in `android/app/src/main/res/values/strings.xml`.

| Cause | Toast |
|---|---|
| Success | "Wallpaper updated" |
| No network | "No connection. Try again." |
| Timeout | "The wallpaper took too long to load. Try again." |
| Other download error | "Could not download the wallpaper. Try again." |
| Tile not set up | "Open Prism to finish setting up this tile." |
| Device blocks wallpaper changes | "Wallpaper changes are not available on this device." |
| Anything else | "Could not apply the wallpaper. Try again." |

- If the user closes the shade, the tile now finishes the work that is running. The service stops new work only. It does not cancel the work that runs. The toast and the tile state update only while the service is alive.
- If Android kills the Prism process, the work is lost. A fix needs WorkManager, which is a new dependency.

### Unavailable state

Each tile class has `isConfigured`. If it returns false, the tile state is `Tile.STATE_UNAVAILABLE`. On Android 10 (API 29) and newer, the subtitle reads "Open Prism to set up".

| Tile | Configured when |
|---|---|
| Shuffle Wallpaper | `flutter.quick_tile.category.name` is not blank |
| Wall of the Day | `flutter.quick_tile.wotd.url` is not blank |
| Random Favourite | `flutter.quick_tile.favs.wall_urls` is not blank and is not `[]` |

The tile state updates when the user opens the shade (`onStartListening`) and after an apply.

### Favourites tile cache fix

Before, the cache was cleared on cold start, before favourites loaded. The tile then had an empty list. Now `FavouriteQuickTileListener` clears the cache only when the user logs out or switches account. It writes the list only when the user is signed in and favourites have loaded for that user.

## Limits

- "Add to Quick Settings", the tile messages and the work-finishing change were not compiled and were not run on a device. CI compiles the Kotlin. A person must test them on an Android 13 or newer device.

- The Kotlin changes were not compiled and were not run on a device or emulator. This covers `WallpaperTileService.kt`, `MyTileService.kt`, `WotdTileService.kt`, and `FavsTileService.kt`. Treat these parts as untested:
  - the Unavailable state and subtitle
  - the Wallhaven `categories` and `ratios=portrait` query
  - the Pexels `page` and `large2x` change
- The Dart parts have tests: defaults seeding, the category mirror, and the favourites listener.
- The Wall of the Day tile needs the app to cache the URL first. Open Prism once a day.
- The Random Favourite tile needs a signed-in user with favourites.
- The Pexels tile needs the Pexels key. Prism writes it to the preferences when it caches a URL (`persistPexelsApiKey`).

## How to test

1. Use an Android phone with a fresh install. Open Prism and sign in.
2. Before you open Quick tiles, add the three Prism tiles in the notification shade. Make sure the Shuffle tile is dimmed and reads "Open Prism to set up". Android 10 or newer shows the subtitle.
3. Open Settings, then "Quick tiles". Make sure all three sections show "Both" as selected.
4. Change the category and "Apply to" for each tile. Leave the screen. Open it again. Make sure the choices stay with no Save button.
5. Open the shade. Tap the Shuffle tile. Make sure a portrait wallpaper applies.
6. Open Settings, then the content filter, and change the Wallhaven category. Pick a Wallhaven category in the tile screen and tap the tile. Make sure the result matches the filter.
7. Favourite 2 wallpapers. Close and open Prism. Tap the Random Favourite tile. Make sure it applies a favourite and does not show an empty-list error.
8. Log out. Make sure the Random Favourite tile becomes unavailable.
9. On Android 13 or newer, tap "Add to Quick Settings" under each tile. Confirm in the system dialog. Make sure the tile appears in the shade and the snackbar reads "Tile added to Quick Settings." Tap the button again. Make sure the snackbar says the tile is already added.
10. Turn on airplane mode. Tap the Shuffle tile. Make sure the toast reads "No connection. Try again."
11. On a slow network, tap a tile and close the shade at once. Make sure the wallpaper still changes and the toast reads "Wallpaper updated" if the shade opens again.

Automated tests:

- `test/features/quick_tiles/quick_tile_defaults_test.dart`
- `test/features/quick_tiles/quick_tile_settings_screen_test.dart`
- `test/features/favourite_walls/favourite_quick_tile_listener_test.dart`

Commands:

```sh
fvm flutter test --no-pub test/features/quick_tiles
fvm flutter test --no-pub test/features/favourite_walls/favourite_quick_tile_listener_test.dart
```
