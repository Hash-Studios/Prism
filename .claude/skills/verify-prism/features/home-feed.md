# Home feed

Home is the first tab of the dashboard (route `/dashboard/home`, `HomeTabRoute`, `lib/features/navigation/views/pages/home_tab_page.dart`). It shows a wallpaper grid sourced from Prism's own catalog, Wallhaven, or Pexels (`lib/features/prism_feed`, `lib/features/wallhaven_feed`, `lib/features/pexels_feed`, plus `personalized_feed` and `category_feed`), under a shared top app bar and bottom nav.

## Sub-features

- `bottom-nav` shows 4 tabs: `Home`, `Search`, `Streak`, `Collections` (`lib/features/navigation/views/widgets/prism_bottom_nav.dart`). There is no bottom-nav Profile tab; profile is reached from the top app bar.
- `top-bar` shows `Feed settings`, `Open notifications`, and `Your profile` (`lib/features/navigation/views/widgets/prism_top_app_bar.dart`).
- `fab` shows `Upload` (`lib/features/navigation/views/widgets/prism_fab.dart`), for uploading a wallpaper.
- `feed-settings` sheet (`personalized_feed_settings_bottom_sheet.dart`) offers `Balanced`, `Creators`, `Discovery` feed modes.
- `wallpaper-grid` opens a wallpaper's detail screen on tap.

## How to get to it (user POV)

- Land on Home by default after sign-in, or by tapping the `Home` tab.
- Tap `Feed settings` (top bar) to open the mode sheet.
- Tap `Open notifications` to go to the notifications inbox (see `features/notifications.md`).
- Tap `Your profile` to go to the profile tab (see `features/profile.md`).
- Tap a wallpaper tile to open `features/wallpaper-detail.md`.

## Driving it with the helper

Preconditions:

- App launched (`verify-prism launch --platform <p>`), signed in or out (Home itself does not require a session; feed personalization does).

- **Land on Home.** Snapshot `--tag home`. Assert the bottom nav labels `Home`, `Search`, `Streak`, `Collections`.
- **Feed settings.** Tap `Feed settings`. Assert `Balanced`, `Creators`, `Discovery`. Snapshot `--tag home-feed-settings`. Close without changing the mode unless the recipe is specifically about feed personalization.
- **Notifications.** Tap `Open notifications`; see `features/notifications.md` for what should render there.
- **Grid tap.** Tap the first wallpaper tile (Android: match by `content-desc` or fall back to `--x/--y` on the tile bounds from `describe`, since tiles may not carry unique text). Confirm `WallpaperDetailRoute` opens (see `features/wallpaper-detail.md`).
- **Proof.** Snapshot before and after opening a sheet or navigating, not only the final frame.

## Gotchas

- `SKIP_FIREBASE_INIT=true` builds may show an empty or stalled grid if the feed reads Firestore/CDN data that init-skip disables. If the grid looks empty, check whether this is a UI-only build before reporting a bug; use Doppler dev secrets to get a real feed.
- Home's own feature folder is thin; the actual tab page lives under `lib/features/navigation/views/pages/home_tab_page.dart`, and the grid rendering is split across `prism_feed`, `wallhaven_feed`, `pexels_feed`, `personalized_feed`, and `category_feed`. Check the right folder for the source you are trying to verify (Prism catalog vs. Wallhaven vs. Pexels) rather than assuming one file owns the whole feed.
- Tile-level accessibility labels were not read in detail while building this map; confirm with `describe` before writing a tap recipe against a specific tile.
