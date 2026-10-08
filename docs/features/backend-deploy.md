# Backend release notes

This page gives the exact order to ship the backend changes in this release. It covers Firestore indexes, Cloud Functions, the Cloudflare worker, the website, and the client.

Do not deploy from this page without the human owner's yes at each step. The `prism-release` skill (`.claude/skills/prism-release/SKILL.md`) has the same rule.

## Where to find it

| Item | Path |
|---|---|
| Index and TTL settings | `firestore.indexes.json` |
| Firebase settings | `firebase.json`, `.firebaserc` (project `prism-wallpapers`) |
| Functions | `functions/src/index.ts` |
| Worker | `infra/cloudflare/worker/` (`wrangler.toml`, name `prismwalls-links`) |
| Website | `web/` (`wrangler.toml`, name `prismwalls`) |
| Release steps | `.claude/skills/prism-release/SKILL.md` |
| Worker runbook | `infra/cloudflare/README.md` |

## Platforms

The backend serves Android and iOS. Two items are iOS only:

- The Apple association file (`/share` paths) in the worker.
- The App Store badge and link on the website.

## Free and Pro

No change. No step in this release touches coins, premium, or subscription rules. `firestore.rules` is not changed. Do not deploy `firestore:rules` in this release.

## How it works

### Before you start

1. Make sure that `firebase projects:list` shows `prism-wallpapers`. If it does not, run `firebase login:use <email>` or add `--account <email>` to each command.
2. Run the local gates from the repo root: `make ci`.
3. Run the functions tests: `cd functions && npm ci && npm run build && node --test lib/__tests__/`.
4. Run the worker tests: `make cloudflare-worker-check`.
5. Run the web build: `cd web && npm ci && npm run build`.
6. Make sure that no step needs a new secret. The diff adds no new `process.env` name, no new Doppler key, and no new Wrangler binding.

### Order

```text
1 indexes  ->  wait READY  ->  2 functions  ->  3 worker  ->  4 web  ->  5 client
```

### Step 1. Firestore indexes

What changes in `firestore.indexes.json`:

| Change | Detail |
|---|---|
| New composite index | Collection `walls`: `tags` (array contains), `review` (ascending), `createdAt` (descending). Tag search and "More like this" use it. |
| New TTL field override | Collection group `viewRate`, field `expireAt`, `ttl: true`. Rate docs now carry `expireAt` (24 hours after the view). |

Commands:

```sh
firebase firestore:indexes --project prism-wallpapers --account <email>
firebase deploy --only firestore:indexes --project prism-wallpapers --account <email> --non-interactive
gcloud firestore indexes composite list --project=prism-wallpapers
```

Rules for this step:

- Compare the live list with `firestore.indexes.json` first. The file must list every live index. A forced deploy deletes indexes that the file does not list. Never use `--force`.
- Wait until the new `walls` index shows state `READY`. The Firebase console (Firestore, Indexes) shows it as `Enabled` after `Building`. A large `walls` collection can take a long time.
- Do not start step 2 until the index is ready.

Console step, TTL: open Firebase console, Firestore, TTL. Make sure that a policy for `viewRate.expireAt` exists and shows `Serving`. If it does not, the CLI did not create it. Create it in the console. The `gcloud` form is `gcloud firestore fields ttls update expireAt --collection-group=viewRate --enable-ttl --project=prism-wallpapers`. I did not run it. The TTL policy only deletes docs that have `expireAt`. Old `viewRate` docs have no `expireAt`, so they stay.

### Step 2. Cloud Functions

Changed or new exports in `functions/src/index.ts` (from `git diff`):

