# Remix

A remix starts a new AI wallpaper from an approved AI wallpaper that has a prompt. The AI tab fills the prompt, style and tier. The user can change them. The app never generates by itself. The AI tab is in [ai-wallpaper.md](ai-wallpaper.md).

## Where to find it

| Surface | What the user sees |
|---|---|
| Wallpaper detail, Remix action | **Remix** on an approved wallpaper that has a prompt. Studio wallpapers and user AI wallpapers both qualify. |
| AI tab | The filled prompt and style. A chip **Remixing <title> by <creator>** with a thumbnail, above the prompt. |
| Wallpaper detail, Remixes | A row of approved remixes by other creators, under the original. |
| Wallpaper detail, remix | **Remix of <title> by <creator>**. A tap opens the original. |
| Inbox | "Your wallpaper was remixed" for the original creator. |

## When the action is hidden

The Remix action is hidden when AI is off by Remote Config `ai_enabled`, the wallpaper is not approved, the wallpaper is premium-gated for a free user, the wallpaper is streak exclusive, or the creator is blocked.

## How it works

### Remix action

1. A tap tracks `remix_tapped` with `source_wall_type` (`studio` or `user`) and pushes `AiTabRoute(remixSeed: ...)`.
2. The AI tab fills the prompt, clipped to 160 characters at a word boundary.
3. The AI tab fills the style. Studio and older wallpapers store no style, so the user's current style stays.
4. The tier comes from the original's `aiModel`: z-image turbo is fast, seedream is balanced, gpt-image is quality, unknown is balanced.
5. The app steps the tier down to the best tier the coin balance covers. If none is covered, the tier is fast.
6. Normal cost and coin rules apply. The user taps Generate to spend coins.

### Linked state

- The chip's x drops the link and tracks `remix_link_dropped` with `source_wall_type`. The prompt stays.
- A generation made while linked stores `remixOf` on the local and synced AI history record. It tracks `remix_generated`.
- Submit to community writes `remixOf` (the original's Firestore doc id) on the new wallpaper. It tracks `remix_submitted`.

### Server check on submit

`onWallSubmitted` (`functions/src/onWallSubmitted.ts`) removes `remixOf` unless all of these are true:

- The value matches `^[A-Za-z0-9_-]{1,64}$` and is not the new wallpaper's own id.
- The new wallpaper is AI.
- The original exists, is approved, is AI, has a prompt, and does not point back to the new wallpaper.

The server never trusts the client value.

### Remix count

`onWallRemixWritten` runs on each write of `walls/{wallId}`. It has retry on. It keeps one ledger doc, `wallRemixes/{remixId}`, for each counted remix. It changes the original's `remixCount` in the same transaction.

- Approve adds 1.
- A withdraw (`review` changes from true to false), a delete, or a changed `remixOf` takes the remix back.
- A retry does not count twice. The count never goes below 0.
- A remix of your own wallpaper (same email) is never counted and never notified.

### Inbox notice

- On the first approval of a counted remix, the original creator gets one inbox item, "Your wallpaper was remixed", with the remix thumbnail. It has no push.
- The inbox doc id is `remix_<remixId>`. Its kind is `wallRemixed`. Its route is `wall`.
- The item is skipped when `postAlerts` is false in `usersv2/{uid}/private/session`.
- `wallRemixNotices/{remixId}` makes sure the item is sent once. It also holds after a withdraw and a new approval.

### Detail panel

- An original with `remixCount` above 0 shows **Remixes**, the count, and a horizontal row of approved remixes by other creators, newest first, with the creator name.
- Gated remixes, blocked creators and the viewer's own remixes are hidden.
- A tap opens the remix. The user swipes through the row. It tracks `remixes_grid_opened` when the row shows.
- A remix is hidden when the original is gone, not approved, gated, or by a blocked creator.

## Data

| Path or field | Writer | Contents |
|---|---|---|
| `walls.remixOf` | Client at create only. The server removes it when invalid. | Optional string. Doc id of the original. |
| `walls.remixCount` | Server only. | Count of counted remixes. Never below 0. |
| `wallRemixes/{remixId}` | Server only. | One ledger doc for each counted remix. |
| `wallRemixNotices/{remixId}` | Server only. | Marks the inbox notice as sent. |

Firestore rules refuse client writes of `remixCount` and owner changes of `remixOf`.

Index: `walls` with `remixOf` ascending, `review` ascending, `createdAt` descending.

## Privacy and limits

- The app did not show `aiPrompt` before this feature. Now a remix shows the prompt of any AI wallpaper to every user, Studio prompts included. The submit sheet says so: "Anyone can see your prompt and remix this wallpaper."
- A Studio wallpaper and an older wallpaper have no style. A remix keeps the user's style.
- A remix never generates an image. The user spends normal coins.

## Deploy order

Do all three steps before the store build that writes `remixOf`.

1. Firestore rules.
2. Firestore indexes.
3. Cloud Functions (`onWallSubmitted`, `onWallRemixWritten`).

Use `docs/features/backend-deploy.md` for the commands. Do not deploy without the owner's yes.

## Analytics

| Event | Fields |
|---|---|
| `remix_tapped` | `source_wall_type` (`studio` or `user`) |
| `remix_generated` | `source_wall_type`, `quality` |
| `remix_submitted` | `generation_id` |
| `remix_link_dropped` | `source_wall_type` |
| `remixes_grid_opened` | `count` |

## Code

| Path | Role |
|---|---|
| `lib/features/wall_remix/domain/wall_remix.dart` | Remix data shape. |
| `lib/features/wall_remix/data/wall_remix_repository.dart` | Remix repository. |
| `lib/features/wall_remix/views/widgets/` | Remix action, chip and Remixes row. |
| `functions/src/wallRemix.ts` | `onWallRemixWritten`: ledger, count and inbox notice. |
| `functions/src/onWallSubmitted.ts` | Checks `remixOf` on submit. |

## How to test

1. As user A, approve an AI wallpaper that has a prompt. Open its detail screen. Make sure **Remix** shows.
2. Tap **Remix**. Make sure the AI tab fills the prompt and style, and the chip shows. Tap its x. Make sure the prompt stays.
3. As user B, remix the wallpaper and submit it. Make sure the submit sheet has the privacy line. In the console, check that the new wall has `remixOf`.
4. Approve the new wall. Make sure the original shows **Remixes** with count 1 for other viewers.
5. As user A, check the inbox. Make sure "Your wallpaper was remixed" shows once, with no push.
6. As user A, remix your own wallpaper. Make sure the count does not change and no inbox item comes.
