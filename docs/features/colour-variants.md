# Colour variants

A colour variant is the same wallpaper in another colour. One wall has 2 to 5 colours. Each colour is a full wall. It has its own review, files, stats and favourites.

The creator adds a variant from an approved wall. The set shows on the wall detail screen. The Studio plan for variants is at the end of this page.

## Where to find it

| Surface | What the user sees |
|---|---|
| Wallpaper detail, dots | A row of dots above the action bar. One dot for each colour in the set. |
| Wallpaper detail, Add | **Add a colour variant** on your own approved wall. Hidden when the set has 5 colours. |
| Upload | A chip **Colour variant of** the parent title, with the parent thumbnail. |
| Your uploads | A status line for each variant. See the table below. |

| Status | Text |
|---|---|
| Waiting for review | Colour variant. It joins the set after review. |
| Joined | In a set of colour variants. |
| Not joined | **Not added as a colour variant**, then the reason. |

Feed cells show no colour indicator. We chose the detail screen only. `.impeccable.md` says chrome must not compete with wallpapers on grids.

## How it works on the device

### Dots

- The dot colour is the first colour id in `walls.colors`, from the app palette.
- A wall with no known colour shows its thumbnail in the dot.
- Each dot target is 44 points. The visible dot is 24 points. A 2 point ring marks the selected dot.
- The label reads "Variant 2 of 3, Blue". Without a colour, it reads "Variant 2 of 3".

### Switching

- A tap on a dot shows that variant.
- A tap on the wall shows the next variant. The switch cross-fades.
- With reduced motion on, the cross-fade has zero length.
- A tap while the controls are hidden shows the controls. It does not switch the variant.
- A wall with no variants keeps the tap that hides the controls.
- A feed swipe still moves from wall to wall.
- Download and Set use the variant on screen.
- A downloaded file is used only while the wall that was opened is on screen.
- The app warms the pictures of the set before a switch.

## Data

| Path or field | Writer | Contents |
|---|---|---|
| `walls.variantOf` | Client at create only. The server removes it when a check fails. | Doc id of the wall this one is a colour of. |
| `walls.variantGroupId` | Server only. | Doc id of the first wall in the set. |
| `walls.variantIndex` | Server only. | Position in the set, from 0. |
| `walls.variantLink` | Server only. | `linked`, or the drop reason. |
| `wallVariantGroups/{groupId}` | Server only. | `walls` (ordered doc ids), `creatorUid`, `updatedAt`. |

The group id is the first wall's doc id.

Firestore rules refuse client writes of `variantGroupId`, `variantIndex` and `variantLink`. `wallVariantGroups` has no rule, so clients cannot read or write it.

No new index is needed. The client query uses only equality filters on `variantGroupId` and `review`.

## Server check on submit and on approval

`onWallSubmitted` checks `variantOf` when the wall is created. `onWallVariantWritten` checks it again on approval, in a transaction. A group can fill while a wall waits.

| Code | Meaning |
|---|---|
| `not_found` | The target wall does not exist, or it is the wall itself. |
| `not_approved` | The target wall is not approved. |
| `not_owner` | The two walls do not share an email. When both walls have a `creatorUid`, the uid must match too. |
| `aspect_ratio` | A `resolution` is missing or invalid, or the width to height ratios differ by more than 2 percent. |
| `group_full` | The set would have more than 5 colours. |

A failed check removes `variantOf` and writes the code to `variantLink`. The upload stays. It remains a normal wall in review.

A passed check writes `variantLink` as `linked`.

## Group repair

`onWallVariantWritten` runs on each write of `walls/{wallId}`. It has retry on. It runs when `review`, `variantOf`, `email`, `creatorUid` or `resolution` changes.

- **Approve** joins the wall to its target's group. A new group starts with the target. A wall that was in the group keeps its old place. Otherwise the wall goes after the target.
- **Withdraw**, **delete** and **reject** remove the wall. A reject moves the wall to `rejectedWalls`. The other walls renumber.
- A group with 1 wall is deleted. Its last wall loses `variantGroupId` and `variantIndex`.
- Two approvals at the same time wait for each other on the group doc. One transaction handles each.

