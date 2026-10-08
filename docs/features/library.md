# Library: Favourites, Downloads and History

The **Library** is one screen with tabs. It holds the wallpapers the user keeps. **Favourites** are saved in the user account. **Downloads** are image files on the device. **History** lists the wallpapers the user set (Android only). Favourites and Downloads support multi-select with bulk actions.

## Where to find it

- Profile drawer: **Library** opens `LibraryScreen` (route `/library`). It replaces the two old drawer entries.
- The old routes stay for deep links and notifications: `FavouriteWallpaperScreen` (`/fav-walls`), `DownloadScreen` (`/downloads`) and `WallpaperHistoryScreen` (`/wallpaper-history`).
- The Auto-rotate screen links to Favourites and Downloads.
- A local download notification opens `DownloadScreen`.
- Route argument: `LibraryRoute(initialTab: LibraryTab.downloads)` opens another tab first.

## Platforms

| Platform | Tabs | Favourites | Downloads |
|---|---|---|---|
| Android | Favourites, Downloads, History | Full. The Set action shows in multi-select. The **Recently set** row shows above the search field. | Full. Delete uses MediaStore on Android 10 (API 29) and later. Older versions delete the file. One selected file can be set as the wallpaper. |
| iOS | Favourites, Downloads | Full. `hideSetWallpaperUi` hides the Set action and the **Recently set** row. | Full. Delete removes the app copy. No Set action. |

## Free and Pro

The Library has no premium or coin gate.

## How it works

| Path | Role |
|---|---|
| `lib/features/favourite_walls/views/widgets/fav_grid.dart` | Favourites UI: toolbar, grid, multi-select, undo. |
| `lib/features/favourite_walls/views/pages/favourite_wall_screen.dart` | Favourites page shell. |
| `lib/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart` | State: items, sort, source filter, query, remove, restore. |
| `lib/features/favourite_walls/domain/entities/favourite_wall_entity.dart` | Entities, `FavouriteSort`, `applyFavouritesView`. |
| `lib/features/favourite_walls/data/repositories/favourite_walls_repository_impl.dart` | Firestore reads, writes, and batched deletes. |
| `lib/features/favourite_walls/views/widgets/favourite_quick_tile_listener.dart` | Pushes favourite URLs to the quick settings tile. |
| `lib/features/favourite_walls/data/favourites_sync_service.dart` | Live listener on the user's favourites. |
| `lib/features/favourite_walls/data/guest_favourites_store.dart`, `guest_favourites_merger.dart` | Guest favourites file and the merge at sign-in. |
| `lib/features/favourite_walls/data/favourite_wall_doc_mapper.dart` | Maps a Firestore doc to an entity and back. |
| `lib/features/library/views/pages/library_screen.dart` | The hub: app bar, tabs, `LibraryTab`. |
| `lib/features/library/views/widgets/recently_set_row.dart` | **Recently set** row (from `WallpaperHistoryStore`). |
| `lib/features/library/views/widgets/offline_chip.dart` | **Offline** chip from `ConnectivityService.onConnectionChange`. |
| `lib/features/library/data/favourites_export.dart` | Builds and writes the favourites export file. |
| `lib/features/favourite_walls/views/widgets/favourite_tile_image.dart` | Grid image with the **Unavailable** state. |
| `lib/features/wallpaper_detail/views/pages/download_screen.dart` | Downloads UI: `DownloadsBody` (used by the hub) and the `DownloadScreen` page around it. |
| `lib/features/wallpaper_detail/data/downloaded_wall_index.dart` | Maps a file name to its wallpaper: `remember`, `has`, `forget`, `clear`, `resolve`. |
| `pigeons/prism_media_api.dart` | Host API: `listDownloads`, `deleteDownload(String path)`. |
| `android/app/src/main/kotlin/com/hash/prism/PrismMediaHostApiImpl.kt` | Android `deleteDownload`. |
| `ios/Runner/PrismMediaHostApiImpl.swift`, `ios/Runner/Media/PrismMediaFiles.swift` | iOS `deleteDownload` and the newest-first list. |

### Library hub

