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
| Clear inbox | Floating button with tooltip "Clear inbox". It clears at once with no dialog. A snackbar shows "Inbox cleared" with an Undo action. |
| Deleted items stay deleted | Each deleted id goes in a tombstone list. Sync skips these ids. |
| Clear watermark | Clear stores the time of the clear. Sync asks the server only for newer items, and drops older ones. |
| Undo | Removes the ids from the tombstone list and puts the items back. It works for a swipe and for Clear inbox. |
| Open a row | A row with a link opens the link through `openPrismLink`. A Prism link that has a screen (wallpaper, profile, short link) opens in the app. A referral link keeps the inviter and opens the Rewards tab. Other Prism pages, such as `/privacy` and `/terms`, open in the browser. |

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

A push with `wall_ids` opens the gallery page first.

Push taps also record the event `push_opened` with `kind`: `streak_reminder`, `follower`, `post` (route `wall`), `wotd` or `moderation` (route `content_report` with a `report_id`). Report moderation pushes contain only that route and report ID plus generic copy; admins load report details from the admin-only report screen. `fromPayload` records the tap. `fromRoute`, which the inbox uses, does not. The older event `wotd_opened_from_push` stays.

The fallback (default `fallbackToInbox: true`) opens the inbox. If `route` is not empty, the app shows the toast "That item is no longer available". The mapper then never returns null.

### Preferences sheet

`lib/features/in_app_notifications/views/widgets/notification_settings_sheet.dart`

| Switch | What it controls |
|---|---|
| Wall of the Day | Time zone topic for the daily pick. Works for signed-out users. |
| Followers | Alerts for new followers. Needs sign-in. |
| Posts | Alerts for new work from followed creators. Needs sign-in. Off when Followers is off. |
| Folders you follow | The daily "New in <folder>" push. Needs sign-in. Saved as `folderAlerts` in `usersv2/{uid}/private/session`. The token sync also writes `folderAlertsToken`. |
| Recommendations | Topic `recommendations`. A signed-in user also saves it as `marketingPushes` in `usersv2/{uid}/private/session`, next to `followerAlerts`. Win-back pushes skip a user with `marketingPushes == false`. A switch turned off before sign-in is saved on the next token sync. |
| Streak reminders | Evening reminder around 8 PM local. Needs sign-in. |

Guests: Followers, Posts and Streak reminders show the hint "Sign in to turn on" when they are off, and the switch is disabled. A guest can still turn one off on this device. Wall of the Day and Recommendations work for guests.

Permission rules:

- When the OS permission is off, a banner says "Notifications are off for Prism." with an "Open settings" button.
- The banner updates when the app resumes.
- When the user turns a switch on, the sheet first asks the OS for permission. If the user refuses, the switch stays off and a toast shows.
- Turning a switch off never asks for permission.

### Posts topics

A follow stores the creator email only. The app joins localized variants of two topics for each followed creator:

- `<email prefix>_posts_loc_v1`. Creators with the same email prefix share it. Legacy clients use `<email prefix>_posts`.
- `posts_<creator uid>_loc_v1`. It is unique per creator. Legacy clients use `posts_<creator uid>`.

The uid comes from the caller when it knows it. Else the app reads the public profile once (`PublicProfileRepository.watchProfile`, 8 s limit) and keeps the email-to-uid pair in the settings key `creatorUidByEmail`. Unfollow, sign-out and the Posts switch leave both topics. One uid read never repeats. Builds with the follow digest leave these topics and do not join them on follow.

### Foreground pushes

`LocalNotification.showPushNotification` shows a banner for a push that arrives while the app is open. The id is the hash of the Android `tag` of the push. When there is no tag, it is the hash of title, body and data. It is masked to 31 bits. The server sends a personal push to one bound session token. Retries share a collapse key, so an earlier banner is replaced. `onlyAlertOnce` stops a second sound.

### Gallery pushes

