# Desktop companions

A desktop companion is a wide version of an approved wall. The server makes it for a Prism Studio wall, from the same prompt and the same model as the wall. A creator can upload one for their own approved wall. An admin reviews the upload first. See [Creator desktop versions](#creator-desktop-versions). The web catalogue and the app both offer it. The app calls it **Desktop version**.

The server code is in `functions/src/studio/desktop.ts`. The backfill script is in `functions/src/scripts/backfillDesktopCompanions.ts`. The web pages are in `infra/cloudflare/worker/src/catalog.ts`.

## What it is

A companion has two files.

| File | Size | Use |
|---|---|---|
| Original | 2560 x 1600 (16:10) | The full desktop image. Tablets set it or save it. |
| Wide | 2560 x 1440 (16:9) | A centered crop of the original. |

The web downloads are smaller versions of these two files. See [web-catalogue.md](web-catalogue.md).

The server makes a companion only for approved Prism Studio walls. Duo reveal walls are skipped. Creators upload their own companion. Both kinds have the same files and the same `desktopVariant` shape, so every reader works the same way.

## How it is made

The trigger is `onStudioWallDesktop`. It runs when a Studio wall is approved. It makes a companion only when `studioConfig/current.desktopCompanions` is `true`. The flag is off by default.

The server then does these steps.

1. The prompt changes. `DESKTOP_COMPOSITION` replaces the phone composition at the end of the prompt. The scene, the palette, the series style and the exclusions stay the same. A prompt without a known phone composition is skipped.
2. The server calls the wall model (`wall.aiModel`) through the Worker Studio route. The model must be one of these: GPT Image 2.5, Seedream 4.5 or Seedream 5 Lite. When the wall has a candidate seed, the server sends the same seed. GPT Image 2.5 has no seed. So its companion is a sibling of the wall, not a pixel match.
3. An output smaller than 2560 x 1600 is refused. The server never enlarges an image.
4. Cloud Vision checks safe search, text and logos. A flagged image is rejected.
5. The server stores the two files and the thumbnail, then links the companion to the wall.

Known limit. No human reviews a Studio companion. The automatic checks decide. A Studio companion appears on the wall when the checks pass.

## Storage and data

| Object or document | Access | Contents |
|---|---|---|
| `desktop-originals/<shareId>/<sha256>.jpg` | Private bucket | The original and the wide file. Each file has its own SHA-256. |
| `previews/desktop-<sha256>.jpg` | Public | The 960 x 600 thumbnail. |
| `desktopCompanions/{shareId}` | Server only | The manifest of the companion. |

The manifest holds `status`, `attempts`, `model`, `prompt`, `costUsd`, `original`, `wide`, `thumb` and `variant`. The `status` field has these values.

| Status | Meaning |
|---|---|
| `generating` | A run holds the claim and is making the companion. |
| `queued` | A transient error stopped the run. A later run retries it. |
| `deferred` | The Studio budget is used up. A later run retries it. |
| `ready` | The companion is linked to the wall. |
| `rejected` | A check failed. The companion is not retried. |
| `failed` | A permanent error stopped the run, or all attempts are used. The companion is not retried. |

The wall document holds `desktopVariant`, with `v`, `width`, `height`, `wideHeight` and `thumb`. The value of `v` is the first 16 characters of the original's SHA-256. A new original has a new `v`, so a cache never serves an old file. Only the server writes `desktopVariant`. The rules refuse client writes to it.

Deleting a wall deletes its companion. The server deletes the objects and the manifest.

## Spend and retries

- A companion gets at most 3 attempts (`STUDIO_MAX_ATTEMPTS`). After that, the status is `failed`.
- A Studio budget refusal sets the status to `deferred`. It does not use an attempt.
- The daily Studio cap is shared with the daily candidates. This change does not change the cap.

Cost per wall:

| Model | Model cost | Vision cost | Total |
|---|---|---|---|
| GPT Image 2.5 | $0.07 | $0.0045 | $0.0745 |
| Seedream 4.5 or Seedream 5 Lite | $0.04 | $0.0045 | $0.0445 |

## The backfill

Only a wall approved after the flag is `true` gets a companion from the trigger. Older walls need the backfill.

```sh
cd functions && npm run studio:desktop-backfill -- --limit=N
```

- A run without `--apply` is a dry run. It lists each wall and its cost. It calls no paid service. This is the default.
- `--apply` makes the companions and spends the Studio budget.
- `--limit=N` sets how many walls the run plans. The default is 25.
- `--start-after=<id>` resumes after a wall. The last line of a run prints `last=`, the id of the last wall that the run checked.

The run skips a wall that has a companion. It also skips a wall with a `rejected` or `failed` companion, and a wall that is not approved or not Studio. A second run does not pay twice. `--apply` needs `STUDIO_SECRET` and the R2 environment variables.

A dry run on 2026-11-01 read production. It scanned 167 Studio walls. 129 were eligible and 38 were not approved. The total cost is $9.61. With the $2 daily Studio budget, the backfill takes about 5 days. It competes with the daily candidates for the budget. The owner must agree before anyone runs `--apply`.

## Where users see it

On the web, the wall page has a Phone tab and a Desktop tab. The download links offer 1920 x 1200 and 1920 x 1080 files. The pages `/desktop-wallpapers` and `/matching-sets` list the walls that have a desktop version.

In the app, the wall detail shows a **Desktop version** chip when the wall has a companion. The chip opens a sheet with a preview. The sheet has **Send to my computer**, which shares the wall link. On tablets, the sheet gets the 2560 x 1600 original through `resolveOriginalAccess` with variant `desktop`. On Android, it sets the wallpaper. On iPad, it saves the file to Photos. The price is the same as the phone set.

**Open on computer** is a share target in the app. It shows only for a Prism wall that the web catalogue shows. It opens a sheet with a QR code and the link. The link opens desktop mode, which shows the desktop version first when there is one. See [web-catalogue.md](web-catalogue.md#desktop-mode).

## Limits

- The server makes companions only for Studio walls. Duo reveal walls are skipped.
- No human reviews a Studio companion. The automatic checks decide.
- A creator upload 1920 px wide is enlarged to 2560 px. It can look less sharp than a 2560 px upload.
- The GPT Image 2.5 companion is a sibling of the wall, not a pixel match.

## Creator desktop versions

A creator can add a desktop version to their own approved wall. An admin reviews it. After approval, it shows everywhere a Studio companion shows: the **Desktop version** chip, the web catalogue, watch sets and **Send to my computer**. These readers did not change.

The server code is in `functions/src/desktopSubmissions.ts`.

### The upload

1. On their own approved wall, the creator taps **Add a desktop version**. When the wall has a desktop version, the button is **Replace desktop version**. When an upload waits for review, the button is **Desktop version in review** and is disabled.
2. The creator picks an image. The app checks it before upload:
   - The image is landscape.
   - The aspect ratio is 16:10 or 16:9, within 2%.
   - The image is at least 1920 px wide.
3. The app shows the phone wall and the wide image side by side. The creator taps **Submit for review**.
4. The callable `submitDesktopVersion` receives the file. It does the same checks again. It never trusts the app.

`submitDesktopVersion` does these steps:

1. It reads the owner from the wall (`creatorUid`, or the verified email). The request does not name the owner. Another user's wall is refused (`desktop-not-owner`).
2. It refuses a wall that is not approved (`desktop-wall-not-approved`).
3. It counts the upload against the daily upload limit (`reserveUploadSlot`, 30 a day), the same as a wall upload.
4. It reads the upright size (EXIF orientation applies) and checks the size and the aspect ratio. A file over 15 MB is refused.
5. It makes the companion files with `sharp`: a 2560 x 1600 original and a 2560 x 1440 wide file, each a cover fit of the upload, and the 960 x 600 thumbnail. A 16:9 upload keeps its full width in the wide file.
6. In a transaction, it refuses a second submission while one is pending (`desktop-pending-exists`). It writes the submission with the state `uploading`.
7. It stores the three files with the same R2 layout as a Studio companion. Then it sets the state to `pending`.

Identical uploads have the same file names. So each creator step that stores or deletes files takes a short per-wall lease (`desktopStorageLeases/{shareId}`, server only). A second step on the same wall waits for the first, and the app shows "Unable to submit". If storage fails, the server deletes the stored files and the submission. A submission that stays `uploading` for more than 10 minutes is from a crashed run. The next submission for that wall deletes it and its files.

The server does not write `desktopVariant` before an admin approves.

### Review

The admin review screen has a **Desktop** tab. Each card shows the phone wall next to the wide image, the upload size, and a note when the upload replaces a desktop version. The admin taps **Approve**, or **Reject** with the existing reject reasons.

The callable `reviewDesktopSubmission` accepts only admins.

- **Approve.** In one transaction, the server checks that the wall is still approved and has the same owner. It replaces the `desktopCompanions/{shareId}` manifest (`source: "creator"`) and writes `desktopVariant` on the wall. For a creator version, `v` comes from the SHA-256 of both new files, because the wide file keeps edges that the original crops. So a cache never serves an old file. The files of the old companion are listed in `pendingObjects`. The server deletes them after the transaction, then clears the list.
- **Reject.** The server saves the reason and deletes the files of the upload. The old companion stays on the wall. A file that the live companion also uses (an identical upload) is kept.

A second approve or reject of the same submission does nothing. It does not send a second push.

### Pushes

The creator gets a push and an inbox entry from `notificationCatalog`:

| Kind | Title | Body |
|---|---|---|
| `desktopVersionApproved` | Your desktop version is live | "{title}" now has a desktop version. |
| `desktopVersionRejected` | Desktop version not approved | Reason: {reason} |

Installed builds do not have native resources for these kinds. So the system banner uses English, and the in-app inbox uses the app language.

### Data

| Document | Access | Contents |
|---|---|---|
| `desktopSubmissions/{id}` | The creator reads their own. Admins read all. Only the server writes. | `wallDocId`, `shareId`, `creatorUid`, `state`, `reason`, `reasonCode`, `original`, `wide`, `thumb`, `source` (upload size and aspect), `wallThumb`, `wallTitle`, `creatorName`, `replaces`, `createdAt` |

| State | Meaning |
|---|---|
| `uploading` | The server stores the files. The app and the admin queue do not show it. |
| `pending` | It waits for an admin. |
| `approved` | It is the live companion of the wall, or it was replaced later. |
| `rejected` | An admin rejected it. Its files are deleted. |
| `withdrawn` | The wall or the account was deleted while it waited. The server deletes it. |

The admin queue reads `state == "pending"`, newest first. This needs the composite index `desktopSubmissions (state, createdAt desc)`.

### Delete

- When a wall is deleted, `onStudioWallDesktop` deletes the companion files and the manifest, and `onDesktopSubmissionWallDeleted` deletes every submission of the wall and the files of the ones that were not approved.
- `deleteAccount` deletes every submission of the account. It deletes the files of a pending upload. An approved desktop version stays on the wall, because the wall stays with the name "Deleted Account".

### Analytics

| Event | Fields | Sent by |
|---|---|---|
| `desktop_upload_started` | `wall_id`, `replace` | The creator taps the button. |
| `desktop_upload_submitted` | `wall_id`, `aspect`, `replace` | The server accepted the upload. |
| `desktop_upload_approved` | `wall_id` | The admin approved it. |
| `desktop_upload_rejected` | `wall_id`, `reason` (a reject reason name, or `other`) | The admin rejected it. |

### Deploy order for creator desktop versions

Do not deploy without the owner's OK. Deploy in this order, before a store build that has the new screens:

1. Indexes: `firebase deploy --only firestore:indexes`. Wait until the `desktopSubmissions` index is built.
2. Rules: `firebase deploy --only firestore:rules`. This adds read access to `desktopSubmissions`. No client write changes.
3. Functions: `submitDesktopVersion`, `reviewDesktopSubmission`, `onDesktopSubmissionWallDeleted` and `deleteAccount`. Use `make functions-deploy`.
4. The store build.

## Deploy order

1. Deploy the Firestore rules: `firebase deploy --only firestore:rules`. This makes `desktopVariant` server-only.
2. Deploy the functions: `onStudioWallDesktop`, `wallpaperPreview`, `resolveOriginalAccess`, `onWallWebCatalog` and `buildWebCatalog`. Use `make functions-deploy`.
3. Run the backfill with `--apply`. Do this only with the owner's OK and the cost in this page.
4. Deploy the links Worker: `npx wrangler deploy` in `infra/cloudflare/worker`. The routes `/desktop-wallpapers*` and `/matching-sets*` are added. Set the `MIXPANEL_TOKEN` variable to the website's public Mixpanel token, so that downloads count. Then run `buildWebCatalog` with a force run. This deploy also turns on desktop mode and the `?d=1` link hint.
5. Deploy the website. The header links to the desktop pages.

After these steps, set `studioConfig/current.desktopCompanions` to `true`. New approvals get a companion from then on.