- The app bar shows the title **Library**, a back button, and a small **Offline** chip. The chip shows only while the device has no connection. It reads `ConnectivityService.onConnectionChange` and the first `hasConnection()` result.
- The tab bar switches between the bodies. Each tab keeps its state when the user swipes away.
- Each tab change sends `library_tab_changed{tab}` (`favourites`, `downloads` or `history`). The first tab is not tracked.
- **Favourites** and **Downloads** are the same widgets as the old screens (`FavouriteGrid` and `DownloadsBody`). The old screens and the hub do not differ in behaviour.
- **History** is a thin tab. It shows a short note and the **Open history** button. The button opens `WallpaperHistoryScreen` (route `/wallpaper-history`). The history list keeps its own clear and remove actions there.
- **Recently set** (Android): a row of up to 8 wallpapers from `WallpaperHistoryStore.items()`, newest first, one per image. A tap opens the set sheet for that wallpaper. The row is hidden when the history is empty.
- **Source filter**: the chip row All, Prism, Wallhaven, Pexels is part of the Favourites toolbar. It uses `applyFavouritesView`.

### Favourites

Toolbar (shows when the list has items):

- Search field, hint "Search by creator or category". It matches the creator name or the category.
- **Sort** menu: Recently added, Oldest, Source. Walls without a date go last. Source sorts by source, then newest first.
- **More** menu (three dots): **Export favourites** and **Clear all favourites**.
- Source chips: All, Prism, Wallhaven, Pexels.
- A line with the number of favourites, for example "128 favourites".

Multi-select:

1. Long press a tile to start. A tap on other tiles adds or removes them.
2. The header shows the count. System back leaves selection mode.
3. The action bar has **Remove from favourites**, **Set** (Android only), and **Share**.

Actions:

- **Remove from favourites** sends one `removeRequested` event. The repository deletes in batches of at most 400 (`_maxBatchDeletes`). A snackbar shows "Removed from favourites" or "Removed N favourites" with **Undo**. Undo adds the walls back (`restoreRequested`). If a remove fails, the toast "Could not remove favourites. Try again." shows and the bloc loads the list again.
- **Set** uses the first selected wall. With more than one wall selected, the header shows "Set uses the first one you picked".
- **Share**: one wall shares a link. More than one wall shares the full image URLs, one per line. On failure the toast is "Could not share. Try again."

**Clear all favourites**: a dialog asks "Clear N favourites?" with the text "This removes them from your account." (a guest reads "This removes them from this device."). After **Clear all**, the bloc reads the server list first and removes what the server holds. A snackbar shows "Cleared N favourites" with **Undo**. **Undo** adds back the list as it was before the clear (`restoreRequested`). If the clear fails, the toast is "Couldn't clear favourites. Try again."

**Export favourites**: the action writes `prism-favourites-YYYY-MM-DD.json` to the temp directory and opens the system share sheet with the file. The file has `app`, `exportedAt`, `count` and `favourites`. Each item is the same map that Prism saves in the Firestore doc of the favourite (dates are ISO 8601 strings). The log tag is `favourite_walls.export`. The event is `favourites_exported{count}`. With no favourites, the toast is "No favourites to export yet." and nothing is shared. If the write or the share fails, the toast is "Couldn't export favourites. Try again."

**Unavailable tile**: the grid image tries the thumbnail, then the full image. If both fail (or the URL is empty), the tile shows "Unavailable" and a **Remove** button. **Remove** sends the normal `removeRequested` event and shows the same **Undo** snackbar.

**Refresh failure**: if a refresh fails while favourites are on screen, the list stays and the toast "Couldn't refresh favourites. Showing your saved list." shows.

**Guest**: a guest with saved favourites sees the list and a banner "Sign in to keep them on every device" with **Sign in** and a **Dismiss** button. **Dismiss** hides the banner until the app restarts. The first frame, before the list loads, shows `SignInPrompt(feature: 'favourites')`.

States:

| State | Title and action |
|---|---|
| Not signed in, before the list loads | "Sign in to use favourites" with **Sign in**. |
| Loading | Loading cards. |
| Load failed, nothing cached | "Could not load favourites" with **Retry**. |
| No items | "No favourites yet" with **Browse wallpapers**. |
| Filters match nothing | "No matching favourites" with **Clear filters**. |

Each state sits inside a scrollable list, so pull to refresh works.

Legacy favourites: a favourite that older app versions wrote and the app cannot map to a source is a `LegacyFavouriteWall`. A tap shows the snackbar "This favourite is from an older version and cannot be opened. Press and hold to remove it." A long press selects it, so the user can remove it.

Quick tile: `FavouriteQuickTileListener` pushes the favourite URLs to the tile after a successful load. It pushes an empty list only on logout or account switch.

### Sync, offline saves and guest favourites

Sync:

- `FavouritesSyncService` listens to `usersv2/{uid}/images` for the whole session. It starts at sign-in (in `completeSignIn`, inside the sign-in bootstrap) and at app start for a signed-in user (`HomeTabPage`).
- Each server snapshot replaces the local heart set and sends `FavouriteWallsEvent.synced(userId, items)` to the bloc. The bloc moves to `success`, also with zero items. A favourite from another device shows up without a reload.
- A snapshot from the local cache with no items is ignored. A cold cache must not wipe the hearts. Only an empty snapshot from the server counts.
- The listener stops when the signed-in user changes. The sign-out path can also call `FavouritesSyncService.stop()`.
- The quick tile and Auto-rotate read the bloc list. The sync service fills it at start, so they no longer wait for the user to open Favourites.

Saving:

- The heart sends the state it is going to show: `toggleRequested(wall, desired: !isFavorite)`. A stale list can no longer turn a save into a removal.
- The repository writes the local heart set first. Then it writes to Firestore and waits at most 8 seconds. After 8 seconds it reports success and logs "queued offline". The Firestore SDK keeps the write and sends it when the network returns.
- If Firestore refuses the write (for example `permission-denied`), the repository puts the local heart back and the toast "Couldn't update favourites. Try again." shows.
- Clear all uses the same rule for each batch.
- The heart ignores a second tap for 300 ms. A new favourite shows a short Glint (`GlintMood.love`). Reduce motion turns the Glint off.
- Every new favourite stores `favouritedAt`. The lists sort by `favouritedAt`, then by `createdAt` for older docs. A new favourite from any source shows first. `FavStatusChangedEvent` has `isFavourite`.
- **Clear favourite walls** first reads the favourites from the server. If that read fails, it stops with a failure and removes nothing. It clears what the server holds, not the list on the device. Undo uses `FavouriteWallsAdapter.restoreWalls(walls)` (event `restoreRequested`).

Guest favourites:

- A guest can tap the heart. There is no sign-in prompt. The wall goes to `GuestFavouritesStore` (file `guest_favourites`, newest last, at most 200) and to the local heart set for the guest.
- After the 3rd guest save, the toast "Sign in to keep your favourites on every device" shows. Analytics: `FavouriteSavedAsGuestEvent`.
- At sign-in, `GuestFavouritesMerger` adds the guest walls the account does not have. A wall already in the account keeps its server doc. It writes in batches of 400 (source tag `favourite_walls.guest_merge`), clears the guest store, and tracks `GuestFavouritesMergedEvent(count)`.
- If the merge fails (for example offline), the guest list stays on the device. The next start for that account tries again.

### Downloads

- The toolbar shows "1 download" or "N downloads", then the total size, for example "12 downloads · 38.4 MB". The sizes come from the file stat when the list loads.
- The **Sort** menu has **Newest** (default), **Oldest** and **Name**. Newest and oldest use the file modified time. Name is case-insensitive. Files with the same key keep the order of the host list. The choice is not saved.
- The list comes from `PrismMediaHostApi().listDownloads()`. The screen drops files that do not exist. Thumbnails use `ResizeImage(FileImage(file), width: 400)`.
- Long press a tile to start multi-select. The action bar has **Delete** and **Share**. On Android, with exactly one file selected, it also has **Set as wallpaper**. It uses `SetWallpaperButton` with the file path, so the normal set sheet and history apply.
- **Delete** asks "Delete this download?" or "Delete N downloads?". After the user confirms, the screen calls `deleteDownload(path)` for each file. Then it reads the list again. If some deletes fail, the toast is "Could not delete N downloads."
- **Share** sends the files with the system share sheet.
- After a delete, `DownloadedWallIndex.forget` drops the entries of the deleted files. An entry stays while another copy of the file (`name (1)`) is still on the device. `DownloadedWallIndex.clear()` forgets every entry. Settings **Clear downloads** and the account wipe call it. `DownloadedWallIndex.has(link)` tells whether a link was downloaded before. The file may be gone, so a caller that charges for a download must also check the file list.
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
- The Favourites query has no limit and no pagination. It loads every favourite in one read. The sync listener reads every favourite once per session.
- A guest who saves more than 200 walls loses the oldest one. A guest who never signs in loses the list when the app is removed.
- An offline save shows as saved at once, but the server gets it only when the network returns. If the user clears the app data before that, the save is lost.
- Favourites saved before this change have no `favouritedAt`. They sort by `createdAt`, which is the upload date for Prism walls.
- The merge cannot see server docs that are not in the device cache when the device is offline. It then writes the guest doc over a server doc with the same wall id. The wall data is the same.
- The Downloads sort uses the file modified time, not the time of the download. A file copied back to the device keeps its old time. The host list order (MediaStore `DATE_ADDED`, file modified time or creation date) is only the tie-break.
- The Downloads sort choice is not saved. It resets to **Newest** each time the tab opens.
- The History tab does not embed the history list. It opens the history screen. The list needs a body widget without its own app bar before it can sit in the tab.
- **Recently set** shows the last 8 different images. It does not show which screen got the wallpaper.
- The Offline chip trusts the connectivity check, which runs every 20 seconds. It can lag behind a real change.
- **Export favourites** has no import. It also exports the legacy favourites with the fields they already have.
- A guest with an empty list sees "No favourites yet", not the sign-in prompt, because a guest can save favourites on the device.
- Downloads has no **Favourite** action for a selected file yet.