| Function | Change |
|---|---|
| `sendWallOfTheDayBuckets` | New. Scheduled job. Runs every 15 minutes (`*/15 * * * *`, UTC, `retryCount: 1`). Sends the Wall of the Day push to the topic of each UTC offset where it is 09:00 local. |
| `wallOfTheDay` | Changed. Still runs at 03:30 UTC (`retryCount: 2`). Skips when today's pick exists. Skips streak-exclusive and premium-collection walls. Sends to the legacy topic `wall_of_the_day` for old clients. |
| `sendStreakReminders` | Changed. `timeoutSeconds: 540`. Chunks of 25. Sent marker first, rollback on failure. |
| `claimDailyStreak` | Changed. Time zone re-lock when the device offset differs and 24 hours passed since the last claim. |
| `sendWinBackPushes` | Changed. 2-day window per step. Sends to the uid topic and the FCM token. |
| `spendCoins` | Changed. Optional `requestId`. A repeated request returns the first result and does not charge twice. |
| `awardCoins` | Changed. `reason` is trimmed to 200 characters. |
| `categorizeWallpaper` | Changed. Rejects a bad `wallId` with `invalid-argument`. |
| `deleteAccount` | Changed. Also deletes `blockedUsers`, `referralStats`, `subscriptionSync`, `githubUploadStats`, `badgeCheckRate`, and `coinAdRateDaily` docs. A failed delete now fails the call. A retry is safe. |
| `recordWallpaperView`, `recordSetupView` | Changed. Use `FieldValue.increment`. Rate docs get `expireAt`. |
| `onWallApproved` | Changed. Stamps `approvedNotifiedAt` so one approval sends one set of pushes. |
| `onFollowCreated` | Changed. Fixed inbox doc id. Reads the user again before it pushes. |
| `onWallSubmitted`, `onContentReportCreated`, `onCampaignNotificationRequested`, `onNotificationCreated` | Changed. Personal pushes go to the uid topic and the FCM token. |

All other exports are not changed in the diff. Firebase can still redeploy them.

Commands:

```sh
firebase functions:list --project prism-wallpapers --account <email>
make functions-deploy FIREBASE_ACCOUNT=<email>
firebase functions:list --project prism-wallpapers --account <email>
firebase functions:log --lines 60 --project prism-wallpapers --account <email>
git checkout -- functions/lib
```

- `make functions-deploy` writes `functions/.env` from Doppler `prd`, builds, then runs `firebase deploy --only functions,firestore:indexes`. The index part is a no-op after step 1.
- To deploy only functions: `firebase deploy --only functions --project prism-wallpapers --account <email> --non-interactive`.
- Do not use `--force`. A forced deploy can delete a function.
- Make sure that `sendWallOfTheDayBuckets` appears in the list and its Cloud Scheduler job exists (Google Cloud console, Cloud Scheduler, region `asia-south1`).
- Wall of the Day reads `premiumCollections` from Remote Config. If the log shows "Could not read premiumCollections from Remote Config", the function uses the app defaults. Give the functions service account read access to Remote Config to fix this.
- No new secret is needed. `GH_TOKEN` and `REVENUECAT_SECRET_KEY` do not change.

### Step 3. Cloudflare worker

What changes in `infra/cloudflare/worker/src/`:

| Change | File |
|---|---|
| Apple association paths add `/share` and `/share*` | `association_files.ts` |
| Share links (`/share`, `/user`, `/setup`, `/refer`, `/l`) show a landing page. It has the wallpaper, title, creator, "Open in Prism", and store buttons by user agent. No instant redirect. | `index.ts` |
| Preview image host allowlist: `raw.githubusercontent.com`, `images.pexels.com`, `w.wallhaven.cc`, `th.wallhaven.cc`, `prismwalls.com`. Other hosts give no image. | `index.ts` |
| The AI daily cap is released when a generation does not succeed and was not billed. New Durable Object op `user_daily_cap_release`. | `ai.ts` |
| The original image is saved before watermarking. If watermarking fails, the call still succeeds. The app retries the watermark on the first read of the public image. | `ai.ts` |

The `AiQuotaCoordinator` class and its migration tag do not change, so no new Durable Object migration is needed. `wrangler.toml` is not changed.

Commands (from `infra/cloudflare/README.md`):

```sh
make cloudflare-worker-check
cd infra/cloudflare/worker && wrangler deploy
curl -i https://prismwalls.com/.well-known/apple-app-site-association
curl -i https://prismwalls.com/apple-app-site-association
curl -i https://prismwalls.com/.well-known/assetlinks.json
```

- Purge the cache for the three association URLs after the deploy.
- Make sure that each association URL gives HTTP 200, JSON, and no redirect. Make sure that the iOS file lists `/share`.
- Open a `https://prismwalls.com/share?...` link on a phone. Make sure that the landing page shows and does not redirect.

### Step 4. Web

What changes in `web/`:

| Change | Detail |
|---|---|
| Page deleted | `web/app/home-screen-setups/page.tsx`. The route and its SEO entry are removed. |
| File added | `web/public/_redirects`. It sends `/home-screen-setups` and `/home-screen-setups/` to `/` with status 301. |
| App Store badge | Hero and footer link to `APP_STORE_URL` (`https://apps.apple.com/app/id1405860595`). SEO data lists Android and iOS. |

