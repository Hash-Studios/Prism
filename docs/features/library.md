# Library: Favourites and Downloads

The user keeps wallpapers in two lists. **Favourites** are saved in the user account. **Downloads** are image files on the device. Both lists support multi-select with bulk actions.

## Where to find it

- Profile drawer: **Favourite Wallpapers** opens `FavouriteWallpaperScreen` (route `/fav-walls`).
- Profile drawer: **Downloaded Walls** opens `DownloadScreen` (route `/downloads`).
- The Auto-rotate screen links to both lists.
- A local download notification opens `DownloadScreen`.

## Platforms

| Platform | Favourites | Downloads |
|---|---|---|
| Android | Full. The Set action shows in multi-select. | Full. Delete uses MediaStore on Android 10 (API 29) and later. Older versions delete the file. |
| iOS | Full. `hideSetWallpaperUi` hides the Set action in multi-select. | Full. Delete removes the app copy. The list is newest first by creation date. |

## Free and Pro

Both screens are free. They have no premium or coin gate.

## How it works

| Path | Role |
|---|---|
| `lib/features/favourite_walls/views/widgets/fav_grid.dart` | Favourites UI: toolbar, grid, multi-select, undo. |
| `lib/features/favourite_walls/views/pages/favourite_wall_screen.dart` | Favourites page shell. |
| `lib/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart` | State: items, sort, source filter, query, remove, restore. |
| `lib/features/favourite_walls/domain/entities/favourite_wall_entity.dart` | Entities, `FavouriteSort`, `applyFavouritesView`. |
| `lib/features/favourite_walls/data/repositories/favourite_walls_repository_impl.dart` | Firestore reads, writes, and batched deletes. |
| `lib/features/favourite_walls/views/widgets/favourite_quick_tile_listener.dart` | Pushes favourite URLs to the quick settings tile. |
| `lib/features/wallpaper_detail/views/pages/download_screen.dart` | Downloads UI: grid, multi-select, delete, share. |
| `pigeons/prism_media_api.dart` | Host API: `listDownloads`, `deleteDownload(String path)`. |
| `android/app/src/main/kotlin/com/hash/prism/PrismMediaHostApiImpl.kt` | Android `deleteDownload`. |
| `ios/Runner/PrismMediaHostApiImpl.swift`, `ios/Runner/Media/PrismMediaFiles.swift` | iOS `deleteDownload` and the newest-first list. |

### Favourites

Toolbar (shows when the list has items):

- Search field, hint "Search by creator or category". It matches the creator name or the category.
- **Sort** menu: Recently added, Oldest, Source. Walls without a date go last. Source sorts by source, then newest first.
- Source chips: All, Prism, Wallhaven, Pexels.

Multi-select:

1. Long press a tile to start. A tap on other tiles adds or removes them.
2. The header shows the count. System back leaves selection mode.
3. The action bar has **Remove from favourites**, **Set** (Android only), and **Share**.

Actions:

- **Remove from favourites** sends one `removeRequested` event. The repository deletes in batches of at most 400 (`_maxBatchDeletes`). A snackbar shows "Removed from favourites" or "Removed N favourites" with **Undo**. Undo adds the walls back (`restoreRequested`). If a remove fails, the toast "Could not remove favourites. Try again." shows and the bloc loads the list again.
- **Set** uses the first selected wall. With more than one wall selected, the header shows "Set uses the first one you picked".
- **Share**: one wall shares a link. More than one wall shares the full image URLs, one per line. On failure the toast is "Could not share. Try again."

States:

| State | Title and action |
|---|---|
| Not signed in | "Sign in to save favourites". |
| Loading | Loading cards. |
| Load failed, nothing cached | "Could not load favourites" with **Retry**. |
| No items | "No favourites yet" with **Browse wallpapers**. |
| Filters match nothing | "No matching favourites" with **Clear filters**. |

