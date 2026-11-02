# Wallpaper comments

A signed-in user can comment on an approved Prism wall. A comment is text and emoji only. Stickers and GIFs are not supported. Guests and signed-out users can read comments. They cannot post.

The server owns every write. Clients cannot create, change or delete a comment, a count, or a rate-limit doc.

## Data

| Item | Where | Notes |
|---|---|---|
| Comment | `walls/{wallId}/comments/{commentId}` | `wallId`, `authorUid`, `authorName`, `authorUsername`, `authorPhoto`, `text`, `createdAt`, `state` (`visible` or `hidden`), `requestId`. `wallId` is the wall document ID. |
| Comment ID | First 32 hex characters of `sha256(uid + "\n" + requestId)` | A retry with the same `requestId` finds the comment that it wrote. |
| Count | `wallpaper_stats/{wall id field}.comments` | The number of visible comments. It is in the stats doc next to `favs` and `views`, not in the wall doc. See "Why the count is not on the wall". |
| Rate limit | `commentRate/{uid}` | `lastAtMs`, `day`, `count`. One doc for each author. |
| Push gate | `commentPush/{wallId}` | `lastAtMs`, `creatorUid`. One doc for each wall. |

The author name and photo are copied from `usersv2/{uid}` when the comment is written. A later rename does not change old comments.

## Callables

All callables are in `asia-south1` and `us-central1` (`CALLABLE_REGIONS`).

### addComment

Input: `{wallId, text, requestId}`. Output: `{ok: true, comment}` or `{ok: false, reason}`.

The checks run in this order:

| Check | Refusal |
|---|---|
| Signed in | `unauthenticated` error |
| `wallId`, `requestId` and `text` have the correct type | `invalid-argument` error |
| Remote Config `comments_enabled` is not `false` | `comments_disabled` |
| Same `requestId` already posted | Returns the stored comment. Nothing more is written. |
| Text after cleanup is not empty | `comment_empty` |
| No control, format or private-use character. A newline and a joiner between two emoji are allowed. | `comment_hidden_characters` |
| 500 grapheme clusters or fewer (`TEXT_SEGMENTER`) | `comment_too_long` |
| No blocked word (`hasBlockedWord`) | `comment_blocked_word` |
| Verified, not disabled, not anonymous, has a `usersv2` profile that is not deleted | `comment_guest` |
| Firebase Auth account is 24 hours old or more | `comment_too_new` |
| The wall exists and `review == true` | `comment_wall_unavailable` |
| No block from the creator to the author, and no block from the author to the creator | `comment_blocked` |
| 10 seconds or more since the author's last comment | `comment_too_fast` |
| Fewer than 50 comments by the author on this UTC day | `comment_daily_limit` |

Text cleanup: line breaks become `\n`, runs of spaces become one space, more than one blank line becomes one, and the ends are trimmed.

One transaction creates the comment, adds 1 to the count and updates the rate limit. The rate limit is for each author, not for each `requestId`. Many request IDs do not get around it.

### deleteComment

Input: `{wallId, commentId}`. Output: `{ok: true, deleted, role}`.

The author, the wall creator (`walls.creatorUid`) or an admin (`isAdminCaller`) can delete. Other callers get `permission-denied`. A missing comment returns `deleted: false`. A visible comment removes 1 from the count. A hidden comment does not change the count.

### setCommentHidden

Input: `{wallId, commentId, hidden}`. Admins only. It hides a comment or shows it again, and changes the count by 1. It does nothing when the comment is already in that state.

## Reports and moderation

- `submitContentReport` accepts `contentType: "comment"`. The target is `{wallId}:{commentId}`. A comment ID has no colon, so the text after the last colon is the comment ID.
- `onContentReportCreated` uses the existing threshold: 3 different reporters with accounts older than 7 days. Then it sets the comment to `hidden`, sets `hiddenBy: "reports"`, and removes 1 from the count. A retry does not remove 1 again.
- The admin review screen shows a comment report card. **Keep comment** shows the comment again and closes the report as `dismissed`. **Remove** deletes the comment and closes the report as `content_removed`.
- A long press on a comment gives Report, Block and Delete. Each item shows only where it applies. The app also hides comments by users that the viewer blocked.

## Push

The wall creator gets at most one push for each wall in each hour. The creator gets no push for their own comment. The push uses `sendToUser` on the `followers` channel. The creator's `private/session.followerAlerts` switch turns it off. The inbox item and push title are "{name} commented on {wall title}". The body is the first 80 characters of the comment. A tap opens the wall.

Catalog kind: `wallCommented`. Native keys: `notif_push_wall_commented_title`, `notif_push_wall_commented_title_untitled`, `notif_push_wall_commented_body`.

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
