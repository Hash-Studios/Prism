# Notifications

Prism sends push notifications and keeps an inbox in the app. The user decides which pushes to get in one preferences sheet.

## Where to find it

| Place | How to open it |
|---|---|
| Inbox | `NotificationScreen` (route `NotificationRoute`). Opens from the top app bar and from a push tap. |
| Preferences sheet | Inbox app bar, icon with tooltip "Notification preferences". Settings, section NOTIFICATIONS, row "Notification preferences". |
| Permission prompt | Runs once after a first value action (see "Post-onboarding prompt"). |

Both entry points call `showNotificationSettingsSheet`. There is one sheet. Settings and the inbox do not have separate lists.

## Platforms

| Platform | Notes |
|---|---|
| Android | Full support. The OS permission can be `denied` before the first ask, so the app can ask again. The banner opens the app notification settings. |
| iOS | Full support. `provisional` access delivers quietly, so the app can still ask for full access. The banner opens `app-settings:`. The app badge clears when the app becomes active (`ios/Runner/AppDelegate.swift`). |

## Free and Pro

No difference. Every notification type is free. Campaign pushes can target the `premium` or `free` topic. The app subscribes to one of them by tier (`syncPushTopics`).

## How it works

### Inbox

| Behavior | Detail |
|---|---|
| Unread row | Shows a dot and a bold title. Read rows have no dot. |
| Mark all as read | App bar icon with tooltip "Mark all as read". Shows only when `unreadCount > 0`. |
| Swipe to delete | Swipe left or right. No dialog. A snackbar shows "Notification removed" with an Undo action. A group swipe shows "<n> notifications removed". |
| Clear inbox | Floating button with tooltip "Clear inbox". It still asks for confirmation. |
| Deleted items stay deleted | Each deleted id goes in a tombstone list. Sync skips these ids. |
| Clear watermark | Clear stores the time of the clear. Sync asks the server only for newer items, and drops older ones. |
| Undo | Removes the ids from the tombstone list and puts the items back. |

Tombstone limits (`lib/data/notifications/notification_tombstones.dart`):

- The list holds at most 500 ids (`maxIds`). When it is full, the oldest ids drop first.
- The list lives in the local store key `notifications.deleted_ids`. The clear time lives in `notifications.cleared_at_utc`.

### Route mapper

`lib/core/router/notification_route_mapper.dart` turns a push or inbox payload into a route.

| `route` value | Result |
|---|---|
| `wall` | Wall detail. Needs a wall with `review == true`. An admin can open an unapproved wall. |
| `wall_of_the_day` | Wall detail when `wall_id` resolves. Else the Home tab. |
| `streak_reminder` | Rewards tab. |
| `follower` | Profile when an identifier exists. Else the inbox. |
| `announcement` | Inbox. |
| `content_report` | Admin review page for an admin. Else the fallback. |
| Setup link | Home tab, and the toast "Home screen setups are no longer available." |
| Anything else, or a lookup error | Fallback. |

The fallback (default `fallbackToInbox: true`) opens the inbox. If `route` is not empty, the app shows the toast "That item is no longer available". The mapper then never returns null.

### Preferences sheet

`lib/features/in_app_notifications/views/widgets/notification_settings_sheet.dart`

| Switch | What it controls |
|---|---|
| Wall of the Day | Time zone topic for the daily pick. Works for signed-out users. |
| Followers | Alerts for new followers. Needs sign-in. |
| Posts | Alerts for new work from followed creators. Needs sign-in. Off when Followers is off. |
| Recommendations | Topic `recommendations`. |
| Streak reminders | Evening reminder around 8 PM local. Needs sign-in. |

Permission rules:

- When the OS permission is off, a banner says "Notifications are off for Prism." with an "Open settings" button.
- The banner updates when the app resumes.
- When the user turns a switch on, the sheet first asks the OS for permission. If the user refuses, the switch stays off and a toast shows.
- Turning a switch off never asks for permission.

### Post-onboarding prompt

