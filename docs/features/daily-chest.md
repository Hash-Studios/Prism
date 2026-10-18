# Daily chest

Status: implementation spec, 2026-10-18. Replaces the quest chest row and sheet from coin economy v2.
Stacked on the spin wheel (`docs/features/spin-wheel.md`): the chest uses the wheel's prize table shape, its 3D button,
its coin burst and its odds sheet. XP follows `docs/features/xp-and-creator-milestones.md`: the chest pays a fixed
activity award, never a prize.

## Why

The chest was a list row with an Open button and a sheet that counted coins up. It did not feel like opening anything,
and it only paid coins. The owner asked for a CRED-style box that opens, costs 5 to 10 coins, and pays coins or
something else.

## Rules

- One chest per user per UTC day, on any client. The receipt is the ledger doc
  `coinTransactions/ctx_questChest_{uid}_{dayKey}`, the same id the 3.6.0 `openQuestChest` writes.
- Opening costs `spend.dailyChest` (8). It is free when today's three daily quests are done, which was the old unlock.
- The client sends `maxCost`: 0 when it showed "free", else the price it showed. The server never charges more.
- Every chest pays something. The odds are on screen before the user pays.
- The bonus quest (watch a video, or the Pro free spin) doubles the coins of the prize. It does not double the XP. A
  cosmetic is one item; its fallback coins double.
- Opening grants `xp.activities.questChest` (10 XP) once, on the server, whatever the prize and whatever the price paid.
  No prize pays XP. The XP is in the same transaction as the coins, so a rank reward that the 10 XP unlocks lands in
  `inventory.owned` at once. The client never grants XP itself.
- The rarity tier comes from the odds of the slot that won, so a tier can never disagree with the odds sheet:
  25 % or more is common, 10 % or more is rare, 3 % or more is epic, less is legendary.
- `openQuestChest` and `award.questChestMin/Max/CosmeticChance` stay unchanged for 3.6.0 clients. They write the same
  receipt, so a user who has both builds still opens one chest a day.

## Prize table (`award.dailyChest`, defaults)

Same JSON shape as `award.spinWheel` (`kind`, `coins` / `fallbackCoins`, `weight`), 2..12 slots. No slot pays XP. A
configured table with an `xp` slot is invalid: the server and the client use the whole default table, as for the wheel.

| # | Prize | Weight | Tier |
|---|---|---|---|
| 0 | 5 coins | 34 | common |
| 1 | 8 coins | 28 | common |
| 2 | 12 coins | 15 | rare |
| 3 | 20 coins | 11 | rare |
| 4 | Mystery cosmetic (25 coins if all owned) | 8 | epic |
| 5 | 40 coins | 3 | epic |
| 6 | 100 coins | 1 | legendary |

The weights add up to 100, so a weight is a percent. Coin EV is 10.14 a chest (1.7 + 2.24 + 1.8 + 2.2 + 1.2 + 1.0; the
cosmetic slot counts as 0 coins), near the old 5..15 roll (10). A paid chest nets about +2.1 coins, so paying is fair,
not a sink. Doubled, EV is 20.28. Each open also gives 10 XP, which no table sets.

## Callable `openDailyChest`

Request `{requestId, maxCost, sourceTag}`. `requestId` must pass `isValidRequestId`; `maxCost` must pass `isPrice`.

One transaction:

1. Receipt exists with the same `requestId`: return its stored `replay` with the live balance, `delta: 0` and the live
   XP receipt with `xpAwarded: 0`. A replay never grants XP again.
2. Receipt exists with another `requestId`, or `quests.chestOpened`: refuse `daily_chest_already_opened`.
3. `free` = every daily quest item is claimed. `cost` = free ? 0 : `spend.dailyChest`.
4. Refuse `daily_chest_price_changed` when `cost > maxCost`; refuse `daily_chest_insufficient_balance`
   (`insufficientBalance: true`) when `coins < cost`.
5. `grantXp(xp.activities.questChest)` and `rankRewardsFor` on the new XP. The prize roll then sees the rank rewards as
   owned.
6. `weightedPick(award.dailyChest)`, `resolveWheelPrize`. `doubled` = the bonus item is claimed; coins × 2, XP unchanged.
7. Root: `coins = balance - cost + coins`, plus the XP fields from step 5.
8. `private/economy`: `quests` with `chestOpened: true, chestDoubled: doubled`; the cosmetic and the rank rewards in
   `inventory.owned`.
9. Receipt: `action: "questChest"`, `delta = coins - cost`, extras `{requestId, cost, free, doubled, slot, prize, coins,
   itemId, replay}`. `coins`, `doubled`, `itemId` and `requestId` keep the 3.6.0 replay branch readable. The stored
   `replay` has no XP fields, because a replay computes them live.

Every reply carries `status: {opened, free, price}`, the standard coin fields and the XP receipt `xpPolicyVersion: 1`,
`xp`, `xpWeek: {weekKey, xp}` and `xpAwarded`. `xp` and `xpWeek` are the absolute totals after the call.
`xpAwarded` is 10 (the configured amount) on a win. It is 0 on a replay and on a refusal, which carry the live totals
and grant nothing. A win adds `cost`, `free`, `doubled`, `slot`, `prize: {kind, coins, xp: 0, itemId}` and `slots` (the
table the server rolled). `prize.xp` is always 0.

## Client

- Types in `lib/core/coins/daily_chest.dart`: `DailyChestStatus` (derived from today's `QuestState` and the config,
  nothing new is stored), `ChestTier`, `DailyChestResult` = `ChestWon | ChestRefused | ChestFailed`.
  `ChestWin.xp` is the XP this open granted. The service reads it from `xpAwarded` (0 when absent), not from the
  prize, and `daily_chest_opened.xp` sends the same value.
  `CoinsService.openDailyChest({maxCost})`. The old `openQuestChest`, `ChestResult`, `ChestOutcome`, the chest sheet
  and the quests bloc chest event are deleted.
- XP on the client: `_callEconomy` passes a successful reply to `applyRoutineXpReply`, which adopts the absolute `xp`
  and `xpWeek`. The client adds nothing to its own total. A reply without the receipt (an older backend) starts a rank
  reconcile instead of an estimate. A stale reply is not adopted, and a changed one starts the same reconcile.
- The reveal card shows the prize and, under it, a small `+10 XP` caption when `xpAwarded` is above 0. A replay reports
  0, so it shows no caption.
- Feature `lib/features/daily_chest/`: a full-screen page from the Today card's chest row.
- The box is a Lottie, `assets/lottie/daily_chest.json`, made by `tool/daily_chest_lottie.py`. A designer can replace
  the file if it keeps the markers and keypaths below; `test/features/daily_chest/daily_chest_asset_test.dart` checks them.

| Marker | Frames | Plays when |
|---|---|---|
| `idle` | 0..120, loops | the chest is ready |
| `charge` | 120..180, loops | the app waits for the server |
| `open` | 180..270, once | the server said what is inside |
| `opened` | 270..390, loops | the prize is on screen |
| `spent` | 390..392, still | today's chest is already open |

Keypaths: `glow` takes the tier colour; `accent_light`, `accent_mid`, `accent_dark` take the user accent.

## Why Lottie, not Rive

Rive files are authored in the Rive editor; there is no headless way to make one here. Rive's runtime is also a native
plugin, which changes `ios/Podfile.lock`, and this build host cannot run `pod install`. A Lottie is plain JSON: a
script draws it, the app tints it at runtime and plays it by marker, and a designer can drop in a better one later.
