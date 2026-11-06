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
| Upscale, worst case (16 MP output) | $0.016 + $0.003 = $0.019 | 10 | 5 |

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
5. For Extend, the user can move the photo in the frame (drag) and make it smaller (pinch), to 60% of its largest size. "Reset position" puts it back in the centre. A screen reader gets 3 actions: move to start, centre and end.
6. The job button shows the cost, for example "Extend · 75 coins". When the balance is too low, it reads "Get coins · need N" and opens Rewards.
7. While the job runs, the page shows the photo in the frame and "Extending your photo". On iOS, the AI Live Activity shows the job.
8. The result page shows before and after with a slider. The actions are "Set as wallpaper", "Download" (Android only, because on iOS Set saves to Photos), "Save to folder" and "Use another photo".
9. When the job fails, the page tells the user why and if the coins came back.

The privacy note under the picker says: "Your photo goes to our AI provider, fal.ai, for this job only. Prism deletes it when the job ends."

## How it works

### Server: `createPhotoWallpaper`

The callable runs the full job. The app does not spend coins or ask for a refund itself.

1. It refuses a request that has no sign-in or an anonymous sign-in.
2. It checks the input: `requestId`, `mode` (`extend` or `upscale`), `target` (`phone` or `desktop`), the phone size (720 to 1600 px wide, 1.6 to 2.4 times as tall), and the placement for Extend.
3. It decodes the photo with `sharp`, turns it upright, and writes a new JPEG. The new JPEG has no EXIF, GPS or other metadata. The photo must be 256 to 4096 px on each side and at most 6 MB.
4. It makes the plan again from the photo size. When the plan is not the requested mode, it refuses the job (`plan_mismatch`).
5. In one transaction it:
   - Replays the job when `photoJobs/pj_{uid}_{requestId}` exists. A finished job returns its stored result. A running job returns `aborted`. A running job older than 10 minutes is ended as `timeout` and refunded.
   - Checks the caps (10 for each user each day, 400 for all users each day).
   - Checks the balance.
   - Takes the coins, writes the debit `coinTransactions/ctx_photoWallpaper_{uid}_{requestId}`, writes the job with state `running`, and adds 1 to both daily counts.
6. It checks the photo with Cloud Vision SafeSearch.
7. It calls fal with the photo inline as a data URI, `sync_mode: true` and the header `X-Fal-Store-IO: 0`. Then it deletes the fal request data (`DELETE /v1/models/requests/{id}/payloads`).
8. It resizes the result to the exact target size and writes a JPEG with no metadata. A free member gets the "Made with Prism AI" badge. A Pro member gets no badge (the same rule as AI wallpapers).
9. It checks the result with SafeSearch.
10. It stores the result in the public R2 bucket at a random key (`photo-walls/{32 hex}.jpg`), the same way AI results are stored: a link that is hard to guess, shown only to its owner. The job gets state `succeeded` and the link.

Every failure after step 5 calls `failPhotoJob`. It marks the job `failed` and returns the coins in the same transaction, with the credit `coinTransactions/ctx_photoWallpaperRefund_{uid}_{requestId}`. Only the claim that started the job can end it, so a refund happens one time only.

The scheduled function `sweepStalePhotoJobs` runs every 15 minutes. It refunds jobs that stay `running` for more than 10 minutes, for example when the instance stopped.

### Content filter

SafeSearch blocks an image when `adult` or `violence` is LIKELY or more, or `racy` is VERY_LIKELY. A missing result also blocks it. A blocked input gives `unsafe_input`. A blocked result gives `unsafe_output`. Both refund the coins. The upscale model also has its own safety checker on.

### App

- `lib/features/ai_wallpaper/domain/entities/photo_job.dart`: `PhotoJob` (source photo, mode, target, model, cost, state), the planner, the placement and the cost.
- `lib/features/ai_wallpaper/data/repositories/photo_wallpaper_repository.dart`: picks the photo, makes the upload copy, and calls the callable. When the connection drops, it tries one more time with the same `requestId`.
- `lib/features/ai_wallpaper/views/pages/photo_wallpaper_page.dart` and `views/widgets/photo_wallpaper_widgets.dart`: the page.

The upload copy is decoded to raw pixels on the phone and then written as a JPEG (the same method as Search by photo). It has no metadata. Extend sends a long side of at most 2560 px. Upscale sends the photo at full size, because it is smaller than the screen.

### Analytics

| Event | Fields |
|---|---|
| `photo_job_started` | `mode`, `target`, `cost` |
| `photo_job_done` | `mode`, `target`, `cost` |
| `photo_job_failed` | `mode`, `target`, `reason`, `refunded` |
| `photo_job_result_set` | `mode`, `target`, `platform` |

## Privacy

- The photo goes to fal.ai for the job and to Google Cloud Vision for the check. Prism keeps the photo only in memory during the job.
- Prism asks fal.ai not to store the request (`X-Fal-Store-IO: 0`), gets the result inline (`sync_mode`), and deletes the request data at fal.ai after the job.
- Prism keeps the result, the job record (mode, target, model, cost, state) and the daily count.
- The privacy policy (`web/app/privacy/page.tsx`) lists fal.ai and this use.

## Limits

- The results do not show in the "Recent" strip of the AI tab. The result shows on the page after the job. "Save to folder" keeps it.
- A desktop version is one fixed size, 2560 x 1600.
- The models and prices are from the fal model pages. They were not checked against the Prism fal account before the change.

## Deploy order

Do not deploy without the owner.

1. Deploy functions: `createPhotoWallpaper` and `sweepStalePhotoJobs`. They need the secrets `FAL_API_KEY`, `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY`, and the R2 environment values that `r2Storage.ts` reads.
2. Optional: set `spend.photoExtend`, `spend.photoUpscale` and `proDiscountActions` in `economyConfig/current`. Without them, the defaults apply.
3. Release the app.

No Firestore rule or index change is necessary. The app does not read `photoJobs`, `photoJobDaily` or `photoJobBudget`, and the default rule refuses client access.

## How to test

1. `cd functions && npm run build && node --test lib/__tests__/photoWallpaper.test.js`
2. `fvm flutter test test/features/ai_wallpaper/photo_job_test.dart test/features/ai_wallpaper/photo_wallpaper_page_test.dart`
