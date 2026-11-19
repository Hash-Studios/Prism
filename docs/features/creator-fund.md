# Creator fund

Each week, Prism shares a fixed pool of Prism Coins among creators. The share of a creator depends on the engagement that the server recorded on their approved walls. Roadmap item J1.

The fund is off when the pool is 0. The default pool is 0.

## Where to find it

| Item | Path |
|---|---|
| Config (`creatorFund` block) | `functions/src/economy.ts`, Firestore `economyConfig/current` |
| Score and payout math (pure) | `functions/src/creatorFund/score.ts` |
| Event ledger | `functions/src/creatorFund/events.ts` |
| Read-only loaders | `functions/src/creatorFund/load.ts` |
| Weekly job `settleCreatorFund` | `functions/src/creatorFund/settle.ts`, `functions/src/creatorFund/compute.ts` |
| Status callable `getCreatorFundStatus` | `functions/src/creatorFund/status.ts` |
| Dry run | `functions/src/scripts/creatorFundDry.ts`, `functions/src/creatorFund/legacy.ts` |
| App row | `lib/features/creator_fund/`, shown on Creator stats |

## Domain model

### Events

An event is one action by one user on one wall: `{wallId, metric, actorUid}`. `wallId` is the normalized wall ID (trimmed, upper case). The metrics are `saves`, `sets`, `downloads`, `remixes` and `folderAdds`.

Only the server writes events, to `creatorFundEvents/{id}`. The ID is a SHA-256 hash of the week, wall, metric and actor. Thus one user counts one time for each wall, metric and week. A repeat writes the same document. Live hooks bind an identified wall to its approved document, creation time, logical ID and creator. Settlement checks that binding against its census. An event cannot move to a replacement wall.

| Metric | Written by | Actor |
|---|---|---|
| `sets`, `downloads` | `recordWallpaperAction`, only when the action counted | The caller |
| `saves` | `onFavouriteWritten`, only when a favourite becomes active | The user who saved |
| `remixes` | `syncRemixCredit`, only on the first counted credit | The creator of the remix |
| `folderAdds` | `countFolderCreation`, only on the first counted item | The adding member (`addedBy`), or the owner for older owner-only writes. Automatic smart-folder items do not count. |

A save uses the server creation time of the active membership. A delayed trigger does not move the save into a later week. Shares and views do not count. The app never sends a count. Sets and downloads are authenticated client reports: the server can validate the wall, caller and rate, but cannot attest an OS action. Independent verified accounts older than seven days can still belong to the same person. Events expire after 63 days (TTL on `expireAt`).

### Score

1. Each event gets its weight from the config. The default weights are: saves 1, sets 3, downloads 2, remixes 5, folder adds 1.
2. The contribution of a user to a creator is the sum of the weights of their events on the walls of that creator.
3. The raw score of a creator is the sum of all contributions.
4. One user can add at most `maxUserSharePercent` (default 10) of the raw score. The capped sum is the score.

The math uses hundredths of a point (`scoreCenti`), so the cap is an exact integer.

### Exclusions

| Excluded | Rule |
|---|---|
| Studio walls | A wall with `origin == "studio"` does not count (`approvedWall`). Studio walls are Prism's own. |
| Walls that are not approved | `review` must be `true` and `wallpaper_provider` must be `prism`. |
| Shared wall IDs | When two wall documents have the same normalized ID, neither counts. |
| Prism team accounts | UIDs in `excludedUids`. They get no payout, and their actions do not count. |
| Moderation strike | A creator with a wall that reports held for review (a hold in that week, or an active `heldForReview` on an unapproved wall now) gets no payout for that week. |
| Blocked accounts | A Firebase Auth user that is disabled. As a creator, no row. As an actor, the actions do not count. |
| Deleted accounts | A missing or `deleted` `usersv2` document, or a closed `creatorDeletionState`. Same as blocked. |
| Own actions | A creator's actions on their own walls do not count. |
| New or anonymous actors | An actor must have a verified email and sign in with a real provider, and the account must be at least 7 days old when the week ends. Else the actions do not count. This is the same rule as for tips. The creator can still earn. |

The report transaction keeps a weekly strike under `creatorDeletionState/{uid}/fundStrikes/{week}`. Deleting or reapproving the wall cannot erase that week’s strike. Earlier holds are detectable only from the wall fields that still exist.

### Qualify

A creator qualifies when all of these are true:

- The account gate is `ok` (not team, not struck).
- At least `minDistinctUsers` (default 5) different users have a contribution above 0.
- The score is above 0.

### Payout

