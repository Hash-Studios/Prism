# Upload

A creator sends wallpapers from the gallery to Prism. A moderator reviews each one before it shows to other people. The creator can add a title, a category and tags, and can send up to ten wallpapers in one go.

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
| `lib/features/wallpaper_upload/views/widgets/submission_metadata_form.dart` | The title, category and tags form. |
| `lib/features/wallpaper_upload/views/widgets/upload_batch_stepper.dart` | The "Wallpaper 2 of 3" step with one mark per image. |
| `lib/features/wallpaper_upload/views/pages/upload_wall_screen.dart` | Prepares the image, uploads two files, saves the wall record. |
| `lib/data/upload/wallpaper/wallfirestore.dart` | `createRecord` builds the wall record. |
| `lib/data/upload/wallpaper/wall_files.dart` | `deleteWallFiles` removes the repo files of a pending wall. |
| `lib/data/upload/upload_id.dart` | `randomUploadId` and `uploadIdLength`. |

### Wall id

A new wall gets a 10 character id: capital letters with one digit. Four characters gave about 700,000 values, so two walls could share an id. Ten characters give about 5e14 values. The app does not check for a repeat, because a creator cannot read the pending walls of other people. Old walls keep their 4 character ids.

### Details (optional)

- The ready step shows **Details (optional)**: a title (60 characters at most), a category and tags.
- The category list is **General** plus the 18 categories that the upload classifier writes. **General** is the default. A wall that stays in **General** is filed by the server classifier later. A wall with a chosen category is not changed.
- A tag is lower case. The app removes `#` and extra spaces. A tag has 24 characters at most. A wall has 8 tags at most. The user adds tags with a comma, the keyboard Done key, or the add button.
- Every field can stay empty. A blank title is not saved.
- The record gets `title`, `category` and `tags`. Search and "More like this" read `tags`.
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

### Delete a pending wallpaper

- In **Review status**, a creator can delete a wall that is still in review.
- The wall record now stores `wallpaper_path`, `wallpaper_sha`, `thumb_path` and `thumb_sha`. On delete, the app also calls `githubDeleteFile` for the two files. The server then gives the weekly upload slot back.
- A failed file delete does not stop the record delete. The app logs it.
- A wall saved before this change has no file details. The app deletes only the record, and the slot stays used.
- Rejected walls are not changed by this.

### AI original image

The wall record no longer holds `aiOriginalImageUrl` (the image without the watermark). Nothing in the app or the functions read the field.

### Analytics

| Event | Fields |
|---|---|
| `upload_stage` | `stage`: `ready`, `uploading`, `saving`, `submitted` |
| `upload_failed` | `reason`: `oversize`, `processing`, `upload`, `weekly_limit`, `submission`, `submission_unconfirmed`, `quota_exceeded` |
| `upload_metadata_submitted` | `has_title`, `tag_count`, `category` |

## Limits

- The title, tags and category editor is on the gallery upload only. The AI wallpaper submit step does not use it. It still sends the title, category and tags that the server suggests.
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