After the first wallpaper step in onboarding, `NotificationPermissionPromptService.maybePromptAfterValueAction` runs (`lib/features/onboarding_v2/src/views/onboarding_v2_shell.dart`). It also runs after a download or a wallpaper set.

- It asks once. The flag is `notificationPermissionPromptedV2`.
- When the user grants permission, it subscribes to the Wall of the Day bucket (if that switch is on). For a signed-in user it also subscribes to the uid topic and the followers topic.

### Push data path

```text
Cloud Function event
   |
   +-- inbox doc in Firestore `notifications` (unless push only)
   |
   +-- personal push -> topic u_<uid>  and  FCM token(s) from
   |                    usersv2/{uid}/private/session (fallback usersv2.fcmToken)
   |
   +-- Wall of the Day -> topic wall_of_the_day_utc_<p|m><hh><mm> (every 15 min)
                       -> legacy topic wall_of_the_day (03:30 UTC, old clients)
```

### Server rules

| Rule | Detail |
|---|---|
| Personal pushes | `sendToUser` in `functions/src/notificationHelper.ts` sends to the uid topic `u_<uid>` and to the FCM token. Both pushes share one `collapseKey`, so the device shows one. |
| Email topic | Used only when no user doc matches the email. The topic is shared by every address with the same prefix. |
| Who uses it | Follow, wall approved, wall submitted (admins), content report (admins), win-back, campaign with an email, inbox entry with an email. |
| Badge | The server no longer sets `aps.badge`. The iOS app clears the badge on its own. |
| Approval push | `onWallApproved` stamps `approvedNotifiedAt` in a transaction. A retried event sends nothing. |
| Follow inbox doc | `onFollowCreated` writes one doc with a fixed id (`follow_<hash>_<uid>`). A retry rewrites the same doc. |
| Wall of the Day pick | `wallOfTheDay` runs at 03:30 UTC, retries 2 times, skips when today's pick exists. It skips streak-exclusive walls and walls in premium collections. |
| Wall of the Day push | `sendWallOfTheDayBuckets` runs every 15 minutes. It sends to the topic of each UTC offset where it is 09:00 local. |
| Legacy topic | `wallOfTheDay` also sends to topic `wall_of_the_day` at 03:30 UTC for old clients. |
| Streak reminder | `sendStreakReminders` runs every 15 minutes, `timeoutSeconds: 540`. It handles users in chunks of 25 with `Promise.allSettled`, in pages of 200. It writes the sent marker first and rolls it back if the push fails. |
| Win-back | `sendWinBackPushes` steps are 3, 7, 14, 30, 60 days. Each step stays open for 2 days (`WINDOW_DAYS`). A dedupe stamp stops repeats. |

### Wall of the Day topics

- Topic name: `wall_of_the_day_utc_` + `p` (east of UTC) or `m` (west) + `hh` + `mm`. Example: `wall_of_the_day_utc_p0530`. FCM topic names cannot hold `+`.
- Offsets round to 15 minutes. The range is -12:00 to +14:00.
- `setWotdTopics` joins the bucket and leaves `wall_of_the_day`. `refreshWotdTopics` runs on app resume and moves the device when the offset changes.

### Main files

| Path | Role |
|---|---|
| `lib/features/in_app_notifications/views/pages/notification_screen.dart` | Inbox UI: dot, bold, Mark all as read, swipe, Undo, Clear. |
| `lib/features/in_app_notifications/views/widgets/notification_settings_sheet.dart` | Shared preferences sheet, permission banner. |
| `lib/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart` | Bloc with mark all read and restore events. |
| `lib/features/in_app_notifications/data/repositories/notifications_repository_impl.dart` | Delete, clear, mark all read, restore. |
| `lib/data/notifications/notification_tombstones.dart` | Tombstone list (cap 500) and clear watermark. |
| `lib/data/notifications/notifications.dart` | Remote sync. Applies the tombstones. |
| `lib/core/router/notification_route_mapper.dart` | Payload to route, inbox fallback. |
| `lib/notifications/topic_subscription.dart` | Topics, Wall of the Day buckets. |
| `lib/features/startup/services/notification_permission_prompt_service.dart` | One-time permission prompt. |
| `functions/src/notificationHelper.ts` | `sendNotification`, `sendToUser`, token lookup. |
| `functions/src/wallOfTheDay.ts` | Daily pick, bucket job. |
| `functions/src/streak.ts` | Streak reminder job. |
| `functions/src/winBack.ts` | Win-back job. |