A gallery push shows 2 to 4 walls in one image. The collapsed notification shows one wall as the thumbnail. The expanded notification shows the walls side by side.

`functions/src/pushGallery.ts` makes the image with `sharp`. The image is a 1200 x 545 px JPEG, under 200 KB. The function uses only the public preview thumbnails (`img.prismwalls.com/previews/...`). It never uses originals.

The image is stored once in the R2 preview bucket at `push-gallery/v1/<sha256>.jpg`. The image is served from `https://img.prismwalls.com/push-gallery/v1/...`. The object key is the hash of the layout, the version and the sorted wall IDs. A second push for the same walls reuses the object.

There are two layouts.

| Layout | Used for | How it works |
|---|---|---|
| `strip` | iOS | Shows the walls in sorted ID order. The push data gives `gallery_thumb_index`, the slot of the lead wall. |
| `hero` | Android, 3 or more walls | Shows the lead wall in the centre square and 2 other walls at the sides. Android 12 to 15 crop the centre square for the collapsed icon. Android 16 crops the centre to about 16:9. In both, the lead wall is whole and in the centre, with no seam. |

On Android with 2 walls, the push shows the lead wall thumbnail.

Only approved walls that a free user can open appear in a gallery. The gate removes premium collection walls, streak exclusive walls, drop reserved walls, and walls that are in a drop.

The Drop live push is the exception. It shows the walls of that drop. The Drops page and the earlier Drop push do the same.

If fewer than 2 walls remain after the gate, or if making the image fails, the push keeps its single image.

Push data:

| Key | Value |
|---|---|
| `gallery` | `"1"` |
| `gallery_url` | URL of the gallery image |
| `gallery_count` | Number of walls in the image |
| `gallery_thumb_index` | Slot of the lead wall |
| `wall_ids` | Wall IDs, lead wall first |

A gallery push has no `data.imageUrl`, so the payload stays small. The Android notification `imageUrl` is the hero image. When a payload is too large, `fcmMessage` removes wall ids from the end of `wall_ids`, and keeps at least 2. The APNs payload sets `mutable-content: 1` on every push with an image.

Senders:

| Sender | Gallery |
|---|---|
| Wall of the Day | Today's pick plus up to 3 walls that share its moods or tags. Chosen once per pick and kept in `wall_of_the_day/current.gallery`. |
| Drop live | Up to 4 walls of the drop. The tap still opens the Drops page. |
| Follow digest | Single image. See "Follow digest". |

Daily cap: a user gets at most 1 gallery push a day. On the UTC day that a drop goes live, the Drop push is the gallery. The Wall of the Day push then keeps its single image (`dropOwnsGallery`). The follow digest always uses a single image. On other days, the Wall of the Day push is the gallery.

Copy: topic pushes reach builds that do not have new native keys. So they reuse shipped keys.

- Wall of the Day uses `notif_push_wotd_for_audience_*`. The tags line is the body.
- Drop uses `notif_push_drop_live_title`. The tags line goes through `notif_push_wotd_for_audience_body`.

The tags line holds the 3 tags that the most walls share. The tags can be moods, vision labels or collections. They are joined with " · ".

Tap: a push with 2 or more `wall_ids` opens `/gallery?ids=...&source=push` (`GalleryScreen`). The walls keep push order. Tiles, detail and swipe work as usual. `DeepLinkDispatcher.openPush` checks `wall_ids` before `url`. Builds without the gallery page open the lead wall from `route` and `url`. Inbox rows open the lead wall.

Analytics: the scoreboard keeps its kinds. It adds the `gallery_sends`, `gallery_accepts`, `gallery_fails` and `gallery_taps` maps, keyed by kind. The app sends the tap signal with `gallery: true` for a gallery push. It records the event `gallery_opened` with `source` and `wall_count` when the page opens.

### iOS Notification Service Extension

The target is `PrismNotificationService`. Its bundle ID is `com.hash.prism.NotificationService`. It is embedded in Runner.

