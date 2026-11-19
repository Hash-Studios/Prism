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
| Weekly job `settleCreatorFund` | `functions/src/creatorFund/settle.ts` |
| Status callable `getCreatorFundStatus` | `functions/src/creatorFund/status.ts` |
| Dry run | `functions/src/scripts/creatorFundDry.ts`, `functions/src/creatorFund/legacy.ts` |
| App row | `lib/features/creator_fund/`, shown on Creator stats |

## Domain model

### Events

An event is one action by one user on one wall: `{wallId, metric, actorUid}`. `wallId` is the normalized wall ID (trimmed, upper case). The metrics are `saves`, `sets`, `downloads`, `remixes` and `folderAdds`.

Only the server writes events, to `creatorFundEvents/{id}`. The ID is a SHA-256 hash of the week, wall, metric and actor. Thus one user counts one time for each wall, metric and week. A repeat writes the same document.

| Metric | Written by | Actor |
|---|---|---|
| `sets`, `downloads` | `recordWallpaperAction`, only when the action counted | The caller |
| `saves` | `onFavouriteWritten`, only when a favourite becomes active | The user who saved |
| `remixes` | `syncRemixCredit`, only on the first counted credit | The creator of the remix |
| `folderAdds` | `countFolderCreation`, only on the first counted item | The folder owner |

Shares and views do not count. The app never sends a count. Events expire after 63 days (TTL on `expireAt`).

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
| Moderation strike | A creator with a wall that reports held for review (`heldAt` in that week, or `heldForReview == true` now) gets no payout for that week. |
| Blocked accounts | A Firebase Auth user that is disabled. As a creator, no row. As an actor, the actions do not count. |
| Deleted accounts | A missing or `deleted` `usersv2` document, or a closed `creatorDeletionState`. Same as blocked. |
| Own actions | A creator's actions on their own walls do not count. |
| New or anonymous actors | An actor must sign in with a real provider, and the account must be at least 7 days old when the week ends. Else the actions do not count. This is the same rule as for tips. The creator can still earn. |

Note: Prism has no other strike record. The held-by-reports state is the nearest server-recorded moderation action.

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

`settleCreatorFund` runs every hour from 06:00 to 12:00 UTC on Monday. It settles the ISO week that ended at Monday 00:00 UTC. Each run continues the state that it finds.

```text
(no doc) --pool > 0--> computing --> paying --> notifying --> complete
   |                      ^
   +--pool == 0: no write |  a crashed compute starts again
```

| State | What the job does |
|---|---|
| No doc, pool 0 | Nothing. It writes nothing. |
| No doc, pool above 0 | Creates `creatorFund/{week}` with the pool, `rulesVersion` and a copy of the rules. |
| `computing` | Deletes old rows, loads events, the wall census and the account gates, then writes one row for each creator with events. |
| `paying` | Pays due rows in transactions of 100 creators. |
| `notifying` | Sends one inbox item and push to each paid creator. |
| `complete` | Nothing. One read. |

A lease on the week document (10 minutes) stops two runs from working at the same time. A second run returns `busy`. The job stops a phase after 240 seconds. The next hourly run continues.

### Documents

`creatorFund/{week}`: `week`, `state`, `pool`, `rulesVersion`, `rules`, `totals {creators, qualified, paid, coins, unpaid, scoreCenti}`, `events`, `coinsPaid`, `paidCreators`, timestamps.

`creatorFund/{week}/creators/{uid}`: `status` (`paid` or `notQualified`), `reason`, `scoreCenti`, `shareBps`, `coins`, `distinctUsers`, `capped`, `payState` (`due`, `done`, `none`, `void`), `noticeState`, `txId`, `paidAt`. Rows have no names and no email addresses.

### Payment safety

- One payout for each creator and week. The ledger ID is `coinTransactions/ctx_creatorFund_{uid}_{week}`. The UID is escaped like tips (`encodeURIComponent`, `_` as `%5F`).
- One transaction reads the row, the ledger document, the user and the deletion barrier. It writes the balance, the ledger document and the row together. Thus a crash leaves all three or none.
- If the ledger document exists, the job marks the row `done` and pays nothing.
- If the account was deleted after compute, the row becomes `void` and nobody gets those coins.
- A batch has at most 301 writes (3 for each of 100 creators, plus the week totals). The Firestore limit is 500.
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

The job claims the notice before it sends. A crash can lose a push. It cannot send two.

Installed builds do not have native strings for this kind. The system banner is in English. The inbox shows the localized copy.

## Status callable

`getCreatorFundStatus` needs sign-in. Send `{}`. It uses only `request.auth.uid`.

It returns `{schemaVersion: 1, week, state, distinctUsers, minDistinctUsers, minPayout}` and:

| State | Extra fields | When |
|---|---|---|
| `off` | none | No week doc and the pool is 0. |
| `pending` | none | No week doc and the pool is above 0, or the week is `computing`. |
| `paid` | `coins`, `shareBps` | The row is `paid`. |
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

The script only reads. It prints counts, totals for each pool, and a table with hashed UIDs. It never prints names or email addresses.

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
- The census scans every wall each week. The job fails if there are more than 100,000 walls or 2,000,000 events in one week.
- The per-user cap reduces the score of a creator with a small audience. Five equal users give 50% of the raw score.
