# Wallpaper history

The app keeps a list of wallpapers the user set. The user can open the list and set a wallpaper again.

## Where to find it

Settings > **Wallpaper history** ("Wallpapers you set before"). The route is `WallpaperHistoryRoute` (`/wallpaper-history`).

## Platforms

The Settings row shows on Android only (`settings_screen.dart`). iOS cannot set wallpapers from the app, so the list would stay empty there. The route works on iOS if code opens it, but no screen does.

## Free and Pro

Free for all users. No gate.

## How it works

| Rule | Value |
|---|---|
| Cap | 100 items (`wallpaperHistoryLimit`). The store drops the oldest. |
| Order | Newest first. |
| Same wallpaper again | Same `fullUrl` and same target within 1 minute (`wallpaperHistoryDedupeWindow`). The old row moves to the top with the new time and id. The store does not add a second row. After 1 minute the app adds a new row. |
| Storage | One JSON string in `SettingsLocalDataSource`, key `wallpaper.history.items`. Local to the device. |
| Bad data | The store skips invalid entries when it reads. |

Store API (`WallpaperHistoryStore`):

- `items()`: all rows, newest first.
- `record(item)`: saves the row and returns its id.
- `currentFor(target)`: the newest row that is on `home` or `lock` now. A `both` row counts for each screen. Undo reads it.
- `remove(id)`: deletes one row.
- `clear()`: deletes all rows.

Each item (`AppliedWallpaper`) has: `id`, `source` (`prism`, `wallhaven`, `pexels`, or `local`), `thumbnailUrl`, `fullUrl`, `target` (`home`, `lock`, `both`), `appliedAt`.

The screen:

- Shows a grid of two columns. Each tile shows the image, the target (Home screen, Lock screen, Both screens), and the date and time.
- The newest row for the home screen and the newest row for the lock screen show a **Current** badge. A `both` row counts for each screen. The badge shows what Prism set last. It cannot see changes made outside Prism.
- Tap a tile to set it again. The set sheet always opens, even when a default target is saved.
- Long press a tile, or swipe it sideways, to remove that row. A snackbar says "Removed from history" and has **Undo**. Screen readers get a "Remove from history" action.
- **Clear history** in the app bar opens a dialog "Clear history?" with Cancel and Clear. The text says the wallpapers stay as they are.
- When the list is empty, the screen shows "No wallpapers yet".

Where the app records:

- `WallpaperService.setWallpaper` records after an `applied` result. It does not record `pending` or failed results.
- The set sheet flow, the downloaded wallpaper screen, and the onboarding first wallpaper (through `WallpaperService.setWallpaper`) use this default.
- The Position studio sets a rendered copy but passes the original wallpaper as `historySource` and `historyThumbnail`. The row keeps the original URL, so a set again works.
- A different wallpaper for the lock screen writes two rows, one for each screen.
- Undo removes the rows the undone set wrote.
- The editor passes `recordHistory: false`, so edited exports do not enter the list.
- Quick tiles, auto-rotate, and live wallpapers do not write history.
- A set again from the history screen records a new item, unless the dedupe rule applies.

| Path | Role |
|---|---|
| `lib/features/wallpaper_history/data/wallpaper_history_store.dart` | Store with cap, move to top, order, `currentFor`, `remove`. |
| `lib/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart` | Events: started, cleared, removed, restored. |
| `lib/features/wallpaper_history/domain/entities/applied_wallpaper.dart` | Item and JSON mapping. |
| `lib/features/wallpaper_history/views/pages/wallpaper_history_screen.dart` | Screen, clear dialog. |
| `lib/features/wallpaper_history/views/widgets/applied_wallpaper_tile.dart` | Tile with date and target. |
| `lib/core/platform/wallpaper_service.dart` | Records the item. |

## Limits

- The list is local. It does not sync between devices and does not use the account.
- If a Prism wallpaper URL stops working, the thumbnail shows a plain placeholder and a set again can fail.
- The history screen does not show a source label, although the item stores one.
- Sign out clears the list (`signOutGoogle` calls `WallpaperHistoryStore.clear()`). A signed-out user starts with an empty list.

## How to test

1. On Android, set three different wallpapers. Open Settings > **Wallpaper history**. Make sure the newest is first, with target and date.
2. Set the same wallpaper to the same target twice within 1 minute. Make sure the list shows one row for it, at the top.
3. Tap a tile. Make sure the set sheet opens. Pick a target. Make sure the wallpaper changes.
4. Tap **Clear history**, then Cancel. Make sure the list stays.
5. Tap **Clear history**, then Clear. Make sure "No wallpapers yet" shows.
6. Set a wallpaper from the editor. Make sure it does not appear in the list.
7. Set wallpaper A on the lock screen and wallpaper B on the home screen. Open the list. Make sure A and B each show **Current**.
8. Long press a row. Make sure it goes away and the snackbar shows **Undo**. Tap **Undo**. Make sure the row comes back in its place.
9. Swipe a row sideways. Make sure it goes away.
10. Sign out and sign in. Make sure the list is empty.

Automated tests:

- `test/features/wallpaper_history/wallpaper_history_store_test.dart`
- `test/features/wallpaper_history/wallpaper_history_bloc_test.dart`
- `test/features/wallpaper_history/wallpaper_history_screen_test.dart`

Command: `fvm flutter test --no-pub test/features/wallpaper_history`