Code: `ios/PrismNotificationService/NotificationService.swift`. Logic: `ios/PrismNotificationService/Core/PushImage.swift`.

The extension downloads `gallery_url` with URLSession. It sets the clipping rect of wall `gallery_thumb_index` with `UNNotificationAttachmentOptionsThumbnailClippingRectKey`. If there is no gallery, it downloads `imageUrl`. It accepts only https URLs on `img.prismwalls.com`, with no port, user, query or fragment. A gallery path must be `/push-gallery/v1/<sha256>.jpg`. A single-image path must be `/previews/<sha256>.img`. It does not follow redirects. The download has at most 20 seconds.

The extension checks the image header without decoding the image. The image must be a JPEG, PNG or HEIC. It must be at most 5 MB, at most 4096 px on each side, and at most 2,000,000 px in total.

On any failure, the push is delivered as text. This also happens when the system time limit comes.

Before this target, iOS pushes showed no image. Now a push shows its image when the image URL passes these checks. Every Prism wall thumbnail and gallery image passes.

Tests:

```sh
swift test --package-path ios --filter PushImageTests
```

TestFlight needs the secret `IOS_NOTIFICATION_SERVICE_PROVISIONING_PROFILE_BASE64`. It holds an App Store profile for `com.hash.prism.NotificationService`. The TestFlight workflow, `.github/workflows/testflight.yml`, needs this secret.

### Follow digest

`sendFollowDigests` runs every 15 minutes. It sends at 19:00 local time, using `appOpenTimezoneOffsetMinutes`.

The job collects walls approved in the last 24 hours (`approvedNotifiedAt`). The walls must pass the gallery gate and must not be Studio walls. It groups them by creator. It sends one push to each follower (`profiles/{creator}/followers`).

Titles depend on the shape of the digest. The examples use the creator name "Asha".

| Shape | Title |
|---|---|
| One creator, one wall | "Asha posted a new wall" |
| One creator, several walls | "Asha posted 3 new walls" |
| Two creators | "Asha and Ben posted 5 new walls" |
| More creators | "Asha and 3 others posted 9 new walls" |

The body is the tags line. If there are no tags, the body is "Tap to see them all."

The title keys are `notif_push_follow_digest_title_one`, `_solo`, `_pair` and `_group`, in the row order of the table. The body keys are `notif_push_follow_digest_body` and `notif_push_follow_digest_body_untitled`. Every app language has these keys.

The digest goes only to a session with `postAlerts == true` and `postAlertsToken` equal to `fcmToken`. Only builds with the digest write `postAlertsToken`. Those builds leave the per-upload posts topics and do not join them on follow. Older builds keep the per-upload topic pushes from `onWallApproved`. That function does not change.

- The Posts switch writes `postAlerts`.
- Turning Followers off writes `postAlerts: false`.
- Token sync writes `postAlerts` (Posts and Followers both on) and `postAlertsToken`.

The digest is sent once per local day. The job claims `usersv2/{uid}/private/followDigest.day` in a transaction before the send. It releases the claim if the send fails. Blocked creators are dropped in both directions. There are no quiet hours other than the fixed local time.

| Key | Value |
|---|---|
| `route` | `wall` |
| `wall_id` | Lead wall |
| `wall_ids` | Wall IDs |
| `push_kind` | `post` |
| `notification_kind` | `follow_digest` |

The collapse key is `follow_digest_<day>`. The inbox doc is `follow_digest_<uid>_<day>`.

Scoreboard data at the time of the change (2026-10-17 to 2026-10-28):

- `post` had 13,194 sends and 0 taps. All sends were on 2026-10-20 and 2026-10-21.
- `wotd` had 1,916 sends and 13 taps.

Topic sends count once per message, not once per device. The data does not show that per-upload pushes work better for users who follow one creator. So every build with the digest gets it.

### Folder digest

