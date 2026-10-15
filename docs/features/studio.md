# Prism Studio

Prism Studio makes new wallpapers every day. A daily job generates AI wallpapers in fixed art series and runs quality checks. Each image that passes goes into the normal review queue. An admin approves or rejects it. Nothing goes live without approval.

## Where to find it

- There is no new screen in phase 1. Studio walls show in the admin swipe review screen (`lib/features/admin_review/`) with the other pending walls.
- After approval, a Studio wall shows in Latest, For you, its category and search, like any wall. The creator is the Prism Studio account.

## Platforms and plans

Backend only. The walls work on Android and iOS, for free and Pro users, like other walls.

## How it works

| Path | Role |
|---|---|
| `functions/src/studio/series.ts` | Art direction: series, subjects, palettes, composition rules. |
| `functions/src/studio/plan.ts` | Builds the day's prompts. No subject twice in 21 days. |
| `functions/src/studio/planRun.ts` | `planStudioBatch` (daily, 20:00 UTC) and `runStudioBatch` (admin callable). |
| `functions/src/studio/process.ts` | `processStudioCandidate`: generate, check, store, create the pending wall. |
| `functions/src/studio/gates.ts` | Quality checks. |
| `functions/src/studio/config.ts` | Reads `studioConfig/current`. |
| `functions/src/studio/account.ts` | `npm run studio:account`: the Studio profile, its identity and the onboarding starter pack. |
| `infra/cloudflare/worker/src/ai.ts` | `/api/ai/studio/*` routes: fal generation, R2 storage, Studio budget. |

### Flow

1. `planStudioBatch` reads `studioConfig/current`. A missing doc, a flag other than `generationEnabled: true`, an empty `identity.email`, or invalid configured dimensions stops generation.
2. It writes `studioRuns/d<yyyymmdd>` and one doc for each candidate in `studioRuns/{runId}/candidates/`. A second run with the same id does nothing.
3. `processStudioCandidate` claims each candidate before work. It calls `POST /api/ai/studio/generations` with the candidate id. The worker calls fal and stores the image in R2 at `ai/studio/raw/<id>.<ext>`.
4. The function runs the checks. A rejected image is deleted from R2. The candidate records unfinished deletes in `cleanupKeys`, so an event retry can finish cleanup without another generation.
5. A passed image becomes a JPEG (quality 90) and a thumbnail the same size the app makes for uploads. The worker stores both at `ai/studio/<id>.jpg` and `ai/studio/thumb_<id>.jpg`.
6. The publish transaction checks the current attempt and all Studio signatures again. It updates `studioState/signatureIndex` to serialize concurrent publishers, creates `walls/{id}` with `review: false` and `studioSignatures/{candidateId}`, and sets the candidate to `pending_review`.
7. An admin approves or rejects in the swipe review screen.

Subjects on the 21-day cooldown never enter a plan. When no eligible subjects remain, the plan is shorter or empty. An invalid stored daily count closes that day's cap instead of resetting it.

The `runStudioBatch` callable accepts an `admin: true` custom claim. Email-list admin access also requires `email_verified: true`. Manual callable runs use unique ids even when requests arrive in the same millisecond.

### Checks

| Check | Rejects when |
|---|---|
| Size | Not portrait, short edge under 1400, long edge under 3000, or height/width outside 2.0 to 2.4 |
| Safety | Vision SafeSearch adult, racy, violence or medical is `POSSIBLE` or higher, or any required result is missing, invalid or `UNKNOWN` |
| Text | Vision finds a word with 3 or more letters or digits |
| Logo | Vision finds a logo with score 0.5 or higher |
| Duplicate | Correlation 0.93 or higher with any Studio wall, including an exact flat-image copy. A corrupt signature also rejects. The signature is a 16x36 grey thumbnail. |

All values go into the candidate doc (`gates.details`), so the limits can be tuned.

A 64-bit dHash was tried first. It called different After Dark walls the same, because their black areas give the same bits. Correlation looks only at how each image varies, and the small thumbnail averages away the dark grain. On test images, near copies (JPEG, tint, 2% crop) scored 0.97 or higher. Different scenes scored 0.84 or lower.

### Notifications and rewards

- `onWallSubmitted` and `onWallApproved` send nothing for a Studio wall. There is no admin push, no "Your wallpaper is live" push and no follower push.
- A wall counts as a Studio wall only when `origin` is `studio` and its candidate doc points back at the same wall id. A user cannot fake this, because clients cannot write `studioRuns`.
- If the candidate lookup fails, the hooks throw before owner sync or notifications. They do not treat an unreadable Studio record as a community wall.
- A verified Studio wall is not evidence for the `firstWallpaperUpload` coin award. A failed provenance lookup awards no coins. A community wall that merely claims `origin: studio` still follows the community path.
- A rejection writes the usual "Wallpaper Rejected" notice to the Studio account. Nobody uses that account on a device, so no push arrives.

