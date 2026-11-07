# Photo to wallpaper

The user picks a photo from the gallery. AI extends the photo to the shape of the screen (outpaint), or makes it larger (upscale). The user can also make a desktop version (16:10).

## Where to find it

- App: the AI tab, "From your photo". Code: `lib/features/ai_wallpaper/`.
- Server: the `createPhotoWallpaper` callable in `functions/src/photoWallpaper.ts`.

## Models and price

The models were selected on 2026-11-06 from the fal model pages. The prices are the list prices on those pages.

| Mode | Model | fal price | Why |
|---|---|---|---|
| Extend | `fal-ai/bria/expand` | $0.04 for each image | It accepts an exact canvas size and an exact position for the photo. The placement step in the app gives these values directly. Bria trains only on licensed data. |
| Upscale | `fal-ai/seedvr/upscale/image` | $0.001 for each output megapixel | High detail at a very low price. |

Models that were not selected:

| Model | Price | Why not |
|---|---|---|
| `fal-ai/ideogram/v3/reframe` | $0.03 to $0.09 | It accepts only preset sizes. It does not accept a position for the photo. |
| `fal-ai/image-apps-v2/outpaint` | $0.035 for each megapixel | It accepts only margins of 0 to 700 px. A landscape photo on a phone needs more. A phone canvas costs more than $0.04. |
| `fal-ai/recraft/upscale/crisp` | $0.004 for each image | Good, but SeedVR2 costs less at phone size. |
| `fal-ai/clarity-upscaler` | $0.03 for each megapixel | Too expensive for the gain. |

The content filter is Cloud Vision SafeSearch. It costs $0.0015 for each image after the first 1000 images each month. Each job checks 2 images: the input photo and the result.

## Cost per job

| Job | Provider cost | Coins | Coins for Pro |
|---|---|---|---|
| Extend, phone or desktop | $0.040 + $0.003 = $0.043 | 75 | 38 |
| Upscale, phone (about 3.3 MP) | $0.0033 + $0.003 = about $0.007 | 10 | 5 |
| Upscale, bounded worst case (under 8 MP output) | under $0.008 + $0.003 = $0.011 | 10 | 5 |

The largest phone target is 1600 x 3840 (6.144 MP). Upscale accepts at most 5% shape drift. Its factor rounds up to the next 0.1, capped at 4. Since an upscale factor is at least 1, rounding increases either edge by less than 10%. Thus provider output is bounded by `6.144 / 0.95 * 1.1²`, under 7.83 MP. Desktop output has a smaller bound. A very small photo that needs more than 4x AI growth is resized to the final target after the capped AI step.

