# Notifications inbox

In-app notification list, route `/notifications` (`NotificationRoute`, `lib/features/in_app_notifications/views/pages/notification_screen.dart`). Reached from the `Open notifications` icon in the top app bar (`features/home-feed.md`), and from tapping a real push notification (`notification_route_mapper.dart`).

## Sub-features

- `list`: each row has a combined semantic label `<summary>. <time>. Already read` or `<summary>. <time>. Not read yet`.
- `loading` / `error`: `Loading notifications` label while loading; `Try again` retry button on failure.
- `preferences`: tooltip `Notification preferences` opens notification settings.
- `clear-inbox`: tooltip `Clear inbox`, with a confirm dialog.
- `close`: tooltip `Close`.
- `push-routing`: a tapped push with `data.route` of `wall` or `wall_of_the_day` opens the wallpaper detail (falling back to Home if the wall was deleted); `streak_reminder` opens the profile tab; `follower` opens the follower's `ProfileRoute` (or the inbox itself if no identifier is present); `announcement` opens this inbox (`lib/core/router/notification_route_mapper.dart`).

## How to get to it (user POV)

- Tap `Open notifications` in the top app bar.
- Tap a real push notification banner (background/terminated) or an in-app foreground push.

## Driving it with the helper

Preconditions:

- Signed-in human, since the inbox is per-account. `SKIP_FIREBASE_INIT=true` builds will not receive real pushes; use Doppler dev secrets to test push routing end to end.

- **Open inbox.** Tap `Open notifications`. Snapshot `--tag notifications`. Assert the tooltip `Close` and `Notification preferences`.
- **Read a row.** Tap a notification row; confirm it routes per `notification_route_mapper.dart` (wallpaper detail, profile, or the inbox itself depending on type) and its semantic label flips from `Not read yet` to `Already read` on return.
- **Clear inbox.** Tap `Clear inbox`; assert a confirm dialog appears. This permanently removes the account's notification history; only confirm it when the recipe is specifically about that action, and prefer a disposable QA account.
- **Push routing (needs a human or a real push).** Send yourself (or have the human send) a real push of each `route` value (`wall`, `wall_of_the_day`, `streak_reminder`, `follower`, `announcement`) and confirm it lands on the screen `notification_route_mapper.dart` predicts. Sending a push to any account other than the QA account's own needs the human's go-ahead first, per the project's "never message a real user without asking" rule.
- **Proof.** Snapshot the inbox in loaded, empty, and (if reproducible) error states.

## Gotchas

- `Clear inbox` is destructive and not undoable from inside the app; do not run it against an account with notification history the human cares about.
- Push routing logic looks up the wall by id in Firestore (`notification_route_mapper.dart:_mapWallRoute`) before deciding where to send the user; a `wall`/`wall_of_the_day` push for a wall that no longer exists correctly falls back to Home, that is not a bug.
- This screen needs live Firestore data to be meaningful; do not report an empty inbox as broken under a `SKIP_FIREBASE_INIT=true` build.
