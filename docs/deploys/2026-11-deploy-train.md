# Deploy train, November 2026

Date: 2026-11-02. All times are UTC. Firebase project: `prism-wallpapers`.

This document records the backend steps that the merged PRs from #720 to #795 listed. It gives what ran, when, the versions, how each step was verified, and what was not run, with the reason.

Installed builds at the time: 3.17.0 at 100% on Google Play, and 3.18.0 and 3.18.1 on TestFlight.

## 1. State before the train

Releases 3.17.0, 3.18.0 and 3.18.1 deployed most of the backend on 2026-10-31 and 2026-11-01. On 2026-11-02 at 09:00, the live state was as follows. It was compared against master `b911c46f6`.

| Surface | Live state | Gap |
|---|---|---|
| Functions | 183 instances (119 names). The deployed source was the same, byte for byte, as `functions/src`. | None |
| Firestore rules | Ruleset `58b89ba5`, released 2026-11-01 14:52 | None |
| Indexes | 65 composite indexes, all READY. 38 field overrides. | None |
| Links Worker `prismwalls-links` | Version `02cc93fb`. The code was the same as the master build. | The `MIXPANEL_TOKEN` secret was missing (#783). |
| Website `prismwalls` | Version `0b3c8deb`, built from `b911c46f6` | None |
| Remote Config | v99. All keys that the PRs need were present. | None |
| One-off jobs | Spatial backfill (#721), `refreshCollections` (#729), challenge themes (#759), `buildCreatorDirectory` (#778) and `buildWebCatalog` (#780, #787) were done. | The desktop companion backfill and its flag (#783), and the Duo batch (#770), were not done. |

Two read-only reviews compared master against the client code of every tag from 3.12.0 to 3.18.1. Neither review found a Firestore write or a callable call from an installed build that the backend refuses.

PRs #786, #793, #794 and #795 were merged on 2026-11-02 during the train. Their steps were added as group A (section 3).

## 2. Group G: steps from #720 to #792

### G1. Smoke test (no change)

- 09:11: an unauthenticated POST to each of the 23 new callables, in both regions (44 instances). Each instance returned 401, 400 or 403. None returned 404 or 500.
- 09:11: `wallpaperPreview` (#728) returned 200 two times, about 2.2 s each. The preview was already in the cache from an earlier deploy, so the second call was not faster.
- 09:13: `make rules-test` on the local emulator: 638 pass, 0 fail.

### G2. Worker secret `MIXPANEL_TOKEN` (#783)

- 09:14: `gh variable get NEXT_PUBLIC_MIXPANEL_TOKEN --repo Hash-Studios/Prism | npx wrangler secret put MIXPANEL_TOKEN --name prismwalls-links`
- Result: Worker version `19197e79`. The code did not change.
- Verification: `wrangler secret list` shows `MIXPANEL_TOKEN`. Nine Worker routes returned 200.
- Not verified: no real web download was tracked in Mixpanel during the train.

### G3. Desktop companion backfill, sample of 5 walls (#783, paid)

- 09:16: dry run, `--limit=5`. Result: 5 walls, $0.3725.
- 09:18: `--limit=5 --apply` failed on the first wall. The local Application Default Credentials (ADC) sent Cloud Vision calls to the quota project `whatsappclone-6c198`, and Vision is not enabled in that project. The image for wall `0IAHBTMOSU` was generated, and its manifest stayed `queued`. Production functions do not use local ADC, so production was not affected.
- Local fix, with the owner's OK: `gcloud auth application-default set-quota-project prism-wallpapers`.
- 10:32: the second run gave 5 `ready`, 0 failed. The Worker replayed the stored image for `0IAHBTMOSU`, so that image was not paid for again.
- Verification: 5 `desktopCompanions` docs are `ready`, 5 walls have `desktopVariant`, and the 5 thumbnails return 200 (`image/jpeg`). The owner looked at the 5 companions and approved them.

Command, run from the main checkout because the Doppler token is scoped to it:

```sh
cd <main checkout> && GOOGLE_CLOUD_PROJECT=prism-wallpapers GCLOUD_PROJECT=prism-wallpapers \
  doppler run --project prism --config prd -- \
  sh -c 'cd <worktree>/functions && npm run studio:desktop-backfill -- --limit=5 --apply'
```

### G4. Desktop companion backfill, remaining 124 walls (#783, paid, in progress)

- 10:59: the first run was stopped by hand before it finished a wall. `planStudioBatch` plans 10 Studio candidates each day at 20:00 and uses the same $2 daily Studio budget. A backfill that uses up the budget before 20:00 makes those candidates fail with `budget_exhausted`. Wall `5BPVSQZJXR` stayed `generating`. The next run claims it again after 6 minutes, and the Worker does not charge for a stored generation again.
- New schedule: a T3 scheduled task runs the backfill each night at 23:30, after the 20:00 batch. Each run uses only the budget that is left for that UTC day. The expected time is about 8 nights.
- The task stops at the first error that is not `deferred`. When no walls are left, it runs `buildWebCatalog` and checks `/desktop-wallpapers`, then it disables itself.
- Run log: `~/.deploy-train-2026-11/g4_runs.md` on the owner's Mac.

### G5 and G6. Not run

- G5, `studioConfig/current.desktopCompanions = true` (#783): waits for G4. Each new approved Studio wall then costs about $0.0745 from the Studio budget. This needs a separate OK.
- G6, Duo batch (#770, about $1.68 plus extras): waits for G4, because both use the same daily Studio budget. This needs a separate OK.

## 3. Group A: steps from #786, #793, #794 and #795

The branch was fast-forwarded to master `be4dd20d0` before these steps.

| Step | Time | Command | Version | Verification |
|---|---|---|---|---|
| A1. Rules (#793 `layoutPrefs`, #786 `wrapped`) | 11:05 | `firebase deploy --only firestore:rules` | Ruleset `04a08a2c` | The live source is the same, byte for byte, as `firestore.rules`. The change is additive only. |
| A2. Index `entries.creatorUid` (#786) | 11:06, READY at 11:10 | `firebase deploy --only firestore:indexes` | n/a | The field override is READY at collection and collection-group scope. The 65 composite indexes are still READY. |
| A3. All functions (#786, #793, #794, #795) | 11:12 to 11:18 | `make functions-env`, then `firebase deploy --only functions` | Archive MD5 `qyQ4eE3ZTACbZsH/fPLBaQ==` | See the list below. |
| A4. Links Worker (#786 `/wrapped`, #793 `/layout`) | 11:21 | `npx wrangler deploy` in `infra/cloudflare/worker` | Version `42316e86` | The deployed script is the same, byte for byte, as the `wrangler deploy --dry-run` build of master. The secrets are kept. 12 paths return 200. The association file lists `/layout` and `/wrapped`. `make cloudflare-worker-check`: 208 pass. |
| A5. Open this week's challenge (#794) | 11:21 | The one-off `openChallengeSlot(2026-11-02)` command from #794 | n/a | `weeklyChallenges/2026-11-02` exists with theme "Quiet horizons" (`theme_01`) and closes on 2026-11-09. |

A3 verification:

- All functions were deployed because 17 modules import the changed `notificationCatalog.ts`.
- The Doppler token is scoped to the main checkout. To write `functions/.env` from a worktree, use `make functions-env DOPPLER_PROJECT="prism --scope <main checkout>"`. The values matched the live function environment for all 2,196 comparisons.
- 39 instances logged `failed to update` after a 429 quota error. The CLI retried each one, and each one then logged `Successful update operation`. The live state confirms this. All 183 instances are ACTIVE and were updated between 11:12 and 11:18. All 183 use one source archive, and that archive is the same, byte for byte, as `functions/src`, `package.json` and `package-lock.json`.
- No function logged an error from 11:13 to 11:20. Before the fix, `onReviewQueueChanged` logged 106 errors from 00:00 to 01:00 on this day. It must be monitored for a full day.

## 4. Not run, with the reason

| Item | PR | Reason |
|---|---|---|
| Wrapped job (`npm run job:wrapped`, then `-- --apply`) | #786 | It needs a separate OK, and it costs about $2.50 in Firestore reads. A run on about 30 November includes all of November. |
| Remote Config `wrapped_2026_enabled = true` | #786 | Set it on 1 December. |
| Wrapped launch push (`npm run job:wrapped -- --notify --apply`) | #786 | It runs after the flag. |
| Two-phone `redeemCode` IP check | #781 | The owner must do it, with two phones on different networks. |
| Website deploy | none | No web changes after `b911c46f6`. |
| AI receipts migration (`migrate:ai-receipts`) | #616, #617, #620 | It is older than #720, so it is out of scope. Its state was not checked. |

## 5. Local changes on the operator Mac

- The ADC quota project is now `prism-wallpapers`. Before, it was `whatsappclone-6c198`.
- `functions/.env` in the worktree contains production values. The file is ignored by git.