## Deploy order

Deploy the backend before the client. The exact steps are in `docs/features/backend-deploy.md`.

1. Firestore indexes.
2. Cloud Functions (`sendWallOfTheDayBuckets` is new).
3. Cloudflare worker, then web.
4. Client release.

If the client ships first, new builds leave `wall_of_the_day`. The bucket topic then gets no push until `sendWallOfTheDayBuckets` is live. Those users get no Wall of the Day push.

## Limits

- Tombstones and the clear time are local to one device. They do not sync between devices. A second device shows the item again.
- After 500 deletes, the oldest tombstones drop. A forced or first sync (30-day backfill) can bring back an old item.
- Devices east of about +05:30 get the previous day's pick. Their 09:00 local is before 03:30 UTC, and the pick for the new day does not exist yet. The bucket job accepts a pick up to 30 hours old (`MAX_PICK_AGE_MS`). This follows from the code. It was not confirmed on a live device.
- Old clients that only know the email-prefix topic get no personal pushes when a user doc exists for the email. Shipped clients subscribe to `u_<uid>`.
- The Wall of the Day push does not write an inbox doc. Only the legacy send at 03:30 UTC writes it (`docId: wotd_<date>`).
- The app badge clear is native code. It needs a device to confirm.
- Push delivery, the OS permission banner and the OS prompt need a real device. Automated tests use fakes.

## How to test

1. Open the inbox with unread items. Make sure that unread rows show a dot and a bold title.
2. Tap "Mark all as read". Make sure that the dots go away.
3. Swipe one row. Make sure that no dialog shows and the snackbar has "Undo".
4. Tap "Undo". Make sure that the row comes back.
5. Swipe a row and wait. Reopen the inbox so it syncs. Make sure that the row stays gone.
6. Tap "Clear inbox" and confirm. Reopen the inbox. Make sure that old items do not return.
7. Turn off OS notifications for Prism. Open Settings, "Notification preferences". Make sure that the banner shows, and "Open settings" opens the OS page.
8. Turn a switch on while OS notifications are off. Make sure that the OS prompt shows, and the switch stays off if you refuse.
9. Tap a push for a deleted wall. Make sure that the inbox opens and the toast "That item is no longer available" shows.
10. On a fresh install, finish onboarding to the first wallpaper step. Make sure that the OS prompt shows once.

Automated tests:

| Area | File |
|---|---|
| Inbox screen | `test/features/in_app_notifications/notification_screen_test.dart` |
| Preferences sheet | `test/features/in_app_notifications/notification_settings_sheet_test.dart` |
| Bloc and repository | `test/features/in_app_notifications/biz`, `test/features/in_app_notifications/data` |
| Tombstones and sync | `test/data/notifications/notification_tombstones_test.dart`, `test/data/notifications/notifications_sync_test.dart` |
| Route mapper | `test/core/router/notification_route_mapper_test.dart` |
| Topics | `test/notifications/topic_subscription_test.dart`, `test/notifications/push_topics_sync_test.dart` |
| Functions | `functions/src/__tests__/wallOfTheDay.test.ts`, `notificationHelper.test.ts`, `personalPushes.test.ts`, `onWallApproved.test.ts`, `onFollowCreated.test.ts`, `streak.test.ts`, `winBack.test.ts` |

Commands:

```sh
fvm flutter test --no-pub test/features/in_app_notifications test/data/notifications test/core/router/notification_route_mapper_test.dart test/notifications
cd functions && npm ci && npm run build && node --test lib/__tests__/
```
