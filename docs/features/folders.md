# Folders: private and public

A **folder** is a named group of saved wallpapers. Each folder is private when the user makes it. The owner can make a folder **public**. Other signed-in users can then see the folder, follow it, and share its link. Followers get one "New in <folder>" push a day when the owner adds wallpapers.

The Library page ([library.md](library.md)) covers the Folders tab, the folder grid and the Save to folder sheet. This page covers public folders.

## Where to find it

| Surface | What the user sees |
|---|---|
| Folder page, owner, overflow menu | **Make public** or **Make private**. |
| Folder page, owner, public folder | A header with the **Public** tag, the counts and the **Share folder** button. |
| Library > Folders | A globe icon on each public folder card. A **Folders you follow** section below the user's folders. |
| Public profile | A **Folders** row with the user's public folders, between the header and the wallpaper grid. The owner sees the globe icon on each card. |
| Folder link | `https://prismwalls.com/folder/<folderId>` opens the folder page. |
| Push | "New in <folder>" once a day, at 13:00 local time. |
| Settings > Notifications | **Folders you follow**. |

## Platforms

| Platform | Support |
|---|---|
| Android | Full. |
| iOS | Full. |

A guest cannot open a folder. The `/folder/:folderId` route has the signed-in guard.

## Free and Pro

Public folders are free. A viewer opens each wallpaper through the normal detail page. The Pro, Drop and streak gates of the detail page stay in effect.

## How it works

### Data

| Path | Writer | Readers | Contents |
|---|---|---|---|
| `folders/{id}` | Owner, through the client rules. The server sets `public` and `moderationHidden`. | Owner | The private folder. The rules for this path did not change. |
| `folders/{id}/items/{key}` | Owner | Owner | Copies of favourite docs, with the raw `url`. |
| `publicFolders/{id}` | Server only | Signed-in users, when no block exists in either direction | `ownerId`, `name`, `itemCount`, `covers`, `followerCount`, `shareImage`, `generation`, `sourceCreatedAt`, `createdAt`, `updatedAt`, `lastAddedAt`. |
| `publicFolders/{id}/items/{key}` | Server only | Signed-in users, when the header exists and no block exists | `id`, `provider`, `thumb`, `wallpaperDocumentId`, `addedAt`, `projectedAt`. |
| `publicFolders/{id}/followers/{uid}` | Server only | Nobody | `uid`, `createdAt`. |
| `usersv2/{uid}/followedFolders/{id}` | Server only | The user | `folderId`, `ownerId`, `createdAt`. |
| `folderVisibilityRateDaily`, `folderFollowRateDaily` | Server only | Nobody | Daily counts for the rate limits. |
| `publicFolderState/{id}` | Server only | Nobody | `generation`, `deleting`, `ownerId`. The removal fence. |

The public data is a server projection. It is not a copy of the private docs. The projection never holds the raw `url`.

### Projection

`functions/src/publicFolders.ts` owns the projection.

- `onFolderWritten` calls `syncPublicFolder` when `public`, `name`, `ownerId` or `moderationHidden` changes, or when the folder is deleted.
- `onFolderItemWritten` calls `syncPublicFolderItem` after it repairs the folder counts.
- Each projection write reads the folder, the owner account, the deletion barrier, the header and the fence in one transaction. An item write also reads the private item and its wall in that transaction.
- The header keeps the folder doc `createTime` as `sourceCreatedAt`. A new folder that reuses a deleted folder id is a new source, so it starts with no old followers.
- `publicFolderState/{id}` fences a removal. The server deletes the header first. The header stays absent until the old followers, follows and items are gone. A delayed write from before the removal cannot restore data.

A folder is projected only when all of these are true:

1. `public` is `true` and `moderationHidden` is not `true`.
2. The name passes `publicFolderName`: 1 to 50 characters after the spaces are collapsed, with no control, format, private-use or unassigned characters. If the name fails, the server sets `public` to `false`.
3. The owner is open: `usersv2/{uid}` exists and is not `deleted`, the deletion barrier is not closed, and the Firebase Auth user is not disabled.

An item is projected only when all of these are true:

1. The item `ownerId` is the folder owner.
2. The item is a Prism wall. Wallhaven and Pexels items stay private, because the client writes their thumbnails.
3. The wall doc exists. The server finds it by `wallpaperDocumentId`. Only an older item without that field is found by its `id`.
4. The wall passes the free gallery gate: `review == true`, a protected original, not streak exclusive, not drop reserved, not in a drop (`dropWeek`), and not in a premium collection.

`onWallPublicGateChanged` runs on each wall write. When a projected wall stops passing the gate, or its thumbnail changes, the server re-projects each public copy of that wall. A wall that is held after reports, deleted or moved into a drop leaves every public folder.

The server takes `thumb`, `id` and `wallpaperDocumentId` from the wall doc, not from the item. The `thumb` must be a Prism preview URL. The server clamps `addedAt` to the current time.