## How to test

1. Sign in. Favourite 4 wallpapers from Prism, Wallhaven, and Pexels.
2. Open the profile drawer and tap **Library**. Make sure it is one entry and the Favourites tab shows.
3. Tap a source chip. Make sure the grid shows only that source.
4. Type a creator name. Make sure the grid narrows. Tap the X button to clear it.
5. Open the **Sort** menu and choose Oldest. Make sure the order flips.
6. Long press a tile. Tap one more tile. Tap **Remove from favourites**. Make sure the snackbar shows. Tap **Undo**. Make sure the walls return.
7. On Android, select two walls and tap **Set**. Make sure the first wall you picked is set.
8. Download 3 wallpapers. Open the **Downloads** tab. Make sure the toolbar shows "3 downloads" and a size.
9. Long press a tile and tap **Delete**. Tap **Delete** in the dialog. Make sure the file leaves the list and the device gallery (Android) or the app folder (iOS).
10. On iOS, make sure the newest download is first.
11. Turn on airplane mode and pull to refresh Favourites. Make sure the loaded items stay.
12. Sign in on two devices. Favourite a wallpaper on device A. Make sure the heart on device B fills without a reload.
13. Turn on airplane mode. Tap a heart. Make sure it fills at once and the loader ends in 8 seconds. Turn the network on. Make sure the wall shows on the other device.
14. Sign out. Tap the heart on 3 wallpapers. Make sure no sign-in prompt shows and the nudge toast shows after the 3rd. Sign in. Make sure the 3 walls are in Favourites.
15. Favourite a Pexels wallpaper. Open Favourites with Recently added. Make sure it is first.
16. On Android, set two wallpapers. Open Library. Make sure **Recently set** shows both. Tap one. Make sure the set sheet opens.
17. Swipe to **Downloads**, then **History**. Make sure the tab changes and, in the analytics debug log, `library_tab_changed` shows `downloads` then `history`. Tap **Open history**. Make sure the history screen opens. On iOS, make sure there is no History tab.
18. Turn on airplane mode. Make sure the **Offline** chip shows in the app bar. Turn it off. Make sure the chip goes away.
19. In Favourites, open the three-dot menu and tap **Clear all favourites**. Make sure the dialog shows the count and "This removes them from your account." Confirm. Make sure the list is empty and **Undo** brings it back.
20. Open the three-dot menu and tap **Export favourites**. Make sure the share sheet shows a `prism-favourites-<date>.json` file. Open the file. Make sure it lists the favourites.
21. Block the image host on a test device (or use a favourite with a dead link). Make sure the tile shows "Unavailable" and **Remove** takes it out.
22. In Downloads, open the **Sort** menu. Choose Oldest, then Name. Make sure the order changes. Long press one file. Make sure **Set as wallpaper** shows on Android and sets that file.
23. Sign out and open `/fav-walls` or Library with 2 saved guest favourites. Make sure the banner shows. Tap **Dismiss**. Make sure it goes.

Automated tests:

- `test/features/favourite_walls/fav_grid_test.dart`
- `test/features/favourite_walls/biz/bloc`
- `test/features/favourite_walls/domain/favourite_view_test.dart`
- `test/features/favourite_walls/data` (repository, sync service, guest store, guest merge)
- `test/features/favourite_walls/fav_wallpaper_button_test.dart`
- `test/features/favourite_walls/favourite_walls_bloc_adapter_test.dart`
- `test/features/navigation/home_tab_push_test.dart`
- `test/features/favourite_walls/favourite_quick_tile_listener_test.dart`
- `test/features/favourite_walls/legacy_favourite_thumbnail_test.dart`
- `test/features/wallpaper_detail/views/pages/download_screen_test.dart`
- `test/features/wallpaper_detail/data/downloaded_wall_index_test.dart`
- `test/features/library`
- `test/features/public_profile/drawer_library_entry_test.dart`

Command:

```sh
fvm flutter test --no-pub test/features/favourite_walls test/features/library test/features/wallpaper_detail/views/pages/download_screen_test.dart test/features/wallpaper_detail/data/downloaded_wall_index_test.dart test/features/public_profile/drawer_library_entry_test.dart
```
