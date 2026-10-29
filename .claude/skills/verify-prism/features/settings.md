# Settings

Route `/settings` (`SettingsRoute`, `lib/features/session/views/pages/settings_screen.dart`). It works signed in and signed out. Labels are sentence case. Seasonal decorations (Spooky web, spider, Diwali diya) can overlap the top right corner.

## Sub-features

- `account-card` (`settings_account_card.dart`): `Sign in to Prism` when signed out, `Open your profile` when signed in.
- `Account` (signed in only): `Review status`, `Blocked accounts`, `Share your profile`.
- `Appearance`: `Themes` (`Light, dark and accent colour`), `Shop`, `Haptic feedback`.
- `Personalise`: iOS has `Widgets` and `Change automatically`. Android has `Quick tiles`, `Auto-rotate wallpapers`, `Live wallpapers`, `Wallpaper history`, `Default action for Set`.
- `Content`: `Show anime wallpapers`. `Show sketchy wallpapers` is not on iOS.
- `Notifications`: `Notification preferences` opens the sheet (see `features/notifications.md`).
- `Storage`: `Data saver`, `Clear cache`, `Clear all downloads`, `Saved offline`, `Clear favourite wallpapers` (signed in).
- `Purchases`: `Buy premium` or `Manage subscription`, `Restore purchases`.
- `Privacy and data`: `Privacy policy`, `Terms of use`, `Clear learned taste`, `Export favourites`, `Ad privacy choices`.
- `Admin` (admin only): `Debug panel` and moderation rows.
- `Help`: `Report a problem`, `About Prism`.
- `session` (signed in): `Log out` and `Delete account`.
- There is no `Download Quality` row.

## How to get to it (user POV)

- Signed out: the Profile page shows a `Settings` icon in its top bar (`profile_screen.dart`).
- Signed in: open your profile, tap `Menu`, then `Settings` (`drawer_widget.dart`).
- Deep link `/settings` (`lib/core/router/deep_link_route_catalog.dart`).

## Driving it with the helper

Preconditions:

- Works signed in or out. Drive the signed-out rows first. Ask the human to sign in for the rest.

- **Landing.** Snapshot `--tag settings`. Assert `Sign in to Prism` (or `Open your profile`), `Themes`, `Notification preferences`, `Clear cache`.
- **Scroll.** The list is long. Scroll to assert `Privacy and data`, `Help`, and the last group.
- **Toggles.** Flip `Haptic feedback` and `Show anime wallpapers`, re-open the screen, and confirm the state stays. Restore them after.
- **Navigation rows.** `Themes` opens `/theme`. `Notification preferences` opens a sheet. Go back after each.
- **Signed out.** The card button starts sign-in (`features/onboarding-signin.md`).
- **Proof.** Snapshot the top of the list and the group you tested. Name each row you did not tap.

## Gotchas

- Never drive `Log out`, `Delete account`, or the confirm of `Clear cache?`. Assert that the rows exist.
- `Clear all downloads` (confirm `Delete all downloads?`) removes real saved files. `Clear favourite wallpapers` removes real favourites. Cancel the confirm.
- The delete flow is a danger sheet with `Cancel`. Cancel only if you must open it.
- Row presence depends on platform, sign-in state, and admin flag. Check `describe` before you assert.
