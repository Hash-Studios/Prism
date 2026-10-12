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
6. In one transaction the function creates `walls/{id}` with `review: false`, `studioHashes/{candidateId}`, and sets the candidate to `pending_review`.
7. An admin approves or rejects in the swipe review screen.

### Checks

| Check | Rejects when |
|---|---|
| Size | Not portrait, short edge under 1400, long edge under 3000, or height/width outside 2.0 to 2.4 |
| Safety | Vision SafeSearch adult, racy, violence or medical is `POSSIBLE` or higher |
| Text | Vision finds a word with 3 or more letters or digits |
| Logo | Vision finds a logo with score 0.5 or higher |
| Duplicate | dHash distance 6 or less to any Studio wall |

All values go into the candidate doc (`gates.details`), so the limits can be tuned.

### Pushes

- `onWallSubmitted` and `onWallApproved` send nothing for a Studio wall. There is no admin push, no "Your wallpaper is live" push and no follower push.
- A wall counts as a Studio wall only when `origin` is `studio` and its candidate doc points back at the same wall id. A user cannot fake this, because clients cannot write `studioRuns`.
- A rejection writes the usual "Wallpaper Rejected" notice to the Studio account. Nobody uses that account on a device, so no push arrives.

### Spend

- The worker has a separate Studio budget: `STUDIO_DAILY_BUDGET_USD` (2) and `STUDIO_MONTHLY_BUDGET_USD` (60) in `wrangler.toml`. Over the budget it returns 429 `budget_exhausted` and does not call fal.
- `studioConfig/current.maxCandidatesPerDay` (30 at most) limits all runs of one UTC day.
- A candidate is tried at most 3 times.

### Data

| Collection | Holds |
|---|---|
| `studioConfig/current` | `generationEnabled`, `dailyCandidates` (10), `maxCandidatesPerDay` (30), `model`, `width` (1440), `height` (3200), `seriesWeights`, `identity {by, email, userPhoto}` |
| `studioRuns/{runId}` | One run: source, day, count, model, size |
| `studioRuns/{runId}/candidates/{id}` | Prompt, status (`queued`, `generating`, `rejected`, `failed`, `pending_review`), attempts, worker answer, check results, wall id |
| `studioDaily/{yyyy-mm-dd}` | Candidates made that day |
| `studioSubjectUse/{subjectId}` | When a subject was last used |
| `studioHashes/{candidateId}` | dHash of each Studio wall |

New wall fields: `origin`, `seriesId`, `studioCandidateId`, `studioRunId`, `pHash`. The usual AI fields are also set: `isAiGenerated`, `aiProvider`, `aiModel`, `aiPrompt`.

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
