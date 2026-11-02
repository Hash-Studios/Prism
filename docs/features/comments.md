# Wallpaper comments

A signed-in user can comment on an approved Prism wall. A comment is text and emoji only. Stickers and GIFs are not supported. Guests and signed-out users can read comments. They cannot post.

The server owns every write. Clients cannot create, change or delete a comment, a count, or a rate-limit doc.

## Data

| Item | Where | Notes |
|---|---|---|
| Comment | `walls/{wallId}/comments/{commentId}` | `wallId`, `statsId`, `authorUid`, `authorName`, `authorUsername`, `authorPhoto`, `text`, `createdAt`, `state` (`visible` or `hidden`), `requestId`. `wallId` is the wall document ID. |
| Comment ID | First 32 hex characters of `sha256(uid + "\n" + requestId)` | A retry with the same `requestId` finds the comment that it wrote. |
| Count | `wallpaper_stats/{wall id field}.comments` | The number of visible comments. It is in the stats doc next to `favs` and `views`, not in the wall doc. See "Why the count is not on the wall". |
| Rate limit | `commentRate/{uid}` | `lastAtMs`, `day`, `count`. One doc for each author. |
| Push gate | `commentPush/{wallId}` | `lastAtMs`, `creatorUid`. One doc for each wall. |

The author name and photo are copied from `usersv2/{uid}` when the comment is written. A later rename does not change old comments. New comments retain `statsId`, the normalized wall `id` used for their count. Hiding or deleting a comment uses this key even if the wall was deleted or its `id` changed. Older comments without this key fall back to the current wall `id`. If that wall is already gone, its original stats key cannot be recovered from the comment.

## Callables

All callables are in `asia-south1` and `us-central1` (`CALLABLE_REGIONS`).

### addComment

Input: `{wallId, text, requestId}`. Output: `{ok: true, comment}` or `{ok: false, reason}`.

The checks run in this order. Text parsing happens before the kill-switch lookup, but text refusal results are returned after the switch check.

| Check | Refusal |
|---|---|
| Signed in | `unauthenticated` error |
| `wallId`, `requestId` and `text` have valid types and identifiers | `invalid-argument` error |
| Remote Config `comments_enabled` is not `false` or `0` | `comments_disabled` |
| Raw text is at most 8000 UTF-16 code units | `comment_too_long` |
| No control, format, private-use or unpaired surrogate character before whitespace cleanup. A newline and a joiner between two emoji are allowed. | `comment_hidden_characters` |
| Text after cleanup is not empty | `comment_empty` |
| 500 grapheme clusters or fewer (`TEXT_SEGMENTER`) | `comment_too_long` |
| No blocked word (`hasBlockedWord`) | `comment_blocked_word` |
| Verified, not disabled, not anonymous Firebase Auth account | `comment_guest` |
| Firebase Auth account is 24 hours old or more | `comment_too_new` |
| A `usersv2` profile exists, is not deleted, and has no closed `creatorDeletionState` | `comment_guest` |
| The wall exists and `review == true` | `comment_wall_unavailable` |
| No block from the creator to the author, and no block from the author to the creator | `comment_blocked` |
| Existing comment matches the author, wall and request ID | `already-exists` error on a collision; a matching visible comment is returned without another write; a matching hidden comment returns `comment_wall_unavailable` without its text |
| 10 seconds or more since the author's last comment | `comment_too_fast` |
| Fewer than 50 comments by the author on this UTC day | `comment_daily_limit` |
| The wall has a valid stats ID | `comment_wall_unavailable` |

Text cleanup: line breaks become `\n`, runs of spaces become one space, more than one blank line becomes one, and the ends are trimmed.

One transaction creates the comment, adds 1 to the count and updates the rate limit. The rate limit is for each author, not for each `requestId`. Many request IDs do not get around it. The callable checks visibility again after commit before returning the comment or sending a notification.

### deleteComment

Input: `{wallId, commentId}`. Output: `{ok: true, deleted, role}`.

The author, the wall creator (`walls.creatorUid`) or an admin (`isAdminCaller`) can delete. Other callers get `permission-denied`. A missing comment returns `deleted: false`. A visible comment removes 1 from the count. A hidden comment does not change the count.