## Analytics

| Event | Fields |
|---|---|
| `wallpaper_variant_switched` | `source` (`dot` or `tap`), `wall_id`, `variant_index`, `variant_count` |
| `wallpaper_variant_upload_started` | `wall_id`, `variant_count` |
| `wallpaper_variant_link_resolved` | `wall_id`, `result` (`linked`, `not_found`, `not_owner`, `not_approved`, `group_full`, `aspect_ratio`) |

- `source` is `dot` for a dot tap. It is `tap` for a tap on the wall and for the screen reader action "Show the next colour".
- `wallpaper_variant_upload_started` fires when the user taps Add. It fires before the picker opens.
- `wallpaper_variant_link_resolved` fires once for each upload, when its link result first shows.

## Deploy order

Nothing is deployed yet. Do the three steps in this order.

1. Functions: `onWallVariantWritten` (new) and `onWallSubmitted` (changed).
2. Firestore rules.
3. The app release.

The rules accept `variantOf` only after the server can check it. An old app never writes the new fields, so it needs no change.

Use `docs/features/backend-deploy.md` for the commands. Do not deploy without the owner's yes.

## Studio plan (plan only)

Nothing is generated here. A paid run needs the owner's OK.

### Code today

- `StudioPalette` (`functions/src/studio/series.ts:20`) holds `id`, `name`, `prompt` and `tags`. Four series have 6 palettes each (`series.ts:157`, `256`, `355`, `381`).
- `studioPrompt` (`functions/src/studio/plan.ts:84`) joins the subject, the palette and the series style.
- `StudioPlanItem` (`functions/src/studio/plan.ts:16`) is one candidate: `seriesId`, `subjectId`, `paletteId`, `prompt`, `title`, `seed`.
- `createStudioRun` (`functions/src/studio/planRun.ts:37`) writes the run and its queued candidates.
- `processCandidate` (`functions/src/studio/process.ts:431`) runs `generate` (`process.ts:123`), then the checks, then writes the wall through `publishWall` (`process.ts:308`). `wallRecord` (`process.ts:382`) builds the wall fields.

### Plan

| Step | Code | Input | Output |
|---|---|---|---|
| 1. Pick walls | New. `planPaletteVariants` is a proposed name, not in the repo. | Approved Studio walls with `studioCandidateId` | Each wall's candidate doc: `subjectId`, `seriesId`, `paletteId`, `title`, `category`, `tags` |
| 2. Build prompts | `studioPrompt` and `studioTitle` (`plan.ts:80`, `84`) | The series palettes, without the wall's own palette. Two picks per wall. | Two `StudioPlanItem` per wall, with the same subject |
| 3. Queue | Same pattern as `planRun.ts:84-93` | Plan items | One run. Two queued candidates per wall, with `variantOf` set to the original wall id. |
| 4. Generate | `generate` (`process.ts:123`) | Candidate id, prompt, model, 1440x3200 | One image in R2 |
| 5. Check | `runGates` (`gates.ts`) | The image | Pass, or reject reasons. The depth series also runs the depth check. |
| 6. Publish | `processCandidate`, `publishWall`, `wallRecord` | The passing image | `walls/{id}` with `review: false` and `origin: studio` |
| 7. Approve | `onWallVariantWritten` | Admin approval | The wall joins the set |

- Skip the `studioSubjectUse` write (`planRun.ts:94-96`). The subject is not new.
- Variant candidates count toward `maxCandidatesPerDay`.

### Cost