### Model

The default is GPT Image 2.5 Sunburst on fal at `high` quality, about $0.07 for one 1440x3200 image. It was first on the LMArena and Artificial Analysis image boards in October 2026, and it makes the exact phone size with no crop or upscale. It has no seed input.

The worker also allows Seedream 4.5 and Seedream 5 Lite. Both reserve $0.04 per image in the worker. To change the model, set `studioConfig/current.model`. A model must be in `STUDIO_MODELS` in `infra/cloudflare/worker/src/ai.ts`. The worker rejects an unknown model before a provider call.

No visual test of the models was run yet. Compare the first week of candidates before you commit to one model.

### Spend

- The worker calls fal with `STUDIO_FAL_API_KEY` if it is set, so Studio can use its own fal account. Without it, Studio uses `FAL_API_KEY`, the key of the AI tab.
- The worker has a separate Studio budget: `STUDIO_DAILY_BUDGET_USD` (2) and `STUDIO_MONTHLY_BUDGET_USD` (60) in `wrangler.toml`. Over the budget it returns 429 `budget_exhausted` and does not call fal.
- Each worker generation id has a persistent claim. A completed request replays its stored response. Neither elapsed time nor a changed prompt permits another fal call for that id.
- After a fal request starts, failures and unknown billing outcomes keep the reservation charged. The worker stores the failure response instead of releasing the id for another paid attempt. A stuck claim returns 409 `in_progress` without another fal call.
- Failures before the fal request starts release the claim for a retry. Missing `STUDIO_SECRET`, R2 storage or a fal key disables the relevant route with 503 `service_disabled`.
- `studioConfig/current.maxCandidatesPerDay` (30 at most) limits all runs of one UTC day.
- A candidate has at most 3 processing attempts. Transient worker errors requeue the candidate, but they do not bypass the worker's generation claim.

### Data

| Collection | Holds |
|---|---|
| `studioConfig/current` | `generationEnabled`, `dailyCandidates` (10), `maxCandidatesPerDay` (30), `model` (`openai/gpt-image-2.5/sunburst/text-to-image`), `width` (1440), `height` (3200), `seriesWeights`, `identity {by, email, userPhoto}` |
| `studioRuns/{runId}` | One run: source, day, count, model, size |
| `studioRuns/{runId}/candidates/{id}` | Prompt, status (`queued`, `generating`, `rejected`, `failed`, `pending_review`), attempt ownership, worker answer, check results, wall id, `cleanupKeys`, `outputAssetKeys` |
| `studioDaily/{yyyy-mm-dd}` | Candidates made that day |
| `studioSubjectUse/{subjectId}` | When a subject was last used |
| `studioSignatures/{candidateId}` | Image signature of each Studio wall (base64 16x36 grey thumbnail) |
| `studioState/signatureIndex` | Revision used to serialize signature checks and publication |

The quota Durable Object stores Studio generation claims and response bodies separately from consumer charge records.

New wall fields: `origin`, `seriesId`, `studioCandidateId`, `studioRunId`. The usual AI fields are also set: `isAiGenerated`, `aiProvider`, `aiModel`, `aiPrompt`.

Clients cannot read or write the Studio collections. The last rule in `firestore.rules` denies them.

## Setup

1. Sign in for the scripts: `gcloud auth application-default login` as the Prism owner.
2. In `functions/`, run `GOOGLE_CLOUD_PROJECT=prism-wallpapers npm run studio:account`. It is a dry run and prints the plan. Then run it again with `-- --apply`. It creates the profile `usersv2/prism-studio` (`studio@prismwalls.com`) if no profile has that email. It creates `studioConfig/current` with the identity and `generationEnabled: false`. If that doc exists, it fills only the empty identity fields and keeps all other fields.
3. Make one random secret. Set it as `STUDIO_SECRET` in the worker (`wrangler secret put STUDIO_SECRET`) and in Firebase (`make functions-secrets-sync` after you add it to Doppler `prd`).
4. Deploy the worker.
5. Deploy the functions: `processStudioCandidate`, `planStudioBatch`, `runStudioBatch`, `onWallApproved`, `onWallSubmitted`.
6. Set `generationEnabled: true`. Test with `cd functions && npm run studio:run -- --count 1`.
7. When 5 Studio walls are live, run `npm run studio:account -- --apply` again. It adds `{"email": "studio@prismwalls.com", "rank": 0}` to the Remote Config list `onboarding_starter_pack_v1` and publishes it. It keeps the other entries. The 3 lowest ranks are ticked by default, so rank 0 makes new users follow Studio. To list Studio but not tick it, add `--rank` with a number higher than the third rank. With fewer than 5 live walls, the script skips this step, because the onboarding card shows 5 walls.

