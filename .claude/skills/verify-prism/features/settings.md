# Settings

Route `/settings` (`SettingsRoute`, `lib/features/session/views/pages/settings_screen.dart`). Works both signed in and signed out (a signed-out user sees a `Sign in` row instead of account rows).

## Sub-features

- `appearance`: `Themes` row (opens `/theme`, `ThemeViewRoute`, subtitle `Accent colours, light & dark themes`).
- `content-toggles`: `Show Anime Wallpapers`, `Show Sketchy Wallpapers` (both `SwitchListTile`).
- `download-quality`: row `Download Quality`, opens a picker with `Original` (`Full resolution, larger file size`) and `Compressed` (`Smaller file size, slightly reduced quality`).
- `alerts`: `Wall of the Day` (`Daily wallpaper recommendation alert`) and `Promotional Alerts` (`New features, events & announcements`), both switches.
- `quick-tile-settings`: row `Quick Tile Settings`, opens `/quick-tile-settings` (`Configure Android Quick Settings tiles`, Android-only feature).
- `storage`: `Clear Cache` (`Clear locally cached images`), `Clear all Downloads` (`Remove all downloaded wallpapers`).
- `account-signed-out`: `Sign in` row (`Sign in to sync data across devices`) when there is no session.
- `account-signed-in`: identity row (`prismUser.name` / `prismUser.email`), `Review Status` (`Track your submitted wallpaper reviews`), `Blocked accounts` (`Manage users you have blocked`), `Share your Profile` (`Share a link to your Prism profile`), `Clear favourite walls` (`Remove all favourite wallpapers`), `Restore Purchases` (`Restore a previously purchased subscription`), `Delete Account` (red text, `Permanently delete your account and data`), `Logout` (accent-colored, subtitle is the account email).

## How to get to it (user POV)

- Reached from the profile tab or a settings icon; exact entry affordance was not traced for this map, confirm with `describe` on the profile screen.

## Driving it with the helper

Preconditions:

- Works signed in or out; drive the signed-out row set first (safe), then ask the human to sign in for the account rows.

- **Landing.** Snapshot `--tag settings`. Assert `Themes`, `Download Quality`, `Clear Cache`, `Clear all Downloads`.
- **Toggles.** Flip `Show Anime Wallpapers`, `Show Sketchy Wallpapers`, `Wall of the Day`, `Promotional Alerts` and confirm each switch's state persists across a re-open of the screen. Leave them as you found them unless the recipe is specifically about a toggle's effect.
- **Download quality.** Tap `Download Quality`; assert `Original` and `Compressed` options with their subtitle copy; pick one and confirm the row's subtitle updates.
- **Storage actions.** `Clear Cache` and `Clear all Downloads` are destructive to local device state only (not the account); safe to exercise, but note that `Clear all Downloads` removes files a real user saved, so avoid it against a device with downloads the human wants kept.
- **Signed-out.** Assert `Sign in` row routes to onboarding (`features/onboarding-signin.md`).
- **Signed-in account rows.** Assert `Review Status`, `Blocked accounts`, `Share your Profile`, `Restore Purchases` render. Do **not** tap `Delete Account` or `Logout` in an automated recipe; both are terminal, real-account actions (deletion is permanent; logout drops the session you may still need). Only exercise them when the recipe is specifically about that flow, against a disposable QA account, with the human's confirmation.
- **Clear favourite walls.** Removes all real favourites for the signed-in account; treat like any other destructive account action.
- **Proof.** Snapshot the top of the settings list and the download-quality picker; note any row you deliberately did not tap and why.

## Gotchas

- `Delete Account`, `Logout`, and `Clear favourite walls` are real, hard-to-undo account actions. Default to asserting they render correctly rather than completing them.
- `Quick Tile Settings` is Android-only (Android Quick Settings tiles); expect it to be absent or a no-op on iOS.
- The entry point into `/settings` from the rest of the app was not traced for this map; find it with `describe` before writing a "tap into settings" step for a longer recipe.