`sendFolderDigests` sends "New in <folder>" at 13:00 local time, once per follower and local day. It needs `folderAlerts == true` and `folderAlertsToken` equal to `fcmToken` in `private/session`. The **Folders you follow** switch writes `folderAlerts`. The push has one image, like the follow digest. The details are in [folders.md](folders.md).

### Remix notice

`onWallRemixWritten` writes one inbox item to the original creator when a counted remix is first approved. The title is "Your wallpaper was remixed", with the remix thumbnail. The doc id is `remix_<remixId>` and the kind is `wallRemixed`. The item has no push. It is skipped when `postAlerts` is false in `private/session`. The details are in [remix.md](remix.md).

### Notification copy and adding a language

Known server notifications store a stable `message.kind` and argument map in the inbox document and push data. The inbox and foreground banner resolve those values through `lib/features/in_app_notifications/domain/notification_copy.dart` and `AppLocalizations`. Android and iOS also receive native FCM localization keys, so the OS selects background banner copy from the device locale. Historical notifications and admin-authored campaigns retain their stored text because their copy is not a known template. The notification cache preserves the kind and arguments.

Topic subscriptions use the `_loc_v1` suffix for clients with native notification resources. During the migration, Functions send each topic push to both the legacy topic and its `_loc_v1` topic. Typed copy keeps the English `notification` fallback on the legacy send and omits those fields on the localized send so Android and iOS can resolve their native resource keys. Literal campaigns are delivered to both topics with their authored text. Both sends share a collapse key. The app subscribes to the localized topic, then removes its legacy subscription; sign-out removes both. Deploy the Functions update before releasing the app so new clients never depend on a server that only sends to legacy topics.

Direct-token localization is enabled only when `usersv2/{uid}/private/session` contains `notificationLocalizationVersion: 1` and `notificationLocalizationToken` equal to the current `fcmToken`. The app writes those fields together when syncing a token. Comparing the marker token avoids treating a token written by an older client as localization-capable when a stale version field remains in the merged session document. Session reads and writes remain owner-only under `firestore.rules`.

To add a locale, add its `app_<locale>.arb` catalog beside `lib/l10n/app_en.arb`, translate every notification key with the same ICU placeholder names and types, add the locale to the app's supported locales through `flutter gen-l10n`, and translate every `notif_push_*` entry in Android `values-<locale>/strings.xml` and iOS `Localizable.xcstrings`. Keep each value as a complete sentence template with positional placeholders for dynamic arguments. Native FCM resources do not evaluate Flutter ICU plurals, so count-bearing Drop copy uses count-neutral sentence templates with the number passed as a placeholder. The OS device locale selects localized copy for topic pushes too, so no per-user locale field is needed.

For each new notification template, add its English copy to `lib/l10n/app_en.arb`, map the kind and typed arguments in `notification_copy.dart` and `functions/src/notificationCatalog.ts`, and add its native keys and argument mapping in `nativeNotificationLocalization`. User-authored campaign copy remains literal. Run `make l10n-check`, Functions tests, and notification tests. Resource coverage and positional argument counts are checked in `functions/src/__tests__/notificationHelper.test.ts`.

### Links and share text

- The link parser accepts the roots that the Android manifest and the iOS association file claim: `share`, `user`, `setup`, `refer`, `l`. It also accepts the older aliases `profile`, `fprofile`, `follower-profile`, `share-setup` and `referral`. `www.prismwalls.com` and `prism://` parse the same way.
- `shareSafeText` (`lib/core/share/share_text.dart`) removes text that holds an email address. The share card line is cleaned with it. A wallpaper can have an email as its creator name when the creator has no display name.

### Post-onboarding prompt

After the first wallpaper step in onboarding, `NotificationPermissionPromptService.maybePromptAfterValueAction` runs (`lib/features/onboarding_v2/src/views/onboarding_v2_shell.dart`). It also runs after a download or a wallpaper set.

- It asks once. The flag is `notificationPermissionPromptedV2`.
- When the user grants permission, it subscribes to the Wall of the Day bucket (if that switch is on). For a signed-in user it also subscribes to the followers topic and unsubscribes from the old uid topic.

