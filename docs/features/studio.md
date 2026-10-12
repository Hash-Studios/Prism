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
| `infra/cloudflare/worker/src/ai.ts` | `/api/ai/studio/*` routes: fal generation, R2 storage, Studio budget. |

### Flow

1. `planStudioBatch` reads `studioConfig/current`. If `generationEnabled` is not `true`, or `identity.email` is empty, it stops.
2. It writes `studioRuns/d<yyyymmdd>` and one doc for each candidate in `studioRuns/{runId}/candidates/`. A second run with the same id does nothing.
3. `processStudioCandidate` runs once for each candidate doc. It calls `POST /api/ai/studio/generations` on the worker. The worker calls fal and stores the image in R2 at `ai/studio/raw/<id>.<ext>`.
4. The function runs the checks. A rejected image is deleted from R2.
5. A passed image becomes a JPEG (quality 90) and a thumbnail the same size the app makes for uploads. The worker stores both at `ai/studio/<id>.jpg` and `ai/studio/thumb_<id>.jpg`.
6. In one transaction the function creates `walls/{id}` with `review: false`, `studioSignatures/{candidateId}`, and sets the candidate to `pending_review`.
7. An admin approves or rejects in the swipe review screen.

### Checks

| Check | Rejects when |
|---|---|
| Size | Not portrait, short edge under 1400, long edge under 3000, or height/width outside 2.0 to 2.4 |
| Safety | Vision SafeSearch adult, racy, violence or medical is `POSSIBLE` or higher |
| Text | Vision finds a word with 3 or more letters or digits |
| Logo | Vision finds a logo with score 0.5 or higher |
| Duplicate | Correlation 0.93 or higher with any Studio wall. The signature is a 16x36 grey thumbnail. |

All values go into the candidate doc (`gates.details`), so the limits can be tuned.

A 64-bit dHash was tried first. It called different After Dark walls the same, because their black areas give the same bits. Correlation looks only at how each image varies, and the small thumbnail averages away the dark grain. On test images, near copies (JPEG, tint, 2% crop) scored 0.97 or higher. Different scenes scored 0.84 or lower.

### Pushes

- `onWallSubmitted` and `onWallApproved` send nothing for a Studio wall. There is no admin push, no "Your wallpaper is live" push and no follower push.
- A wall counts as a Studio wall only when `origin` is `studio` and its candidate doc points back at the same wall id. A user cannot fake this, because clients cannot write `studioRuns`.
- A rejection writes the usual "Wallpaper Rejected" notice to the Studio account. Nobody uses that account on a device, so no push arrives.

### Model

The default is GPT Image 2.5 Sunburst on fal at `high` quality, about $0.07 for one 1440x3200 image. It was first on the LMArena and Artificial Analysis image boards in October 2026, and it makes the exact phone size with no crop or upscale. It has no seed input.

The worker also allows Seedream 4.5 ($0.04) and Seedream 5 Lite ($0.035) as cheaper options. To change the model, set `studioConfig/current.model`. A model must be in `STUDIO_MODELS` in `infra/cloudflare/worker/src/ai.ts`.

No visual test of the models was run yet. Compare the first week of candidates before you commit to one model.

### Spend

- The worker calls fal with `STUDIO_FAL_API_KEY` if it is set, so Studio can use its own fal account. Without it, Studio uses `FAL_API_KEY`, the key of the AI tab.
- The worker has a separate Studio budget: `STUDIO_DAILY_BUDGET_USD` (2) and `STUDIO_MONTHLY_BUDGET_USD` (60) in `wrangler.toml`. Over the budget it returns 429 `budget_exhausted` and does not call fal.
- `studioConfig/current.maxCandidatesPerDay` (30 at most) limits all runs of one UTC day.
- A candidate is tried at most 3 times.

### Data

| Collection | Holds |
|---|---|
| `studioConfig/current` | `generationEnabled`, `dailyCandidates` (10), `maxCandidatesPerDay` (30), `model` (`openai/gpt-image-2.5/sunburst/text-to-image`), `width` (1440), `height` (3200), `seriesWeights`, `identity {by, email, userPhoto}` |
| `studioRuns/{runId}` | One run: source, day, count, model, size |
| `studioRuns/{runId}/candidates/{id}` | Prompt, status (`queued`, `generating`, `rejected`, `failed`, `pending_review`), attempts, worker answer, check results, wall id |
| `studioDaily/{yyyy-mm-dd}` | Candidates made that day |
| `studioSubjectUse/{subjectId}` | When a subject was last used |
| `studioSignatures/{candidateId}` | Image signature of each Studio wall (base64 16x36 grey thumbnail) |

New wall fields: `origin`, `seriesId`, `studioCandidateId`, `studioRunId`. The usual AI fields are also set: `isAiGenerated`, `aiProvider`, `aiModel`, `aiPrompt`.

Clients cannot read or write the Studio collections. The last rule in `firestore.rules` denies them.

## Setup

1. Create the Prism Studio account. Sign in to Prism once with it, and set the name, username and photo.
2. Make one random secret. Set it as `STUDIO_SECRET` in the worker (`wrangler secret put STUDIO_SECRET`) and in Firebase (`make functions-secrets-sync` after you add it to Doppler `prd`).
3. Deploy the worker.
4. Write `studioConfig/current` with `generationEnabled: false` and `identity`.
5. Deploy the functions: `processStudioCandidate`, `planStudioBatch`, `runStudioBatch`, `onWallApproved`, `onWallSubmitted`.
6. Set `generationEnabled: true`. Test with `cd functions && npm run studio:run -- --count 1`.

## Limits

- Approval publishes at once, so the time of review is the time the walls go live.
- No reserve: if nobody reviews for a day, no Studio walls go live that day.
- The app shows no AI label yet. `PrismWallDocDto` reads `aiMetadata` only, not the top-level AI fields.
- The duplicate check compares Studio walls only, not community walls.
- Raw images of passed candidates stay in R2.

## How to test

- `cd functions && npm run build && node --test 'lib/__tests__/*.test.js'`. The Studio tests are `studio*.test.ts`.
- `sh ./tool/cloudflare-worker-check.sh` for the worker routes.
- After deploy: run `npm run studio:run -- --count 1`. Check that the candidate reaches `pending_review` and the wall shows in the swipe review screen. Approve it. Check that it shows at the top of Latest and that no push arrived.
