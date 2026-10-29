# Library and Folders

The Library (`/library`, `LibraryRoute`) holds Favourites, Folders, Downloads and History in one tabbed page (`lib/features/library/views/pages/library_screen.dart`). A Folder is a user collection of favourites (`/folder/:folderId`, `FolderRoute`, `lib/features/folders/views/pages/folder_screen.dart`). Old routes `/fav-walls` and `/downloads` still exist (`lib/core/router/app_router.dart`).

## Sub-features

- `library-tabs`: tabs `Favourites`, `Folders`, `Downloads`, `History`. `History` is hidden on iOS (`hideSetWallpaperUi`, `libraryTabs()`). The deep link `?tab=folders|downloads|history|favourites` picks the tab. Tabs read `Favourites, Tab 1 of 3` on iOS and `... of 4` on Android.
- `favourites`: header `N favourites` (or search hint), button tooltip `Sort and filter`, menu tooltip `More favourites actions` with `Export favourites` and `Clear all favourites` (`lib/features/favourite_walls/views/widgets/fav_grid.dart`).
- `folders`: `FoldersGrid`. App bar button `New folder` (signed in only) opens a sheet titled `New folder` with the field `Folder name` and the button `Create` (disabled until you type).
- `folder-detail`: menu tooltip `More options` with `Rename`, `Make public` or `Make private`, `Delete`. `Delete` asks `Delete <name>?` (`The wallpapers stay in your favourites.`) with `Delete folder` and `Cancel`. Long-press a wallpaper to get the confirm `Remove from this folder?`.
- `save-to-folder`: sheet `Save to folder` (`folder_sheet.dart`): `Close`, a new-folder field with `Create folder`, one switch per Folder (`<name>, N wallpapers`), and `Done`.
- `public-folders`: public Folders show on profiles (`profile_folders_row.dart`).

## How to get to it (user POV)

- Own profile drawer, group `Your content`, row `Library` (`drawer_widget.dart`).
- Settings rows `Wallpaper history` (opens `History`) and the export favourites row (opens `Favourites`) (`settings_screen.dart`).
- On a wallpaper detail page, long-press the Favourite heart. The `Save to folder` sheet opens (`fav_wallpaper_button.dart`).
- The bottom nav tab `Collections` is NOT the Library. It is the category feed (`CollectionTabPage` > `CollectionScreen`).
- `/folder/:folderId` has `_signedInGuard`. `/library`, `/fav-walls`, `/downloads` have no guard.

## Driving it with the helper

Preconditions: signed in (ask the human). At least one favourite for most checks.

- **Library.** Open the drawer, tap `Library`. Assert the title `Library` and the tabs. On iOS assert `History` is absent.
- **Create.** Tap `Folders`, tap `New folder`, type a name with `type`, tap `Create`. Snapshot `--tag folders-created`.
- **Detail.** Tap the Folder card. Tap `More options`, then `Make public`. Stop at the confirm text `Make this folder public?` unless the human agrees.
- **Remove.** Long-press a wallpaper, assert `Remove from this folder?`, tap `Remove`.
- **Delete.** `More options` > `Delete` > `Delete folder` (title `Delete {name}?`). Delete only a Folder this run made.

## Gotchas

- Signed out: `/folder/:folderId` redirects to onboarding. Folders and Favourites show a sign-in prompt (`SignInPrompt`).
- `Make public` is a real public write. A name may be refused (`Rename this folder to make it public.`).
- A pin icon on Favourites was not found in source (`fav_grid.dart` has none). Do not plan a pin step.
- No Folder entry was found in `lib/features/auto_rotate` at this commit.
- Confirm every label with `describe` before tapping.
