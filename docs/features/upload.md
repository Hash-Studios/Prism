# Upload

A creator sends wallpapers from the gallery to Prism. A moderator reviews each wallpaper before publication. The creator can add a title, description, category, and tags. A batch can contain up to ten wallpapers.

## Where to find it

- The create button in the bottom bar opens the Create sheet (`UploadBottomPanel`, `lib/features/navigation/views/widgets/upload_bottom_panel.dart`). **Wallpapers** starts an upload.
- The steps are: pick images, **Edit wallpaper** (crop, `EditWallScreen`), **Upload wallpaper** (`UploadWallScreen`), then **Review status** (`ReviewScreen`).
- The AI wallpaper tab has its own submit step. See `docs/features/ai-wallpaper.md`.

## Platforms and plans

Android and iOS. The user must be signed in.

| Plan | Weekly limit | Images per pick |
|---|---|---|
| Free | 3 uploads a week (`UploadQuota.freeUploadsPerWeek`) | Up to the uploads left this week |
| Prism Pro | None | Up to 10 (`maxProBatchSize`) |

## How it works

| Path | Role |
|---|---|
| `lib/features/navigation/views/widgets/upload_bottom_panel.dart` | Opens the gallery picker. Uses `pickMultiImage(limit:)`. |
| `lib/features/wallpaper_upload/biz/upload_batch.dart` | `UploadBatch`: the queue, the position, the result of each image, and `uploadPickLimit`. |
| `lib/features/wallpaper_upload/biz/submission_metadata.dart` | `SubmissionMetadata`, the category list, and tag clean-up. |
| `lib/features/wallpaper_upload/biz/upload_quality.dart` | The size warnings. |
| `lib/features/wallpaper_upload/views/widgets/submission_metadata_form.dart` | The title, description, category and tags form. |
| `lib/features/wallpaper_upload/views/widgets/upload_batch_stepper.dart` | The "Wallpaper 2 of 3" step with one mark per image. |
| `lib/features/wallpaper_upload/views/pages/upload_wall_screen.dart` | Prepares the image, uploads two files, saves the wall record. |
| `lib/data/upload/wallpaper/wallfirestore.dart` | `createRecord` builds the wall record. |
| `lib/data/upload/wallpaper/wall_files.dart` | `deleteWallFiles` removes the repo files of a pending wall. |
| `lib/data/upload/upload_id.dart` | `randomUploadId` and `uploadIdLength`. |

### Wall id

A new wall gets a 10 character id: capital letters with one digit. Four characters gave about 700,000 values, so two walls could share an id. Ten characters give about 5e14 values. The app does not check for a repeat, because a creator cannot read the pending walls of other people. Old walls keep their 4 character ids.

### Details (optional)

- The ready step shows **Details (optional)**. The title limit is 60 characters. The description limit is 500 characters.
- The category list is **General** plus the 18 categories that the upload classifier writes. **General** is the default. A wall that stays in **General** is filed by the server classifier later. A wall with a chosen category is not changed.
- A tag is lower case. The app removes `#` and extra spaces. A tag has 24 characters at most. A wall has 8 tags at most. The user adds tags with a comma, the keyboard Done key, or the add button.
- Every field can stay empty. A blank title is not saved.
- The record gets `title`, `desc`, `category`, and `tags`. Search and "More like this" read `tags`.
- The event `upload_metadata_submitted` has `has_title`, `tag_count` and `category`. It fires once, after the wall saves.

### Size warnings

The ready step shows a note, and never blocks the upload, when:

- the short side is under 1080 px (low resolution), or
- the image is wider than tall (landscape).

### Send several wallpapers

1. The picker returns up to the limit in the table above. The app drops any image over the limit, because some devices ignore the limit.
2. One image starts the normal single upload.
3. Two or more images start a batch. The images go through **Edit wallpaper**, **Upload wallpaper** and submit, one after the other. Each image uses the same single upload code.
4. The screens show "Wallpaper 2 of 3" and one mark per image: submitted, skipped, not sent, current, waiting.
5. **Skip this wallpaper** drops the current image. The app deletes any file it already uploaded for it.
6. After the last image, the app shows a message such as "2 of 3 wallpapers submitted. 1 not sent." and opens **Review status**. If no image was sent, the app only closes.
7. Back ends the batch. The images that are left are dropped.

A free user who reaches the weekly limit in a batch sees the normal "Upload limit reached" step. The batch ends there.

### Withdraw a pending wallpaper

- In **Review status**, **Withdraw upload** removes a pending wallpaper after confirmation.
- The wall record now stores `wallpaper_path`, `wallpaper_sha`, `thumb_path` and `thumb_sha`. On delete, the app also calls `githubDeleteFile` for the two files. The server then gives the weekly upload slot back.
- If file cleanup fails, the wall record stays in review. The creator can retry.
- A wall saved before this change has no file details. The app deletes only the record, and the slot stays used.
- **Delete from history** removes only a rejected archive.

### Edit submitted details

**Edit details** on a pending upload opens the shared form. Save reads the current wall in a transaction and updates only title, description, category, and tags. A concurrent approval, rejection, or edit refuses the save. The editor keeps unsaved text and offers reload.

The owner of an approved Prism wallpaper can open **Edit details** from wallpaper details. This form omits category. `getWallMetadataForEdit` supplies a server revision. `editWallMetadata` checks that revision and changes only `title`, `desc`, `tags`, and derived `searchTerms`.

The server permits ten changed approved saves per owner per UTC day. No-op saves and identical operation retries do not use another save. A private audit records exact old and new text fields. Admins can inspect edit history and revert the latest applicable edit. Revert does not change the image, category, approval, credit, or rewards.

