# Daily chest

Status: implementation spec, 2026-10-18. Replaces the quest chest row and sheet from coin economy v2.
Stacked on the spin wheel (`docs/features/spin-wheel.md`): the chest uses the wheel's prize table shape, its 3D button,
its coin burst and its odds sheet.

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
- The bonus quest (watch a video, or the Pro free spin) doubles the coins and the XP of the prize. A cosmetic is one
  item; its fallback coins double.
- The rarity tier comes from the odds of the slot that won, so a tier can never disagree with the odds sheet:
  25 % or more is common, 10 % or more is rare, 3 % or more is epic, less is legendary.
- `openQuestChest` and `award.questChestMin/Max/CosmeticChance` stay unchanged for 3.6.0 clients. They write the same
  receipt, so a user who has both builds still opens one chest a day.

## Prize table (`award.dailyChest`, defaults)

Same JSON shape as `award.spinWheel` (`kind`, `coins` / `xp` / `fallbackCoins`, `weight`), 2..12 slots.

| # | Prize | Weight | Tier |
|---|---|---|---|
| 0 | 5 coins | 32 | common |
| 1 | 10 coins | 26 | common |
| 2 | 25 XP | 15 | rare |
| 3 | 20 coins | 13 | rare |
| 4 | Mystery cosmetic (25 coins if all owned) | 8 | epic |
| 5 | 40 coins | 4 | epic |
| 6 | 100 coins | 2 | legendary |

Coin EV is 10.4 a chest, near the old 5..15 roll (10). A paid chest nets about +2.4 coins, so paying is fair, not a
sink. Doubled, EV is 20.8.

## Callable `openDailyChest`

Request `{requestId, maxCost, sourceTag}`. `requestId` must pass `isValidRequestId`; `maxCost` must pass `isPrice`.

One transaction:

1. Receipt exists with the same `requestId`: return its stored `replay` with the live balance and `delta: 0`.
2. Receipt exists with another `requestId`, or `quests.chestOpened`: refuse `daily_chest_already_opened`.
3. `free` = every daily quest item is claimed. `cost` = free ? 0 : `spend.dailyChest`.
4. Refuse `daily_chest_price_changed` when `cost > maxCost`; refuse `daily_chest_insufficient_balance`
   (`insufficientBalance: true`) when `coins < cost`.
5. `weightedPick(award.dailyChest)`, `resolveWheelPrize`. `doubled` = the bonus item is claimed; coins and XP × 2.
6. Root: `coins = balance - cost + coins`, XP `xp + xpForCoins(coins)` through `grantXp`.
7. `private/economy`: `quests` with `chestOpened: true, chestDoubled: doubled`; the cosmetic in `inventory.owned`.
8. Receipt: `action: "questChest"`, `delta = coins - cost`, extras `{requestId, cost, free, doubled, slot, prize, coins,
   itemId, replay}`. `coins`, `doubled`, `itemId` and `requestId` keep the 3.6.0 replay branch readable.

Every reply carries `status: {opened, free, price}` and the standard coin fields. A win adds `cost`, `free`, `doubled`,
`slot`, `prize: {kind, coins, xp, itemId}` and `slots` (the table the server rolled).

## Client

- Types in `lib/core/coins/daily_chest.dart`: `DailyChestStatus` (derived from today's `QuestState` and the config,
  nothing new is stored), `ChestTier`, `DailyChestResult` = `ChestWon | ChestRefused | ChestFailed`.
  `CoinsService.openDailyChest({maxCost})`. The old `openQuestChest`, `ChestResult`, `ChestOutcome`, the chest sheet
  and the quests bloc chest event are deleted.
- Feature `lib/features/daily_chest/`: a full-screen page from the Today card's chest row.
- The box is a Lottie, `assets/lottie/daily_chest.json`, made by `tool/daily_chest_lottie.py`. A designer can replace
  the file if it keeps the markers and keypaths below; `test/features/quests/daily_chest_asset_test.dart` checks them.

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
