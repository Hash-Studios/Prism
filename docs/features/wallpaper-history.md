# Wallpaper history

The app keeps three lists:

- **Applied history**: the wallpapers the user set on this device. The user can set one again. Local only.
- **Synced history**: the catalogue wallpapers the user set or downloaded. The app keeps a copy in the account, so the list comes back after a phone reset or on a new phone.
- **Recently viewed**: the wallpapers the user opened on this device. It never leaves the device.

The **History** tab of the Library shows them. See [library.md](library.md) for the Library screen.

## Where to find it

- Library > **History** tab. The route is `LibraryRoute(initialTab: LibraryTab.history)`.
- Settings > **Wallpaper history** ("Wallpapers you set before") opens the Library on the **History** tab.
- The `/wallpaper-history` link opens the Library on the **History** tab.
- `WallpaperHistoryScreen` and `WallpaperHistoryRoute` are removed.

## Platforms

The Settings row shows on Android only (`settings_screen.dart`). iOS cannot set wallpapers from the app. The **History** tab shows on Android and iOS. On iOS, the first list is **Downloaded**, because the user cannot set a wallpaper there.

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

- A segmented control at the top picks the list: **Set and downloaded** (iOS: **Downloaded**) or **Recently viewed**.
- **Set and downloaded** shows the applied history and the synced history in one list. A synced wallpaper that a row of the applied history already shows does not show again.
- One line above **Set and downloaded** explains the sync: "Saved to your account, so these come back on a new phone." A signed-out user sees "Sign in to keep these on a new phone."
- Each list has its own **Clear** button above the list. Each button opens a confirm dialog. See the clear rules below.
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
- **Clear** on **Set and downloaded** opens "Clear history?". **Clear history** confirms. It clears the applied history and the synced history, on the device and in the account. A signed-in clear reads the account first. When the account cannot be reached (offline), nothing is cleared and a toast says "Couldn't clear history. Check your connection and try again." Analytics: `library_history_cleared{count}`.
- **Clear** on **Recently viewed** opens "Clear recently viewed?". **Clear recently viewed** confirms. Analytics: `recently_viewed_cleared{count}`.
- **Cancel** keeps the list in both dialogs.
- A synced row from another device has no **Set again** button. It has no local file. Tap it to open the detail page, then set it from there.
- Long press on a row in **Set and downloaded** removes it. A removed applied row also removes the synced row of the same wallpaper. **Undo** puts both back. Recently viewed rows have no remove action.
- When a list is empty, the tab shows an empty state with **Browse wallpapers**. The button opens Home. When **Save viewing history** is off, **Recently viewed** shows "Viewing history is off" with a **Turn on** button.

Where the app records:

- `WallpaperService.setWallpaper` records after an `applied` result. It does not record `pending` or failed results.
- The set sheet flow, the downloaded wallpaper screen, and the onboarding first wallpaper (through `WallpaperService.setWallpaper`) use this default.
- The Position studio sets a rendered copy but passes the original wallpaper as `historySource` and `historyThumbnail`. The row keeps the original URL, so a set again works.
- A different wallpaper for the lock screen writes two rows, one for each screen.
- Undo removes the rows the undone set wrote.
- The editor passes `recordHistory: false`, so edited exports do not enter the list.
- Quick tiles, auto-rotate, and live wallpapers do not write history.
- A set again from the History tab records a new item, unless the dedupe rule applies.

### Recently viewed

| Rule | Value |
|---|---|
| When a view counts | The detail page stays on screen for 2 seconds (`viewDwell`), or the user opens the preview, sets, saves (favourites) or downloads the wallpaper. |
| Swipe through | A wallpaper the user swipes past in less than 2 seconds does not count. The 2 seconds start again when the user comes back to it. |
| Cap | 100 (`recentlyViewedLimit`). The oldest go first. |
| Order | Newest first. A new view moves the wallpaper to the top. One row for each wallpaper. |
| Data | `HistoryWall`: wallpaper id, provider, public thumbnail URL, time. No original URL and no signed link. |
| Storage | `SettingsLocalDataSource`, key `history.viewed.items`. Device only. |
| Setting | Settings > **Save viewing history**, key `history.viewed.enabled`, on by default. Off stops the recording and clears the list. Analytics: `viewing_history_toggled{value}`. |

`ViewRecorder` (`recently_viewed_rules.dart`) holds the rule. The detail page calls `shown()` when the wallpaper is loaded and active in the feed, `hidden()` when the feed moves to another wallpaper, and `acted()` on an action.

### Synced history

