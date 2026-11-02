# Notifications inbox

In-app notification list at route `/notifications` (`NotificationRoute`, `lib/features/in_app_notifications/views/pages/notification_screen.dart`). Reached from the bell in the top app bar (`features/home-feed.md`) and from a real push tap (`lib/core/router/notification_route_mapper.dart`).

## Sub-features

- `bell`: Semantics `Open notifications` (`excludeSemantics`). The inner icon tooltip is `Notifications`.
- `list`: rows are grouped by title and can expand. Row semantics are `<summary>. <time>. Already read` or `<summary>. <time>. Not read yet` (`notification_row.dart`). A group reads `<title>. <n> notifications · Show all. Collapsed. Has unread. Activate to expand.`
- `toolbar`: tooltips `Mark all as read` (only with unread items), `Notification preferences`, `Clear inbox` (only with items). Back tooltip is `Back`. There is no `Close`.
- `remove`: swipe a row to delete it. A snackbar `Notification removed` has `Undo`.
- `clear-inbox`: confirm `Clear this notification?` or `Clear {n} notifications?` with confirm `Clear inbox`. Then snackbar `Inbox cleared` with `Undo`.
- `preferences`: sheet `Notification preferences` with toggles `Wall of the Day`, `Weekly Drops`, `Followers`, `Posts`, `Folders you follow`, `Recommendations`, `Streak reminders` (`notification_settings_sheet.dart`), and a `Close` button. On iOS the `Wall of the Day` switch is announced as `1`, not by its title; the other switches carry their title.
- `states`: a skeleton while loading (no label). Empty: `No notifications`. Error: `We couldn't load your notifications` with `Try again`. A stale banner (`Couldn't load new notifications...`) also has `Try again`.
- `push-routing`: `wall` and `wall_of_the_day` open the wallpaper. `streak_reminder` and `rewards` open `/dashboard/rewards`. `follower` opens the user's `ProfileRoute`. `announcement` opens this inbox. Only `wall_of_the_day` falls back to Home. A `wall` push for a missing wall shows the toast `That item is no longer available` and opens the inbox.

## How to get to it (user POV)

- Tap `Open notifications` in the top app bar.
- Tap a push banner (background or terminated) or an in-app push.

## Driving it with the helper

Preconditions:

- A signed-in human, since the inbox is per account. `SKIP_FIREBASE_INIT=true` builds get no real pushes. Use Doppler dev secrets for push routing.

- **Open inbox.** Tap `Open notifications`. Snapshot `--tag notifications`. Assert `Notification preferences` and `Back`.
- **Preferences.** Open the sheet and assert the toggle names. Do not flip a toggle on a real account without the human.
- **Read a row.** Tap a row. A Folder notification opens that Folder (or `This folder is private or no longer exists`). A row whose target cannot resolve opens `NotFoundRoute`. Check the label flips from `Not read yet` to `Already read`.
- **Clear inbox.** Tap `Clear inbox` and assert the confirm. Cancel unless the recipe is about clearing.
- **Push routing.** Have a real push sent for each `route`. Confirm the screen above. Pushes to other accounts need the human's go-ahead.
- **Proof.** Snapshot loaded, empty, and error states.

## Gotchas

- `Clear inbox` and swipe delete remove items from the device. Use `Undo` at once, or use a disposable account.
- The mapper reads the wall from Firestore first (`_mapWallAction`). A deleted wall is not a bug.
- An empty inbox under `SKIP_FIREBASE_INIT=true` is not a bug.
