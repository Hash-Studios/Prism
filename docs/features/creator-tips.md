# Creator tips

A signed-in user can tip a creator Prism Coins from a wall or from the creator profile. The creator gets the coins, an inbox item, and one push a day. Creator stats show the tips. The wall shows "Tipped by N people" when N is 3 or more.

Coins move only through the `tipCreator` callable. Clients cannot write `coins` or `coinTransactions`.

## The tip

| Part | Rule |
|---|---|
| Sender | Signed in with a verified email and a provider that is not anonymous (no guests). Firebase Auth account 7 days old or more. Has a `usersv2` profile that is not deleted. |
| Receiver (creator) | Not the sender. Has a `usersv2` profile that is not deleted, no closed `creatorDeletionState`, and a Firebase Auth user that is not disabled. Has 1 approved wall or more: `walls.creatorUid == uid`, `review == true`, `wallpaper_provider == prism`, `origin != studio` (the same rule as creator milestones). Prism Studio has no Auth user, so it cannot get tips. |
| Blocks | Refused when the creator blocked the sender, or the sender blocked the creator. |
| Amounts | 10, 25 or 50 coins. Any other value is `invalid-argument`. |
| Fee | None. The creator gets the full tip. See the farming check for why. |
| Sender cap | 5 tips a UTC day (`tipRateDaily/{sender}_{day}`). |
| Pair cap | 1 tip a UTC day from one sender to one creator (`tipRateDaily/pair_{sender}_{creator}_{day}`). |
| Receiver cap | 100 coins a UTC day per creator (`tipRateDaily/recv_{creator}_{day}`). A tip that would go over the cap is refused. |
| Wall link | Optional `wallId`. It is the wall document ID, not the wall's `id` field. The server checks that the wall exists, is approved, and belongs to the creator. |
| Ledger, sender | `coinTransactions/ctx_tip_{sender}_{requestId}`: `action: tipSent`, `delta: -amount`, `tipId`, `counterpartyUid: creator`, `wallId`. |
| Ledger, creator | `coinTransactions/ctx_tipin_{sender}_{requestId}`: `action: tipReceived`, `delta: +amount`, the same `tipId`, `counterpartyUid: sender`, `wallId`. |
| Idempotency key | `requestId` from the client. `tipId = tip_{sender}_{requestId}`. A retry with the same `requestId` returns the stored result and moves no coins. |
| Transaction | One Firestore transaction reads both users, both blocks, the caps, the wall and the sender ledger doc. Then it writes both balances, both ledger docs, the caps, the creator tips aggregate and the wall tipper marker. |
| XP, quests, badges | `tipCreator` never calls `grantXp`. A received tip counts for no quest, badge, leaderboard, rank or creator milestone. |
| Refunds | `tipSent` is not in the refundable actions, so a tip cannot be refunded. |
| Account deletion | `deleteAccount` deletes `creatorTips/{uid}` and `tipRateDaily/{uid}_{day}` with the other per-user docs. |
| Public signal | `wallpaper_stats/{wall id field}.tippers` counts distinct senders on the wall (`wallTippers/{hash}` marks each sender once). Only verified senders 7 days old or more can tip, so only they count. The app shows it only when it is 3 or more, and never shows names or amounts. |
| Creator stats | `creatorTips/{creator}` keeps tips and coins per ISO week (last 9 weeks) and per wall. `getCreatorStats` returns them. |
| Push | One push a creator a UTC day, on the first tip. Later tips that day rewrite the same inbox item with the day's total and send no push. |

## Failure cases

| Case | Result | Coins moved |
|---|---|---|
| Not signed in | `unauthenticated` error | No |
| Bad `creatorUid`, `amount`, `requestId` or `wallId` | `invalid-argument` error | No |
| Tip to self | `invalid-argument`, `tip_self` | No |
| Guest, anonymous or unverified sender | `tip_sender_ineligible` | No |
| Sender younger than 7 days | `tip_sender_too_new` | No |
| Creator deleted, disabled, missing, Prism Studio, or with no approved wall | `tip_creator_unavailable` | No |
| Wall missing, not approved, or by someone else | `tip_wall_invalid` | No |
| A block in either direction | `tip_blocked` | No |
| Sender sent 5 tips today | `tip_daily_limit` | No |
| Sender already tipped this creator today | `tip_pair_limit` | No |
| Creator would pass 100 coins today | `tip_creator_limit` | No |
| Balance below the amount | `tip_insufficient_balance`, `insufficientBalance: true` | No |
| Retry of a finished tip | The stored result | No (already moved once) |
| Two tips race on one balance | Firestore retries the second transaction on fresh data. It is refused if the balance is short. | Once per tip that fits |
| Push send fails | The tip still succeeds | Yes |

## Farming check

Before code, a reviewer checked the table for coin farming and laundering through alt accounts. Results:

| Question | Verdict | Change |
|---|---|---|
| Can alts pool coins into one creator? | Yes, but tips mint no coins. Each alt must earn its coins first (ads, streak, quests). | Receive cap cut from 300 to 100 coins a day. 100 is below the 210 coins one honest account can earn a day from ads alone, so a ring of alts cannot out-earn a real user. Raise it with real data. |
| Is a burn needed? | No. A burn only matters when a tip creates value. Nothing pays out for a received tip. A burn would tax honest creators and leave the faucet the same. | Creator gets the full tip. |
| Can two accounts tip each other in a ring to farm XP, ranks, badges, quests, leaderboards or milestones? | No. None of them read `tipReceived` credits. | None. |
| Can alts fake "Tipped by N"? | Partly: 3 alts that pass the sender checks make "Tipped by 3" for 30 coins. | Senders must be verified, not anonymous, and 7 days old. The signal stays quiet (3 or more, no names, no amounts). |
| Refunds | `tipSent` is not refundable. | Test added. |
| Account deletion | The ledger rows go; `creatorTips` and `tipRateDaily` were left behind. | Both added to `deleteAccount`. |
| UTC day edge | The caps reset at 00:00 UTC, so a burst across midnight can reach 2 times a cap. | Accepted and noted in the code. |

## Deploy order

No rules change: `tipRateDaily`, `wallTippers` and `creatorTips` have no client rule, so clients cannot read or write them. `wallpaper_stats` is already public read and server write. No new composite index: the approved-wall query uses two equality filters.

1. Functions: `tipCreator` (new), `getCreatorStats` (returns `tips`), `deleteAccount` (cleans tip docs).
2. Then the store build.

## Follow-up: cash revenue share

Out of scope here. A cash share needs payouts, tax forms and KYC per country, and a ledger that can convert coins to money. Track it as its own project.
