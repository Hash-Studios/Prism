# Coins and streak

Prism has a coin economy (`lib/core/coins`) and a daily streak (`lib/features/streak`). The `Streak` bottom-nav tab (`/dashboard/streak`, `StreakTabRoute`) and a standalone `/streak` route both lead to `lib/features/streak/views/pages/streak_page.dart` (app bar title `Daily streak`). A coin balance chip and a streak pill are shown elsewhere in the app (`lib/core/widgets/coins/coin_balance_chip.dart`, `streak_pill.dart`) and push `CoinTransactionsRoute` / `StreakRoute` on tap.

## Sub-features

- `coin-balance-chip`: accessibility label `$balance Prism coins`; tapping it opens `/coin-transactions` (`CoinTransactionsRoute`, `lib/features/session/views/pages/coin_transactions_screen.dart`).
- `streak-pill`: tapping it opens `/streak`.
- `streak-shop`: a shop for spending or earning coins/streak inside `streak_page.dart`, with earn actions `Watch a short video` (rewarded ad) and `Invite a friend` (referral).
- `streak-shop-loading` / `streak-shop-error`: `Loading streak shop` semantic label while loading; a `Try again` retry button on failure.
- `coin-transactions`: a list/history screen for coin earn/spend events.

## How to get to it (user POV)

- Tap the coin balance chip (wherever it appears, for example the AI wallpaper tab) to reach coin transaction history.
- Tap `Streak` in the bottom nav, or tap a streak pill, to reach the daily streak / streak shop screen.

## Driving it with the helper

Preconditions:

- Signed-in human for anything that actually earns or spends coins/streak against a real account. Read-only viewing of the streak screen and shop labels does not strictly need a session, but empty/zero state is expected when signed out.

- **Daily streak.** Tap `Streak`. Snapshot `--tag streak`. Assert the app bar title `Daily streak`.
- **Streak shop.** Assert `Watch a short video` and `Invite a friend` render as earn options. Do not actually tap `Watch a short video`; it plays a real rewarded ad unit (see `lib/features/ads`) and can affect real ad-network accounting. Do not tap `Invite a friend` and complete a real invite/referral without the human's go-ahead, since it can message or credit a real second account.
- **Coin balance → transactions.** Tap the coin balance chip. Snapshot `--tag coin-transactions`. Confirm the list renders (or an empty state, if the account has no history).
- **Loading / error.** If you can reproduce it, confirm the `Loading streak shop` state resolves, and that `Try again` recovers from a forced error (for example airplane mode).

## Gotchas

- Rewarded-ad and referral earn actions have real external side effects (ad SDK calls, referral crediting). Treat them like any other real-money-adjacent action: verify the button exists and is tappable, but do not complete the flow without the human's confirmation.
- `SKIP_FIREBASE_INIT=true` builds will not reflect real coin/streak state (that data is server-backed); use Doppler dev secrets when the recipe needs to see an actual balance or streak count change.
- The exact coin-earn/spend rules live in `lib/core/coins/coin_policy.dart` and `streak_shop_policy.dart`; read those if a proof needs to explain *why* a balance changed by a specific amount, not just that it changed.