Wallpaper details show the saved text immediately. An older metadata refresh cannot replace a newer save on the same wall.

### Fix a rejected upload

**Fix and resubmit** keeps the previous rejection reason and metadata. If the full original remains retrievable through its URL, the app retrieves it. Otherwise, **Choose image** keeps the editing context. The app never uses the thumbnail as the original. AI source details are not copied or asserted from an archive.

Resubmission uploads fresh original and thumbnail bytes through the normal upload quota path. `submitWallResubmission` verifies those completed uploads and creates a new pending wall. `resubmitOf` points to the immediate rejected document. A private root record limits the original lineage to three lifetime linked admissions. Rejection, withdrawal, and history deletion do not return an attempt. An identical operation retry returns its original result, even after the new wall was deleted.

The local weekly counter uses durable receipts keyed by owner and operation. A successful retry does not charge the counter again after restart or an interrupted local write. A retry from an earlier week does not charge the current week. Local account cleanup removes the owner's receipts. These receipts do not replace server quota checks. After quota persistence, the app rechecks the account before it updates the signed-in user's upload fields. It also rechecks the account before it requests the first-upload reward.

The limit applies only to callable-admitted linked resubmissions. Existing general-create rules still permit an unrelated upload of the same artwork. The feature is not a universal duplicate-image limit.

The review queue shows a resubmission label and the captured old reason only after an admin callable verifies the private admission record. A raw `resubmitOf` value is not proof. Failed context lookup shows unavailable details.

`rejectWallForReview` reads the current wall and archives its exact server creation time in one transaction. It refuses a changed revision or review state. `undoWallRejection` refuses a changed archive or an admitted child. Undo preserves the previous approval state, but does not restore deleted image files.

Admin rejection and undo support legacy walls without a mapped owner, missing owner profiles, and anonymized walls retained after account deletion. Identifiable owners remain subject to the transactional account-deletion fence. A closed deletion fence blocks rejection and undo for those owners. Creator edits and resubmission admission still require an active verified owner.

### Reuse the last successful details

**Use last details** explicitly copies only category and tags from the last successful submission on this device. The values are scoped to the signed-in owner. Title, description, request, remix, image, and resubmission context stay unchanged. Defaults are not applied automatically over a draft. A defaults write failure does not turn a completed upload into a failed upload.

Drafts preserve description, lineage, operation identity, filenames, and completed file references. A resumed matching draft takes precedence over a rejected seed. Resubmission draft identity includes the rejected source so the same image does not collide with a normal draft or a different lineage.

### Deployment boundary

Deploy rules, indexes, and functions, in that order, before a store build that uses these callables. Each deploy and the store upload require separate explicit approval. No production deployment is part of this implementation.

Pending client text checks are feedback, not a new rules boundary. Existing pending-write rules remain broader than a four-field allowlist. Approved direct owner edits remain denied. Withdrawal keeps the existing files-before-document workflow. It does not make storage cleanup atomic with concurrent approval.

### AI original image

The wall record no longer holds `aiOriginalImageUrl` (the image without the watermark). Nothing in the app or the functions read the field.

### Analytics

| Event | Fields |
|---|---|
| `upload_stage` | `stage`: `ready`, `uploading`, `saving`, `submitted` |
| `upload_failed` | `reason`: `oversize`, `processing`, `upload`, `weekly_limit`, `submission`, `submission_unconfirmed`, `quota_exceeded` |
| `upload_metadata_submitted` | `has_title`, `tag_count`, `category` |
| `wall_pending_edited` | `asset_id`, changed `fields` |
| `wall_approved_metadata_edited` | `asset_id`, changed `fields` |
| `wall_resubmitted` | `asset_id`, lifetime `attempt` |
| `upload_last_details_used` | No fields |
| `upload_withdrawn` | `asset_id` |

## Limits

- New gallery uploads use the shared metadata form. The AI wallpaper submit step does not use it. It still sends the title, category, and tags that the server suggests.
- The batch lives in memory. If the app closes, the batch is lost. The images the user did not send are not saved as drafts.
- There is no id check for repeats (see above). A script that lists repeated ids is a follow-up for the backend owner.
- Walls that were saved with `aiOriginalImageUrl` before this change still hold the field. A one-off script must unset it. The script is not part of this change.

## How to test

1. Sign in with a free account. Tap Create, then Wallpapers. Pick 3 images. The picker allows the number of uploads left this week.
2. On the first **Upload wallpaper** step, type a title, pick a category, and add two tags. Tap **Submit for review**. Check the wall in Firestore: `title`, `category`, `tags`, `id` with 10 characters.
3. On the second image, tap **Skip this wallpaper**. Check that the step reads "Wallpaper 3 of 3".
4. Finish the third image. Check the message and **Review status**.
5. Pick a landscape image or one under 1080 px on the short side. Check the note. Check that you can still submit.
6. In **Review status**, delete a pending wall that you uploaded after this change. Check that the weekly count goes down and the two files leave the repo.
7. Run `fvm flutter test test/features/wallpaper_upload test/data/upload test/features/navigation/upload_bottom_panel_test.dart`.
8. Edit pending details. Before saving, approve or reject the wall from another session. Check that the save refuses the change.
9. Resubmit a rejected wall with and without its original image. Check that the reason and metadata remain visible.
10. Admit three linked attempts, including a rejected descendant. Check that a fourth admission fails and an identical retry succeeds.
11. Edit approved text. Check the detail title, description, tags, search results, audit history, daily limit, and latest-only admin revert.
12. Use last details after a successful upload. Check that only category and tags change, including after a draft restart.
