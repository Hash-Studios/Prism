# Spin the wheel

Status: implementation spec, 2026-10-18. Replaces the free Pro spin card from coin economy v2.

## Why

The Pro spin was a flat card with a Spin button. It did not feel like a game, free users could not play, and it paid
38 coins a day for free with nothing spent. The owner asked for a CRED-style wheel machine that costs coins and pays
coins or something else.

## Rules

- Everyone can spin. A paid spin costs `spend.spinWheel` (10).
- Pro members get one free spin per UTC day. It shares the daily receipt with the legacy `claimProSpin` and
  `proDailyBonus` (`coinState.proSpinDate`, `coinState.proDailyBonusDate`), so one Pro user gets one free spin a day on
  any client.
- At most `award.spinWheelMaxPerDay` (5) paid spins per UTC day. The free spin does not count.
- The client sends `maxCost`, the price it showed. The server refuses with `spin_wheel_price_changed` when the real
  cost is higher. The server never charges more than the user saw.
- Every spin pays something. Equal-size slices, odds shown in the odds sheet.
- The 3.6.0 client keeps `claimProSpin` and `award.proSpin`. Do not change either.

## Prize table (`award.spinWheel`, defaults)

Index 0 sits under the pointer at rest. Order is the wheel order, clockwise.

| # | Prize | Weight |
|---|---|---|
| 0 | 10 coins | 18 |
| 1 | 25 XP | 22 |
| 2 | 5 coins | 30 |
| 3 | 100 coins | 1 |
| 4 | 20 coins | 8 |
| 5 | 50 XP | 12 |
| 6 | 50 coins | 3 |
| 7 | Mystery cosmetic (50 coins if all owned) | 6 |

Coin EV is 7.4 a spin, plus about 19 XP. A paid spin is a mild sink (net -2.6 coins). The cosmetic is a random
unowned `common` shop item (`pickChestCosmetic`), the same pool as the quest chest.

Segment JSON: `{"kind": "coins", "coins": 10, "weight": 18}`, `{"kind": "xp", "xp": 25, "weight": 22}`,
`{"kind": "cosmetic", "fallbackCoins": 50, "weight": 6}`. `coins`, `xp` and `fallbackCoins` are integers
1..1000, `weight` 0..1000 with a positive sum, 2..12 segments. Anything else falls back to the default table.

## Callable `spinWheel`

Request: `{requestId, maxCost, sourceTag}`. `requestId` must pass `isValidRequestId`. `maxCost` is an integer
0..10000, else `invalid-argument`.

One Firestore transaction:

1. Replay. Ledger doc `coinTransactions/ctx_spinWheel_{uid}_{requestId}` exists: return its stored reply with a
   fresh `status`.
2. Free spin: `premium == true` and neither `coinState.proSpinDate` nor `coinState.proDailyBonusDate` is today and
   `private/economy.spinWheel.freeUsed` is not true for today.
3. Paid spin: refuse `spin_wheel_daily_limit` when today's `paid >= spinWheelMaxPerDay`. Cost is `spend.spinWheel`.
4. Refuse `spin_wheel_price_changed` when `cost > maxCost`.
5. Refuse `spin_wheel_insufficient_balance` (`insufficientBalance: true`) when `coins < cost`.
6. `weightedPick(award.spinWheel)`. Grant the prize. Cosmetic: `pickChestCosmetic(owned)`, write
   `inventory.owned.{id} = nowMs`; none left pays `fallbackCoins`.
7. Root update: `coins = balance - cost + prizeCoins`, XP `prizeXp + xpForCoins(prizeCoins)` through `grantXp`, and
   both `coinState` dates when free.
8. `private/economy` through `writePrivate`: `spinWheel = {dayKey, paid, freeUsed}`; the `pro_spin` quest event when
   the spin was the free Pro spin.
9. One ledger doc, `action: "spinWheel"`, `delta = prizeCoins - cost`, extras `{cost, free, segment, prize}`.

Every reply carries `status: {freeSpinAvailable, paidSpinsLeft, price}` and the standard coin fields
(`success`, `changed`, `previousBalance`, `currentBalance`, `delta`, `reason`, `transactionId`). A win adds
`cost`, `free`, `segment`, `prize: {kind, coins, xp, itemId}` and `segments` (the table the server spun, so the
client lands on the truth even with a stale config). Cosmetic fallback replies `kind: "cosmetic"`, `itemId: null` and
the fallback in `coins`.

## Client

- Types live in `lib/core/coins/spin_wheel.dart`. `CoinsService.spinWheel({maxCost})` returns `SpinWon`,
  `SpinRefused` or `SpinFailed`. `CoinsService.spinWheelNotifier` holds today's `SpinWheelStatus`, from
  `private/economy.spinWheel`, the `pro_spin` bonus quest and each reply.
- Request ids go through `_economyPurchase('spinWheel', 'next', ...)`: a lost reply replays the same id on the next
  tap, so one tap never spins twice.
- Analytics: `spin_wheel_spun` with `free`, `cost`, `segment`, `prize`, `coins`, `xp`.

## Machine (UI)

Built in Flutter with `CustomPainter` and widgets, not Lottie or Rive. The server picks the slice, the labels come
from the config and the colours come from the theme, so a baked animation cannot land or relabel.

- Full-screen stage from Rewards. Accent glow behind the wheel, close button, page-local coin pill.
- Static gold bezel with bulbs that chase while the wheel turns and flash on a win. Pointer flapper at the top that
  kicks on every peg with a selection haptic (throttled).
- Wheel face in a `RepaintBoundary`, turned with `Transform.rotate`, so a frame only changes a transform.
- Plinth below with a 3D SPIN button: "Free spin" or the price, "Get coins" when short, "Back tomorrow" at the cap.
- Motion: wind back, spin up, cruise until the reply, then a quartic ease-out that lands inside the target slice.
  Reduced motion jumps to the result.
- Result panel with a coin burst, the prize, "Spin again" and "Done". "See the odds" sheet lists every slice.