The header `covers` are the 4 newest projected thumbnails. `lastAddedAt` is the newest `projectedAt`, so a header refresh does not lose it. When the covers change, the server makes a 4-wall image with the push gallery renderer (`buildPushGallery`) and stores its URL in `shareImage`. The image needs at least 2 Prism preview thumbnails.

### Removal

The server removes the projection in this order: the header, then each follower edge pair, then the items. The follow callable and the item rules need the header, so they stop at the first step.

| Event | Result |
|---|---|
| The owner makes the folder private | The projection is removed. The followers are removed. |
| The owner deletes the folder | The projection is removed. |
| The owner deletes the account | `deleteAccount` removes the owner's projections and follows. The deletion barrier stops new syncs. |
| `usersv2/{uid}` gets `deleted: true`, or is removed | `projectUserProfile` removes the owner's projections and the user's followed-folder edges. |
| A moderator hides the folder | `moderationHidden: true`. The projection is removed. The owner cannot make it public again. |
| A user blocks another user | `blockUser` removes the folder follows in both directions. |

### Callables

| Callable | Input | Checks |
|---|---|---|
| `setFolderPublic` | `folderId`, `public` | Signed in. The folder id matches `[A-Za-z0-9_-]{1,128}`. The caller owns the folder. The name passes the check (error `failed-precondition`, message `name`). The folder is not hidden (message `hidden`). At most 30 changes a day. It runs the sync before it returns `{public}`. |
| `setFolderFollow` | `folderId`, `following` | Signed in. Valid id. One transaction checks that the folder is still public, the owner is open, the caller account is open and no block exists in either direction. The caller is not the owner. At most 200 follows a day and 500 followed folders. An unfollow always works and does not count, so a user can remove a follow of a folder that went private. |
| `setFolderHidden` | `folderId`, `hidden` | Admins only (`isAdminCaller`). |

### Reports and moderation

The folder page overflow menu has **Report folder**. It opens the content report sheet with `contentType: folder` and the folder id. `submitContentReport` checks that `publicFolders/{id}` exists.

When 3 different reporters with accounts older than 7 days report one folder, `onContentReportCreated` hides it. An admin can hide or show a folder with `setFolderHidden`.

### Follow and the "New in" push

`sendFolderDigests` runs every 15 minutes. It sends at 13:00 local time, from `appOpenTimezoneOffsetMinutes`. The follow digest sends at 19:00, so one user never gets both pushes at the same time.

1. The job finds the headers with `lastAddedAt` in the last 24 hours.
2. It reads the items with `projectedAt` in the last 24 hours, at most 12 for each folder.
3. Before it plans and again before it sends, it checks the folder, the owner, the items, the gallery gate of each wall, the follower, the follow, the blocks and the folder alert token.
4. It makes one digest for each follower. The folder with the most new walls is first. The walls alternate between folders. A wall in two followed folders shows once.
5. It drops a folder when a block exists in either direction, or when the follower no longer follows it.
6. It claims `usersv2/{uid}/private/folderDigest.day` in a transaction. That transaction also checks that the follower and the folder owners are open. After the claim, it does the delivery checks again just before the send. It releases the claim if the send fails or a check fails.

The push goes only to a session with `folderAlerts == true` and `folderAlertsToken` equal to `fcmToken`. Only builds with this feature write those fields.

| Field | Value |
|---|---|
| Title | "New in Night" for one folder. "New in Night and 2 more" for three folders. |
| Body | The tags line of the walls, or "Tap to see them all." |
| `route` | `folder` |
| `url` | `https://prismwalls.com/folder/<lead folder id>` |
| `folder_id`, `folder_count` | The lead folder and the number of folders |
| `notification_kind` | `folder_digest` |
| Image | The lead wall thumbnail |

The push has one image. The daily gallery cap allows one gallery push a day, and the Wall of the Day or the Drop push is that gallery. A tap opens the lead folder, where the new walls are first. The native title keys are `notif_push_folder_digest_title_one` and `notif_push_folder_digest_title_more`.

### Share

**Share folder** makes a short link with `createFolderLink`. The link type is `page` and the canonical URL is `https://prismwalls.com/folder/<id>`. The preview has the folder name, the count, the owner and the `shareImage`.

The worker (`infra/cloudflare/worker/src/index.ts`) accepts the image only when it is `<R2_PREVIEW_BASE_URL>/push-gallery/v1/<64 hex>.jpg`. For a folder link, the worker uses that image as `og:image` (1200 x 545) and does not render a browser card. A direct `/folder/<id>` landing shows "A folder on Prism", not the folder id.

The share sheet uses the `shareImage`, or the newest cover when there is no share image. With no covers, the app shares the name and the link as text.

### App

