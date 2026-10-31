# Creator tips

A signed-in user can tip a creator Prism Coins from a wall or from the creator profile. The creator gets the coins, an inbox item, and one push a day. Creator stats show the tips. The wall shows "Tipped by N people" when N is 3 or more.

Coins move only through the `tipCreator` callable. Clients cannot write `coins` or `coinTransactions`.

## The tip

| Part | Rule |
|---|---|
| Sender | Signed in. Firebase Auth account 7 days old or more. Has a `usersv2` profile that is not deleted. |
| Receiver (creator) | Not the sender. Has a `usersv2` profile that is not deleted, no closed `creatorDeletionState`, and a Firebase Auth user that is not disabled. Has 1 approved wall or more (`walls.creatorUid == uid`, `review == true`). Prism Studio has no Auth user, so it cannot get tips. |
| Blocks | Refused when the creator blocked the sender, or the sender blocked the creator. |
| Amounts | 10, 25 or 50 coins. Any other value is `invalid-argument`. |
| Fee | None. The creator gets the full tip. See the farming check for why. |
| Sender cap | 5 tips a UTC day (`tipRateDaily/{sender}_{day}`). |
| Pair cap | 1 tip a UTC day from one sender to one creator. |
| Receiver cap | 300 coins a UTC day per creator (`tipRateDaily/recv_{creator}_{day}`). A tip that would go over the cap is refused. |
| Wall link | Optional `wallId` (the wall document ID). The server checks that the wall exists, is approved, and belongs to the creator. |
| Ledger, sender | `coinTransactions/ctx_tip_{sender}_{requestId}`: `action: tipSent`, `delta: -amount`, `tipId`, `counterpartyUid: creator`, `wallId`. |
| Ledger, creator | `coinTransactions/ctx_tipin_{sender}_{requestId}`: `action: tipReceived`, `delta: +amount`, the same `tipId`, `counterpartyUid: sender`, `wallId`. |
| Idempotency key | `requestId` from the client. `tipId = tip_{sender}_{requestId}`. A retry with the same `requestId` returns the stored result and moves no coins. |
| Transaction | One Firestore transaction reads both users, both blocks, the caps, the wall and the sender ledger doc. Then it writes both balances, both ledger docs, the caps, the creator tips aggregate and the wall tipper marker. |
| XP, quests, badges | A received tip gives no XP and counts for no quest, badge or leaderboard. |
| Public signal | `wallpaper_stats/{wall id}.tippers` counts distinct senders on the wall. The app shows it only when it is 3 or more, and never shows names or amounts. |
| Creator stats | `creatorTips/{creator}` keeps tips and coins per ISO week (last 9 weeks) and per wall. `getCreatorStats` returns them. |
| Push | One push a creator a UTC day, on the first tip. Later tips that day rewrite the same inbox item with the day's total and send no push. |

## Failure cases

| Case | Result | Coins moved |
|---|---|---|
| Not signed in | `unauthenticated` error | No |
| Bad `creatorUid`, `amount`, `requestId` or `wallId` | `invalid-argument` error | No |
| Tip to self | `invalid-argument`, `tip_self` | No |
| Sender younger than 7 days | `tip_sender_too_new` | No |
| Creator deleted, disabled, missing, or with no approved wall | `tip_creator_unavailable` | No |
| Wall missing, not approved, or by someone else | `tip_wall_invalid` | No |
| A block in either direction | `tip_blocked` | No |
| Sender sent 5 tips today | `tip_daily_limit` | No |
| Sender already tipped this creator today | `tip_pair_limit` | No |
| Creator would pass 300 coins today | `tip_creator_limit` | No |
| Balance below the amount | `tip_insufficient_balance`, `insufficientBalance: true` | No |
| Retry of a finished tip | The stored result | No (already moved once) |
| Two tips race on one balance | Firestore retries the second transaction on fresh data. It is refused if the balance is short. | Once per tip that fits |
| Push send fails | The tip still succeeds | Yes |
