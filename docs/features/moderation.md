# Moderation and creator safety

This page covers the backend rules that protect creators and keep reports moving. It has no screen of its own. The admin review screen and the notification inbox show the results.

## Where to find it

| Item | Path |
|---|---|
| Report auto-hold, admin push | `functions/src/onContentReportCreated.ts` |
| Report sweeper `sweepOpenReports` | `functions/src/reportSweeper.ts` |
| Block and follow cleanup | `functions/src/userBlockCallables.ts`, `functions/src/onFollowCreated.ts` |
| Username dedupe | `functions/src/onUserCreated.ts`, `functions/src/claimUsername.ts` |
| Submit check | `functions/src/onWallSubmitted.ts` |
| Wall of the Day creator notice | `functions/src/wallOfTheDay.ts` |
| One admin check | `functions/src/adminConfig.ts` (`isAdminCaller`) |
| Rules | `firestore.rules` |

## Platforms and plans

Android and iOS share the same backend. Every plan gets the same protection.

## How it works

### Report auto-hold

When a report for a wall is created, `onContentReportCreated` counts the different reporters (`reporterUid`) of that wall. A reporter counts only when the account is older than 7 days. A reporter that the server cannot read does not count.

At 3 or more reporters, one transaction on `walls/{id}` runs. It acts only when `review` is `true`. It sets `review: false`, `heldForReview: true` and `heldAt`. The wall leaves the public feed and waits in the admin review list. An admin approves it again from the review screen. The approval push does not repeat, because `approvedNotifiedAt` is already set.

A report with reason `blocked` (filed by `blockUser`) sends no admin push.

### Report sweeper

`sweepOpenReports` runs every 2 hours. For each report with `status == "open"` that is older than 12 hours and has no `escalatedAt`, it pings the admins once and sets `escalatedAt`. This supports the 24 hour review promise in the terms.

### Blocks

`blockUser` removes the follow in both directions. The reverse pair goes too: if the blocked user follows the caller, that follow ends. When a blocked user follows again, `onFollowCreated` removes the follow from both users and sends no push.

### Usernames

- `onUserCreated` runs when a profile is created. If another profile has the same `usernameLower`, the new profile gets a suffix from its uid (`JohnSmith_ab12`). The trigger also stores `usernameLower` and `nameLower`.
- `onFollowCreated` keeps `usernameLower` and `nameLower` in sync on later updates. `nameLower` supports case-insensitive creator search.
- `claimUsername({username})` takes 3 to 30 letters, digits or underscores. It runs in a transaction on `usernames/{lowercase}` (`{uid, claimedAt}`). It refuses a name that another registry doc or profile holds. It frees the old registry doc and writes `username` and `usernameLower` on the profile. The collection `usernames` is readable by signed-in users. Only functions write it.

### Wall submit check

`onWallSubmitted` writes `by` and `userPhoto` on a new wall from the owner profile (`name` or `username`, and `profilePhoto`). The client value is not trusted. It logs a warning when `wallpaper_url` or `wallpaper_thumb` is not on `raw.githubusercontent.com`. It does not reject the wall. AI walls skip the host check.

### Wall of the Day creator notice

After the public push, the creator of the pick gets a personal push and an inbox doc. The inbox doc id is `wotd_creator_<utc date>`. The collapse key is the same text. A failure never fails the public push.

The bucket push now uses the scheduled time of the run, not the clock at the start. A late run no longer skips a bucket.

### Admin check

`isAdminCaller` answers one question for functions: the `admin` claim, or a verified email with a doc in `admin_users`, or an email in `config/adminNotifications`. `categorizeWallpaper` and `githubDeleteFile` use it. The admin check of the config list does not need a verified email, as before.

### Rules

| Change | Effect |
|---|---|
| Admin by `admin_users` needs `email_verified == true` | An unverified token with an admin email is not an admin. |
| Owner update of `walls` and `setups` needs the stored `review != true` | An owner cannot unpublish an approved item, then delete it. |
| Owner may delete `rejectedWalls` and `rejectedSetups` docs of their email | Creators can clear their rejected list. |
| `isOwner` comes before `isConfiguredAdmin` under `usersv2` | Fewer `exists()` reads on owner writes. The result is the same. |
| `usernames` readable when signed in, no client writes | Registry is server owned. |

## Limits

- Backend only. The app does not call `claimUsername` yet, so old and new clients still write `username` directly. The registry can drift until rules refuse direct writes. That is an owner decision.
- The username suffix runs once at profile creation. Two profiles created at the same moment can both pass the check.
- The app can show the old username until it reads the profile again.
- `nameLower` fills in for a user when the profile next changes. Old profiles have no `nameLower` until then.
- The Wall of the Day wall pick still uses a random offset. Wall doc ids are not random, so a start-at pick would be biased.
- The report hold counts reports of walls only. It does not scan images (no SafeSearch).
- The sweeper reads at most 200 open reports per run.
- The blocked-report skip also skips the webhook for that report.

## How to test

1. Run `cd functions && npm run build && node --test 'lib/__tests__/onContentReportCreated.test.js' 'lib/__tests__/reportSweeper.test.js' 'lib/__tests__/claimUsername.test.js' 'lib/__tests__/onUserCreated.test.js' 'lib/__tests__/onWallSubmitted.test.js' 'lib/__tests__/userBlockCallables.test.js' 'lib/__tests__/onFollowCreated.test.js' 'lib/__tests__/wallOfTheDay.test.js' 'lib/__tests__/adminConfig.test.js'`.
2. Run the rules smoke test (`make rules-test`). It covers the unverified admin, the unpublish block, the rejected delete and the new reads.
3. On a staging project, file 3 reports for one approved wall from 3 accounts older than 7 days. The wall goes to the review list.