1. `coins = floor(pool × score / total score of qualified creators)`.
2. `coins` is at most `perCreatorCap` (default 1,000).
3. If `coins` is less than `minPayout` (default 5), the creator gets 0 and the reason is `smallShare`.
4. Coins that are not paid stay unpaid. They do not go to other creators.

### Row reasons

| Reason | Meaning |
|---|---|
| `fewUsers` | Fewer than `minDistinctUsers` people engaged. |
| `smallShare` | The share is less than the minimum payout. |
| `moderation` | Reports held a wall of the creator for review. |
| `team` | A Prism team account. |
| `noActivity` | The callable only. The week ran, but the creator has no row. |

## Config

`economyConfig/current.creatorFund`:

```json
{
  "pool": 0,
  "weights": {"saves": 1, "sets": 3, "downloads": 2, "remixes": 5, "folderAdds": 1},
  "maxUserSharePercent": 10,
  "minDistinctUsers": 5,
  "perCreatorCap": 1000,
  "minPayout": 5,
  "excludedUids": []
}
```

`parseEconomy` checks each field. A bad field gets its default. A bad pool gets 0, so a broken config never pays. Bounds: pool 0 to 100,000. Weights 0 to 100. `maxUserSharePercent` 1 to 100. `minDistinctUsers` 1 to 1,000. `perCreatorCap` 1 to 100,000. `minPayout` 1 to `perCreatorCap`.

Set the pool with `npm run economy:config -- --set creatorFund.pool=<coins>`. Add `--apply` to write.

## Weekly job

`settleCreatorFund` runs every hour from 06:00 to 12:00 UTC on Monday. It settles the ISO week that ended at Monday 00:00 UTC. The Monday runs can open a week. Outside that window the hourly job only resumes an unfinished week, even if a newer week has started.

```text
(no doc) --pool > 0--> computing --> paying --> notifying --> complete
   |                      ^
   +--pool == 0: no write |  a retry continues from the committed page
```

| State | What the job does |
|---|---|
| No doc, pool 0 | Nothing. It writes nothing. |
| No doc, pool above 0 | Creates `creatorFund/{week}` with the pool, `rulesVersion` and a copy of the rules. |
| `computing` | Builds the wall census, accumulates actor weights, applies the caps, sums qualified scores, allocates each row and removes temporary records. Each page and its cursor commit together. |
| `paying` | Pays due rows in transactions of up to 75 creators. |
| `notifying` | Sends one inbox item and push to each paid creator. |
| `complete` | Nothing. One read. |

The job and the status callable run in `us-central1` only. The app calls that region, and `asia-south1` has no free CPU budget. A lease on the week document (10 minutes) stops two runs from working at the same time. A second run returns `busy`. The lease lasts longer than the 540-second invocation timeout. After 240 seconds the job starts no more pages, payment batches or individual notices; an in-flight operation can finish. The next hourly run continues.

### Documents

`creatorFund/{week}`: `week`, `state`, `pool`, `rulesVersion`, `rules`, `totals {creators, qualified, paid, coins, unpaid, scoreCenti}`, `events`, `coinsPaid`, `paidCreators`, timestamps.

`creatorFund/{week}/creators/{uid}`: `status` (`paid` or `notQualified`), `reason`, `scoreCenti`, `shareBps`, `coins`, `distinctUsers`, `capped`, `payState` (`due`, `done`, `none`, `void`), `noticeState`, `txId`, `paidAt`. Rows have no names and no email addresses. `totals` describes the allocation; `coinsPaid` and `paidCreators` describe committed credits. The temporary `fundIndex` and `fundPairs` collections are private and removed before payment.

### Payment safety

- One payout for each creator and week. The ledger ID is `coinTransactions/ctx_creatorFund_{uid}_{week}`. The UID is escaped like tips (`encodeURIComponent`, `_` as `%5F`).
- One transaction reads the row, the ledger document, the user and the deletion barrier. It writes the balance, the ledger document and the row together. Thus a crash leaves all three or none.
- If the ledger document exists, the job marks the row `done` and pays nothing.
- Payment rechecks the recipient’s Auth record, account document, deletion barrier, report strike and current holds. A newly ineligible creator gets no credit; the remaining creators do not inherit it. Auth and Firestore cannot commit atomically. Actor eligibility is checked while computing contributions.
- A payment batch has at most 226 writes (3 per creator plus the week) and 451 Firestore reads (6 per creator plus the week). Compute pages write at most 400 rows and one checkpoint. The job rejects an unsafe balance or a batch that would exceed the frozen pool.
- Rows are frozen when the state is `paying`. A rerun never computes new amounts.