### Push data path

```text
Cloud Function event
   |
   +-- inbox doc in Firestore `notifications` (unless push only)
   |
   +-- personal push -> bound FCM token from usersv2/{uid}/private/session
   |
   +-- Wall of the Day -> topic wall_of_the_day_utc_<p|m><hh><mm> (every 15 min)
                       -> legacy topic wall_of_the_day (03:30 UTC, old clients)
```

### Server rules

| Rule | Detail |
|---|---|
| Personal pushes | `sendToUser` sends only to a token in `usersv2/{uid}/private/session`. The token must be a string and have `fcmTokenBindingVersion: 1` and `fcmTokenBindingToken` equal to `fcmToken`. No UID or email-prefix topics carry personal payloads. If no valid token exists, the inbox entry is kept and the legacy inbox nudge is sent. |
| Legacy tokens | `usersv2.fcmToken` is not used for delivery. Old private-session tokens without the binding marker fail closed. There is no safe server backfill because a stored token cannot prove which signed-in account currently owns the device. Users need a client version that rotates and binds the token before full personal pushes resume. |
| Legacy inbox nudge | Temporary, for builds up to v3.9.0. When a recipient has no bound token, `sendInboxNudge` sends one push to the condition `'u_<uid>' in topics \|\| 'u_<uid>_loc_v1' in topics`. It has the text "Prism" and "You have a new notification.", only `route: announcement` as data, and the collapse key `prism_inbox_nudge`. It carries no payload content, so a topic listener learns only the timing. It is not counted on the scoreboard. Remove it after a release or two of adoption. |
| Delivery rollout | The token-binding client and this backend gate must both ship. No function deploy or app release has been run as part of this change. Older app registrations receive only the legacy inbox nudge until an updated app refreshes its token and writes the binding marker. In-app inbox writes and public broadcast topics remain available. |
| Push envelope | Personal delivery changes only the target. Android notification channels, iOS/APNs sound and collapse headers, localization markers, and the existing envelope format remain in use. |
| Who uses it | Follow, gifts, draw winners, wall approvals, wall submissions and reports for admins, Wall of the Day creators, win-back, streak reminders, email campaigns, and personal inbox entries. |
| Badge | The server no longer sets `aps.badge`. The iOS app clears the badge on its own. |
| Approval push | `onWallApproved` stamps `approvedNotifiedAt` in a transaction. A retried event sends nothing. |
| Followers push | `onWallApproved` sends the new-wall push to both generations of the legacy topic `<email prefix>_posts` and uid topic `posts_<uid>`. Each pair shares a collapse key, and all deliveries for one event use `posts_<hash>`. The email prefix topic is shared by creators with the same prefix. |
| Wall of the Day creator notice | After the public push, the creator of the pick gets a personal push and an inbox doc `wotd_creator_<utc date>`. A failure never fails the public push. |
| Wall of the Day slot | `wallOfTheDay` and `sendWallOfTheDayBuckets` pick the buckets from the scheduled time of the run. A late run still sends to its own slot. |
| Follow inbox doc | `onFollowCreated` writes one doc with a fixed id (`follow_<hash>_<uid>`). A retry rewrites the same doc. |
| Wall of the Day pick | `wallOfTheDay` runs at 03:30 UTC, retries 2 times, skips when today's pick exists. It skips streak-exclusive walls and walls in premium collections. |
| Wall of the Day push | `sendWallOfTheDayBuckets` runs every 15 minutes. It sends to both topic generations for each UTC offset where it is 09:00 local. |
| Legacy topic | `wallOfTheDay` also sends to topic `wall_of_the_day` at 03:30 UTC for old clients. |
| Streak reminder | `sendStreakReminders` runs every 15 minutes, `timeoutSeconds: 540`. It handles users in chunks of 25 with `Promise.allSettled`, in pages of 200. It writes the sent marker first and rolls it back if the push fails. |
| Win-back | `sendWinBackPushes` runs every 15 minutes. It sends to the UTC offsets where it is 18:00 local. Steps are 7, 14, 30, and 60 days since `lastAppOpenAt`. Each step stays open for 2 days. Day 7 and 14 open the feed, day 30 opens AI, and day 60 opens Wall of the Day. The Android channel is `recommendations`. The Recommendations switch (`marketingPushes`) still gates it. A missed evening sends the next day, once. Deploy the `usersv2` index on `appOpenTimezoneOffsetMinutes` + `lastAppOpenAt` before this query, or the job fails. |
| Last app open | A signed-in open writes `lastAppOpenAt` (server timestamp) and `appOpenTimezoneOffsetMinutes` (offset rounded to 15 minutes), at most every 15 minutes. A user with no last open is not eligible for win-back. |
| Scoreboard | Daily counts are split across `metrics/notificationScoreboard/days/{utc date}_{00-31}`: sends, accepts, fails, taps, next-day returns, and permission results. Accepts are FCM API accepts. Every FCM message counts as an attempt: a personal push with both topic generations and a token counts as three. Admins see the sum of those shards for the last 14 UTC dates on the Notifications tab. |
| Gallery image | A gallery image is stored once for each layout and sorted wall set. A push for the same walls reuses it. A failure keeps the single image. |
| Gallery cap | A user gets at most 1 gallery push a day. The Drop push owns the gallery on its UTC day. |
| Follow digest | `sendFollowDigests` sends at 19:00 local time, once per follower and local day. The day is claimed before the send. |

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
| `lib/core/router/notification_route_mapper.dart` | Payload to route, inbox fallback, `push_opened` event. |
| `lib/notifications/topic_subscription.dart` | Topics, Wall of the Day buckets, posts topics by email and uid. |
| `lib/notifications/fcm_token_service.dart` | Token sync, `followerAlerts`, `marketingPushes`. |
| `lib/notifications/local_notification.dart` | Foreground push banner, stable id. |
| `lib/core/utils/url_launcher_compat.dart` | `openPrismLink`, `opensInApp`. |
| `lib/features/startup/services/notification_permission_prompt_service.dart` | One-time permission prompt. |
| `functions/src/notificationHelper.ts` | `sendNotification`, `sendToUser`, token lookup. |
| `functions/src/wallOfTheDay.ts` | Daily pick, bucket job. |
| `functions/src/streak.ts` | Streak reminder job. |
| `functions/src/winBack.ts` | Win-back job. |
| `functions/src/pushGallery.ts` | Gallery image, layouts and gallery push data. |
| `functions/src/followDigest.ts` | Follow digest job. |
| `lib/features/moods/views/pages/gallery_screen.dart` | Gallery page for `/gallery`. |
| `ios/PrismNotificationService/` | iOS notification service extension. |

