# Streak rescue

A user who misses a day loses a streak. If the streak was 7 days or longer, the user can buy it back for 100 coins within 48 hours.

## Where to find it

The app shows the offer in the daily claim sheet, right after the claim that broke the streak. The sheet is the broken-streak variant of `DailyClaimSheet`.

## App behaviour

Code: `lib/features/streak/data/streak_rescue_service.dart` and `lib/features/rewards/views/widgets/daily_claim_sheet.dart`.

1. The claim answer does not carry the offer. The app reads it from the claim: `streakBroken` is true and `previousStreakCount` is 7 or more. This matches the server rule that writes `coinState.rescue`.
2. The sheet shows "Restore your N-day streak · 100 coins" and a Restore button. `streak_rescue_offered` is logged once with the old streak length.
3. A balance under 100 coins changes the button to "Earn coins". It shows "You have X. You need 100." The tap closes the sheet and opens the earn section. It does not call the server.
4. Restore calls `restoreStreak({requestId})` through `appFunctions` (region `asia-south1`, 20 second timeout). The app saves the `requestId` in settings under `pendingStreakRescueRequest.<uid>`. A retry after a timeout or an error uses the same id. The app clears the id after any answer from the server.
5. On success the app refreshes the balance and the streak. Glint celebrates. The title reads "Your streak is back".
6. On a refusal the offer disappears and a toast gives the reason. The reasons `streak_rescue_cooldown` and `streak_rescue_expired` have their own copy. All other reasons give "This streak can't be restored now."
7. On a network or server error the offer stays. The toast reads "Couldn't restore your streak. Try again."
8. `streak_rescue_used` is logged with `result`: `restored`, `insufficientBalance`, `unavailable` or `failed`.

## Platforms and plans

| Platform | Free | Pro |
|---|---|---|
| Android and iOS | Same price and same rules | Same price and same rules |

Premium does not change the price or the limits. This matches streak freezes.

## How it works

1. `claimDailyStreak` finds a broken streak. If the streak before the break was 7 days or longer, it writes `coinState.rescue = {count, expiresAtMs}`. `count` is the old streak length. `expiresAtMs` is 48 hours after the claim.
2. The app calls `restoreStreak({requestId})`. `requestId` is 8 to 64 characters: letters, digits, `_` and `-`.
3. In one transaction, the server checks the rules below. If all pass, it does these steps:
   - It takes 100 coins (`STREAK_RESCUE_COST`).
   - It sets `coinState.streakCount` to `count + 1`.
   - It sets `coinState.streakDay` to the day of the 7-day cycle for the new count.
   - It raises `coinState.streakBest` if the new count is higher.
   - It removes `coinState.rescue`.
   - It sets `coinState.rescueLastAt` to the current time in milliseconds.
   - It writes one debit row to `coinTransactions` with the id `ctx_streakRescue_<uid>_<requestId>`, `action: streakRescue` and `reason: streak_rescue`.
4. The call returns `{success, changed, previousBalance, currentBalance, delta, streakCount, insufficientBalance, reason, transactionId}`.

A repeat call with the same `requestId` returns `success: true`, `reason: duplicate` and takes no coins.

### Refusal reasons

The call returns `success: false` with one of these `reason` values. It changes nothing.

| `reason` | Meaning |
|---|---|
| `streak_rescue_unavailable` | No rescue offer is stored. |
| `streak_rescue_expired` | The 48 hour window ended. |
| `streak_rescue_too_short` | The old streak was shorter than 7 days. |
| `streak_rescue_not_needed` | The current streak is already longer than the old streak. |
| `streak_rescue_cooldown` | The user bought a rescue less than 30 days ago. |
| `streak_rescue_insufficient_balance` | The balance is under 100 coins. `insufficientBalance` is `true`. |

## Limits

- The offer shows only in the claim sheet. If the user closes the sheet, the app has no other place to restore. The server still accepts a restore for 48 hours.
- The app does not read `coinState.rescueLastAt`. A user in the 30 day cooldown sees the offer and gets the cooldown toast when they tap Restore.
- The app shows a ledger label for `streakRescue` through the generic label rule ("Streak rescue").
- One rescue every 30 days.
- The coins already paid for the day of the break stay. The rescue does not pay them again.
- A rescue does not give back freezes the break used.

## How to test

1. Run `cd functions && npm run build && node --test 'lib/__tests__/coinsCallables.test.js' 'lib/__tests__/streak.test.js'`.
2. The tests cover: the offer after a break of 7 days or more, no offer for a shorter break, the paid restore, a repeat call, an expired window, a short streak, two rescues in 30 days, and a low balance.
3. App: run `fvm flutter test test/features/streak/streak_rescue_service_test.dart test/features/rewards/claim/streak_rescue_sheet_test.dart`. They cover the offer rule, the sheet variants, a low balance and `requestId` reuse.
4. Manual check after deploy: break a 10 day streak on a test account, claim the next day, then call `restoreStreak` and check `coinState` and the new ledger row.