### Ledger and coins

| Field | Value |
|---|---|
| `action` | `creatorFund` |
| `delta` | the coins |
| `description` | `Creator fund: {week}` |
| `reason` | `creator_fund_{week}` |
| `sourceTag` | `creatorFund.weekly` |

Fund coins are earned coins. They grant no XP. They do not count for quests, badges, the leaderboard or milestones. They cannot be refunded. The app shows the line as **Creator fund**.

### Push

Each paid creator gets one inbox item and one push: **You earned N coins from the Creator fund**. The body is **See your share in Creator stats.** The route is `creator_stats`. The kind is `creatorFundPaid` with args `{coins, week}`. The channel is `posts`.

The push uses the **Posts** switch (`postAlerts` in `usersv2/{uid}/private/session`). Editors' Choice, remix and weekly challenge notices for creators use the same switch. When `postAlerts` is `false`, the inbox item stays and the push does not go.

The claim and deterministic inbox item commit in one transaction before push delivery. A crash can lose a push, but cannot lose the committed inbox item or trigger another push. Account deletion removes the creator’s rows, notices, temporary weights, weekly strikes and actor events after closing the deletion barrier.

Installed builds query personal inbox items by email. A creator without an email can still receive the credit and see it in Creator stats, but the current inbox query will not fetch that item.

Installed builds do not have native strings for this kind. The system banner is in English. The inbox shows the localized copy.

## Status callable

`getCreatorFundStatus` needs sign-in. Send `{}`. It uses only `request.auth.uid`.

It returns `{schemaVersion: 1, week, state, distinctUsers, minDistinctUsers, minPayout}` and:

| State | Extra fields | When |
|---|---|---|
| `off` | none | No week doc and the pool is 0. |
| `pending` | none | No week doc and the pool is above 0, the week is `computing`, or the caller’s payout is still due. |
| `paid` | `coins`, `shareBps` | The row has a committed payment. The displayed share is the coins paid divided by the frozen pool, after floors and caps. |
| `notQualified` | `reason`, `shareBps` | The row is `notQualified`, or the week ran and there is no row (`noActivity`). |

## App

Creator stats shows a **Creator fund** row below the tips. It shows the payout and the share of last week, or the reason in plain words. The row has one screen-reader label. The text wraps at large text sizes. The layout supports right-to-left. The typed analytics event is `creator_fund_viewed` with `state` and `reason`.

## Rules

Clients cannot read or write `creatorFund/**` or `creatorFundEvents/**`. The app reads its row through the callable.

## Dry run

```sh
cd functions
GOOGLE_APPLICATION_CREDENTIALS=<read credential> GCLOUD_PROJECT=prism-wallpapers \
  npm run creator-fund:dry -- --week 2026-W46 --pool 1000,5000 --top 20
```

The script only reads. It uses the stored rules for an existing week. It prints counts, totals for each pool, and hashed UIDs for both the table and the exclusion list. It never prints names or email addresses.

`--source ledger` reads `creatorFundEvents`. `--source legacy` rebuilds the week from older records: favourite contributions, action receipts, remix credits and folder items. `auto` (the default) uses the ledger when it has events for that week. The legacy source undercounts sets and downloads, because only some app builds send action receipts.

## Deploy order

1. Rules: `firebase deploy --only firestore:rules`.
2. Indexes and TTL: `firebase deploy --only firestore:indexes`.
3. Functions: the event hooks, `settleCreatorFund` and `getCreatorFundStatus`.
4. The store build with the app row.
5. After at least one full week of events: set `creatorFund.pool` in the economy config.

The pool stays 0 until step 5, so steps 1 to 4 pay nothing.

## Known limits

- The first full week of events starts on the Monday after the functions deploy.
- An event that a trigger retries after Monday 06:00 UTC can miss its week.
- When an action supplies only a logical ID, the live hook resolves its submitted, uppercase and lowercase spellings. It skips an ambiguous target. When no spelling matches, settlement can still use the normalized census if the unique wall was already approved and its server document has not changed since the action. Unresolved actions on legacy mixed-case or padded IDs can undercount if the document has since changed. Explicit folder and remix document references do not have this limitation.
- If event collection has not finished before the first events reach their 63-day TTL, settlement stops without paying from an incomplete ledger.
- The census scans every wall each week. The job fails if there are more than 100,000 walls or 2,000,000 events in one week.
- The per-user cap reduces the score of a creator with a small audience. Five equal users give 50% of the raw score.