Each state sits inside a scrollable list, so pull to refresh works.

Legacy favourites: a favourite that older app versions wrote and the app cannot map to a source is a `LegacyFavouriteWall`. A tap shows the snackbar "This favourite is from an older version and cannot be opened. Press and hold to remove it." A long press selects it, so the user can remove it.

Quick tile: `FavouriteQuickTileListener` pushes the favourite URLs to the tile after a successful load. It pushes an empty list only on logout or account switch.

### Downloads

- The header shows "1 download" or "N downloads" when the list has files.
- The list comes from `PrismMediaHostApi().listDownloads()`. The screen drops files that do not exist. Thumbnails use `ResizeImage(FileImage(file), width: 400)`.
- Long press a tile to start multi-select. The action bar has **Delete** and **Share**.
- **Delete** asks "Delete this download?" or "Delete N downloads?". After the user confirms, the screen calls `deleteDownload(path)` for each file. Then it reads the list again. If some deletes fail, the toast is "Could not delete N downloads."
- **Share** sends the files with the system share sheet.
- On Android 10 and later, `deleteDownload` removes the MediaStore row. It also removes the cache copy when the path is a cache copy. On older Android, it deletes the file only in a known downloads folder and rescans it. On iOS, it deletes the file only if it is in the app downloads folder.
- If the file is not found, the host API returns the error code `NOT_FOUND`.

States:

| State | Title and action |
|---|---|
| Loading | Loading cards. |
| List failed, nothing shown | "Could not load downloads" with **Retry**. |
| List failed, files shown | The files stay. The toast "Could not refresh downloads. Try again." shows. |
| No files | "No downloads yet" with **Browse wallpapers**. |

## Limits

- Kotlin and Swift were not compiled here (no Android SDK and no Xcode). The host code is unbuilt and untested on a device. The Dart side uses a mocked host API in tests.
- The Set action in Favourites uses only the first selected wall.
- Downloads delete runs one file at a time through the host API. It is not a batch call.
- The Favourites query has no limit and no pagination. It loads every favourite in one read.
- The Dart screen does not sort downloads. The order comes from the host: MediaStore `DATE_ADDED` descending (Android 10 and later), file modified time descending (older Android), creation date descending (iOS).

## How to test

1. Sign in. Favourite 4 wallpapers from Prism, Wallhaven, and Pexels.
2. Open the profile drawer and tap **Favourite Wallpapers**.
3. Tap a source chip. Make sure the grid shows only that source.
4. Type a creator name. Make sure the grid narrows. Tap the X button to clear it.
5. Open the **Sort** menu and choose Oldest. Make sure the order flips.
6. Long press a tile. Tap one more tile. Tap **Remove from favourites**. Make sure the snackbar shows. Tap **Undo**. Make sure the walls return.
7. On Android, select two walls and tap **Set**. Make sure the first wall you picked is set.
8. Download 3 wallpapers. Open **Downloaded Walls**. Make sure the header shows "3 downloads".
9. Long press a tile and tap **Delete**. Tap **Delete** in the dialog. Make sure the file leaves the list and the device gallery (Android) or the app folder (iOS).
10. On iOS, make sure the newest download is first.
11. Turn on airplane mode and pull to refresh Favourites. Make sure the loaded items stay.

Automated tests:

- `test/features/favourite_walls/fav_grid_test.dart`
- `test/features/favourite_walls/biz/bloc`
- `test/features/favourite_walls/domain/favourite_view_test.dart`
- `test/features/favourite_walls/data/repositories`
- `test/features/favourite_walls/favourite_quick_tile_listener_test.dart`
- `test/features/favourite_walls/legacy_favourite_thumbnail_test.dart`
- `test/features/wallpaper_detail/views/pages/download_screen_test.dart`

Command:

```sh
fvm flutter test --no-pub test/features/favourite_walls test/features/wallpaper_detail/views/pages/download_screen_test.dart
```