Commands (from `web/README.md` and `web/package.json`):

```sh
cd web && npm ci && npm run deploy
curl -I https://prismwalls.com/home-screen-setups
```

- `npm run deploy` runs `next build` and `wrangler deploy`. The build writes `web/out`. Next copies `web/public/_redirects` into `web/out`.
- Make sure that the `curl` call gives a 301 to `/`.
- Worker routes on `prismwalls.com` (for example `/share*`) stay in front of the website. Do not change them.

### Step 5. Client release

Follow `.claude/skills/prism-release/SKILL.md`. In short:

1. Bump `pubspec.yaml`, run `make version-sync` and `make version-guard`.
2. Add the `### vX.Y.Z` section to `CHANGELOG.md`.
3. Ship the bump commit as its own PR. Merge it with a merge commit after the `ci` check passes.
4. Build: `make build-aab DOPPLER_CONFIG=prd` (Android) and `make build-ipa BUILD_NUMBER=<N> DOPPLER_CONFIG=prd` (iOS).
5. Upload to Play and TestFlight. The human picks the track and the rollout fraction.
6. Smoke-test a release build with the `verify-prism` skill.

The client sends `requestId` on every `spendCoins` call. It subscribes to the Wall of the Day bucket topic. It shows the UMP consent form. These need steps 1 and 2 first.

### Console steps

| Step | Where | What to do |
|---|---|---|
| AdMob UMP consent message | AdMob console, Privacy and messaging | Create and publish a GDPR message for the EEA and the UK for app `ca-app-pub-4649644680694757~6175744196`. Make sure that it is published before the client ships. Without it, the app finds no form to show. |
| TTL policy | Firebase console, Firestore, TTL | Make sure that `viewRate.expireAt` shows `Serving` (see step 1). |
| Cloud Scheduler | Google Cloud console, Cloud Scheduler, `asia-south1` | Make sure that the job for `sendWallOfTheDayBuckets` exists and is enabled after step 2. |
| Remote Config access | Google Cloud console, IAM | Only when the log shows the `premiumCollections` warning. Give the functions service account read access to Remote Config. |
| FCM | None | Topics are created when a device subscribes. No console step. |

The client code for consent is `lib/features/ads/data/ad_consent.dart`. It asks for consent before it loads a rewarded ad. If consent is not given, the app skips the ad load.

### What breaks if the order is wrong

| Wrong order | What breaks |
|---|---|
| Client before functions | New builds leave the topic `wall_of_the_day` and join a bucket topic. Nothing sends to the bucket yet, so those users get no Wall of the Day push. `spendCoins` ignores `requestId`, so a retry can charge twice. |
| Functions before the index is READY | Tag search and "More like this" fail with `failed-precondition`. The search code handles this and shows no tag results until the index is ready. |
| TTL policy not on | Rate docs get `expireAt` but nothing deletes them. They pile up until the policy is on. |
| Client before the worker | New iOS installs read an Apple association file without `/share`. Universal links for `/share` do not open the app until the worker is live. |
| Worker before web | No break. The two deploys do not depend on each other. |
| Web before the worker | No break. Users see the old share behavior until the worker deploys. |
| UMP message not published | Users in the EEA and the UK see no consent form. What the ads SDK then allows in those regions is not confirmed. |
| `firebase deploy --force` | Can delete a live index or a function that the file or `index.ts` does not list. |

## Fix wave (second round of this release)

The fix wave adds backend changes on top of the steps above. Ship them in this order. Each step needs the human owner's yes.

```text
A indexes  ->  wait READY  ->  B rules  ->  C functions  ->  D worker (flag off)  ->  E client  ->  F flag flip
```

### Step A. Firestore indexes

| Change | Detail |
|---|---|
| New TTL field override | Collection group `wallActionRate`, field `expireAt`. |
| New TTL field override | Collection group `wallpaper_stats_daily`, field `expireAt`. |

No new composite index. Check both TTL policies show `Serving` in the console after the deploy.

### Step B. Firestore rules

`firestore.rules` changes. Every change only loosens a rule or blocks a write that no shipped client makes:

| Change | Detail |
|---|---|
| `walls`, `setups` owner update | Needs the stored `review != true` as well. Owners cannot unpublish an approved wall. |
| `rejectedWalls`, `rejectedSetups` | Owner can delete (`isEmailOwner(resource.data.email)`). Fixes the "permission denied" on delete. |
| `admin_users` admin | Also needs `request.auth.token.email_verified == true`. Confirm the admin signs in with Google or Apple. |
| `usersv2` chains | `isOwner` is checked before `isConfiguredAdmin` (cost only). |
| New matches | `trending/{d}` and `popular/{d}`: public read, no client write. `usernames/{name}`: signed-in read, no client write. |

The rules smoke test (`tool/firestore_rules_smoke.mjs`) has 20 new cases. CI runs it on the emulator. Command: `firebase deploy --only firestore:rules --project prism-wallpapers --account <email> --non-interactive`.

### Step C. Cloud Functions

New exports:

| Function | What it does |
|---|---|
| `recordWallpaperAction` | Callable. Counts download, set and share per wallpaper. Dedupes per user, wall and action for 24 hours. |
| `onFavouriteWritten` | Trigger on `usersv2/{uid}/images/{wallId}`. Keeps `wallpaper_stats.favs`. |
| `computeTrending` | Scheduled every 3 hours. Writes `trending/current` and `popular/current`. |
| `sweepOpenReports` | Scheduled every 2 hours. Re-pings admins once for reports open longer than 12 hours. |
| `claimUsername` | Callable. Username registry in `usernames/{lower}`. Additive. |
| `onUserCreated` | Trigger on `usersv2/{uid}` create. Adds a suffix to a duplicate username. |
| `restoreStreak` | Callable. Restores a broken streak of 7 days or more for 100 coins, once per 30 days. |
| `reconcileSubscriptions` | Scheduled daily at 02:30 UTC. Revokes expired premium. Never grants. Uses `REVENUECAT_SECRET_KEY`. |

Changed exports: `spendCoins` (optional `label`, refunded replay refused, premium bypass only for downloads), `awardCoins` (optional `requestId`, `adsRemaining`, AI refund evidence check against the worker, 24 hour AI window when evidence allows), `syncSubscription` (grace period counts as active, 5 second floor for Free users), `deleteAccount` (scrubs walls, setups, rejected docs, notifications, follower arrays, reports, rate docs, legacy docs; 300 second timeout), `sendWinBackPushes` (skips `marketingPushes == false`), `claimDailyStreak` (writes `coinState.rescue`), `onContentReportCreated` (auto-hold at 3 distinct reporters), `onWallApproved` (also sends to `posts_<uid>`, collapse key), `onFollowCreated` (removes a blocked follow, keeps `nameLower`), `onWallSubmitted` (rewrites `by` and `userPhoto` from the owner doc), `blockUser` (removes both follow directions), `wallOfTheDay` (creator notice, slot from `scheduleTime`), `recordWallpaperView` (daily doc), `categorizeWallpaper` and `githubDeleteFile` (one admin check).

New Firestore fields: `coinState.rescue`, `coinState.rescueLastAt`, ledger `description`, `wallpaper_stats.{downloads, sets, shares, favs, lastEventAt}`, `usersv2.nameLower`, `walls.{heldForReview, heldAt}`, `contentReports.escalatedAt`, `usersv2/{uid}/images.favouritedAt` (client), `usersv2/{uid}/private/session.marketingPushes` (client).

New collections: `wallActionRate`, `wallpaper_stats_daily`, `trending`, `popular`, `usernames`.

Optional env: `AI_WORKER_BASE_URL` (defaults to `https://prismwalls.com`). No new secret.

Make sure the Cloud Scheduler jobs for `computeTrending`, `sweepOpenReports` and `reconcileSubscriptions` exist after the deploy.

### Step D. Cloudflare worker

| Change | Detail |
|---|---|
| `AI_REQUIRE_CHARGE` | New plain var in `wrangler.toml`, ships as `"false"`. With `"true"` every generation needs a `chargeTxId` that matches a completed `aiGeneration` debit. |
| `chargeTxId` | Optional body field on `/api/ai/generations` and `/variations`. Replay with the same id returns the stored image for 24 hours. Paid requests are never tier-downgraded. |
| `GET /api/ai/charges/{txId}` | Refund evidence for `awardCoins`. No auth. |
| Prompt blocklist | Word boundaries. |
| Share pages | OG tags escaped once. `apple-itunes-app` meta. Branded page for a dead short link. |
| `createLink` | 8 KB body cap, flat `campaign` only, Durable Object rate limit. |
| `/api/ai/health` | Budget numbers only with a valid Firebase token. |