## Deploy order

Deploy the backend before the client. The notification topic migration requires the dual-topic sender to be live before clients switch subscriptions to `_loc_v1`. The exact steps are in `docs/features/backend-deploy.md`.

1. Firestore indexes.
2. Cloud Functions (`sendWallOfTheDayBuckets` is new).
3. Cloud Functions for gallery pushes and the follow digest. `sendFollowDigests` is new. `wallOfTheDay`, `sendWallOfTheDayBuckets` and `sendDropPushes` now need the R2 secrets. Deploy them before the client release, because new clients leave the posts topics.
4. Cloudflare worker, then web.
5. Client release.

If the client ships first, new builds leave `wall_of_the_day`. The bucket topic then gets no push until `sendWallOfTheDayBuckets` is live. Those users get no Wall of the Day push.

## Limits

- The iOS 27.0 Simulator cannot make notification thumbnails (QuickLook error 102) for any attachment. The collapsed gallery thumbnail is not proven on a simulator. The expanded image and the clipping rect values in the system log are proven.
- An inbox row of a gallery push opens the lead wall, not the gallery page.
- The uid of a creator needs one profile read. If the read fails, the app keeps the email prefix topic only and tries again at the next topic sync. A creator whose profile does not exist keeps the email prefix topic only.
- Followed creators that the app cannot resolve do not get `posts_<uid>` pushes. Old creators with a shared email prefix can still get another creator's pushes through the legacy topic.
- Pushes that open as a deep link (a `url` in the payload) are counted by `push_opened` only when the app calls `trackPushOpened` for them.
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
6. Tap "Clear inbox". Make sure that no dialog shows, the inbox empties, and the snackbar has "Undo". Tap "Undo" and make sure that all items return. Clear again, wait, and reopen the inbox. Make sure that old items do not return.
7. Turn off OS notifications for Prism. Open Settings, "Notification preferences". Make sure that the banner shows, and "Open settings" opens the OS page.
8. Turn a switch on while OS notifications are off. Make sure that the OS prompt shows, and the switch stays off if you refuse.
9. Tap a push for a deleted wall. Make sure that the inbox opens and the toast "That item is no longer available" shows.
10. On a fresh install, finish onboarding to the first wallpaper step. Make sure that the OS prompt shows once.
11. Signed out, open "Notification preferences". Make sure that Followers, Posts and Streak reminders show "Sign in to turn on" once they are off, and that Recommendations still works.
12. Signed in, turn off Recommendations. Make sure that `usersv2/{uid}/private/session.marketingPushes` is `false`.
13. Follow a creator. Make sure that the device joins `<prefix>_posts_loc_v1` and `posts_<uid>_loc_v1` and leaves their legacy variants. Unfollow and make sure that it leaves all four topics.
14. Open About, then PRIVACY and TERMS. Make sure that the web pages open in the browser, not the Not found page.
15. Send the same personal push while the app is open. Make sure that one banner shows.
16. Send a gallery push to a test device token. Make sure that the collapsed push shows one wall as the thumbnail.
17. Expand the push. Make sure that the expanded view shows the walls side by side.
18. Tap the push. Make sure that the gallery page opens with those walls.

