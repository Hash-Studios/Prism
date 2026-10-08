# Coins ledger (server rules)

The server owns coins. The app calls callables. Each coin change writes one row to `coinTransactions`. This page lists the rules for those rows.

## Where to find it

The rows show in the Activity list of the Rewards screen. The callables are in `functions/src/coinsCallables.ts`.

## Platforms and plans

| Platform | Free | Pro |
|---|---|---|
| Android and iOS | Pays coins | Skips the cost of downloads and premium filters only. Pays for AI generation. |

## How it works

### Spend: `spendCoins`

- `requestId` (optional) makes a retry safe. A repeat returns the first result and takes no coins.
- A repeat of a `requestId` whose first row was refunded returns `success: false` and `reason: spend_refunded`. It never charges again.
- `allowPremiumBypass` is honoured only for `wallpaperDownload`, `premiumWallpaperDownload` and `premiumFilter`. For `aiGeneration` and all other actions the server ignores it and charges.
- `label` (optional) is a string. The server trims it to 60 characters. It is stored as the row `description`. Without a label, `description` is the `reason`.

### Award: `awardCoins`

- Rewarded ad: the app can send `requestId`. The row id is `award_<uid>_<requestId>`. A repeat returns the first result (same balance and amount) and does not touch the daily ad counter.
- The rewarded ad answer has `adsRemaining`: the ads left today (20 a day, 20 seconds apart).
- Refund: `transactionId` names the debit row. Only the owner can refund. Only `wallpaperDownload`, `premiumWallpaperDownload` and `aiGeneration` debits can be refunded. The limit is 5 refunds a day.
- Refund window: 10 minutes after the debit.
- AI refund evidence: for an `aiGeneration` debit the server asks the AI worker `GET <base>/api/ai/charges/<transactionId>`. The base is `https://prismwalls.com`, or `AI_WORKER_BASE_URL` if set. The wait is 3 seconds.

| Worker answer | Result |
|---|---|
| `succeeded` | Refund refused: `reason: refund_denied_generation_succeeded`. |
| `failed` or `not_started` | Refund allowed for 24 hours after the debit. |
| No answer, an error, or an unknown shape | The 10 minute rule applies. |

- A debit with an unreadable `delta` is not refundable.

## Coin history screen (app)

The Rewards screen shows the 8 latest rows under Activity. "See all" and "Show more" open the full coin history.

- Route: `CoinHistoryRoute`, path `/coin-history`. Code: `lib/features/rewards/views/pages/coin_history_page.dart`.
- Data: `CoinHistoryRepository` in `lib/features/rewards/data/`. It reads `coinTransactions` for the signed-in user, newest first (`createdAt` descending), 40 rows a page. Source tag: `coin_history.page`. The index on `userId` and `createdAt` already exists.
- "Show more" at the end of the list reads the next page. The cursor is the last row shown.
- Each row shows the label, the `description` when it has one and differs from the label, the date, the amount with its sign, and "Balance N" from `balanceAfter`.
- Filter chips Earned, Spent and Refunds work on the rows already loaded. Tap the chip again to clear it. If a chip shows nothing and more rows exist, tap "Show more".
- Analytics: `coin_history_opened` when the screen opens.
- A download debit shows the wallpaper title only when the app sends a `label` with `spendCoins`. See "Spend".

## Related server jobs

- `syncSubscription`: a billing grace period that has not ended counts as active. A user stored as Free can sync again after 5 seconds. A user stored as Pro can sync again after 30 seconds.
- `reconcileSubscriptions`: runs every day at 02:30 UTC. It reads each user stored as premium and asks RevenueCat. It sets `premium` to `false` when the paid entitlement ended. It refreshes the tier. It never makes a Free user premium. If RevenueCat fails for a user, that user stays as stored.
- `deleteAccount`: also scrubs `walls` and `setups` of the creator name, photo and email. It deletes rejected walls and setups, notifications for the email, upload evidence, rate docs, and the legacy `users` and `tokens` docs. It removes the email from other users' `followers` and `following`. It clears `reporterEmail` on reports. The call can run for 300 seconds.
- `sendWinBackPushes`: skips a user when `usersv2/<uid>/private/session` has `marketingPushes: false`. The app does not write this field yet. Until it does, nobody is skipped.

## Limits

- The coin history screen filters only the rows it has loaded. It has no search and no date filter.
- The refund evidence needs the worker endpoint `GET /api/ai/charges/{txId}`. Until the worker ships it, the 10 minute rule applies to all AI refunds.
- The refund limit stays at 5 a day.
- `reconcileSubscriptions` does not replace a RevenueCat webhook. A change shows up at the next daily run or the next sync from the app.

## How to test

1. Run `cd functions && npm run build && node --test 'lib/__tests__/*.test.js'`.
2. The tests for this page are in `coinsCallables.test.ts`, `syncSubscription.test.ts`, `deleteAccount.test.ts` and `winBack.test.ts`.
3. App: run `fvm flutter test test/features/rewards/coin_history_test.dart test/features/rewards/sections/rewards_sections_test.dart`.
4. Manual: open Rewards, then Activity, then "See all". Check the rows, the chips and "Show more" with an account that has more than 40 rows.