Never sign in to Prism with the Studio email. Sign-in finds a profile by Auth uid, so a sign-in makes a second profile with the same email.

## Limits

- Approval publishes at once, so the time of review is the time the walls go live.
- No reserve: if nobody reviews for a day, no Studio walls go live that day.
- The app shows no AI label yet. `PrismWallDocDto` reads `aiMetadata` only, not the top-level AI fields.
- The duplicate check compares Studio walls only, not community walls.
- Raw images are deleted after publication. Failed deletes remain in `cleanupKeys` for a retry. Rendered files from failed or duplicate candidates also enter cleanup.
- Admin rejection retains the final JPEG and thumbnail for `undoRejectWall`. No backend job deletes those retained files.
- An unknown provider outcome can leave an id blocked with 409 `in_progress`. There is no automatic provider-job recovery. Reusing another id can cause another charge.

## How to test

- `cd functions && npm run build && node --test 'lib/__tests__/*.test.js'`. The Studio tests are `studio*.test.ts`.
- `sh ./tool/cloudflare-worker-check.sh` for the worker routes.
- After deploy: run `npm run studio:run -- --count 1`. Check that the candidate reaches `pending_review` and the wall shows in the swipe review screen. Approve it. Check that it shows at the top of Latest and that no push arrived.

## Review findings and regression tests

These tests cover the repaired paths. Test names and assertions are in the files below. This inventory is not a record of passed local gates, hosted CI, deployment or live verification.

| Finding | Current behavior and regression tests |
|---|---|
| Billed failures could generate again. Results expired after seven days. | Persistent claims replay success or failure without another provider call. `infra/cloudflare/worker/test/worker.test.mjs` covers replay, stale claims and dispatched fal failures. |
| Worker image transfers read unbounded bodies. | Downloads and uploads stop after 15 MB. Worker tests cover an oversized fal image and cancellation of an oversized streamed upload. |
| An old attempt could overwrite a newer result. | Candidate updates check attempt ownership. `functions/src/__tests__/studioProcess.test.ts` covers a stale attempt after another attempt publishes. |
| Duplicate checks could miss a concurrent publisher. | The publish transaction rechecks signatures under `studioState/signatureIndex`. `studioProcess.test.ts` covers a signature added after the first gate check. |
| Terminal candidates could leave raw or rendered assets behind. | Persisted cleanup keys survive delete failures. `studioProcess.test.ts` covers a failed R2 deletion followed by a cleanup-only retry. |
| Unknown safety data and exact flat copies could pass. | `functions/src/__tests__/studioGates.test.ts` covers missing and unknown SafeSearch fields, exact flat duplicates and corrupt signatures. |
| The planner reused subjects on cooldown. Large weights, malformed counters and invalid dimensions could break limits. | `functions/src/__tests__/studioPlan.test.ts` covers strict cooldown, large finite weights, missing config and disabled generation for invalid dimensions. `studioPlanRun.test.ts` covers malformed daily counters and disabled generation. |
| Email-only admin access and timestamp run ids were unsafe. | `studioPlanRun.test.ts` covers verified-email access, input validation and same-millisecond ids. Its callable fixture no longer suppresses `no-explicit-any`. |
| Provenance lookup failures enabled hooks. Studio walls could qualify for upload rewards. | `studioProcess.test.ts` covers hook failures before side effects. `functions/src/__tests__/coinsCallables.test.ts` covers Studio exclusion, lookup failure and community-wall controls. |

Open items remain outside those repairs:

- `.env.example` does not list `STUDIO_SECRET` or `STUDIO_FAL_API_KEY`. `CONTRIBUTING.md` requires those reference-schema entries. That file is outside this change's allowed write paths. Doppler provisioning is not verified here.
- A worker crash or failed result write can leave a permanent in-flight claim. Automatic recovery needs a stored provider job or result and is not implemented.
- The subject catalog cannot sustain the default 10 candidates per day over the strict 21-day cooldown. Owner options are to expand the catalog to at least 210 eligible subjects, or explicitly change the cadence or cooldown. Neither decision is included here.
- Admin-rejected final images remain in R2 because the shipped undo action restores their URLs. Owner options are to retain them for undo, as now, or approve a retention window followed by asset deletion. Immediate deletion would break undo.
- The AI-label gap, Studio-only duplicate scope and model visual comparison remain as described above. Live generation, review, feed placement and notification behavior still need post-deploy checks.
