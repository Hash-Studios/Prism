# Folders: private, public and shared

A **folder** is a named group of saved wallpapers. A **smart folder** fills itself from rules. See Smart folders. Each folder is private when the user makes it. The owner can make a folder **public**. Other signed-in users can then see the folder, follow it, and share its link. On iOS, guests can see public folders too, but must sign in to follow one. Followers get one "New in <folder>" push a day when the owner adds wallpapers. The user can save all the wallpapers of a folder at once with **Save all**.

The owner can invite up to 10 people to add and remove wallpapers in a folder. These people are editors. See Shared folders. The owner and the editors can split a folder into named sections. See Sections.

The Library page ([library.md](library.md)) covers the Folders tab, the folder grid and the Save to folder sheet. This page covers public and shared folders. See Discover folders for the Search row and the discover page.

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
| Folder page, owner | A download button **Save all** in the top bar, when the folder has wallpapers. |
| Folder page, a public folder the user follows | The same **Save all** button. It shows only while the user follows the folder. |

## Platforms

| Platform | Support |
|---|---|
| Android | Full. |
| iOS | Full. |

On iOS, a guest can open a public folder link. The page shows the public folder. **Follow** asks the guest to sign in. A guest cannot open a private folder. Android has no guests. See the Access table in [deep-links.md](deep-links.md#access).

## Free and Pro

Public folders are free. A viewer opens each wallpaper through the normal detail page. The Pro, Drop and streak gates of the detail page stay in effect.

## Save all

### The plan

Before a download starts, the app builds a `FolderSavePlan` (`lib/features/folders/domain/entities/folder_save_plan.dart`). The app shows the plan in a sheet.

Each wall gets one kind:

| Kind | Meaning |
|---|---|
| `free` | The wall costs no coins. The user has Pro, a free grace download, or a premium wall with a premium pass. |
| `coins` | The wall costs the download price. The default price is 10 coins. |
| `proOnly` | A premium wall. The user has no Pro and no premium pass. |
| `protected` | A streak or Drop wall. It needs its own unlock. |
| `removed` | The wall is deleted or held for review, or it has no protected original. |
| `saved` | The wall is already in Downloads. |

The app reads the `walls` documents where `review == true`, in batches of 30. It uses them to find premium, protected and removed walls. The app uses the same checks as the server callable `resolveOriginalAccess`.

Free grace downloads go to the first walls in folder order.

The sheet shows one line for each kind. For example: "23 wallpapers are free", "2 wallpapers cost 10 coins each", "3 wallpapers need Pro".

A user without Pro sees two buttons: "Save the 23 free wallpapers" and "Save all I can (20 coins)". **Save all I can** saves the free walls. It also saves the coin walls that the balance covers, in folder order.

A Pro user sees one button. If a folder has no coin walls, the user sees one button.

In Save all, premium walls are for Pro users only. A user without Pro can still buy one premium wall on its own page.

### Coins

Save all adds no coin logic and makes no backend change.

The coin gate (`lib/features/ads/biz/coin_gate.dart`) has no batch mode. So Save all runs the gate once for each wall. The gate shows no ad and no low-balance sheet during Save all.

For a Prism wall, the server callable `resolveOriginalAccess` charges the coins when it grants the original link. Its batch mode takes only 1 or 2 `set` items. So Save all calls it once for each wall. Each call sends `maxCoins`. Its value is the price that the plan showed. If the server asks for more, it charges nothing. The wall then fails with the message "price changed".

Wallhaven and Pexels walls exist only in the owner's private folders. For these walls, the app downloads the file first, with no charge. Then the app spends the coins through the gate. Then the app saves the file. If the save fails, the gate requests a refund. An unconfirmed refund stays in pending recovery and blocks another charge for the same wall until it settles. This is the same refund flow as a single download.

Charges run one at a time. So the server prices each charge after the one before it. Planned-free walls finish before any paid wall starts, so a faster paid request cannot take the grace promised to a slower free wall.

A Prism wall that is charged but not saved keeps its grant for 5 minutes. In that time, "Retry failed" does not charge again. This is the same rule as a single download. After 5 minutes, a new save charges again. See Limits.

Before the first charge, the app asks for Photos or storage access. If the user refuses, nothing is charged.

### Save

`FolderSaveBloc` is one app-wide singleton in `lib/features/folders/biz/folder_save/`. One save runs at a time. Leaving the folder page does not stop a save.

It saves at most 3 walls at the same time. For each wall, the app downloads the file into the app temporary folder `folder_save/`. Then it saves the file. Then it deletes the file. The app deletes the whole `folder_save/` folder at the start and at the end of each run.

Each download tries 2 times when a network or server error occurs.

On iOS, each wall goes to Downloads and Photos. With full Photos access, it also goes to an album with the folder name. With limited or add-only access, the wall goes to Photos with no album.

On Android, each wall goes to `Pictures/Prism/<folder name>`. Each character that a path cannot hold becomes a space. The name is at most 60 characters. The Downloads list also shows the files in every `Pictures/Prism/<name>/` folder. "Clear downloads" in Library deletes them too.

A wall that is already in Downloads is skipped. The plan skips it. The save skips it again just before it saves the wall.

The folder page shows a progress row, for example "Saving 12 of 23", with **Cancel**. **Cancel** stops the walls that have not started. Walls that have started finish. Their coins stay spent when the file saves. A failed Wallhaven or Pexels save uses the gate's refund flow. A failed Prism save keeps its paid grant for 5 minutes for retry, as described above. Walls that did not start cost nothing.

At the end, the row changes to a summary card. The card shows four counts: saved, already in Downloads, failed, and not started after a cancel. **Retry failed** saves the failed walls again. **Done** closes the card.

When no page for that folder is on screen at the end, the app shows a toast. For example, the toast reads "Saved 20 wallpapers from Night." or "Saved 20 from Night. 1 failed. Open the folder to retry."

If the app is killed, the save stops. Walls that saved stay in Downloads and in the album. The pending download recovery returns the coins for a Wallhaven or Pexels wall that did not save. It runs 2 minutes after the charge. To finish, tap **Save all** again. The plan skips the walls that are already in Downloads.

### Followed folders

On a public folder, Save all uses the walls on the page. These walls come from the public projection. They pass the free gallery gate. So a follower gets only the walls that the follower can open. Private folder items, premium walls and Drop walls do not show in Save all.

## How it works

### Data

| Path | Writer | Readers | Contents |
|---|---|---|---|
| `folders/{id}` | Owner, through the client rules. The server sets `public` and `moderationHidden`. | Owner and editors | The private folder. The shared folder rules add editor access. See Shared folders. |
| `folders/{id}/items/{key}` | Owner and editors | Owner and editors | Copies of favourite docs, with the raw `url`. |
| `publicFolders/{id}` | Server only | Guests, and signed-in users when no block exists in either direction | `ownerId`, `name`, `itemCount`, `covers`, `followerCount`, `shareImage`, `generation`, `sourceCreatedAt`, `createdAt`, `updatedAt`, `lastAddedAt`. |
| `publicFolders/{id}/items/{key}` | Server only | Guests and signed-in users, when the header exists. A block hides it from a signed-in user. | `id`, `provider`, `thumb`, `wallpaperDocumentId`, `addedAt`, `projectedAt`. |
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

When `shareImage` is missing, the short-link preview uses the newest cover. The worker (`infra/cloudflare/worker/src/index.ts`) accepts only `<R2_PREVIEW_BASE_URL>/push-gallery/v1/<64 hex>.jpg` strips or `<R2_PREVIEW_BASE_URL>/previews/<64 hex>.img` covers. It uses that image as `og:image` and does not render a browser card. Strips declare 1200 x 545 dimensions; covers omit dimensions. A direct `/folder/<id>` landing shows "A folder on Prism", not the folder id. Existing short links retain their stored image snapshot; sharing again creates a new link when the preview changes.

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
| `lib/features/folders/domain/entities/folder_save_plan.dart` | The Save all plan. |
| `lib/features/folders/domain/entities/folder_save_run.dart` | One Save all run and its outcomes. |
| `lib/features/folders/biz/folder_save/folder_save_bloc.j.dart` | The run, 3 walls at a time, cancel and retry. |
| `lib/features/folders/data/folder_save_gateway_impl.dart` | Wall access, the coin gate for each wall, download and album save. |
| `lib/features/folders/views/widgets/folder_save_views.dart` | The plan sheet, progress row and summary. |

States of the public folder page:

| State | What shows |
|---|---|
| Loading | Grey placeholder tiles. |
| Private, deleted, hidden or blocked | "This folder is private or no longer exists" with **Browse wallpapers**. |
| Load failed | "Could not load this folder." with **Try again**. |
| No visible walls | The header, then "No wallpapers here yet". |

The "By <owner>" row in the header opens the owner's profile. Its tap area is at least `prismTapTarget` high: 44 points on iOS, 48 dp on Android.

When the user comes back to the app, the page reloads the folder without a loading state. A folder that went private while the page was open then shows the private state. A read that fails keeps the shown folder.

### Analytics

| Event | Fields |
|---|---|
| `folder_visibility_changed` | `is_public`, `source` (`folder_menu`) |
| `public_folder_viewed` | `source` (`profile`, `library` or `link`), `item_count` |
| `folder_follow_changed` | `following`, `source` (`folder_page`) |
| `folder_shared` | `source` (`folder_page` or `owner_folder`) |
| `folder_push_opened` | `folder_count` |
| `notification_preference_changed` | `preference: folders` |
| `folder_save_started` | `wall_count`, `coin_cost`, `pro` |
| `folder_save_finished` | `saved`, `skipped`, `failed` |
| `folder_save_cancelled` | `saved`, `not_saved` |

## Shared folders

An owner can invite editors. An editor adds and removes wallpapers in the folder. A shared folder can be public or private. A private shared folder is visible only to its members.

### Roles

| Action | Owner | Editor |
|---|---|---|
| Add and remove wallpapers | Yes | Yes |
| Rename | Yes | No |
| Make public or private | Yes | No |
| Invite people | Yes | No |
| Remove people | Yes | No |
| Delete the folder | Yes | No |
| Add, rename, delete and reorder sections, and move wallpapers | Yes | Yes |
| Auto-rotate and iOS Shortcuts rotation | Yes | No |
| Leave the folder | No | Yes |

A folder has at most 10 editors, besides the owner.

The app reads the folder again each time a member opens it, so a join, a leave or a removal on another device shows at once. Offline, a folder the app already has keeps its last copy.

### Where to find it

| Surface | What the user sees |
|---|---|
| Folder page header | The avatars of the members and the member count. The owner also sees **Invite**. Tap the avatars to open **People**. |
| Folder page overflow menu | The owner sees **Invite**. The owner sees **People** only when the folder has editors. An editor sees **People**. |
| People sheet | Each member, with **Owner** or **Can add and remove**. The owner can **Remove** an editor. An editor can **Leave folder**. |
| Long press on a wallpaper in a shared folder | A sheet with "Added by <name>" and **Remove from folder**. If the folder has no editors, the owner gets the old remove confirm. |
| Library > Folders | A **Shared with you** section after the user's folders and before **Folders you follow**. A people icon marks shared folders. |
| Invite link | A short link to `https://prismwalls.com/folder/<folderId>?invite=<code>`. The app opens the join page at `/folder/invite/<code>`. |
| Push | "<name> added 3 walls to <folder>". A tap opens the folder. |

### Invite and join

- The owner taps **Invite**. The `createFolderInvite` callable makes a code. The code has 10 characters and no look-alike characters. It works once and is valid for 7 days. The app makes a short link and opens the share sheet.
- Opening the link shows the join page. It shows the covers, the name, "<owner> invited you…", the counts and **Join folder**. A guest goes to sign-in first. After sign-in, the join page opens.
- The page reads the folder through the `getFolderInvite` callable. The rules refuse a read by a non-member.
- A refused code shows only its reason. It never shows the folder. A blocked caller or a caller with a closed account gets the generic unavailable status, not a status that reveals the block.
- `joinFolder` refuses a join in one transaction when:

| Reason | Refused when |
|---|---|
| `not_found` | The invite does not exist, the folder is gone, or the invite creator is no longer the owner. |
| `used` | The code was already used. |
| `expired` | The code is older than 7 days. |
| `blocked` | A block exists in either direction between the joiner and the owner or any editor. |
| `account` | The joiner's account is closed or deleted, or the joiner's Firebase Auth user is disabled. |
| `full` | The folder already has 10 editors. |

- The page shows "This invite is not available" for `not_found`, `blocked` and `account`. A block is never revealed. For `used`, the page shows "This invite was already used".
- Joining again as a member, or as the owner, changes nothing. It does not spend the code.

### Data

| Path | Writer | Readers | Contents |
|---|---|---|---|
| `folders/{id}` | Server only | Owner and editors | New fields `members` (map: uid to `addedBy`, `addedAt`) and `memberIds` (sorted editor uids). |
| `folders/{id}/items/{key}` | Owner and editors | Owner and editors | New field `addedBy`, the uid that added the item. `ownerId` stays the folder owner, also for items an editor adds. An item without `addedBy` was added by the owner. |
| `folderInvites/{code}` | Server only | Server only | `code`, `folderId`, `folderCreatedAt`, `createdBy`, `createdAt`, `expiresAt`, `usedBy`, `usedAt`. `folderCreatedAt` binds the invite to this folder generation, so a deleted and recreated folder cannot reuse an old invite. Nobody reads it from a client. |
| `folderActivity/{folderId}` | Server only | Server only | `folderCreatedAt`, `pending` (item key to adder uid), `pendingCreatedAt`, `firstPendingAt`, `dueAt`, `lastSentAt`. Its `items/{itemKey}` receipts store the source item's create time to deduplicate trigger retries after a burst is claimed. |
| `folderInviteRateDaily/{uid_day}` | Server only | Server only | Invite count. 30 invites a day. |

### Rules

- A folder is readable by its owner and by the uids in `memberIds`. Only the owner updates `name`, `updatedAt`, `itemCount` and `covers`. Only the owner deletes the folder. No client writes `members`, `memberIds`, `public` or `moderationHidden`.
- An editor creates an item only when `ownerId` is the folder owner and `addedBy` is the editor. An editor deletes any item of the folder.
- An editor does not write the folder counts. `onFolderItemWritten` repairs `itemCount` and `covers`.
- A private shared folder is visible only to its members. A public folder stays public. Members do not change who can read the public projection. Items an editor adds are projected like the owner's items.

### Callables

| Callable | Input | Checks |
|---|---|---|
| `createFolderInvite` | `folderId` | Signed in. Owner only. The owner's account is open. Fewer than 10 editors. At most 30 invites a day. Returns `code` and `expiresAtMs`. |
| `getFolderInvite` | `code` | Guests allowed. Returns the folder preview only when the code is good or the caller is already a member. |
| `joinFolder` | `code` | The refusals in Invite and join, in one transaction. The message is the reason. |
| `removeFolderMember` | `folderId`, `uid` | Owner only. Removing a non-member returns `removed: false`. |
| `leaveFolder` | `folderId` | Editors only. The owner gets `invalid-argument`. |

### Push

- `onFolderItemWritten` records each new item of a folder with editors in `folderActivity/{folderId}`. It keys each item, so a retried trigger counts once.
- `sendFolderActivityPushes` runs every 10 minutes. A burst waits 10 minutes after its first add. A folder gets at most 1 push an hour.
- Each member gets one push about the other people's adds. The push never covers the member's own adds. It never covers someone the member blocked, or someone who blocked the member. Items removed before the send do not count.
- Title: "<name> added a wall to <folder>", "<name> added 3 walls to <folder>", or "<name> and 2 more added 5 walls to <folder>". Body: "Tap to open the folder." A tap opens the folder.
- The push uses the **Folders you follow** setting (`folderAlerts` and its token). The copy is English for now. A recipient can be on a build without native keys for this push, as with `wallCommented`.

### Cleanup

- deleteAccount: the user leaves every folder they edit, and the invites they created are deleted. The wallpapers they added stay in those folders.
- When the owner deletes their account, each folder they own is deleted, with all its items. This includes the items editors added. The editors lose the folder.
- When the owner deletes a folder, its invites and pending pushes are deleted.
- blockUser: when one user owns a folder that the other edits, the editor leaves it.

### Analytics

| Event | Fields |
|---|---|
| `folder_invite_created` | `source` (`folder_header`, `folder_menu` or `people_sheet`) |
| `folder_joined` | `source` (`invite_link`) |
| `folder_join_refused` | `reason` (`not_found`, `expired`, `used`, `full`, `blocked`, `account` or `error`) |
| `folder_member_removed` | `member_count` |
| `folder_member_left` | `member_count` |

## Sections

A folder can have up to 20 sections. Sections split the wallpapers of a folder into named groups. A section is not a folder. It has no privacy of its own.

Each section has an id, a name and an order. The app accepts 1 to 40 graphemes and at most 160 UTF-16 units for a name. A grapheme is one character as the user sees it. The UTF-16 cap keeps names compatible with the rules.

Each wallpaper is in one section, or in **Unsorted**. **Unsorted** is the group at the top. It holds the wallpapers that have no section. It also holds the wallpapers whose section was deleted. It shows only when it has wallpapers, or while the user drags a wallpaper.

The owner and the editors can add, rename, delete and reorder sections, and move wallpapers. Viewers of a public folder see the sections, but they cannot change them.

### Where to find it

| Surface | What the user sees |
|---|---|
| Folder page, overflow menu | **Add section**, **Suggest sections**, **Select wallpapers** (when the folder has sections) and **Reorder sections** (when it has 2 or more). |
| Section header | The cover (the first wallpaper), the name and the count. Tap the header to collapse or expand the section. A menu has **Rename**, **Save section** and **Delete section**. |
| Section strip | A row of chips at the top of the page. It stays in view as the user scrolls. One chip for each group, with the cover, the name and the count. A tap scrolls to that section. |
| Wallpaper, long press | A menu with **Move to section** and **Remove from folder**. |
| Wallpaper, long press and move | The user drags the wallpaper. |
| Selection bar | "2 selected" and **Move to section**. |
| Public folder page | The same headers and strip. Read only. |
| Web catalogue page | Unsorted first, with no heading. Then each section, with a heading and the count. |

### Move a wallpaper

Use one of these ways to move a wallpaper:

- Drag the wallpaper onto a section header or a chip in the section strip.
- Long press the wallpaper. Tap **Move to section**.
- Tap **Select wallpapers** in the overflow menu. Select the wallpapers. Tap **Move to section** in the selection bar.

The sheet lists **Unsorted**, each section and **New section**.

**Move to section** is the path for screen readers, such as VoiceOver and TalkBack.

### Suggest sections

**Suggest sections** finds groups in the wallpapers of **Unsorted**. The app makes the groups on the device. It makes no AI call.

The app reads the `walls` documents of the Prism wallpapers in **Unsorted**. Each query uses 30 ids and `review == true`.

The app groups the wallpapers by mood, by category, or by main color. The main color is the first entry of `colors`.

The mood rules are a copy of `functions/src/wallMoods.ts`. The copy is in `lib/features/moods/domain/wall_mood_rules_data.dart`. The test `functions/src/__tests__/wallMoodRulesParity.test.ts` fails when the two differ. To write the copy again, set `UPDATE_MOOD_RULES=1`.

- A group needs 2 or more wallpapers.
- The category "General" is not a group.
- Wallhaven and Pexels wallpapers have no mood, category or color data. They stay in **Unsorted**.
- Larger groups come first.
- New sections stop at 20.
- A group whose name is the same as an existing section (case does not matter) goes into that section.

The sheet opens on the kind that sorts the most wallpapers. Ties go to mood, then category, then color.

The sheet shows each group with 4 covers. The user keeps all, some or none of the groups. One write adds the sections and moves the wallpapers.

### Save section

**Save section** runs **Save all** on the wallpapers of one section. The album still has the folder name.

**Save all** for the whole folder works as before.

Auto-rotate (Android), the iOS Shortcuts folder source, the "New in" push and the shared folder push work as before. They ignore sections.

### Delete a section

Deleting a section removes it. Its wallpapers go to **Unsorted**.

The app writes only the folder doc. The items keep their old `sectionId`. The app reads an unknown `sectionId` as **Unsorted**.

### Reorder sections

Open **Reorder sections** from the overflow menu. Drag the handle of a section to its new place. Screen readers get move up and move down actions.

### Data

The `sections` field is in the folder doc, not in a subcollection. At most 20 sections take roughly 11 KB, allowing for 32 ASCII id characters, 160 three-byte BMP name characters and entry overhead per section. Every reader of the folder already reads that doc.

| Path | Writer | Contents |
|---|---|---|
| `folders/{id}` field `sections` | Owner and editors | A list of `{id, name}` in display order. The list position is the order, so two sections can never share an order. |
| `folders/{id}/items/{key}` field `sectionId` (optional) | Owner and editors | The id of the section. A wallpaper with no `sectionId` is in Unsorted. New wallpapers go to Unsorted. |
| `publicFolders/{id}` field `sections` | Server only | The copy of `sections` in the projection. |
| `publicFolders/{id}/items/{key}` field `sectionId` | Server only | The copy of `sectionId` in the projection. |
| `webPages/folder~{id}` field `groups` | `buildWebCatalog` | `[{name, count}]`, one entry for each run of `items`. The empty name `""` is Unsorted. |

### Rules

- The role comes from the stored folder (`ownerId` and `memberIds`), never from the request.
- The owner can update `sections`, with the other owner fields.
- An editor can update only `sections` in the folder doc.
- A member can update an item when only `sectionId` changes. This includes an item that another member added.
- A stranger and a public viewer can write neither.
- `sections` has at most 20 entries. Each entry has only `id` and `name`. Ids use 1 to 32 ASCII letters, digits, underscores or hyphens. The name is a string of 1 to 160 UTF-16 units.
- The rules cannot count graphemes. The app caps names at 40 graphemes.
- Rules allow 1000 expressions for each request, so each entry gets only these checks. The app trims names and drops entries with a bad id when it reads them.
- `sectionId` matches `^[A-Za-z0-9_-]{1,32}$`.

### Server and web catalogue

- `onFolderWritten` syncs the public projection when `sections` changes on a public folder.
- `publicFolderSections` keeps entries with a good id and a name that passes the public name check. It keeps at most 20.
- A move of a wallpaper fires `onFolderItemWritten`. It repairs the counts and projects the item again. A move is not a new wallpaper, so it sends no shared folder push.
- `buildWebCatalog` reads the header `sections` and the item `sectionId` from the docs it already reads. The Worker still reads 1 doc for each folder page. The read budget does not change.
- Sections show only for the 60 newest wallpapers on the page.

### Analytics

| Event | Fields |
|---|---|
| `folder_section_created` | `source` (`folder_menu` or `move_sheet`), `section_count` |
| `folder_section_renamed` | `section_count` |
| `folder_section_deleted` | `wall_count` |
| `folder_wall_moved` | `method` (`drag` or `menu`), `wall_count` |
| `folder_section_suggestions_shown` | `kind`, `group_count` |
| `folder_section_suggestions_accepted` | `count`, `offered`, `kind` |

### Limits

- When two members change sections at the same time, the last write of the list wins.
- Offline, a section change waits in the queue, as other folder writes do.
- Section names are not translated.
- A wallpaper is in one section only.
- Auto-rotate from one section is not in this change. It needs a new source in the auto-rotate settings, the picker and the Android worker.

## Smart folders

A **smart folder** fills itself from rules. The user sets the rules once. When a new wallpaper is approved and matches the rules, the server adds it to the folder. Examples: "Dark and quiet walls from creators I follow", "Pastel and blue", "Desktop version".

### Rules

A rule has a kind and a value.

| Kind | Wire name | Value | A wall matches when |
|---|---|---|---|
| Mood | `mood` | A mood id from `functions/src/wallMoods.ts`, for example `dreamy` | `matchesMood` is true for the wall. |
| Colour | `colour` | A palette id, for example `blue` | The id is in `walls.colors`. |
| Category | `category` | A name from `CATEGORY_NAMES`, for example `Pastel` | `walls.category` is the name. |
| Creators I follow | `followed` | Empty | The folder owner follows `walls.creatorUid` (`profiles/{owner}/following/{creator}` exists). |
| Creator | `creator` | A creator uid | `walls.creatorUid` is the uid. |
| Desktop version | `desktop` | Empty | `parseDesktopVariant(walls.desktopVariant)` is not null. |
| Editors' Choice | `editorsChoice` | Empty | `walls.editorsChoiceAt` is set. |

- A smart folder has 1 to 3 kinds. Different kinds join with AND.
- One kind can have 1 to 6 values. Values of one kind join with OR.
- Example: colour `blue`, colour `teal` and category `Pastel` means (blue OR teal) AND Pastel.
- A smart folder holds only walls that pass the free gallery gate (`isPublicWall`) and have a preview thumbnail. A premium, Drop, streak or held wall never goes into a smart folder, so a public smart folder cannot show one.
- The server checks every rule set (`parseSmartRules`). It refuses an unknown kind or value, more than 3 kinds and more than 6 values in one kind.

### Where to find it

| Surface | What the user sees |
|---|---|
| Library > Folders | A **New smart folder** tile after **New folder**. A sparkle icon on each smart folder card. |
| New smart folder sheet | The name, the rule chips, and a live preview of the first 12 matches with the count. Each rule chip is a `PrismChip` with a 48 dp tap area on Android and 44 points on iOS. The name field has its label above it and no placeholder, so a screen reader reads "Folder name" once. |
| Folder page, smart folder | The rules under the title, for example "Colour: Blue, Teal · Creators I follow". The owner sees **Edit rules**. |
| Empty smart folder | "Nothing matches yet" with **Edit rules**. |
| Save to folder sheet | Smart folders do not show. Nobody saves a wall into a smart folder by hand. |

### Create and edit

1. The user taps **New smart folder**. The sheet opens.
2. The user types a name and taps rule chips. The preview loads 400 ms after the last tap. The count shows "37 matches", "100+ matches" or "0 matches".
3. When nothing matches, the sheet shows: "No wallpaper matches all these rules yet. Remove a rule to see more, or save the folder and new matches go in when they arrive." The user can still create the folder.
4. A tap on a fourth kind, or a seventh value in one kind, does not add the chip. A note tells the user the limit.
5. **Create smart folder** calls `createSmartFolder`. The server makes the folder and fills it. The app opens the folder.
6. **Edit rules** opens the same sheet with the current rules. **Save rules** calls `updateSmartFolderRules`. The server fills the folder again.

The Creator row loads all pages of the returned following list, plus creators already selected in the rules. Selected creators keep a removable chip even when their profile cannot load. The sheet cannot save after the signed-in account changes. A user who follows nobody sees "Follow creators to pick one here."

### Behaviour

| Feature | Smart folder |
|---|---|
| Private by default | Yes. |
| Make public | Yes, with **Make public**, the same as other folders. The projection shows only gated walls. |
| Share for editing | No. `createFolderInvite` refuses with `failed-precondition` and message `smart`. **Invite** and **People** do not show. |
| Add, remove or move walls by hand | No. The rules refuse client item writes. The hold menu does not open. |
| Sections | No. The rules refuse `sections` on a smart folder. The section menu items do not show. |
| Rename and delete | Yes, the owner. |
| Save all | Yes. |
| Auto-rotate (Android) and iOS Shortcuts | Yes. Both read the items. |
| "New in" push and web catalogue | Yes, when the folder is public. Both read the projection. |

### How it works

`functions/src/smartFolders.ts` owns smart folders.

#### Data

| Path | Writer | Readers | Contents |
|---|---|---|---|
| `folders/{id}` field `smartRules` | Server only | Owner | `[{kind, value}]`, sorted. A folder with this field is a smart folder. |
| `folders/{id}/items/{key}` | Server only, for a smart folder | Owner | The same shape as a Prism favourite item, plus `smart: true`. `ownerId` is the folder owner. The key is `prism_<wall id>`. |
| `smartFolderIndex/{folderId}` | Server only | Nobody | `ownerId`, `rules`, `anchorKind`, `anchors`, `updatedAt`. The rule index. |
| `smartWallKeys/{wallDocId}` | Server only | Nobody | `keys`, `wallId`, `thumb`, `createdAt`. The match keys of one gated wall. |
| `smartFolderPreviewRateDaily`, `smartFolderEditRateDaily` | Server only | Nobody | Daily counts for the rate limits. |
| `smartFolderOwners/{uid}` | Server only | Nobody | `ownerId`, `updatedAt`. Two creates at the same time both write it, so one retries and the 20-folder limit holds. |

#### Wall keys

`wallSmartKeys` turns a wall into a list of keys: `mood:<id>` for each matching mood, `category:<name>`, `colour:<id>` for each colour, `creator:<uid>`, `desktop` and `editorsChoice`. A wall has at most 23 keys with the current mood and palette sets. A wall that fails the gate has no keys.

`onWallSmartFolders` runs on each wall write. It returns at once, with no reads, when no key field changed (`changesSmartKeys`). Otherwise `syncWallSmartFolders` reads the wall again and:

1. Reads the current wall and writes `smartWallKeys/{wallDocId}` in one transaction, or deletes the keys doc when the wall has no keys.
2. Finds only smart items of the wall with the `items.wallpaperDocumentId` and `smart == true` collection-group query. It checks each again in a transaction and deletes it when the wall no longer matches. This removes rejected, held, deleted and changed walls.
3. Finds candidate folders in the rule index with one query: `anchors array-contains-any <wall keys>`.
4. Adds the wall to each candidate in a transaction that reads the folder rules, the wall and the follow edge at commit time.

Because the trigger reads the current wall and each write is a transaction, a late, repeated or out-of-order event cannot add a wrong wall.

#### Rule index

Each smart folder has one index entry. The entry stores the keys of one rule kind, the anchor. The anchor is the kind that a new wall is least likely to match, in this order: creator, Editors' Choice, creators I follow, desktop, category, colour, mood.

- A wall that matches the folder must have one anchor key. So the index query returns every folder that can match, and only those folders and folders that share the anchor.
- For "Creators I follow" as the anchor, the anchors are `creator:<uid>` for each followed creator. `onSmartFollowWritten` adds or removes one key when the owner follows or unfollows a creator. The follow trigger reads the live edge, folder and index in one transaction, so an old follow event cannot restore an unfollowed anchor. It also reconciles existing items for every folder with a followed rule, even when another kind is the anchor. Rule edits read the follows and rewrite the folder and index in the same transaction.
- Firestore allows 30 values in `array-contains-any`. The current maximum of 23 wall keys fits in one query.

#### Cost at 10,000 smart folders

| Step | Reads | Writes |
|---|---|---|
| Wall write with no key change (counters) | 0 | 0 |
| Derived wall keys | 1 current wall | 1 keys set or delete |
| Index query | 1 per candidate folder (at least 1) | 0 |
| Smart item check | Matching smart item query + 3 transaction reads per held item, plus a follow edge when needed | 1 delete per removed item |
| Add to one folder | 4 or 5 (folder, wall, item, count, optional follow edge), plus 2 at the cap | Item + folder serialization write, plus 1 delete when full |

These are the smart-folder operations, not the total downstream trigger bill. Item writes also run count repair, public projection and activity hooks. Public folders can cost more than private folders. Premium collection configuration is cached separately.

At 10,000 smart folders, a wall whose anchors select 200 folders reads those 200 index entries, not all 10,000 folders. Add work scales with those candidates and held smart items. Manual folder saves do not enter the held-item query. Candidate and held-item processing uses batches of 25 concurrent transactions. There is no global candidate cap, since a cap would skip matching folders.

#### Fill

`fillSmartFolder` runs after a create or a rule edit.

1. It queries `smartWallKeys` with `keys array-contains-any <anchor keys>`, newest first, in pages of 200. Index: `smartWallKeys` (`keys` CONTAINS, `createdAt` DESC). It checks the other rules on each result. It stops at 101 matches or after 1,000 docs for each chunk of 30 anchor keys.
2. It adds up to 100 newest matches found within those scan bounds. Each add rechecks the live wall, rules and follow edge in a transaction. New items use the wall `createdAt` for `addedAt`; existing matching items keep their timestamp. Adds to this one folder run sequentially.
3. It reconciles existing items against current rules and wall state in transactions, not against an earlier discovery snapshot.
4. It drops the oldest items until the folder has 500 or fewer.

A "Creators I follow" fill reads at most 10 chunks, which is 300 followed creators. These bounds mean a fill is not guaranteed to find the globally newest 100 matches when there are more followed creators or the scan limit is reached. Approval processing still indexes all followed creators. Preview `more` is true when follow chunks or the scan bound leave results unknown.

`previewSmartFolder` runs the same query and returns the count (at most 100), `more`, and the first 12 walls.

#### Cap

A smart folder keeps at most 500 items, the same limit the app reads (#739). When a new wall would make 501, the add transaction compares the incoming timestamp with the oldest existing `addedAt`. The oldest item drops, including the incoming item when an old fill loses to 500 newer items. The transaction writes the folder as a serialization fence, so concurrent boundary adds retry rather than both admitting a 501st item.

#### Callables

| Callable | Input | Checks |
|---|---|---|
| `previewSmartFolder` | `rules` | Signed in. Valid rules. At most 300 previews a day. |
| `createSmartFolder` | `name`, `rules` | Signed in. Name of 1 to 50 characters after trim. Valid rules. The account is open. At most 20 smart folders (`resource-exhausted`, message `limit`). Returns `folderId` and `count`. |
| `updateSmartFolderRules` | `folderId`, `rules` | Signed in. Owner only, and the folder must be a smart folder. Valid rules. At most 50 edits a day. Returns `count`. |

Creation rechecks account deletion state and the 20-folder count inside the folder/index transaction. An owner account write serializes concurrent creates.

#### Rules

- A client cannot create a folder with `smartRules` or change `smartRules`. The create and update key lists do not include it.
- A client cannot create, update or delete an item of a smart folder. The owner can still delete items of a deleted folder.
- The owner cannot write `sections` on a smart folder.
- No client reads or writes `smartFolderIndex`, `smartWallKeys` or `smartFolderOwners`.

#### Cleanup

- Folder delete: the app deletes only the folder doc. `onFolderWritten` deletes the index entry and the smart items.
- `deleteAccount`: removes the user's index entries with `removeOwnerSmartFolders`. The owned folders and their items go with the other owned folders.

### Analytics

| Event | Fields |
|---|---|
| `smart_folder_created` | `rule_kinds`, `rule_count`, `match_count` |
| `smart_folder_rules_edited` | `rule_kinds`, `rule_count`, `match_count` |
| `smart_folder_opened` | `rule_kinds`, `item_count` |
| `smart_folder_made_public` | `rule_kinds` |

### Limits

- Only walls approved after the deploy have `smartWallKeys`. Older walls need the backfill (`functions/src/scripts/backfillSmartWallKeys.ts`). Until it runs, a new smart folder finds only new walls.
- A new follow does not add the creator's older walls. Edit the rules to fill the folder again.
- A smart folder holds no premium walls, also for a Pro owner.
- Fill and preview searches are bounded by 300 followed creators and 1,000 scanned walls per anchor chunk; the globally newest 100 matches are not guaranteed beyond those bounds.
- The public folder page does not show the rules.
- A blocked creator in a Creator rule still adds walls. Remove the rule to stop it.

### Deploy order

1. Firestore rules and indexes: `firebase deploy --only firestore:rules,firestore:indexes --project prism-wallpapers`. Wait until these indexes are built: `smartWallKeys` (`keys` CONTAINS, `createdAt` DESC) and the `items` collection-group index (`wallpaperDocumentId` ASC, `smart` ASC). The new rules accept every write that shipped clients make.
2. `make functions-env`, so the new functions get `R2_PREVIEW_BASE_URL`. Without it, the trigger and the fill fail and retry. They do not delete data.
3. Cloud Functions. New: `previewSmartFolder`, `createSmartFolder`, `updateSmartFolderRules`, `onWallSmartFolders`, `onSmartFollowWritten`. Changed: `onFolderWritten`, `createFolderInvite`, `deleteAccount`.
4. Backfill, only with the owner's OK. Dry run: `cd functions && npm run build && R2_PREVIEW_BASE_URL=<value> node lib/scripts/backfillSmartWallKeys.js`. Then the same command with `--apply`.
5. The app release.

### Smart folder tests

| Area | Files |
|---|---|
| Matcher, keys, index, fill, trigger, cap, removal | `functions/src/__tests__/smartFolders.test.ts` |
| Category and kind parity with the app | `functions/src/__tests__/smartRuleParity.test.ts` |
| Account deletion | `functions/src/__tests__/deleteAccount.test.ts` |
| Backfill | `functions/src/__tests__/backfillSmartWallKeys.test.ts` |
| Rules | `tool/firestore_rules_smoke.mjs` (smart folder cases) |
| App | `test/features/folders/biz/smart_folder_builder_cubit_test.dart`, `test/features/folders/views/smart_folder_sheet_test.dart`, `test/features/folders/views/smart_rules_line_test.dart` |

## Discover folders

Users can find good public folders in Search. They do not need a creator profile or a link. Discovery has three lists: **Trending**, **New** and **Like your saves**.

### Where to find it

| Surface | What the user sees |
|---|---|
| Search, before a search | A **Folders to follow** row after **Creators to follow**. It shows up to 10 trending folders, or new folders when nothing trends. **See all** opens the discover page. The row does not show when both lists are empty. |
| Discover page (`/folders`) | The title **Discover folders** and three tabs: **Trending**, **New** and **Like your saves**. |
| Folder card | A 2x2 cover of the newest walls, the name, "By <owner>", the wall count, **Follow** and a menu with **Report folder**. A tap opens the folder page. |
| Admin review | A **Folder report** card for each open folder report, with **Keep folder** and **Hide from discovery**. |
| Web | `https://prismwalls.com/folders` shows **Trending this week** and **New this week**. |

### Eligibility

The daily job lists a public folder only when all of these are true:

1. The folder is public. The header `publicFolders/{id}` exists.
2. The header has 8 or more public walls (`itemCount`).
3. The name passes `publicFolderName` and `hasBlockedWord` (`functions/src/textSafety.ts`) finds no blocked word.
4. The owner account is 7 or more days old and the Auth user is not disabled.
5. The folder has no open report (`contentReports`, `contentType == folder`, `status == open`). The job checks each candidate with its own query, so unrelated reports cannot push a report past a cap.
6. A moderator did not hide it from discovery (`discoveryHidden` is not `true`).

The app removes the viewer's own folders and the folders of creators that the viewer blocked. The server lists do not depend on the viewer.

### Ranking

`computeFolderDiscovery` (`functions/src/folderDiscovery.ts`) runs every day at 03:10 UTC. It writes `folderTrending/current`.

- **Score.** For each of the last 7 UTC days: `follows * 3 + saves * 2 + opens`, times `0.8` for each day of age. The job adds the days.
- **Trending.** The job reads the scored folders in score order, 100 at a time, and keeps the eligible ones. It stops when Trending has 30 folders, or after 1,000 folders. A folder that became ineligible after it scored, for example hidden or reported, does not block the folders below it.
- **New.** Folders with `discoveryEligibleAt` in the last 7 days, newest first. The job keeps the eligible ones.
- **Owner cap.** One owner has at most 2 folders in each list.
- **Size.** Each list has at most 30 folders.

Each list entry has `id`, `ownerId`, `ownerName`, `ownerUsername`, `ownerPhoto`, `name`, `itemCount`, `covers`, `followerCount`, `moods` and `categories`. The moods and categories are the 3 most common of the 12 newest public walls. The job writes the doc in a transaction that reads each listed header again and applies the eligibility rules again. A folder that was hidden, renamed to a blocked name, made smaller or made private while the job ran is not written.

### Signals

| Signal | When | Writer |
|---|---|---|
| Follow | A new follow edge in `setFolderFollow`. | Server. |
| Save | The viewer starts **Save all** on a folder. | The app calls `recordFolderSignal` with `signal: save`. |
| Open | The public folder page loads. A reload of the same page does not count. | The app calls `recordFolderSignal` with `signal: open`. |

`countFolderSignal` (`functions/src/folderSignals.ts`) decides if a signal counts:

- The owner never counts.
- One account counts once for each folder and signal in 7 days. The claim is `folderSignalRate/{uid}_{folderId}_{signal}`.
- An account that is younger than 7 days does not count. The age check runs before the claim, so the account counts once it is 7 days old.
- A folder that is not public does not count. The claim and the count run in one transaction that reads the header again.
- A folder that has fewer than 8 public walls, or that a moderator hid from discovery, does not count. It cannot be listed, so its score must not push eligible folders out of the scan.

A counted signal adds 1 to `folderStatsDaily/{yyyymmdd}_{folderId}`. A TTL policy deletes the stats docs after 14 days and the claims after 7 days.

### New

The projection writes `discoveryEligibleAt` the first time a public folder has 8 public walls. The time goes on the private folder `folders/{id}` and on the header. Because the time is on the private folder, a folder that is made private and public again does not become new again.

### Like your saves

The app ranks this tab on the device. It uses no new server data and sends nothing about the user.

1. The app reads the user's favourites and keeps the 30 newest Prism walls.
2. It reads the moods and the category of those walls from `walls` (`WallTraitsSource`, 30 ids for each query).
3. Each save gives weight to its moods and its category. A newer save counts more: each older save counts 0.95 times the one before. The category "General" counts 0.
4. A folder from the Trending and New lists scores the weight of each mood and category it shares.
5. The app shows folders with a score above 0, best first, at most 2 for each owner. Ties keep the server order.

### Moderation

- **Report folder** on a card opens the content report sheet with `contentType: folder`. This is the report kind that the folder page already uses. After the server accepts the report, the card leaves the viewer's lists.
- An open report removes the folder from discovery at the next job run. The folder stays public.
- 3 trusted reporters still hide the whole folder (`moderationHidden`). See Reports and moderation.
- **Hide from discovery** calls `setFolderDiscoveryHidden` (admins only). It sets `discoveryHidden` on the private folder and on the header in one transaction. Then it removes the folder from `folderTrending/current` and from `webPages/folders` at once. The folder stays public and opens by link.
- **Keep folder** marks the report as reviewed. The folder can show again at the next job run.
- When a folder leaves the projection (private, deleted, hidden, or the owner closed), `finishRemoval` removes it from both lists at once.

### Data

| Path | Writer | Readers | Contents |
|---|---|---|---|
| `folderTrending/current` | Server only | Anyone, guests too | `trending`, `new`, `updatedAt`. |
| `folderStatsDaily/{yyyymmdd}_{folderId}` | Server only | Nobody | `folderId`, `day`, `follows`, `saves`, `opens`, `expireAt`. |
| `folderSignalRate/{uid}_{folderId}_{signal}` | Server only | Nobody | `lastAt`, `expireAt`. |
| `folders/{id}` fields `discoveryHidden`, `discoveryEligibleAt` | Server only | Owner and editors | The discovery state. The rules key lists do not include them, so no client writes them. |
| `publicFolders/{id}` fields `discoveryHidden`, `discoveryEligibleAt` | Server only | Signed-in users | Copies for the job and the web catalogue. |
| `webPages/folders` | `buildWebCatalog` | The Worker | The web discover page. |

### Web

`buildWebCatalog` reads `folderTrending/current` (1 read for each build) and the public folder headers that it already reads. It writes `webPages/folders` with the listed folders that are public, not hidden from discovery, still have 8 walls and a clean name, and have a live wall. The Worker reads 1 doc for each `/folders` page. Before the first list, `/folders` shows the app landing. The page is edge cached like other catalogue pages, so a hide reaches each edge location in about 10 minutes.

### Cost at 50,000 public folders

The job never reads all folders. These are the most reads for one run.

| Step | Reads | Writes |
|---|---|---|
| `folderStatsDaily` for 7 days | At most 50,000 (cap, with a warning). With 5,000 active folders on 3 days each: about 15,000. | 0 |
| Headers of scored folders, 100 at a time until Trending is full | At most 1,000. Usually 100. | 0 |
| New folders query | At most 300 | 0 |
| Open report check, 1 query for each candidate | At most 1,300. Usually 400. | 0 |
| Owner accounts | 0 (Auth `getUsers`, at most 13 calls of 100: 3 for New, 10 for Trending) | 0 |
| Traits: 12 items and 12 walls for each listed folder | At most 1,440 | 0 |
| Owner profiles | At most 60 | 0 |
| Final transaction | At most 60 | 1 |
| **Total** | **At most 54,160. About 17,400 in the example.** | **1** |

Other costs:

| Event | Reads | Writes |
|---|---|---|
| Open or Save all of a public folder | 2 (header and claim). 4 when it counts (the transaction reads the claim and the header again) | 2 when it counts (claim and stats), 0 when it does not |
| New follow | 1 (claim). 3 when it counts | 2 when it counts |
| Discover page open in the app | 1 (`folderTrending/current`) + the user's followed folders (at least 1) | 0 |
| "Like your saves" tab | The user's favourites + 1 for each 30 saved walls | 0 |
| A folder leaves the projection | 4 (the fence and each list, in 2 transactions) | 0 to 2 |
| Each `buildWebCatalog` run | 1 | 0 or 1 |

### App

| File | Role |
|---|---|
| `lib/features/folders/domain/entities/discover_folder.dart` | `DiscoverFolder`, the lists, the block filter and `rankLikeYourSaves`. |
| `lib/features/folders/biz/folder_discover_cubit.dart` | Loads the lists and the follows, follow with undo, report hide, block changes. |
| `lib/features/folders/views/widgets/discover_folders.dart` | `DiscoverFolderCard` and the Search row. |
| `lib/features/folders/views/pages/folders_discover_page.dart` | The discover page and its tabs. |
| `lib/features/admin_review/views/widgets/report_cards.dart` | `FolderReportCard`. |

The cards use `FolderCover`, `PressScale` and `PrismButton`. Each card is one Semantics button with the name, the owner and the count. The Follow button has the label "Follow <name>" or "Unfollow <name>". The page shows cards in rows, not a grid with a fixed height, so a card grows with large text. The tab chips scroll sideways at large text. A tab change does not animate.

### Analytics

| Event | Fields |
|---|---|
| `folder_discover_opened` | `tab` (`trending`, `new` or `like_your_saves`), `source` (`search`, `link` or `tab`) |
| `folder_discover_followed` | `tab` |
| `folder_reported` | `source` (`discover` or `folder_page`) |

### Limits

- Trending starts empty. Signals count from the functions deploy (follows) and from the app release (opens and saves).
- Public folders that had 8 walls before the deploy get `discoveryEligibleAt` at their next header refresh. Until then, they are not new.
- One open report removes a folder from discovery until an admin reviews it. A false report hides a good folder for up to a day.
- The lists change once a day. A follow count on a card can be up to a day old.
- The server lists do not know who blocked the viewer. A folder whose owner blocked the viewer shows on the card, and the folder page shows "This folder is private or no longer exists".
- `hasBlockedWord` checks English words only.
- There is no daily cap on how many different folders one account can send signals for. Each folder counts an account once in 7 days, and `recordFolderSignal` runs with at most 10 instances. This was a product decision on 2026-11-09.

### Deploy order

1. Firestore rules and indexes: `firebase deploy --only firestore:rules,firestore:indexes --project prism-wallpapers`. The new rules only add a read rule for `folderTrending`. The indexes add the TTL policies on `folderStatsDaily.expireAt` and `folderSignalRate.expireAt`. No composite index is new.
2. `make functions-env`.
3. Cloud Functions. New: `computeFolderDiscovery`, `recordFolderSignal`, `setFolderDiscoveryHidden`. Changed: `setFolderFollow`, `setFolderPublic`, `setFolderHidden`, `onFolderWritten`, `onFolderItemWritten`, `onWallPublicGateChanged`, `onContentReportCreated`, `deleteAccount`, `projectUserProfile`, `blockUser` and `buildWebCatalog` (they use the changed projection).
4. Run `computeFolderDiscovery` once from Cloud Scheduler.
5. Cloudflare Worker: `infra/cloudflare/worker`, for `/folders` and its app link. This change does not deploy it.
6. The app release.

### How to test

1. Sign in as user A, with an account older than 7 days. Make a folder with 8 Prism walls public.
2. As users B and C, open the folder and follow it.
3. Run `computeFolderDiscovery`. Open Search. Make sure that **Folders to follow** shows A's folder.
4. Tap **See all**. Make sure that the three tabs show. Tap **Follow** on a card. Make sure that the button changes to **Following**.
5. Open the card menu. Tap **Report folder**. Send the report. Make sure that the card goes away.
6. Sign in as an admin. Open the review queue. Tap **Hide from discovery** on the folder report. Run the job again. Make sure that the folder is not in the lists, and that its link still opens.

| Area | Files |
|---|---|
| Job, score, eligibility, cap, hide, signals, cost | `functions/src/__tests__/folderDiscovery.test.ts` |
| Projection fields, follow signal, list removal | `functions/src/__tests__/publicFolders.test.ts` |
| Web page data | `functions/src/__tests__/webCatalog.test.ts`, `infra/cloudflare/worker/test/catalog.test.mjs` |
| Rules | `tool/firestore_rules_smoke.mjs` (discover cases) |
| App | `test/features/folders/domain/discover_folder_test.dart`, `test/features/folders/biz/folder_discover_cubit_test.dart`, `test/features/folders/views/folders_discover_page_test.dart` |

## Deploy order

Do these steps in this order. No backfill is necessary, because every folder starts private.

1. Firestore rules and indexes: `firebase deploy --only firestore:rules,firestore:indexes --project prism-wallpapers`. Wait until these indexes are built: `publicFolders` (`ownerId` ASC, `updatedAt` DESC), `folders` (`memberIds` CONTAINS, `updatedAt` DESC), the `followedFolders.folderId` collection-group field, and the `items.wallpaperDocumentId` collection-group field.
2. Cloud Functions. New: `setFolderPublic`, `setFolderFollow`, `setFolderHidden`, `sendFolderDigests`, `onWallPublicGateChanged`, `createFolderInvite`, `getFolderInvite`, `joinFolder`, `removeFolderMember`, `leaveFolder`, `sendFolderActivityPushes`. Changed: `onFolderWritten`, `onFolderItemWritten`, `projectUserProfile`, `deleteAccount`, `blockUser`, `submitContentReport`, `onContentReportCreated`, `sendFollowDigests`. The folder triggers, the wall trigger, `setFolderPublic` and `setFolderHidden` need the R2 secrets. Run `make functions-env` first: a new function gets its plain env vars (`R2_PREVIEW_BASE_URL` and the R2 buckets) only from `functions/.env`. Without them, no wall passes the preview check. The functions that render the share image run with 512 MiB.
3. Cloudflare Worker: `infra/cloudflare/worker`. It accepts the `invite` query on folder links.
4. The app release.

The new rules accept every write that shipped clients make. So the rules can go live before the functions.

### Folder sections

1. Firestore rules: `firebase deploy --only firestore:rules --project prism-wallpapers`. No new index.
2. Cloud Functions: changed `onFolderWritten`, `onFolderItemWritten` (projection), `buildWebCatalog`.
3. Cloudflare Worker: `infra/cloudflare/worker`, for the folder page groups. This change does not deploy it.
4. The app release.

The rules accept every write that shipped clients make, so the rules can go first.

## Limits

- Wallhaven and Pexels spending has no server-side price cap. If its price changes after planning, a spend above the plan's cap stops the save and attempts a refund. Pending recovery blocks another charge for the same wall until it settles. Preventing that initial debit needs a backend change.

- Folder names get the length and hidden-character check. Discovery also checks `hasBlockedWord`, which knows English words only. Reports and the moderation hide cover the rest.
- Prism has no suspension state. A disabled Firebase Auth user counts as suspended at the next sync, follow or digest. No event starts a sync when Auth disables a user. A moderator can hide the folders at once with `setFolderHidden`.
- Wallhaven and Pexels wallpapers do not show in public folders.
- A wall that becomes eligible again (for example, approved after a hold) shows in a public folder at the next sync of that folder.
- A short link keeps the name and image it had when it was made. When the folder goes private or is deleted, the link preview still shows them, and the app shows the private state. The Make public dialog tells the owner this.
- Premium walls do not show in public folders. The projection uses the free gallery gate, the same gate as the folder page and the push.
- Making a folder private removes its followers. Making it public again starts at 0 followers.
- A Prism wall that is charged but not saved keeps its grant for 5 minutes. After 5 minutes, a new save charges again.
- Save all does not save the Drop walls that the user unlocked. Save those walls from their own page.
- On iOS, the Save all album needs full Photos access. Limited or add-only access saves to Photos with no album.
- Two editors who block each other both stay in the folder.
- The shared folder push is in English for now.

## How to test

1. Sign in as user A. Open a folder with at least 2 Prism wallpapers. Open the overflow menu. Tap **Make public**. Make sure the dialog says "Anyone on Prism can see its name and wallpapers, follow it and open its link. Links you share keep their preview even if you make it private later."
2. Tap **Make public**. Make sure the toast "This folder is now public." shows and the header shows **Public**.
3. Sign in as user B on a second device. Open A's profile. Make sure the **Folders** row shows the folder.
4. Open the folder. Make sure the header shows "By <A>", the count and "No followers". Tap **Follow**. Make sure the button changes to **Following** and the count changes to "1 follower".
5. Tap the share button. Make sure the share sheet opens with the folder link.
6. As A, add a wallpaper to the folder. Run `sendDueFolderDigests` for 13:00 in B's time zone, or wait until 13:00. Make sure B gets "New in <folder>".
7. As A, tap **Make private**. As B, open the folder link. Make sure "This folder is private or no longer exists" shows.
8. As B, block A. Make sure A's folder does not open for B and does not show on A's profile.

**Save all**

1. Sign in as a free user with 30 coins.
2. Open a folder with 3 or more Prism walls.
3. Tap the **Save all** button.
4. Make sure that the plan shows the kind lines and the two buttons.
5. Tap **Save all I can**.
6. Make sure that the progress row shows. Make sure that the balance drops by the price for each coin wall.
7. Make sure that the summary card shows the counts.
8. On iOS, open Photos. Make sure that the album has the folder name. On Android, open the gallery. Make sure that `Pictures/Prism/<folder>` has the walls.
9. Open Library > Downloads. Make sure that the walls are there.
10. Tap **Save all** again. Make sure that the plan says the walls are already in Downloads.
11. Start a save. Tap **Cancel**.
12. Make sure that the balance drops only for the walls that saved.

Shared folders:

1. Sign in as user A. Open a folder. Tap **Invite**. Copy the link.
2. Sign in as user B on a second device. Open the link. Tap **Join folder**.
3. As B, add a wallpaper to the folder.
4. As A, long press that wallpaper. Make sure the sheet shows "Added by B".
5. Within an hour, make sure A gets the push "B added a wall to <folder>".
6. As A, open **People**. Tap **Remove** on B.
7. As user C, open the same link. Make sure the page shows "This invite was already used".

Sections:

1. As the owner, open a folder that has Prism wallpapers in Unsorted.
2. Tap **Add section**. Name the section **Lock screens**. Tap **Add section** again. Name the section **Dark**.
3. Tap **Suggest sections**. Keep some of the groups. Make sure that the kept groups are sections.
4. Drag a wallpaper onto the **Dark** header.
5. Tap the **Lock screens** header. Make sure that the section collapses.
6. Sign in as an editor on a second device. Open the folder. Long press a wallpaper. Tap **Move to section**. Choose a section.
7. As the owner, open the folder again. Make sure that the move shows.
8. Tap **Make public**. Wait for the catalogue build. Open `https://prismwalls.com/folder/<id>`. Make sure that the sections show with their headings.

Tests:

| Area | Files |
|---|---|
| Projection, callables, cleanup | `functions/src/__tests__/publicFolders.test.ts` |
| Digest | `functions/src/__tests__/folderDigest.test.ts` |
| Rules | `tool/firestore_rules_smoke.mjs` (public folder cases) |
| Worker | `infra/cloudflare/worker/test/worker.test.mjs` (folder link cases) |
| App | `test/features/folders/` |
| Save all plan | `test/features/folders/domain/folder_save_plan_test.dart` |
| Save all bloc | `test/features/folders/biz/folder_save_bloc_test.dart` |
| Save all views | `test/features/folders/views/folder_save_views_test.dart` |
| Shared folders, server | `functions/src/__tests__/sharedFolders.test.ts` |
| Shared folders, rules | `tool/firestore_rules_smoke.mjs` (shared folder cases) |
| Shared folders, app | `test/features/folders/` (shared folder widgets) |
| Sections, rules | `tool/firestore_rules_smoke.mjs` (folder sections cases) |
| Sections, server | `functions/src/__tests__/publicFolders.test.ts`, `functions/src/__tests__/webCatalog.test.ts`, `functions/src/__tests__/wallMoodRulesParity.test.ts` |
| Sections, worker | `infra/cloudflare/worker/test/catalog.test.mjs` |
| Sections, app | `test/features/folders/domain/folder_section_test.dart`, `test/features/folders/domain/folder_edit_test.dart`, `test/features/folders/domain/section_suggester_test.dart`, `test/features/moods/domain/wall_mood_rules_test.dart`, `test/features/folders/biz/folders_organize_test.dart`, `test/features/folders/views/folder_sections_view_test.dart`, `test/features/folders/views/section_suggestions_sheet_test.dart` |
