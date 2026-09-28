# Wallpaper detail

Full-screen wallpaper viewer, route `/wallpaper-detail` (`WallpaperDetailRoute`, `lib/features/palette/views/pages/wallpaper_detail_screen.dart`). Despite the route/bloc living under `lib/features/wallpaper_detail`, the actual screen and action buttons live under `lib/features/palette` and `lib/core/widgets/menu_button`; check both when you need source, not just the folder with the matching name.

## Sub-features

- `favourite` toggles a heart (`lib/core/widgets/menu_button/fav_wallpaper_button.dart`, label `Favourite`).
- `set-wallpaper` opens a `Set Wallpaper as` sheet with `Home Screen`, `Lock Screen`, `Both` (`lib/core/widgets/menu_button/set_wallpaper_button.dart`, button label `Set as wallpaper`).
- `share` (`lib/core/widgets/menu_button/share_button.dart`, label `Share`).
- `edit` (`lib/core/widgets/menu_button/edit_button.dart`, label `Edit`; pushes another route via `context.router.push`, guarded, may need sign-in/ownership).
- `report` (label `Report`, flag icon, in `wallpaper_detail_screen.dart` near line 1089).
- `download` route: `/download-wallpaper` (`DownloadWallpaperRoute`, `lib/features/palette/views/pages/download_wallpaper_screen.dart`).
- Collapsible info panel: `Expand wallpaper details` / `Collapse wallpaper details` toggle, showing collection, category, resolution, date, source (`Prism` or `Pexels`), views, and favourite count.

## How to get to it (user POV)

- Tap any wallpaper tile from Home, Search, or a profile's wallpaper grid.
- Deep link `prismwalls.com/share/<id>?...` also lands here (see `features/deep-links.md`).

## Driving it with the helper

Preconditions:

- Home or search feed is showing (see `features/home-feed.md` / `features/search.md`), or a deep link has been opened.

- **Open detail.** Tap a wallpaper tile. Snapshot `--tag wallpaper-detail`.
- **Info panel.** Tap the label `Expand wallpaper details` (or `Collapse wallpaper details` if already expanded). Confirm resolution/category/source rows render.
- **Favourite.** Tap `Favourite`. Confirm the icon/state flips (`JamIcons.heart_f` fill state) and, if signed in, that the wallpaper now shows up under Settings → `Clear favourite walls` scope or the Favourites collection tab. Toggle back off unless the recipe wants to leave it favourited.
- **Set as wallpaper.** Tap `Set as wallpaper`. Assert the sheet title `Set Wallpaper as` and the three options `Home Screen`, `Lock Screen`, `Both`. **Do not actually confirm** unless the recipe is specifically about the platform wallpaper-manager integration; it changes the simulator/emulator's real home or lock screen image, which is disruptive to the test device and not undoable from inside the app. Dismiss the sheet instead (back gesture / tap outside) and note in the proof that the terminal action was intentionally not taken.
- **Share.** Tap `Share`. This opens the OS share sheet; dismiss it (`Cancel`/back) rather than actually posting anywhere.
- **Edit.** Tap `Edit` only when the wallpaper is the signed-in user's own upload; this is a guarded, ownership-checked action.
- **Report.** Tap `Report` (flag icon). Confirm a report flow/sheet opens; do not submit a report against a real wallpaper unless the recipe is specifically testing that path, and prefer a test upload over a real user's content.
- **Download.** Navigating to `/download-wallpaper` starts a real device download; confirm the flow reaches a save/progress state without necessarily letting a large file finish if bandwidth is a concern.

## Gotchas

- "Set as wallpaper" and "Download" both have real, hard-to-undo side effects on the QA device (changing its actual background, writing files to its gallery). Prefer asserting the sheet/labels appear correctly over completing the action, unless the bug you are reproducing is specifically in that terminal step.
- The three set-wallpaper option labels (`Home Screen`, `Lock Screen`, `Both`) are plain `Text` widgets inside `GestureDetector`s, not buttons with semantic labels; on Android, target them by `text`, and on iOS confirm with `describe` that `axe` picks them up by label (custom-drawn `Container`+`Text` combos sometimes need `--element-type` or coordinates).
- `Report`'s destination screen was not read in detail while building this map; confirm its exact copy with `describe` before writing assertions against it.