| Rule | Value |
|---|---|
| What syncs | A catalogue wallpaper (Prism, Wallhaven, Pexels) that the user set or downloaded. It must have a public `https` thumbnail. Local files do not sync. |
| When it writes | Only on a set (`WallpaperService.setWallpaper` with `recordHistory`) or a download (detail page). A view never writes. One doc write for each set or download. |
| Firestore path | `usersv2/{uid}/history/{provider}_{id}`. |
| Doc fields | `id`, `provider`, `thumb`, `action` (`set` or `download`), `at` (timestamp). The rules refuse all other fields. |
| Cap | 500 (`syncedHistoryLimit`). When a new write goes over the cap, the client deletes the oldest docs in the same batch. |
| Device copy | `SettingsLocalDataSource`, key `history.synced.items`. |
| Restore | Once for each account on each device (`history.synced.restored_for`). It runs at sign-in and at launch for a signed-in user. It reads all docs of the account (the prune keeps them near 500) and merges them with the device copy and the applied history. The newest entry of each wallpaper wins. Entries that are only on the device go up to the account. Analytics: `history_restored{count_bucket}` when the account had entries. |
| Sign out | Clears the device copy and the restore flag. The account keeps its history. |
| Account deletion | `deleteAccount` deletes `usersv2/{uid}/history`. `LocalAccountDataCleaner` clears the device copy. |
| Offline | A set or download updates the device copy at once. Firestore queues the write. |

### Pick up where you left off (Home)

The **For you** feed shows one row, "Pick up where you left off", after the second grid row. The ranker does not change.

- It shows recently viewed wallpapers from the last 7 days that the user did not save, set or download.
- It shows only views from before the app opened. A view in this session does not change the row.
- It shows only on a returning session (`AppSessionTracker.sessionNumber > 1`). The first session after install does not show it.
- It shows 4 to 10 wallpapers. With fewer than 4, the row does not show.
- A tap opens the detail page. Analytics: `pick_up_row_seen{count}` and `pick_up_tile_opened{provider, position}`.

| Path | Role |
|---|---|
| `lib/features/wallpaper_history/data/wallpaper_history_store.dart` | Store with cap, move to top, order, `currentFor`, `remove`. |
| `lib/features/wallpaper_history/data/history_wall_stores.dart` | `RecentlyViewedStore`, `SyncedHistoryStore`, restore and prune. |
| `lib/features/wallpaper_history/domain/entities/history_wall.dart` | `HistoryWall`, the public thumbnail check, and `mergeHistory`. |
| `lib/features/wallpaper_history/domain/recently_viewed_rules.dart` | `ViewRecorder` and `pickUpWalls`. |
| `lib/features/wallpaper_history/views/widgets/pick_up_row.dart` | The Home row. |
| `lib/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart` | Events: started, cleared, viewedCleared, viewingTurnedOn, removed, restored. |
| `lib/features/wallpaper_history/domain/entities/applied_wallpaper.dart` | Item and JSON mapping. |
| `lib/features/wallpaper_history/views/widgets/wallpaper_history_list.dart` | History tab: day groups, empty state, open, remove, set again, clear confirm. |
| `lib/features/wallpaper_history/views/widgets/applied_wallpaper_tile.dart` | Tile with the time, target, **Current** badge and **Set again** button. |
| `lib/features/library/views/pages/library_screen.dart` | Library tab. |
| `firestore.rules` | `usersv2/{uid}/history`: owner only, field allowlist, sizes. |
| `lib/core/platform/wallpaper_service.dart` | Records the item. |

## Limits

- The applied history is local. A set of a local file does not sync.
- A synced row from another device cannot use **Set again**. Open it and set it from the detail page.
- Recently viewed is device only. It does not sync.
- The 500 cap is a client rule. The rules cannot count docs.
- If a Prism wallpaper URL stops working, the thumbnail shows a plain placeholder and a set again can fail.
- The History tab does not show a source label, although the item stores one.
- A row is removed with a long press only. The list has no swipe action.
- Sign out clears the applied history, recently viewed, and the synced device copy. The account keeps the synced history.

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
10. Sign out. Make sure **Recently viewed** is empty. Sign in again. Make sure **Set and downloaded** shows the synced wallpapers again.
11. Open five wallpapers for 2 seconds each. Swipe past one more quickly. Close and open the app. Make sure **Pick up where you left off** shows on Home, and the quick one is not in it.
12. Turn off Settings > **Save viewing history**. Make sure **Recently viewed** shows "Viewing history is off".
13. On iOS, download a wallpaper. Make sure **Downloaded** shows it.

Automated tests:

- `test/features/wallpaper_history/wallpaper_history_store_test.dart`
- `test/features/wallpaper_history/wallpaper_history_bloc_test.dart`
- `test/features/wallpaper_history/wallpaper_history_list_test.dart` (segments, day grouping and labels, refresh, navigation return, tile actions, clear confirms)
- `test/features/wallpaper_history/history_wall_test.dart`, `history_wall_stores_test.dart`, `recently_viewed_rules_test.dart`, `pick_up_row_test.dart`
- `tool/firestore_rules_smoke.mjs` (`make rules-test`) for the `history` rules

Command: `fvm flutter test --no-pub test/features/wallpaper_history`