The `AiQuotaCoordinator` class gets new ops but no new migration.

### Step E. Client release

The client in this wave calls `restoreStreak` and `recordWallpaperAction`, sends `requestId` to `awardCoins` and `label` and `chargeTxId` on AI spends, subscribes to `posts_<uid>`, writes `marketingPushes` and `favouritedAt`, and reads `trending`, `popular`, `wallpaper_stats` and `past_picks`. Steps A to D must be live first. Old clients keep working after every step.

### Step F. Flip the AI charge flag

Only after the client that sends `chargeTxId` is the minimum supported build. Set `AI_REQUIRE_CHARGE = "true"` in `wrangler.toml` and redeploy the worker. This is an owner decision.

### What breaks if the order is wrong

| Wrong order | What breaks |
|---|---|
| Client before functions | `restoreStreak` and `recordWallpaperAction` return `not-found`. The app hides the result. Rewarded ad `requestId` is ignored, so a retry can credit twice. |
| Client before rules | `trending/current` and `popular/current` reads fail. The Popular chip falls back to `wallpaper_stats`. |
| Flag flip before the client | Old builds get 402 `charge_required` on every AI generation. |
| Functions before the worker | AI refunds fall back to the 10 minute rule. Nothing breaks. |

## Rollback

| Part | How to roll back | Note |
|---|---|---|
| Indexes | Do not roll back. The new index is additive and costs little. | To remove it, delete it in the console. Do not deploy a file that lacks live indexes. |
| TTL | `gcloud firestore fields ttls update expireAt --collection-group=viewRate --disable-ttl --project=prism-wallpapers` | Not run here. Already deleted docs do not come back. |
| Functions | Check out the previous commit for `functions/` and run `make functions-deploy`. | To remove the new job: `firebase functions:delete sendWallOfTheDayBuckets --region asia-south1 --project prism-wallpapers`. Old clients keep the legacy topic. |
| Worker | `cd infra/cloudflare/worker && wrangler rollback`, then purge the three association URLs. | `infra/cloudflare/README.md` says the same. |
| Web | `cd web && wrangler rollback`. | The `_redirects` file goes with the old build. |
| Client | Halt the staged rollout in Play Console. | iOS has no rollback. Ship a fixed build. |

Each rollback command needs the human owner's yes.

## Limits

- I did not run any deploy command or `gcloud` command. I read the commands from the repo and the `prism-release` skill.
- The topic name in code is `wall_of_the_day_utc_<p|m><hh><mm>`, for example `wall_of_the_day_utc_p0530`. The letter `p` or `m` replaces the sign, because FCM topic names cannot hold `+`.
- The bucket job runs every 15 minutes, not every hour. An hourly job would miss the +05:30 and +05:45 offsets.
- Whether `firebase deploy --only firestore:indexes` creates the TTL policy depends on the Firebase CLI version. Check it in the console after the deploy.
- The CLI version, the index build time, and the `wrangler rollback` result need a live account to confirm.
- `docs/features/notifications.md` has the notification behavior and its limits.

## How to test

1. After step 1, run `gcloud firestore indexes composite list --project=prism-wallpapers`. Make sure that the `walls` tags index shows `READY`.
2. After step 2, run `firebase functions:list`. Make sure that `sendWallOfTheDayBuckets` shows in region `asia-south1`.
3. Wait for one 15 minute slot. Run `firebase functions:log --lines 60`. Make sure that there is no error from `sendWallOfTheDayBuckets`.
4. After step 3, open a share link on a phone. Make sure that the landing page shows.
5. After step 4, open `https://prismwalls.com/home-screen-setups`. Make sure that it redirects to `/`.
6. On a test device with the new build, set the device time zone to a known offset. Open the app. Make sure that the push for that offset arrives at 09:00 local.
7. Open the app in a UK or EEA test setup. Make sure that the consent form shows before the first rewarded ad.

Automated tests:

| Part | File or command |
|---|---|
| Indexes and TTL | `functions/src/__tests__/firestoreIndexes.test.ts` |
| Functions | `cd functions && npm ci && npm run build && node --test lib/__tests__/` |
| Worker | `make cloudflare-worker-check` (`infra/cloudflare/worker/test/worker.test.mjs`) |
| Consent | `fvm flutter test --no-pub test/features/ads/ad_consent_test.dart` |
| Web | `cd web && npm run build` |