Automated tests:

| Area | File |
|---|---|
| Inbox screen | `test/features/in_app_notifications/notification_screen_test.dart` |
| Preferences sheet | `test/features/in_app_notifications/notification_settings_sheet_test.dart` |
| Bloc and repository | `test/features/in_app_notifications/biz`, `test/features/in_app_notifications/data` |
| Tombstones and sync | `test/data/notifications/notification_tombstones_test.dart`, `test/data/notifications/notifications_sync_test.dart` |
| Route mapper and `push_opened` | `test/core/router/notification_route_mapper_test.dart` |
| Links | `test/core/utils/url_launcher_compat_test.dart`, `test/core/router/deep_link_parser_test.dart`, `test/core/router/deep_link_navigation_test.dart` |
| Share text | `test/core/share/share_text_test.dart`, `test/core/share/share_card_renderer_test.dart` |
| Foreground push ids | `test/notifications/local_notification_test.dart` |
| Topics and token | `test/notifications/topic_subscription_test.dart`, `test/notifications/push_topics_sync_test.dart`, `test/notifications/creator_posts_uid_topics_test.dart`, `test/notifications/fcm_token_service_test.dart` |
| Functions | `functions/src/__tests__/wallOfTheDay.test.ts`, `notificationHelper.test.ts`, `personalPushes.test.ts`, `onWallApproved.test.ts`, `onFollowCreated.test.ts`, `streak.test.ts`, `winBack.test.ts` |
| Gallery pushes and follow digest | `functions/src/__tests__/pushGallery.test.ts`, `functions/src/__tests__/followDigest.test.ts` |
| iOS push image | `ios/RunnerTests/PushImageTests.swift` |

Commands:

```sh
fvm flutter test --no-pub test/features/in_app_notifications test/data/notifications test/core/router/notification_route_mapper_test.dart test/notifications
cd functions && npm ci && npm run build && node --test lib/__tests__/
```
