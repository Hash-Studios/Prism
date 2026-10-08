# Wallpaper history

The app keeps a list of wallpapers the user set. The user can open the list and set a wallpaper again.

## Where to find it

Settings > **Wallpaper history** ("Wallpapers you set before"). The route is `WallpaperHistoryRoute` (`/wallpaper-history`).

## Platforms

The Settings entry shows on Android and iOS. The app records only after a successful set through `WallpaperService`. iOS does not set wallpapers from the app, so the list stays empty there unless a set path runs on iOS. This was not confirmed on a device.

## Free and Pro

Free for all users. No gate.

## How it works

| Rule | Value |
|---|---|
| Cap | 100 items (`wallpaperHistoryLimit`). The store drops the oldest. |
| Order | Newest first. |
| Dedupe | Same `fullUrl` and same target within 1 minute (`wallpaperHistoryDedupeWindow`). The store ignores the new item. |
| Storage | One JSON string in `SettingsLocalDataSource`, key `wallpaper.history.items`. Local to the device. |
| Bad data | The store skips invalid entries when it reads. |

Each item (`AppliedWallpaper`) has: `id`, `source` (`prism`, `wallhaven`, `pexels`, or `local`), `thumbnailUrl`, `fullUrl`, `target` (`home`, `lock`, `both`), `appliedAt`.

The screen:

- Shows a grid of two columns. Each tile shows the image, the target (Home screen, Lock screen, Both screens), and the date and time.
- Tap a tile to set it again. The set sheet always opens, even when a default target is saved.
- **Clear history** in the app bar opens a dialog "Clear history?" with Cancel and Clear. The text says the wallpapers stay as they are.
- When the list is empty, the screen shows "No wallpapers yet".

Where the app records:

- `WallpaperService.setWallpaper` records after an `applied` result. It does not record `pending` or failed results.
- The set sheet flow, the downloaded wallpaper screen, and the onboarding first wallpaper (`setWallpaperFromSource`) use this default.
- The editor passes `recordHistory: false`, so edited exports do not enter the list.
- A set again from the history screen records a new item, unless the dedupe rule applies.

| Path | Role |
|---|---|
| `lib/features/wallpaper_history/data/wallpaper_history_store.dart` | Store with cap, dedupe, order. |
| `lib/features/wallpaper_history/domain/entities/applied_wallpaper.dart` | Item and JSON mapping. |
| `lib/features/wallpaper_history/views/pages/wallpaper_history_screen.dart` | Screen, clear dialog. |
| `lib/features/wallpaper_history/views/widgets/applied_wallpaper_tile.dart` | Tile with date and target. |
| `lib/core/platform/wallpaper_service.dart` | Records the item. |

## Limits

- The list is local. It does not sync between devices and does not use the account.
- If a Prism wallpaper URL stops working, the thumbnail shows a plain placeholder and a set again can fail.
- The history screen does not show a source label, although the item stores one.
- Code does not remove history on sign out. Not confirmed by a test.

## How to test

1. On Android, set three different wallpapers. Open Settings > **Wallpaper history**. Make sure the newest is first, with target and date.
2. Set the same wallpaper to the same target twice within 1 minute. Make sure the list shows one new item.
3. Tap a tile. Make sure the set sheet opens. Pick a target. Make sure the wallpaper changes.
4. Tap **Clear history**, then Cancel. Make sure the list stays.
5. Tap **Clear history**, then Clear. Make sure "No wallpapers yet" shows.
6. Set a wallpaper from the editor. Make sure it does not appear in the list.

Automated tests:

- `test/features/wallpaper_history/wallpaper_history_store_test.dart`
- `test/features/wallpaper_history/wallpaper_history_screen_test.dart`

Command: `fvm flutter test --no-pub test/features/wallpaper_history`