### setCommentHidden

Input: `{wallId, commentId, hidden}`. Admins only. It hides a comment or shows it again, and changes the count by 1. It does nothing when the comment is already in that state.

## Reports and moderation

- `submitContentReport` accepts `contentType: "comment"`. The target is `{wallId}:{commentId}`. A comment ID has no colon, so the text after the last colon is the comment ID.
- `onContentReportCreated` uses the existing threshold: 3 different reporters with accounts older than 7 days. Then it sets the comment to `hidden`, sets `hiddenBy: "reports"`, and removes 1 from the count. The same transaction marks the report `moderationApplied`. A retry cannot hide it again after an admin keeps it. Closed reports are skipped. A new report can still trigger moderation.
- The admin review screen shows a comment report card. **Keep comment** shows the comment again and closes the report as `dismissed`. **Remove** deletes the comment and closes the report as `content_removed`.
- A long press on a comment gives Report, Block and Delete. Each item shows only where it applies. The app also hides comments by users that the viewer blocked.

## Push

The wall creator gets at most one push for each wall in each hour. The creator gets no push for their own comment. The push uses `sendToUser` on the `followers` channel. The creator's `private/session.followerAlerts` switch turns it off. The inbox item and push title are "{name} commented on {wall title}". The body is the first 80 grapheme clusters of the comment. A tap opens the wall.

Before sending, the callable checks that the creator still exists, is not deleted, has no closed deletion barrier, and still allows follower alerts for push.

Open product decision: a delivered push or stored inbox preview can retain text after the comment is hidden. Either keep previews with this limitation, or remove comment text from push and inbox bodies. A delivered push cannot be reliably recalled.

Catalog kind: `wallCommented`. The push preview stops at 80 characters or 400 UTF-8 bytes. The commenter name stops at 40 characters or 160 bytes and the wall title at 60 characters or 240 bytes. These cuts keep the push small. They do not prove a hard limit on the whole FCM payload. The push sends the English title and body. Installed builds that advertise localization version 2 do not have the native keys `notif_push_wall_commented_title`, `notif_push_wall_commented_title_untitled` and `notif_push_wall_commented_body`. The keys ship in this build. Turn on native localization for this kind only after a new localization version is advertised. The app localizes the inbox item and a push that arrives in the foreground.

## Account deletion

`deleteAccount` calls `removeCommentsForAccount`. It finds the author's comments with a collection-group query on `authorUid`, deletes each one, and removes 1 from the count for each visible one. It also deletes `commentRate/{uid}`. A second run changes nothing.

## Firestore rules

- `walls/{wallId}/comments/{commentId}`: a get or a list is allowed for a visible comment on an approved wall. A list must filter on `state == "visible"`. Admins can also read hidden comments. Clients cannot write.
- `commentRate` and `commentPush`: no client reads or writes.

## Indexes

- Composite index on `comments` (collection scope): `state` ascending, `createdAt` descending. The sheet uses it to page 20 comments at a time, newest first.
- Field override on `comments.authorUid` with a collection-group index. Account deletion uses it.

## Kill switch

Remote Config `comments_enabled` (string). The default is on. When it is `false` or `0`, the app hides the comments button and `addComment` returns `comments_disabled`. The server keeps the value for 60 seconds.

## Analytics

`comments_sheet_opened`, `comment_posted`, `comment_refused` (`reason`), `comment_deleted` (`role`: `author`, `creator` or `admin`), `comment_reported`.

## Why the count is not on the wall

Every write to a `walls/{id}` doc starts 12 Firestore triggers. One of them, `onOwnedWallWritten`, runs with 1 GiB and concurrency 1, and it tries a GitHub and R2 conversion again for each approved wall that is not protected. A comment count on the wall doc would start all of them for each comment. The stats doc has no triggers, and the app already reads it for the favourite count.

## Deploy order

1. Firestore rules.
2. Firestore indexes. Wait until the `comments` index is ready.
3. Functions: `addComment`, `deleteComment`, `setCommentHidden`, `submitContentReport`, `onContentReportCreated`, `deleteAccount`.
4. Then release the app.
