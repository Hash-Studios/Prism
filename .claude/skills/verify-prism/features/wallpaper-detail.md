# Wallpaper detail

Full-screen wallpaper viewer, route `/wallpaper-detail` (`WallpaperDetailRoute`). The screen is `lib/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart`. The action bar is `views/widgets/wallpaper_action_bar.dart`. Button widgets live in `lib/core/widgets/menu_button/`. The Set screen is `views/widgets/clock_overlay.dart`.

## Sub-features

- `favourite`: label `Favourite` (`fav_wallpaper_button.dart`), with a count label such as `12 favourites`. Long-press opens the `Save to folder` sheet.
- `share`: label `Share` opens the in-app share card sheet (`lib/core/share/share_sheet.dart`). Formats `Story`, `Post`, `Clean` are swipe pages; the tree shows only the selected page and its neighbour. Targets are `Copy link`, `Save image`, `More`. `Instagram` shows only when Instagram is installed, so not on the QA sim.
- `edit`: label `Edit`. Needs sign-in, then pushes `WallpaperFilterRoute`.
- `download`: label `Download` (Android only).
- `set`: pill text `Set`, tooltip `Set as wallpaper`. It opens a full-screen Set screen. See Driving.
- iOS (`hideSetWallpaperUi`, `lib/core/platform/wallpaper_capability.dart`): the primary pill is `Save` (tooltip `Save to Photos`). When the save costs coins its label is `Save. Costs 10 coins`. There is no `Download` icon and no `Make it live`.
- `phone-preview`: tooltip `Preview on your screen`. Controls: `Hide controls`, `Show controls`, `Icon style`, `Preview in 3D`, `Close preview`. On iOS the tree shows `Lock`, `Home`, `Close preview`, a `Preview in 3D` switch and `Save to Photos. Costs 10 coins`.
- `details-panel`: toggle `Expand wallpaper details` / `Collapse wallpaper details`. Rows: views, favourites, category, resolution, size, date, source (Prism, Wallhaven, Pexels), tags. It also has `Report` (Prism walls only), `Block creator`, and `Make it live` (Android).
- `swatches`: colour swatches. Long-press copies the hex code.
- `feed-swipe`: custom actions `Next wallpaper` and `Previous wallpaper`. Related walls show below.
- `/download-wallpaper` (`DownloadWallpaperRoute`) is a viewer for a saved local file. It is not the download action.

## How to get to it (user POV)

- Tap a wallpaper tile on Home, Search, or a profile grid.
- A deep link `prismwalls.com/share/<id>` also lands here (`features/deep-links.md`).

## Driving it with the helper

Preconditions: a feed or search result is showing, or a deep link is open.

- **Open.** Tap a tile. Snapshot `--tag wallpaper-detail`.
- **Details.** Tap `Expand wallpaper details`. Assert the rows render.
- **Favourite.** Tap `Favourite`. Assert the count label changes. Toggle back.
- **Save to folder.** Long-press `Favourite`. Assert `Save to folder`. Dismiss.
- **Set (Android only).** Tap `Set as wallpaper`. Assert `Where to set it`, `Home screen`, `Lock screen`, `Both`, `Remember this choice`, `Adjust`, `More`. Do NOT tap `Set on home screen` or its siblings. Close the screen and note the skip in the proof.
- **Share.** Tap `Share`. Assert `Story`, `Copy link`, `Save image`, `More`. Tap `Close`. Do not tap `More`.
- **Phone preview.** Tap `Preview on your screen`. Assert `Close preview` and `Preview in 3D`. Tap `Close preview`.
- **Edit and Report.** Tap `Edit` only on your own upload. Open `Report` but do not submit on a real wall.

## Gotchas

- Set and Download change the QA device. Prefer to assert the labels only.
- `Report` shows on Prism walls only. Confirm `Report` and `Block creator` with `describe`.
- `Make it live` shows only on Android and needs a full-size URL.
- Share, Set and preview labels differ by platform. Run `describe` first.
- On Android the image label is `Wallpaper, Hold for favourite, share, and reset actions. Scroll for details.`