Public references checked on 2026-11-06: [Bria price](https://fal.ai/models/fal-ai/bria/expand), [SeedVR price](https://fal.ai/models/fal-ai/seedvr/upscale/image), [Bria schema](https://fal.ai/models/fal-ai/bria/expand/api), [SeedVR schema](https://fal.ai/models/fal-ai/seedvr/upscale/image/api). These are list prices, not a check of the Prism account's billing.

The coin prices are the same as the AI tiers with the same provider cost: Extend costs the same as the balanced tier, Upscale costs the same as the fast tier. The prices are in the economy config (`spend.photoExtend`, `spend.photoUpscale`). Pro pays half, rounded up, while `proDiscountActions` lists `photoWallpaper`.

## Caps and worst case per day

| Cap | Value | Worst case at the cap |
|---|---|---|
| Jobs for each user each day | 10 | 10 x $0.043 = $0.43 for each user |
| Jobs for all users each day | 400 | 400 x $0.043 = $17.20 |

A refused job (bad input, cap reached, not enough coins) does not count. A job that fails after it starts counts, because the provider can charge for it.

## What the user sees

1. On the AI tab, the user taps "From your photo".
2. The user taps "Choose a photo" and picks a photo from the gallery.
3. Prism shows the plan:
   - "Extend to fit your screen" when the shape of the photo is more than 5% from the screen shape.
   - "Upscale" when the shape is correct but the short side is smaller than the short side of the screen.
   - "This photo already fits your screen" when no job is necessary. Then there is no job button.
4. The user can select "Desktop version". The target then is 2560 x 1600 (16:10), and Prism makes the plan again.
5. For Extend, the user can move the photo in the frame (drag) and make it smaller (pinch). The minimum is the larger of 60% of its largest fitting size and the size that covers 10% of the canvas. A narrower photo whose largest fit covers less than 10% is refused. "Reset position" puts it back in the centre. A screen reader gets 3 actions: move to start, centre and end.
6. The job button shows the cost, for example "Extend · 75 coins". When the balance is too low, it reads "Get coins · need N" and opens Rewards.
7. While the job runs, the page shows the photo in the frame and "Extending your photo". On iOS, the AI Live Activity shows the job.
8. The result page shows before and after with a slider. The actions are "Set as wallpaper", "Download" (Android only, because on iOS Set saves to Photos), "Save to folder" and "Use another photo".
9. When the job fails, the page tells the user why and if the coins came back.

The privacy note under the picker says: "Your photo goes to our AI provider, fal.ai, and to Google Cloud Vision for this job only. Prism keeps the finished wallpaper, not your photo, and asks fal.ai to delete the photo after the job."

## How it works

### Server: `createPhotoWallpaper`

The callable runs the full job. The app does not spend coins or ask for a refund itself.

1. It refuses a request that has no sign-in or an anonymous sign-in.
2. It checks the input: `requestId`, `mode` (`extend` or `upscale`), `target` (`phone` or `desktop`), the phone size (720 to 1600 px wide, 1.6 to 2.4 times as tall), and the placement for Extend. Both default and explicit placements must cover at least 10% of the canvas. A photo whose largest fitting placement is smaller is refused before charge.
3. It decodes the photo with `sharp`, turns it upright, and writes a new JPEG. The new JPEG has no EXIF, GPS or other metadata. The photo must be 256 to 4096 px on each side and at most 6 MB.
4. It makes the plan again from the photo size. When the plan is not the requested mode, it refuses the job (`plan_mismatch`).
5. In one transaction it:
   - Refuses new or replayed claims after the account-deletion barrier closes.
   - Replays the job when `photoJobs/pj_{uid}_{requestId}` exists. A finished job returns its stored result. A running job returns `aborted`. A running job older than 10 minutes is ended as `timeout` and refunded.
   - Checks the caps (10 for each user each day, 400 for all users each day).
   - Checks the balance.
   - Takes the coins, writes the debit `coinTransactions/ctx_photoWallpaper_{uid}_{requestId}`, writes the job with state `running` and a random result key marked for cleanup on failure, and adds 1 to both daily counts.
6. It checks the photo with Cloud Vision SafeSearch.
7. It calls fal with the photo inline as a data URI, `sync_mode: true` and the header `X-Fal-Store-IO: 0`. It records the provider request ID and a pending marker, then attempts to delete the fal request data (`DELETE /v1/models/requests/{id}/payloads`). HTTP, per-file or network cleanup failures produce a fixed warning without provider error text or photo bytes and leave the marker for retry. The fal key needs the payload-deletion permissions; retention controls and deletion are provider-side behavior, not a Prism guarantee. A crash before the provider ID can be recorded, or a missing response header, prevents explicit cleanup; the retention controls still apply.
8. It resizes the result to the exact target size and writes a JPEG with no metadata. A free member gets the "Made with Prism AI" badge. A Pro member gets no badge (the same rule as AI wallpapers).
9. It checks the result with SafeSearch.
10. It stores the result in the public R2 bucket at the random key recorded before the provider call (`photo-walls/{32 hex}.jpg`), the same way AI results are stored: a link that is hard to guess, shown only to its owner. The job gets state `succeeded` and the link, and its cleanup marker is cleared.

Every failure after step 5 calls `failPhotoJob`. It marks the job `failed` and returns the coins in the same transaction, with the credit `coinTransactions/ctx_photoWallpaperRefund_{uid}_{requestId}`. Only the claim that started the job can end it, so a refund happens one time only. Once the account-deletion barrier closes, failure handling does not write refunds or change the account's coins.

The scheduled function `sweepStalePhotoJobs` runs every 15 minutes. It pages through all running jobs and refunds jobs older than 10 minutes, for example when the instance stopped. It also deletes failed jobs' recorded result keys and retries pending fal payload deletions after jobs end. Failed deletions stay pending for later sweeps.

The callable has a 180-second request timeout; this does not prove its handler stopped. Before calling fal and before storage, the worker checks its live claim and the deletion barrier, then refuses to start either operation after its 180-second deadline. R2 writes have a 15-second timeout. Account deletion refuses to finish while a job is running and not yet stale; the caller retries after completion or the 10-minute stale cutoff. A late worker that loses to the sweeper removes its own result too. An ambiguous success commit is read back before deciding to delete, so the successful image is kept.

Refunds run before cleanup. Each cleanup queue processes at most 10 records per sweep and stops starting new attempts after its own 20-second budget. The document-ID cursor is saved after every attempt in `photoJobBudget/cleanup`, even when deletion fails, and resets at the queue's end. Slow failures at the front therefore cannot starve later records or the other queue. The scheduled function has a 180-second timeout to allow active attempts to finish.

Known job replies from `createPhotoWallpaper` and `getPhotoWallpaper`, including a running lookup, include the user's current coin balance (`balance`) when the profile read succeeds. This read happens after the charge or refund. A missing profile or failed balance read leaves the job outcome unchanged and omits the balance. The app applies a returned balance only while the account and sign-in session that started the call are still current.

### After an app restart

The app saves pending jobs on the device (`ai.photoWallPendingJob`: user id, request id, mode, target), with one slot for each account. A failed save stops the job before the paid callable. Picking a photo waits for the account's saved-job lookup.

An uncertain job keeps its request id and cannot be replaced by a different photo or target. Retry looks up that request without uploading the photo again. Clears match both the account and request id, so an old completion cannot remove another job. Storage failures keep recovery available.

When the page opens and finds a saved job of the signed-in user, it calls `getPhotoWallpaper(requestId)`. That callable never charges or runs a job. Signing out or switching accounts clears the page's photo and result actions. A late response from an earlier session cannot restore them, even after switching back to that account.

- A finished job returns its result. The page shows the wallpaper alone (the photo is not kept, so there is no before and after) with Set, Download and Save to folder.
- A failed job returns its refund state. The page shows the error and "Choose a photo".
- A running job returns `running`. The page says "Still working on your last photo." and Try again asks again.
- A job that stopped while it ran (older than 10 minutes) is ended and refunded, the same as a replay.
- An unknown id, or another user's id, returns `unknown`, and the page clears the saved job.

`unknown` is final. When the lookup finds no job, it writes a closed record for that request id in a transaction. The record holds the user id, request id, closed state and timestamp, but no photo or charge. A create for the same request id that reaches its claim later refuses with `request_closed` and charges nothing, so the app can safely clear the saved job. Once the account-deletion barrier closes, an unknown lookup writes no closed record; the barrier already prevents a later claim.

### Content filter

SafeSearch blocks an image when `adult` or `violence` is LIKELY or more, or `racy` is VERY_LIKELY. A missing or unknown result also blocks it. A blocked input gives `unsafe_input`. A blocked result gives `unsafe_output`. Both refund the coins. The two Vision checks are required regardless of any model-side filtering.

### App

- `lib/features/ai_wallpaper/domain/entities/photo_job.dart`: `PhotoJob` (source photo, mode, target, model, cost, state), the planner, the placement and the cost.
- `lib/features/ai_wallpaper/data/repositories/photo_wallpaper_repository.dart`: picks the photo, makes the upload copy, and calls the callable. When the connection drops, it tries one more time with the same `requestId`.
- `lib/features/ai_wallpaper/views/pages/photo_wallpaper_page.dart` and `views/widgets/photo_wallpaper_widgets.dart`: the page.

The upload copy is decoded to raw pixels on the phone and then written as a JPEG (the same method as Search by photo). It has no metadata. Extend normally limits the long side to 2560 px, but raises this limit, up to 4096 px, when needed to preserve the server's 256 px minimum short side. Upscale sends the photo at full size, because it is smaller than the screen.

The app reads exact source dimensions from decoder metadata; its smaller preview determines orientation only. While the page remains open, it retains the request ID for uncertain jobs and jobs whose refund is not confirmed. Retry uses the read-only lookup even when the remaining balance is below the price. Refund copy uses the authoritative cost returned by the server.

### Analytics

| Event | Fields |
|---|---|
| `photo_job_started` | `mode`, `target`, `cost` |
| `photo_job_done` | `mode`, `target`, `cost` |
| `photo_job_failed` | `mode`, `target`, `reason`, `refunded` |
| `photo_job_result_set` | `mode`, `target`, `platform` |

## Privacy

- The photo goes to fal.ai for the job and to Google Cloud Vision for the check. The server keeps the input photo only in memory. The app reads the gallery picker's temporary copy, then deletes that copy; it does not delete the user's original gallery photo.
- Prism asks fal.ai not to store the request (`X-Fal-Store-IO: 0`), requests the result inline (`sync_mode`), and attempts to delete the request data at fal.ai after the job. A provider outage or missing key permissions can prevent deletion.
- Account deletion (`deleteAccount`) closes the claim barrier and refuses to finish while a job is running and not stale. The caller retries after completion or the 10-minute stale cutoff. It deletes the stored results, the job records and the daily count before anonymizing the profile and deleting Auth. A failed R2 delete keeps the job record and stops account deletion for a retry. Account deletion stops starting fal payload deletes after 20 seconds; failures and unattempted request ids move to `photoFalCleanup/{requestId}` (no user id). The sweeper reads ordered pages of 10, stops starting deletes after 20 seconds, and advances its cursor so a failed first page cannot starve later records.
- Prism keeps the result, the job record (mode, target, model, cost, state, result key, provider request ID and cleanup markers) and the daily count. Both result transfer paths reject images larger than 30 MB.
- The privacy policy (`web/app/privacy/page.tsx`) lists fal.ai and this use.

## Limits

- The results do not show in the "Recent" strip of the AI tab. The result shows on the page after the job. "Save to folder" keeps it.
- A desktop version is one fixed size, 2560 x 1600.
- The models and prices are from the fal model pages. They were not checked against the Prism fal account before the change.

## Deploy order

Do not deploy without the owner.

1. Deploy functions: `createPhotoWallpaper`, `getPhotoWallpaper` and `sweepStalePhotoJobs`. `createPhotoWallpaper` and `sweepStalePhotoJobs` need the secrets `FAL_API_KEY`, `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY`, and the R2 environment values that `r2Storage.ts` reads.
2. Optional: set `spend.photoExtend`, `spend.photoUpscale` and `proDiscountActions` in `economyConfig/current`. Without them, the defaults apply.
3. Release the app.

No Firestore rule or index change is necessary. The app does not read `photoJobs`, `photoJobDaily` or `photoJobBudget`, and the default rule refuses client access.

## How to test

1. `cd functions && npm run build && node --test lib/__tests__/photoWallpaper.test.js`
2. `fvm flutter test test/features/ai_wallpaper/photo_job_test.dart test/features/ai_wallpaper/photo_wallpaper_page_test.dart`
