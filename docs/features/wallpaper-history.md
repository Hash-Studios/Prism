# Wallpaper history

The app keeps a list of wallpapers the user set. The user can open the list and set a wallpaper again. The list is the **History** tab of the Library. See [library.md](library.md) for the Library screen.

## Where to find it

- Library > **History** tab. The route is `LibraryRoute(initialTab: LibraryTab.history)`.
- Settings > **Wallpaper history** ("Wallpapers you set before") opens the Library on the **History** tab.
- The `/wallpaper-history` link opens the Library on the **History** tab.
- `WallpaperHistoryScreen` and `WallpaperHistoryRoute` are removed.

## Platforms

The Settings row shows on Android only (`settings_screen.dart`). iOS cannot set wallpapers from the app. The Library has no **History** tab on iOS. On iOS, `/wallpaper-history` opens the Library on **Favourites**.

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

### The History tab

- The list is grouped by local calendar day, newest day first: **Today**, **Yesterday**, then a date. The date shows the weekday and the day and month this year. An earlier year also shows the year.
- Each tile shows the image, the screen that got the wallpaper (Home screen, Lock screen, or Both screens), and the time. The day is in the heading above the group.
- The newest home item and the newest lock item show a **Current** badge. A `both` row counts for each screen. The badge shows what Prism set last. It cannot see changes made outside Prism.
- Tap a tile to open the wallpaper:
  - A Prism, Wallhaven, or Pexels wallpaper with an ID opens its detail page.
  - A local file that still exists on the device opens the download preview.
  - Otherwise the set sheet opens.
- The **Set again** icon button on a tile opens the set sheet. The sheet always opens, even when a default target is saved. Analytics: `library_history_set_again{provider, target}`. The list reloads after the sheet closes.
- Opening a tile reloads history when its detail page or download preview returns. Pull to refresh reloads the local history store.
- Long press a tile to remove it. A snackbar says "Removed from history" and has **Undo**. Screen readers get a "Remove from history" action.
- **Clear** in the Library app bar shows when the history has items. It opens a dialog "Clear history?". The **Clear history** button confirms, and **Cancel** keeps the list. The text says the wallpapers stay as they are. Analytics: `library_history_cleared{count}`.
- When the list is empty, the tab shows "No wallpapers yet" with **Browse wallpapers**. The button opens Home.

Where the app records:

- `WallpaperService.setWallpaper` records after an `applied` result. It does not record `pending` or failed results.
- The set sheet flow, the downloaded wallpaper screen, and the onboarding first wallpaper (through `WallpaperService.setWallpaper`) use this default.
- The Position studio sets a rendered copy but passes the original wallpaper as `historySource` and `historyThumbnail`. The row keeps the original URL, so a set again works.
- A different wallpaper for the lock screen writes two rows, one for each screen.
- Undo removes the rows the undone set wrote.
- The editor passes `recordHistory: false`, so edited exports do not enter the list.
- Quick tiles, auto-rotate, and live wallpapers do not write history.
- A set again from the History tab records a new item, unless the dedupe rule applies.

| Path | Role |
|---|---|
| `lib/features/wallpaper_history/data/wallpaper_history_store.dart` | Store with cap, move to top, order, `currentFor`, `remove`. |
| `lib/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart` | Events: started, cleared, removed, restored. |
| `lib/features/wallpaper_history/domain/entities/applied_wallpaper.dart` | Item and JSON mapping. |
| `lib/features/wallpaper_history/views/widgets/wallpaper_history_list.dart` | History tab: day groups, empty state, open, remove, set again, clear confirm. |
| `lib/features/wallpaper_history/views/widgets/applied_wallpaper_tile.dart` | Tile with the time, target, **Current** badge and **Set again** button. |
| `lib/features/library/views/pages/library_screen.dart` | Library tab, including the **Clear** app bar action on the History tab. |
| `lib/core/platform/wallpaper_service.dart` | Records the item. |

## Limits

- The list is local. It does not sync between devices and does not use the account.
- If a Prism wallpaper URL stops working, the thumbnail shows a plain placeholder and a set again can fail.
- The History tab does not show a source label, although the item stores one.
- A row is removed with a long press only. The list has no swipe action.
- Sign out clears the list (`signOutGoogle` calls `WallpaperHistoryStore.clear()`). A signed-out user starts with an empty list.

## How to test

1. On Android, set three different wallpapers. Open Settings > **Wallpaper history**. Make sure the Library opens on **History**. Make sure the newest is first, with the screen and time.
2. Set the same wallpaper to the same target twice within 1 minute. Make sure the list shows one row for it, at the top.
3. Tap a tile. Make sure the wallpaper opens. Tap the **Set again** icon on a tile. Make sure the set sheet opens. Pick a target. Make sure the wallpaper changes.
4. Tap **Clear**, then **Cancel**. Make sure the list stays.
5. Tap **Clear**, then **Clear history**. Make sure "No wallpapers yet" shows.
6. Set a wallpaper from the editor. Make sure it does not appear in the list.
7. Set wallpaper A on the lock screen and wallpaper B on the home screen. Open the list. Make sure A and B each show **Current**.
8. Long press a row. Make sure it goes away and the snackbar shows **Undo**. Tap **Undo**. Make sure the row comes back in its place.
9. Open `/wallpaper-history` from a link. Make sure the Library opens on **History**.
10. Sign out and sign in. Make sure the list is empty.

Automated tests:

- `test/features/wallpaper_history/wallpaper_history_store_test.dart`
- `test/features/wallpaper_history/wallpaper_history_bloc_test.dart`
- `test/features/wallpaper_history/wallpaper_history_list_test.dart` (day grouping and labels, refresh, navigation return, and tile actions)

Command: `fvm flutter test --no-pub test/features/wallpaper_history`