- The image model is GPT Image 2.5 at `high`. It costs $0.07 per image (`infra/cloudflare/worker/src/ai.ts:2322-2323`, `docs/features/studio.md:86`). This is the default model (`functions/src/studio/config.ts:34`).
- Seedream 5 Lite costs $0.04 per image (`infra/cloudflare/worker/src/ai.ts:2351-2352`).
- Each variant makes 1 image (`ai.ts:2333` and `ai.ts:2361`, `num_images: 1`).
- Vision runs 3 features per image. They are safe search, text and logo (`functions/src/studio/gates.ts:191`). The code gives $1.50 per 1,000 units, so 3 units cost $0.0045 (`functions/src/studio/desktop.ts:34-35`).
- The depth series adds 2 Vision units (`docs/features/studio.md:60`) and one BiRefNet call. The BiRefNet price is unknown. It is not in the repo (`functions/src/wallDepth.ts:45`). Measure it on the fal invoice.
- Retries: unknown. Measure how many candidates fail after the fal call. A failure after the call keeps the charge (`docs/features/studio.md:101`).

| Item | Calculation | Cost |
|---|---|---|
| One GPT variant | $0.07 + $0.0045 | $0.0745 |
| One wall, 2 GPT variants | 2 x $0.0745 | $0.149 |
| One Seedream variant | $0.04 + $0.0045 | $0.0445 |
| One wall, 2 Seedream variants | 2 x $0.0445 | $0.089 |
| Depth variant, extra | 2 x $0.0015 (Vision) + BiRefNet | $0.003 + unknown |

Budget limits. The worker budget counts image cost only, not Vision.

- Daily: `STUDIO_DAILY_BUDGET_USD` is 2 (`infra/cloudflare/worker/wrangler.toml:720`). At $0.07, that is 28 images. 29 images cost $2.03, over the budget. Over the budget, the worker returns 429 `budget_exhausted` (`docs/features/studio.md:99`).
- The default daily plan uses 10 images, or $0.70 (`functions/src/studio/config.ts:32`). That leaves $1.30. That covers 9 walls with 2 GPT variants each ($1.26).
- Desktop companions draw from the same budget (`functions/src/studio/desktop.ts:31`).
- Monthly: `STUDIO_MONTHLY_BUDGET_USD` is 60 (`wrangler.toml:721`). At $0.07, that is 857 images.
- Count cap: `maxCandidatesPerDay` is 30 at most (`docs/features/studio.md:103`). At $0.07 each, 30 images cost $2.10. The daily budget stops first.

### Same-creator check

- Studio walls carry the Studio account email from `identity.email` (`functions/src/studio/process.ts:398`). They have no user email.
- `sameCreator` (`functions/src/wallVariants.ts:33`) compares emails. Two Studio walls already share one email, so the email test passes.
- `wallRecord` sets no `creatorUid` on Studio walls, so the uid test is skipped.
- Confirm this before you write a Studio rule. A user wall still gets `not_owner`, because its email differs.
- Pick one rule shape. Option A requires `origin: "studio"` on both walls, and the same `studioRunId`. A variant run must then reuse the original run id. Option B requires `origin: "studio"` on both walls only. Option B is the recommended choice. It needs no change to run ids.

## Code

| Path | Role |
|---|---|
| `lib/features/wallpaper_detail/views/widgets/variant_dots.dart` | Dots row. |
| `lib/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart` | Loads the set and selects a variant. |
| `lib/features/wallpaper_detail/data/repositories/wall_variant_repository_impl.dart` | Set query. |
| `lib/features/wallpaper_upload/views/widgets/wall_tile.dart` | Status lines in Your uploads. |
| `functions/src/wallVariants.ts` | Checks, group sync and `onWallVariantWritten`. |
| `functions/src/onWallSubmitted.ts` | Checks `variantOf` on submit. |

## How to test

1. As user A, approve a wall. Open it. Make sure **Add a colour variant** shows.
2. Upload a variant of that wall. Make sure the upload chip shows the parent thumbnail.
3. Approve the variant as an admin. Make sure both walls show a 2-dot row.
4. Tap a dot. Make sure the wall changes colour with a cross-fade. With reduced motion on, make sure there is no fade.
5. Upload a variant with a different shape. Make sure **Your uploads** shows the shape reason.
6. The app offers **Add a colour variant** only on your own wall. The functions tests and the rules smoke test cover a link to another creator's wall.