| File | Role |
|---|---|
| `lib/features/folders/data/repositories/public_folders_repository_impl.dart` | Reads the projection, calls the callables, maps refusals. |
| `lib/features/folders/biz/public_folder_cubit.dart` | The public folder page: load, follow and unfollow with undo on a refusal. |
| `lib/features/folders/biz/bloc/folders_bloc.j.dart` | `visibilityRequested` for the owner toggle. |
| `lib/features/folders/views/pages/folder_screen.dart` | Owner mode, or `PublicFolderView` when the folder is not the user's. |
| `lib/features/folders/views/widgets/public_folder_view.dart` | Read-only page, header, Follow, Share, Report. |
| `lib/features/folders/views/widgets/profile_folders_row.dart` | The profile Folders row. |
| `lib/features/folders/views/widgets/folder_card.dart` | Shared card for the Library, the profile and followed folders. |
| `lib/features/folders/views/folder_share.dart` | Short link and share sheet. |

States of the public folder page:

| State | What shows |
|---|---|
| Loading | Grey placeholder tiles. |
| Private, deleted, hidden or blocked | "This folder is private or no longer exists" with **Browse wallpapers**. |
| Load failed | "Could not load this folder." with **Try again**. |
| No visible walls | The header, then "No wallpapers here yet". |

### Analytics

| Event | Fields |
|---|---|
| `folder_visibility_changed` | `is_public`, `source` (`folder_menu`) |
| `public_folder_viewed` | `source` (`profile`, `library` or `link`), `item_count` |
| `folder_follow_changed` | `following`, `source` (`folder_page`) |
| `folder_shared` | `source` (`folder_page` or `owner_folder`) |
| `folder_push_opened` | `folder_count` |
| `notification_preference_changed` | `preference: folders` |

## Deploy order

Do these steps in this order. No backfill is necessary, because every folder starts private.

1. Firestore rules and indexes: `firebase deploy --only firestore:rules,firestore:indexes --project prism-wallpapers`. Wait until these indexes are built: `publicFolders` (`ownerId` ASC, `updatedAt` DESC), the `followedFolders.folderId` collection-group field, and the `items.wallpaperDocumentId` collection-group field.
2. Cloud Functions. New: `setFolderPublic`, `setFolderFollow`, `setFolderHidden`, `sendFolderDigests`, `onWallPublicGateChanged`. Changed: `onFolderWritten`, `onFolderItemWritten`, `projectUserProfile`, `deleteAccount`, `blockUser`, `submitContentReport`, `onContentReportCreated`, `sendFollowDigests`. The folder triggers, the wall trigger, `setFolderPublic` and `setFolderHidden` need the R2 secrets.
3. Cloudflare Worker: `infra/cloudflare/worker`.
4. The app release.

## Limits

- Prism has no word filter for public user text. Folder names get the length and hidden-character check. Reports and the moderation hide cover the rest.
- Prism has no suspension state. A disabled Firebase Auth user counts as suspended at the next sync, follow or digest. No event starts a sync when Auth disables a user. A moderator can hide the folders at once with `setFolderHidden`.
- Wallhaven and Pexels wallpapers do not show in public folders.
- A wall that becomes eligible again (for example, approved after a hold) shows in a public folder at the next sync of that folder.
- A short link keeps the name and image it had when it was made. When the folder goes private or is deleted, the link preview still shows them. The app shows the private state. This is an open product decision.
- Premium walls do not show in public folders. The projection uses the free gallery gate, the same gate as the folder page and the push.
- Making a folder private removes its followers. Making it public again starts at 0 followers.

## How to test

1. Sign in as user A. Open a folder with at least 2 Prism wallpapers. Open the overflow menu. Tap **Make public**. Make sure the dialog says "Anyone on Prism can see its name and wallpapers, follow it and open its link."
2. Tap **Make public**. Make sure the toast "This folder is now public." shows and the header shows **Public**.
3. Sign in as user B on a second device. Open A's profile. Make sure the **Folders** row shows the folder.
4. Open the folder. Make sure the header shows "By <A>", the count and "No followers". Tap **Follow**. Make sure the button changes to **Following** and the count changes to "1 follower".
5. Tap the share button. Make sure the share sheet opens with the folder link.
6. As A, add a wallpaper to the folder. Run `sendDueFolderDigests` for 13:00 in B's time zone, or wait until 13:00. Make sure B gets "New in <folder>".
7. As A, tap **Make private**. As B, open the folder link. Make sure "This folder is private or no longer exists" shows.
8. As B, block A. Make sure A's folder does not open for B and does not show on A's profile.

Tests:

| Area | Files |
|---|---|
| Projection, callables, cleanup | `functions/src/__tests__/publicFolders.test.ts` |
| Digest | `functions/src/__tests__/folderDigest.test.ts` |
| Rules | `tool/firestore_rules_smoke.mjs` (public folder cases) |
| Worker | `infra/cloudflare/worker/test/worker.test.mjs` (folder link cases) |
| App | `test/features/folders/` |
