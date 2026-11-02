# Home feed

Home is the first tab of the dashboard (route `/dashboard/home`, `HomeTabRoute`, `lib/features/navigation/views/pages/home_tab_page.dart`). The screen is `lib/features/personalized_feed/views/pages/personalized_feed_screen.dart`. It shows a carousel, mood rows and five feed tabs under a shared top bar and bottom nav.

## Sub-features

- `bottom-nav` has 4 tabs: `Home`, `Search`, `Rewards`, `Collections` (`prism_bottom_nav.dart`, `lib/l10n/app_en.arb`). The Rewards tab is `RewardsTabRoute` (`/dashboard/rewards`); `/dashboard/streak` redirects to it. The nav hides on scroll. A `Scroll to top` button shows (`bottom_nav_bar.dart`). Tap the active tab to pop to its root.
- `top-bar` has `Your profile` (avatar), the `Prism` wordmark and `Open notifications` (`prism_top_app_bar.dart`). There is no `Feed settings` button.
- `feed-tabs` are `For you`, `Following`, `Trending`, `Latest`, `Popular` (`home_feed_tab_bar.dart`). `Following` shows a sign-in prompt when signed out.
- `feed-settings`: tap the already-selected tab (hint `Double tap to open feed settings`). The sheet `Tune your feed` has `Starting points`, `Discovery` with `Familiar`, `Balanced`, `Adventurous`, `Retake This or that`, `Learned from you` with `Clear`, `Reset`, `Save` (`personalized_feed_settings_bottom_sheet.dart`).
- `carousel` (`feed_carousel.dart`): the Wall of the day card with a `Past picks` pill and `See past walls of the day` (opens `/wotd-archive`). A `Weekly Drop` slide opens `/drops`.
- `moods`: a `Moods` chip row (`Dreamy`, `Dark and quiet`, `Bright and bold`, and more; `Spatial ready` and `Depth ready` on iOS only) opens `/mood/:id`. Mood rows have `See all` (`lib/features/moods/views/widgets/`).
- `quick-actions`: hold a tile to open a radial icon menu: `Save to folder`, `Favourite`, `Share link`, `Show less like this` (`wallpaper_quick_actions.dart`, `wallpaper_hold_region.dart`). The menu shows only while the finger stays down. Release on an icon to pick it; release anywhere else closes it. `Show less like this` shows an undo toast.
- `collections`: the `Collections` tab (`/dashboard/collection`, `CollectionTabRoute`, `collection_tab_page.dart`) lists cards labelled `Collection, <name>` (for example `Collection, Space`). A card pushes `/collection-view` (`CollectionViewRoute`), titled with the collection name.
- `fab` `Upload` (`prism_fab.dart`). Signed out, it opens sign-in first. Signed in, it opens the `Create` sheet. See `features/upload.md`.

## How to get to it (user POV)

- Home is the default tab after sign-in. Tap `Home` to return.
- Tap `Open notifications` for the inbox (`features/notifications.md`). Tap `Your profile` for the profile (`features/profile.md`).
- Tap a tile to open `features/wallpaper-detail.md`.

## Driving it with the helper

Preconditions: app launched (`verify-prism launch --platform <p>`). Home does not need a session. Personalization does.

- **Land.** Snapshot `--tag home`. Assert nav labels `Home`, `Search`, `Rewards`, `Collections`.
- **Tabs.** Tap `Following`. Signed out, assert the sign-in prompt. Tap `For you` to go back.
- **Feed settings.** With `For you` selected, tap `For you` again. Assert `Tune your feed`, `Familiar`, `Balanced`, `Adventurous`. Snapshot `--tag home-feed-settings`. Close without `Save` unless the recipe tests personalization.
- **Moods.** Tap `Dreamy`. Assert the mood page opens. Go back.
- **Quick actions.** The menu closes on release, so `describe` never sees it. Record it: `agent-device record start`, hold a tile for 3 s, `record stop`, then pull frames with `ffmpeg -sseof -3 -i <clip> -vf fps=1,tile=3x1`. Assert four icons around the tile. Do not pick `Show less like this` on a shared account.
- **Collections.** Tap `Collections`. Tap `Collection, Space`. Assert the title `Space` and a grid.
- **Grid tap.** Tap the first tile (Android: `content-desc`, else `--x/--y` from `describe`). Confirm `WallpaperDetailRoute` opens.
- **Proof.** Snapshot before and after each sheet or navigation.

## Gotchas

- `SKIP_FIREBASE_INIT=true` builds can show an empty feed. Use Doppler dev secrets for a real feed.
- Only the iOS build shows `Spatial ready` and `Depth ready` (`moods_cubit.dart`).
- The carousel may not show a Weekly Drop or a Wall of the day without backend data.
- Tiles read `Wallpaper by <name>` (or `Wallpaper`), with a switch `Favourite, <n> favourites` and a `<n> views` text. Tap a tile by its `Wallpaper by <name>` label.
